import {
  ToolContext,
  ImageCaptureData,
  SavedFile,
  ToolResponse,
  AIProvider,
  ImageInput,
  imageToolSchema,
} from "../types/index.js";
import { executeSwiftCli, readImageAsBase64 } from "../utils/peekaboo-cli.js";
import {
  parseAIProviders,
  analyzeImageWithProvider,
} from "../utils/ai-providers.js";
import * as fs from "fs/promises";
import * as pathModule from "path";
import * as os from "os";
import { Logger } from "pino";

export { imageToolSchema } from "../types/index.js";

export async function imageToolHandler(
  input: ImageInput,
  context: ToolContext,
): Promise<ToolResponse> {
  const { logger } = context;
  let tempImagePathUsed: string | undefined = undefined;
  let finalSavedFiles: SavedFile[] = [];
  let analysisAttempted = false;
  let analysisSucceeded = false;
  let analysisText: string | undefined = undefined;
  let modelUsed: string | undefined = undefined;

  try {
    logger.debug({ input }, "Processing peekaboo.image tool call");

    // Determine effective path and format for Swift CLI
    let effectivePath = input.path;
    let swiftFormat = input.format === "data" ? "png" : (input.format || "png");
    
    // Create temporary path if needed for analysis or data return without path
    const needsTempPath = (input.question && !input.path) || (!input.path && input.format === "data") || (!input.path && !input.format);
    if (needsTempPath) {
      const tempDir = await fs.mkdtemp(
        pathModule.join(os.tmpdir(), "peekaboo-img-"),
      );
      tempImagePathUsed = pathModule.join(
        tempDir,
        `capture.${swiftFormat}`,
      );
      effectivePath = tempImagePathUsed;
      logger.debug(
        { tempPath: tempImagePathUsed },
        "Using temporary path for capture.",
      );
    }

    const args = buildSwiftCliArgs(input, logger, effectivePath, swiftFormat);

    const swiftResponse = await executeSwiftCli(args, logger);

    if (!swiftResponse.success) {
      logger.error(
        { error: swiftResponse.error },
        "Swift CLI returned error for image capture",
      );
      return {
        content: [
          {
            type: "text",
            text: `Image capture failed: ${swiftResponse.error?.message || "Unknown error"}`,
          },
        ],
        isError: true,
        _meta: { backend_error_code: swiftResponse.error?.code },
      };
    }

    if (
      !swiftResponse.data ||
      !swiftResponse.data.saved_files ||
      swiftResponse.data.saved_files.length === 0
    ) {
      logger.error(
        "Swift CLI reported success but no data/saved_files were returned.",
      );
      return {
        content: [
          {
            type: "text",
            text: "Image capture failed: Invalid response from capture utility (no saved files data).",
          },
        ],
        isError: true,
        _meta: { backend_error_code: "INVALID_RESPONSE_NO_SAVED_FILES" },
      };
    }

    const captureData = swiftResponse.data as ImageCaptureData;
    const imagePathForAnalysis = captureData.saved_files[0].path;
    
    // Determine which files to report as saved
    if (input.question && tempImagePathUsed) {
      // Analysis with temp path - don't include in saved_files
      finalSavedFiles = [];
    } else if (!input.path && (input.format === "data" || !input.format)) {
      // Data format without path - don't include in saved_files
      finalSavedFiles = [];
    } else {
      // User provided path or default save behavior - include in saved_files
      finalSavedFiles = captureData.saved_files || [];
    }

    let imageBase64ForAnalysis: string | undefined;
    if (input.question) {
      analysisAttempted = true;
      try {
        imageBase64ForAnalysis = await readImageAsBase64(imagePathForAnalysis);
        logger.debug("Image read successfully for analysis.");
      } catch (readError) {
        logger.error(
          { error: readError, path: imagePathForAnalysis },
          "Failed to read captured image for analysis",
        );
        analysisText = `Analysis skipped: Failed to read captured image at ${imagePathForAnalysis}. Error: ${readError instanceof Error ? readError.message : "Unknown read error"}`;
      }

      if (imageBase64ForAnalysis) {
        const configuredProviders = parseAIProviders(
          process.env.PEEKABOO_AI_PROVIDERS || "",
        );
        if (!configuredProviders.length) {
          analysisText =
            "Analysis skipped: AI analysis not configured on this server (PEEKABOO_AI_PROVIDERS is not set or empty).";
          logger.warn(analysisText);
        } else {
          const analysisResult = await performAutomaticAnalysis(
            imageBase64ForAnalysis,
            input.question,
            logger,
            process.env.PEEKABOO_AI_PROVIDERS || "",
          );
          
          if (analysisResult.error) {
            analysisText = analysisResult.error;
          } else {
            analysisText = analysisResult.analysisText;
            modelUsed = analysisResult.modelUsed;
            analysisSucceeded = true;
            logger.info({ provider: modelUsed }, "Image analysis successful");
          }
        }
      }
    }

    const content: any[] = [];
    let summary = generateImageCaptureSummary(captureData, input);
    if (analysisAttempted) {
      summary += `\nAnalysis ${analysisSucceeded ? "succeeded" : "failed/skipped"}.`;
    }
    content.push({ type: "text", text: summary });

    if (analysisText) {
      content.push({ type: "text", text: `Analysis Result: ${analysisText}` });
    }

    // Return base64 data if format is 'data' or path not provided (and no question)
    const shouldReturnData = (input.format === "data" || !input.path) && !input.question;
    
    if (shouldReturnData && captureData.saved_files?.length > 0) {
      for (const savedFile of captureData.saved_files) {
        try {
          const imageBase64 = await readImageAsBase64(savedFile.path);
          content.push({
            type: "image",
            data: imageBase64,
            mimeType: savedFile.mime_type,
            metadata: {
              item_label: savedFile.item_label,
              window_title: savedFile.window_title,
              window_id: savedFile.window_id,
              source_path: savedFile.path,
            },
          });
        } catch (error) {
          logger.error(
            { error, path: savedFile.path },
            "Failed to read image file for return_data",
          );
        }
      }
    }

    if (swiftResponse.messages?.length) {
      content.push({
        type: "text",
        text: `Capture Messages: ${swiftResponse.messages.join("; ")}`,
      });
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
    logger.error({ error }, "Unexpected error in image tool handler");
    return {
      content: [
        {
          type: "text",
          text: `Unexpected error: ${error instanceof Error ? error.message : "Unknown error"}`,
        },
      ],
      isError: true,
      _meta: { backend_error_code: "UNEXPECTED_HANDLER_ERROR" },
    };
  } finally {
    if (tempImagePathUsed) {
      logger.debug(
        { tempPath: tempImagePathUsed },
        "Attempting to delete temporary image file.",
      );
      try {
        await fs.unlink(tempImagePathUsed);
        const tempDir = pathModule.dirname(tempImagePathUsed);
        await fs.rmdir(tempDir);
        logger.info(
          { tempPath: tempImagePathUsed },
          "Temporary image file and directory deleted.",
        );
      } catch (cleanupError) {
        logger.warn(
          { error: cleanupError, path: tempImagePathUsed },
          "Failed to delete temporary image file or directory.",
        );
      }
    }
  }
}

export function buildSwiftCliArgs(
  input: ImageInput,
  logger?: Logger,
  effectivePath?: string | undefined,
  swiftFormat?: string,
): string[] {
  const args = ["image"];
  
  // Use provided values or derive from input
  const actualPath = effectivePath !== undefined ? effectivePath : input.path;
  const actualFormat = swiftFormat || (input.format === "data" ? "png" : input.format) || "png";
  
  // Create a logger if not provided (for backward compatibility)
  const log = logger || { 
    warn: () => {}, 
    error: () => {}, 
    debug: () => {} 
  } as any;

  // Parse app_target to determine Swift CLI arguments
  if (!input.app_target || input.app_target === "") {
    // Omitted/empty: All screens
    args.push("--mode", "screen");
  } else if (input.app_target.startsWith("screen:")) {
    // 'screen:INDEX': Specific display
    const screenIndex = input.app_target.substring(7);
    args.push("--mode", "screen");
    // Note: --screen-index is not yet implemented in Swift CLI
    // For now, we'll just use screen mode without index
    log.warn(
      { screenIndex },
      "Screen index specification not yet supported by Swift CLI, capturing all screens",
    );
  } else if (input.app_target === "frontmost") {
    // 'frontmost': Would need to determine frontmost app
    // For now, default to screen mode with a warning
    log.warn(
      "'frontmost' target requires determining current frontmost app, defaulting to screen mode",
    );
    args.push("--mode", "screen");
  } else if (input.app_target.includes(":")) {
    // 'AppName:WINDOW_TITLE:Title' or 'AppName:WINDOW_INDEX:Index'
    const parts = input.app_target.split(":");
    if (parts.length >= 3) {
      const appName = parts[0];
      const specifierType = parts[1];
      const specifierValue = parts.slice(2).join(":"); // Handle colons in window titles
      
      args.push("--app", appName);
      args.push("--mode", "window");
      
      if (specifierType === "WINDOW_TITLE") {
        args.push("--window-title", specifierValue);
      } else if (specifierType === "WINDOW_INDEX") {
        args.push("--window-index", specifierValue);
      } else {
        log.warn(
          { specifierType },
          "Unknown window specifier type, defaulting to main window",
        );
      }
    } else {
      log.error(
        { app_target: input.app_target },
        "Invalid app_target format",
      );
      args.push("--mode", "screen");
    }
  } else {
    // 'AppName': All windows of the app
    args.push("--app", input.app_target);
    args.push("--mode", "multi");
  }

  // Add path if provided
  if (actualPath) {
    args.push("--path", actualPath);
  } else if (process.env.PEEKABOO_DEFAULT_SAVE_PATH) {
    args.push("--path", process.env.PEEKABOO_DEFAULT_SAVE_PATH);
  }

  // Add format
  args.push("--format", actualFormat);

  // Add capture focus
  args.push("--capture-focus", input.capture_focus || "background");

  return args;
}

function generateImageCaptureSummary(
  data: ImageCaptureData,
  input: ImageInput,
): string {
  const fileCount = data.saved_files?.length || 0;

  if (
    fileCount === 0 &&
    !(input.question && data.saved_files && data.saved_files.length > 0)
  ) {
    return "Image capture completed but no files were saved or available for analysis.";
  }

  // Determine mode and target from app_target
  let mode = "screen";
  let target = "screen";
  
  if (input.app_target) {
    if (input.app_target.startsWith("screen:")) {
      mode = "screen";
      target = input.app_target;
    } else if (input.app_target === "frontmost") {
      mode = "screen"; // defaulted to screen
      target = "frontmost application";
    } else if (input.app_target.includes(":")) {
      mode = "window";
      target = input.app_target.split(":")[0];
    } else {
      mode = "multi";
      target = input.app_target;
    }
  }

  let summary = `Captured ${fileCount} image${fileCount > 1 ? "s" : ""} in ${mode} mode`;
  if (input.app_target && target !== "screen") {
    summary += ` for ${target}`;
  }
  summary += ".";

  if (data.saved_files?.length && !(input.question && !input.path)) {
    summary += "\n\nSaved files:";
    data.saved_files.forEach((file, index) => {
      summary += `\n${index + 1}. ${file.path}`;
      if (file.item_label) {
        summary += ` (${file.item_label})`;
      }
    });
  } else if (input.question && input.path && data.saved_files?.length) {
    summary += `\nImage saved to: ${data.saved_files[0].path}`;
  } else if (input.question && data.saved_files?.length) {
    summary += `\nImage captured to temporary location for analysis.`;
  }

  return summary;
}

async function performAutomaticAnalysis(
  base64Image: string,
  question: string,
  logger: Logger,
  availableProvidersEnv: string,
): Promise<{
  analysisText?: string;
  modelUsed?: string;
  error?: string;
}> {
  const providers = parseAIProviders(availableProvidersEnv);
  
  if (!providers.length) {
    return {
      error: "Analysis skipped: No AI providers configured",
    };
  }
  
  // Try each provider in order until one succeeds
  for (const provider of providers) {
    try {
      logger.debug(
        { provider: `${provider.provider}/${provider.model}` },
        "Attempting analysis with provider",
      );
      
      // Create a temporary file for the provider (some providers need file paths)
      const tempDir = await fs.mkdtemp(
        pathModule.join(os.tmpdir(), "peekaboo-analysis-"),
      );
      const tempPath = pathModule.join(tempDir, "image.png");
      const imageBuffer = Buffer.from(base64Image, "base64");
      await fs.writeFile(tempPath, imageBuffer);
      
      try {
        const analysisText = await analyzeImageWithProvider(
          provider,
          tempPath,
          base64Image,
          question,
          logger,
        );
        
        // Clean up temp file
        await fs.unlink(tempPath);
        await fs.rmdir(tempDir);
        
        return {
          analysisText,
          modelUsed: `${provider.provider}/${provider.model}`,
        };
      } finally {
        // Ensure cleanup even if analysis fails
        try {
          await fs.unlink(tempPath);
          await fs.rmdir(tempDir);
        } catch (cleanupError) {
          logger.debug({ error: cleanupError }, "Failed to clean up analysis temp file");
        }
      }
    } catch (error) {
      logger.debug(
        { error, provider: `${provider.provider}/${provider.model}` },
        "Provider failed, trying next",
      );
      // Continue to next provider
    }
  }
  
  return {
    error: "Analysis failed: All configured AI providers failed or are unavailable",
  };
}
