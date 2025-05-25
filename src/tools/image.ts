import { z } from 'zod';
import { ToolContext, ImageCaptureData, SavedFile } from '../types/index.js';
import { executeSwiftCli, readImageAsBase64 } from '../utils/peekaboo-cli.js';

export const imageToolSchema = z.object({
  app: z.string().optional().describe("Optional. Target application: name, bundle ID, or partial name. If omitted, captures screen(s). Uses fuzzy matching."),
  path: z.string().optional().describe("Optional. Base absolute path for saving. For 'screen' or 'multi' mode, display/window info is appended by backend. If omitted, default temporary paths used by backend. If 'return_data' true, images saved AND returned if 'path' specified."),
  mode: z.enum(["screen", "window", "multi"]).optional().describe("Capture mode. Defaults to 'window' if 'app' is provided, otherwise 'screen'."),
  window_specifier: z.union([
    z.object({ title: z.string().describe("Capture window by title.") }),
    z.object({ index: z.number().int().nonnegative().describe("Capture window by index (0=frontmost). 'capture_focus' might need to be 'foreground'.") }),
  ]).optional().describe("Optional. Specifies which window for 'window' mode. Defaults to main/frontmost of target app."),
  format: z.enum(["png", "jpg"]).optional().default("png").describe("Output image format. Defaults to 'png'."),
  return_data: z.boolean().optional().default(false).describe("Optional. If true, image data is returned in response content (one item for 'window' mode, multiple for 'screen' or 'multi' mode)."),
  capture_focus: z.enum(["background", "foreground"]).optional().default("background").describe("Optional. Focus behavior. 'background' (default): capture without altering window focus. 'foreground': bring target to front before capture.")
});

export type ImageToolInput = z.infer<typeof imageToolSchema>;

export async function imageToolHandler(
  input: ImageToolInput,
  context: ToolContext
) {
  const { logger } = context;

  try {
    logger.debug({ input }, 'Processing peekaboo.image tool call');

    // Validate input and apply defaults
    const args = buildSwiftCliArgs(input);
    
    // Execute Swift CLI
    const swiftResponse = await executeSwiftCli(args, logger);
    
    if (!swiftResponse.success) {
      logger.error({ error: swiftResponse.error }, 'Swift CLI returned error');
      return {
        content: [{
          type: 'text',
          text: `Image capture failed: ${swiftResponse.error?.message || 'Unknown error'}`
        }],
        isError: true,
        _meta: {
          backend_error_code: swiftResponse.error?.code
        }
      };
    }

    // If success is true, data should be present
    if (!swiftResponse.data) {
      logger.error('Swift CLI reported success but no data was returned.');
      return {
        content: [{
          type: 'text',
          text: 'Image capture failed: Invalid response from capture utility (no data).'
        }],
        isError: true,
        _meta: {
          backend_error_code: 'INVALID_RESPONSE_NO_DATA'
        }
      };
    }
    
    const data = swiftResponse.data as ImageCaptureData;
    const content: any[] = [];

    // Check for errors related to the user-specified path if provided
    // The original logic relied on savedFile.error, which doesn't exist.
    // If the CLI fails to save to a user-specified path, it should ideally be reflected
    // in swiftResponse.success or swiftResponse.messages. For now, this specific check is removed.
    /*
    if (input.path && data.saved_files?.length > 0) {
      for (const savedFile of data.saved_files) {
        if (savedFile.path.startsWith(input.path) && savedFile.error) { // savedFile.error is the issue
          userPathSaveError = `Peekaboo Warning: Failed to save to user-specified path '${input.path}'. CLI Error: ${savedFile.error}`;
          logger.warn({ userPath: input.path, fileError: savedFile.error }, 'Error saving to user-specified path');
          break;
        }
      }
    }
    */
    
    // Add text summary
    const summary = generateImageCaptureSummary(data, input);
    content.push({
      type: 'text',
      text: summary
    });

    // If there was an error saving to the user-specified path, add it to the content
    // This part is removed as userPathSaveError logic is removed.
    /*
    if (userPathSaveError) {
      content.push({
        type: 'text',
        text: userPathSaveError
      });
    }
    */
    
    // Add image data if requested
    if (input.return_data && data.saved_files?.length > 0) {
      for (const savedFile of data.saved_files) {
        // If swiftResponse.success is true, assume individual files were processed correctly by CLI
        // unless specific messages indicate otherwise. The savedFile.error check is removed.
        /* 
        if (savedFile.error) { // savedFile.error is the issue
          logger.warn({ path: savedFile.path, error: savedFile.error }, 'Skipping base64 conversion for file with reported error by CLI');
          content.push({
            type: 'text',
            text: `Peekaboo Warning: Could not process file '${savedFile.path}' due to CLI error: ${savedFile.error}`
          });
          continue;
        }
        */
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
          logger.error({ error, path: savedFile.path }, 'Failed to read image file');
          content.push({
            type: 'text',
            text: `Warning: Could not read image data from ${savedFile.path}. Error: ${error instanceof Error ? error.message : 'Unknown error'}`
          });
        }
      }
    }
    
    // Add messages from Swift CLI if any
    if (swiftResponse.messages?.length) {
      content.push({
        type: 'text',
        text: `Messages: ${swiftResponse.messages.join('; ')}`
      });
    }
    
    return {
      content,
      saved_files: data.saved_files // Ensure this matches the expected return type, possibly ImageToolOutput
    };
    
  } catch (error) {
    logger.error({ error }, 'Unexpected error in image tool handler');
    return {
      content: [{
        type: 'text',
        text: `Unexpected error: ${error instanceof Error ? error.message : 'Unknown error'}`
      }],
      isError: true
    };
  }
}

export function buildSwiftCliArgs(input: ImageToolInput): string[] {
  const args = ['image'];
  
  // Determine mode
  let mode = input.mode;
  if (!mode) {
    mode = input.app ? 'window' : 'screen';
  }
  
  if (input.app) {
    args.push('--app', input.app);
  }
  
  let effectivePath = input.path;
  if (!effectivePath && process.env.PEEKABOO_DEFAULT_SAVE_PATH) {
    effectivePath = process.env.PEEKABOO_DEFAULT_SAVE_PATH;
  }

  if (effectivePath) {
    args.push('--path', effectivePath);
  }
  
  args.push('--mode', mode);
  
  if (input.window_specifier) {
    if ('title' in input.window_specifier) {
      args.push('--window-title', input.window_specifier.title);
    } else if ('index' in input.window_specifier) {
      args.push('--window-index', input.window_specifier.index.toString());
    }
  }
  
  args.push('--format', input.format);
  args.push('--capture-focus', input.capture_focus);
  
  return args;
}

function generateImageCaptureSummary(data: ImageCaptureData, input: ImageToolInput): string {
  const fileCount = data.saved_files?.length || 0;
  
  if (fileCount === 0) {
    return 'Image capture completed but no files were saved.';
  }
  
  const mode = input.mode || (input.app ? 'window' : 'screen');
  const target = input.app || 'screen';
  
  let summary = `Captured ${fileCount} image${fileCount > 1 ? 's' : ''} in ${mode} mode`;
  if (input.app) {
    summary += ` for application: ${target}`;
  }
  summary += '.';
  
  if (data.saved_files?.length) {
    summary += '\n\nSaved files:';
    data.saved_files.forEach((file, index) => {
      summary += `\n${index + 1}. ${file.path}`;
      if (file.item_label) {
        summary += ` (${file.item_label})`;
      }
    });
  }
  
  return summary;
} 