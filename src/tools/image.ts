import { z } from 'zod';
import { ToolContext, ImageCaptureData, SavedFile, AIProviderConfig, ToolResponse, AIProvider } from '../types/index.js';
import { executeSwiftCli, readImageAsBase64 } from '../utils/peekaboo-cli.js';
import { determineProviderAndModel, analyzeImageWithProvider, parseAIProviders, isProviderAvailable } from '../utils/ai-providers.js';
import * as fs from 'fs/promises';
import * as pathModule from 'path';
import * as os from 'os';

export const imageToolSchema = z.object({
  app: z.string().optional().describe("Optional. Target application: name, bundle ID, or partial name. If omitted, captures screen(s). Uses fuzzy matching."),
  path: z.string().optional().describe("Optional. Base absolute path for saving. For 'screen' or 'multi' mode, display/window info is appended by backend. If omitted, default temporary paths used by backend. If 'return_data' true, images saved AND returned if 'path' specified."),
  mode: z.enum(["screen", "window", "multi"]).optional().describe("Capture mode. Defaults to 'window' if 'app' is provided, otherwise 'screen'."),
  window_specifier: z.union([
    z.object({ title: z.string().describe("Capture window by title.") }),
    z.object({ index: z.number().int().nonnegative().describe("Capture window by index (0=frontmost). 'capture_focus' might need to be 'foreground'.") }),
  ]).optional().describe("Optional. Specifies which window for 'window' mode. Defaults to main/frontmost of target app."),
  format: z.enum(["png", "jpg"]).optional().default("png").describe("Output image format. Defaults to 'png'."),
  return_data: z.boolean().optional().default(false).describe("Optional. If true, image data is returned in response content (one item for 'window' mode, multiple for 'screen' or 'multi' mode). If 'question' is provided, 'base64_data' is NOT returned regardless of this flag."),
  capture_focus: z.enum(["background", "foreground"]).optional().default("background").describe("Optional. Focus behavior. 'background' (default): capture without altering window focus. 'foreground': bring target to front before capture."),
  question: z.string().optional().describe("If provided, the captured image will be analyzed using this question. Analysis results will be added to the output."),
  provider_config: z.custom<AIProviderConfig>().optional().describe("AI provider configuration for analysis (e.g., { type: 'ollama', model: 'llava' }). If not provided, uses server default configuration for analysis. Refer to 'analyze' tool schema for structure.")
});

export type ImageToolInput = z.infer<typeof imageToolSchema>;

