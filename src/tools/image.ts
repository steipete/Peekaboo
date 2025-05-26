import {
  ToolContext,
  ImageCaptureData,
  SavedFile,
  ToolResponse,
  ImageInput,
} from "../types/index.js";
import { executeSwiftCli, readImageAsBase64 } from "../utils/peekaboo-cli.js";
import { performAutomaticAnalysis } from "../utils/image-analysis.js";
import { buildImageSummary } from "../utils/image-summary.js";
import { buildSwiftCliArgs } from "../utils/image-cli-args.js";
import { parseAIProviders } from "../utils/ai-providers.js";
import * as fs from "fs/promises";
import * as pathModule from "path";
import * as os from "os";

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
    const swiftFormat = input.format === "data" ? "png" : (input.format || "png");

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

    const imageData = swiftResponse.data as ImageCaptureData | undefined;
    if (
      !imageData ||
      !imageData.saved_files ||
      imageData.saved_files.length === 0
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

    const captureData = imageData;
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

    const content: Array<{ type: "text" | "image"; text?: string; data?: string; mimeType?: string; metadata?: Record<string, unknown> }> = [];
    let summary = buildImageSummary(input, captureData, input.question);
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