export async function imageToolHandler(
  input: ImageToolInput,
  context: ToolContext
): Promise<ToolResponse> {
  const { logger } = context;
  let tempImagePathUsed: string | undefined = undefined;
  let finalSavedFiles: SavedFile[] = [];
  let analysisAttempted = false;
  let analysisSucceeded = false;
  let analysisText: string | undefined = undefined;
  let modelUsed: string | undefined = undefined;

  try {
    logger.debug({ input }, 'Processing peekaboo.image tool call');

    let effectivePath = input.path;
    if (input.question && !input.path) {
      const tempDir = await fs.mkdtemp(pathModule.join(os.tmpdir(), 'peekaboo-img-'));
      tempImagePathUsed = pathModule.join(tempDir, `capture.${input.format || 'png'}`);
      effectivePath = tempImagePathUsed;
      logger.debug({ tempPath: tempImagePathUsed }, 'Using temporary path for capture as question is provided and no path specified.');
    }

    const cliInput = { ...input, path: effectivePath };
    const args = buildSwiftCliArgs(cliInput);
    
    const swiftResponse = await executeSwiftCli(args, logger);
    
    if (!swiftResponse.success) {
      logger.error({ error: swiftResponse.error }, 'Swift CLI returned error for image capture');
      return {
        content: [{
          type: 'text',
          text: `Image capture failed: ${swiftResponse.error?.message || 'Unknown error'}`
        }],
        isError: true,
        _meta: { backend_error_code: swiftResponse.error?.code }
      };
    }

    if (!swiftResponse.data || !swiftResponse.data.saved_files || swiftResponse.data.saved_files.length === 0) {
      logger.error('Swift CLI reported success but no data/saved_files were returned.');
      return {
        content: [{
          type: 'text',
          text: 'Image capture failed: Invalid response from capture utility (no saved files data).'
        }],
        isError: true,
        _meta: { backend_error_code: 'INVALID_RESPONSE_NO_SAVED_FILES' }
      };
    }
    
    const captureData = swiftResponse.data as ImageCaptureData;
    const imagePathForAnalysis = captureData.saved_files[0].path; 
    finalSavedFiles = input.question && tempImagePathUsed ? [] : captureData.saved_files || [];

    let imageBase64ForAnalysis: string | undefined;
    if (input.question) {
      analysisAttempted = true;
      try {
        imageBase64ForAnalysis = await readImageAsBase64(imagePathForAnalysis);
        logger.debug('Image read successfully for analysis.');
      } catch (readError) {
        logger.error({ error: readError, path: imagePathForAnalysis }, 'Failed to read captured image for analysis');
        analysisText = `Analysis skipped: Failed to read captured image at ${imagePathForAnalysis}. Error: ${readError instanceof Error ? readError.message : 'Unknown read error'}`;
      }

      if (imageBase64ForAnalysis) {
        const configuredProviders = parseAIProviders(process.env.PEEKABOO_AI_PROVIDERS || '');
        if (!configuredProviders.length && !input.provider_config) {
            analysisText = "Analysis skipped: AI analysis not configured on this server (PEEKABOO_AI_PROVIDERS is not set or empty) and no specific provider was requested.";
            logger.warn(analysisText);
        } else {
            try {
                const providerDetails = await determineProviderAndModel(input.provider_config, configuredProviders, logger);

                if (!providerDetails.provider) {
                    analysisText = "Analysis skipped: No AI providers are currently operational or configured for the request.";
                    logger.warn(analysisText);
                } else {
                    analysisText = await analyzeImageWithProvider(
                        providerDetails as AIProvider,
                        imagePathForAnalysis,
                        imageBase64ForAnalysis,
                        input.question,
                        logger
                    );
                    modelUsed = `${providerDetails.provider}/${providerDetails.model}`;
                    analysisSucceeded = true;
                    logger.info({ provider: modelUsed }, 'Image analysis successful');
                }
            } catch (aiError) {
                logger.error({ error: aiError }, 'AI analysis failed');
                analysisText = `AI analysis failed: ${aiError instanceof Error ? aiError.message : 'Unknown AI error'}`;
            }
        }
      }
    }
    
    const content: any[] = [];
    let summary = generateImageCaptureSummary(captureData, input);
    if (analysisAttempted) {
      summary += `\nAnalysis ${analysisSucceeded ? 'succeeded' : 'failed/skipped'}.`;
    }
    content.push({ type: 'text', text: summary });

    if (analysisText) {
      content.push({ type: 'text', text: `Analysis Result: ${analysisText}` });
    }
    
    if (input.return_data && !input.question && captureData.saved_files?.length > 0) {
      for (const savedFile of captureData.saved_files) {
        try {
          const imageBase64 = await readImageAsBase64(savedFile.path);
          content.push({
            type: 'image',
            data: imageBase64,
            mimeType: savedFile.mime_type,
            metadata: {
              item_label: savedFile.item_label,
              window_title: savedFile.window_title,
              window_id: savedFile.window_id,
              source_path: savedFile.path
            }
          });
        } catch (error) {
          logger.error({ error, path: savedFile.path }, 'Failed to read image file for return_data');
        }
      }
    }
    
    if (swiftResponse.messages?.length) {
      content.push({ type: 'text', text: `Capture Messages: ${swiftResponse.messages.join('; ')}` });
    }
    
    const result: ToolResponse = {
      content,
      saved_files: finalSavedFiles,
    };

    if (analysisAttempted) {
      result.analysis_text = analysisText;
      result.model_used = modelUsed;
    }
    if (!analysisSucceeded && analysisAttempted) {
        result.isError = true;
        result._meta = { ...result._meta, analysis_error: analysisText };
    }

    return result;
    
  } catch (error) {
    logger.error({ error }, 'Unexpected error in image tool handler');
    return {
      content: [{
        type: 'text',
        text: `Unexpected error: ${error instanceof Error ? error.message : 'Unknown error'}`
      }],
      isError: true,
      _meta: { backend_error_code: 'UNEXPECTED_HANDLER_ERROR' }
    };
  } finally {
    if (tempImagePathUsed) {
      logger.debug({ tempPath: tempImagePathUsed }, 'Attempting to delete temporary image file.');
      try {
        await fs.unlink(tempImagePathUsed);
        const tempDir = pathModule.dirname(tempImagePathUsed);
        await fs.rmdir(tempDir);
        logger.info({ tempPath: tempImagePathUsed }, 'Temporary image file and directory deleted.');
      } catch (cleanupError) {
        logger.warn({ error: cleanupError, path: tempImagePathUsed }, 'Failed to delete temporary image file or directory.');
      }
    }
  }
}

export function buildSwiftCliArgs(input: ImageToolInput): string[] {
  const args = ['image'];
  
  let mode = input.mode;
  if (!mode) {
    mode = input.app ? 'window' : 'screen';
  }
  
  if (input.app) {
    args.push('--app', input.app);
  }
  
  if (input.path) { 
    args.push('--path', input.path);
  } else if (process.env.PEEKABOO_DEFAULT_SAVE_PATH && !input.question) {
    args.push('--path', process.env.PEEKABOO_DEFAULT_SAVE_PATH);
  }
  
  args.push('--mode', mode);
  
  if (input.window_specifier) {
    if ('title' in input.window_specifier) {
      args.push('--window-title', input.window_specifier.title);
    } else if ('index' in input.window_specifier) {
      args.push('--window-index', input.window_specifier.index.toString());
    }
  }
  
  args.push('--format', input.format!);
  args.push('--capture-focus', input.capture_focus!);
  
  return args;
}

function generateImageCaptureSummary(data: ImageCaptureData, input: ImageToolInput): string {
  const fileCount = data.saved_files?.length || 0;
  
  if (fileCount === 0 && !(input.question && data.saved_files && data.saved_files.length > 0)) {
    return 'Image capture completed but no files were saved or available for analysis.';
  }
  
  const mode = input.mode || (input.app ? 'window' : 'screen');
  const target = input.app || 'screen';
  
  let summary = `Captured ${fileCount} image${fileCount > 1 ? 's' : ''} in ${mode} mode`;
  if (input.app) {
    summary += ` for application: ${target}`;
  }
  summary += '.';
  
  if (data.saved_files?.length && !(input.question && !input.path)) {
    summary += '\n\nSaved files:';
    data.saved_files.forEach((file, index) => {
      summary += `\n${index + 1}. ${file.path}`;
      if (file.item_label) {
        summary += ` (${file.item_label})`;
      }
    });
  } else if (input.question && input.path && data.saved_files?.length){
    summary += `\nImage saved to: ${data.saved_files[0].path}`;
  } else if (input.question && data.saved_files?.length) {
    summary += `\nImage captured to temporary location for analysis.`;
  }
  
  return summary;
} 