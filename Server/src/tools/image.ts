import * as path from "path";
import type { ImageCaptureData, ImageInput, SavedFile, ToolContext, ToolResponse } from "../types/index.js";
import { parseAIProviders } from "../utils/ai-providers.js";
import { getAIProvidersConfig } from "../utils/config-loader.js";
import { performAutomaticAnalysis } from "../utils/image-analysis.js";
import { buildSwiftCliArgs, resolveImagePath } from "../utils/image-cli-args.js";
import { buildImageSummary } from "../utils/image-summary.js";
import { executeSwiftCli, readImageAsBase64 } from "../utils/peekaboo-cli.js";

export { imageToolSchema } from "../types/index.js";

export async function imageToolHandler(input: ImageInput, context: ToolContext): Promise<ToolResponse> {
  const { logger } = context;
  let _tempDirUsed: string | undefined;
  let finalSavedFiles: SavedFile[] = [];
  let analysisAttempted = false;
  let analysisSucceeded = false;
  let analysisText: string | undefined;
  let modelUsed: string | undefined;

  try {
    logger.debug({ input }, "Processing peekaboo.image tool call");

    // Check if this is a screen capture
    const isScreenCapture = !input.app_target || input.app_target.startsWith("screen:");
    let formatWarning: string | undefined;

    // Format validation is now handled by the schema preprocessor
    // The format here is already normalized (lowercase, jpeg->jpg mapping applied)
    let effectiveFormat = input.format;

    // Check if format was corrected by the preprocessor
    const originalFormat = (input as ImageInput & { _originalFormat?: string })._originalFormat;
    if (originalFormat) {
      logger.info({ originalFormat, correctedFormat: effectiveFormat }, "Format was automatically corrected");
      formatWarning = `Invalid format '${originalFormat}' was provided. Automatically using ${effectiveFormat?.toUpperCase() || "PNG"} format instead.`;
    }

    // Defensive validation: ensure format is one of the valid values
    // This should not be necessary due to schema preprocessing, but provides extra safety
    const validFormats = ["png", "jpg", "data"];
    if (effectiveFormat && !validFormats.includes(effectiveFormat)) {
      logger.warn(
        { originalFormat: effectiveFormat, fallbackFormat: "png" },
        `Invalid format '${effectiveFormat}' detected, falling back to PNG`
      );
      effectiveFormat = "png";
      formatWarning = `Invalid format '${input.format}' was provided. Automatically using PNG format instead.`;
    }

    // Auto-fallback to PNG for screen captures with format 'data'
    if (isScreenCapture && effectiveFormat === "data") {
      logger.warn("Screen capture with format 'data' auto-fallback to PNG due to size constraints");
      effectiveFormat = "png";
      formatWarning =
        "Note: Screen captures cannot use format 'data' due to large image sizes that cause JavaScript stack overflow. Automatically using PNG format instead.";
    }

    // Determine effective path and format for Swift CLI
    const swiftFormat = effectiveFormat === "data" ? "png" : effectiveFormat || "png";

    // Create a corrected input object if format or path needs to be adjusted
    let correctedInput = input;

    // If format was corrected and we have a path, update the file extension to match the actual format
    if (input.format && input.format !== effectiveFormat && input.path) {
      const originalPath = input.path;
      const parsedPath = path.parse(originalPath);

      // Map format to appropriate extension
      const extensionMap: { [key: string]: string } = {
        png: ".png",
        jpg: ".jpg",
        jpeg: ".jpg",
        data: ".png", // data format saves as PNG
      };

      const newExtension = extensionMap[effectiveFormat || "png"] || ".png";
      const correctedPath = path.join(parsedPath.dir, parsedPath.name + newExtension);

      logger.debug(
        { originalPath, correctedPath, originalFormat: input.format, correctedFormat: effectiveFormat },
        "Correcting file extension to match format"
      );

      correctedInput = { ...input, path: correctedPath };
    }

    // Resolve the effective path using the centralized logic
    const { effectivePath, tempDirUsed: tempDir } = await resolveImagePath(correctedInput, logger);
    _tempDirUsed = tempDir;

    const args = buildSwiftCliArgs(correctedInput, effectivePath, swiftFormat, logger);

    const swiftResponse = await executeSwiftCli(args, logger, { timeout: 30000 });

    if (!swiftResponse.success) {
      logger.error({ error: swiftResponse.error }, "Swift CLI returned error for image capture");
      const errorMessage = swiftResponse.error?.message || "Unknown error";
      const errorDetails = swiftResponse.error?.details;
      const fullErrorMessage = errorDetails ? `${errorMessage}\n${errorDetails}` : errorMessage;

      return {
        content: [
          {
            type: "text",
            text: `Image capture failed: ${fullErrorMessage}`,
          },
        ],
        isError: true,
        _meta: { backend_error_code: swiftResponse.error?.code },
      };
    }

    const imageData = swiftResponse.data as ImageCaptureData | undefined;
    if (!imageData || !imageData.saved_files || imageData.saved_files.length === 0) {
      const errorMessage = [
        `Image capture failed. The tool tried to save the image to "${effectivePath}".`,
        "The operation did not complete successfully.",
        "Please check if you have write permissions for this location.",
      ].join(" ");
      logger.error({ path: effectivePath }, "Swift CLI reported success but no data/saved_files were returned.");
      return {
        content: [
          {
            type: "text",
            text: errorMessage,
          },
        ],
        isError: true,
        _meta: { backend_error_code: "INVALID_RESPONSE_NO_SAVED_FILES" },
      };
    }

    const captureData = imageData;

    // Always report all saved files
    finalSavedFiles = captureData.saved_files || [];

    if (input.question) {
      analysisAttempted = true;
      const analysisResults: Array<{ label: string; text: string }> = [];

      // Helper function to generate descriptive labels for analysis
      const getAnalysisLabel = (savedFile: SavedFile, isMultipleFiles: boolean): string => {
        if (!isMultipleFiles) {
          // For single files, use the item_label (app name or screen description)
          return savedFile.item_label || "Unknown";
        }

        // For multiple files, prefer window_title if available
        if (savedFile.window_title) {
          return `"${savedFile.window_title}"`;
        }

        // Fall back to item_label with window index if available
        if (savedFile.window_index !== undefined) {
          return `${savedFile.item_label || "Unknown"} (Window ${savedFile.window_index + 1})`;
        }

        return savedFile.item_label || "Unknown";
      };

      const aiProvidersConfig = await getAIProvidersConfig(logger);
      const configuredProviders = parseAIProviders(aiProvidersConfig || "");
      if (!configuredProviders.length) {
        analysisText =
          "Analysis skipped: AI analysis not configured on this server (PEEKABOO_AI_PROVIDERS is not set or empty).";
        logger.warn(analysisText);
      } else {
        // Iterate through all saved files for analysis
        const isMultipleFiles = captureData.saved_files.length > 1;
        for (const savedFile of captureData.saved_files) {
          const analysisLabel = getAnalysisLabel(savedFile, isMultipleFiles);

          try {
            const imageBase64 = await readImageAsBase64(savedFile.path);
            logger.debug({ path: savedFile.path }, "Image read successfully for analysis.");

            const analysisResult = await performAutomaticAnalysis(
              imageBase64,
              input.question,
              logger,
              aiProvidersConfig || ""
            );

            if (analysisResult.error) {
              analysisResults.push({
                label: analysisLabel,
                text: analysisResult.error,
              });
            } else {
              analysisResults.push({
                label: analysisLabel,
                text: analysisResult.analysisText || "",
              });
              modelUsed = analysisResult.modelUsed;
              analysisSucceeded = true;
              logger.info({ provider: modelUsed, path: savedFile.path }, "Image analysis successful");
            }
          } catch (readError) {
            logger.error({ error: readError, path: savedFile.path }, "Failed to read captured image for analysis");
            analysisResults.push({
              label: analysisLabel,
              text: `Analysis skipped: Failed to read captured image at ${savedFile.path}. Error: ${readError instanceof Error ? readError.message : "Unknown read error"}`,
            });
          }
        }

        // Format the analysis results
        if (analysisResults.length === 1) {
          analysisText = analysisResults[0].text;
        } else if (analysisResults.length > 1) {
          analysisText = analysisResults.map((result) => `Analysis for ${result.label}:\n${result.text}`).join("\n\n");
        }
      }
    }

    const content: Array<{
      type: "text" | "image";
      text?: string;
      data?: string;
      mimeType?: string;
      metadata?: Record<string, unknown>;
    }> = [];
    let summary = buildImageSummary(input, captureData, input.question);
    if (analysisAttempted) {
      summary += `\nAnalysis ${analysisSucceeded ? "succeeded" : "failed/skipped"}.`;
    }
    content.push({ type: "text", text: summary });

    // Add format warning if applicable
    if (formatWarning) {
      content.push({ type: "text", text: formatWarning });
    }

    if (analysisText) {
      content.push({ type: "text", text: `Analysis Result: ${analysisText}` });
    }

    // Return base64 data if:
    // 1. Format is explicitly 'data' (but not for screen captures which auto-fallback), OR
    // 2. No path was provided AND no question is asked
    const shouldReturnData = (effectiveFormat === "data" || !input.path) && !input.question && !isScreenCapture;

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
          logger.error({ error, path: savedFile.path }, "Failed to read image file for return_data");
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
      result._meta = { ...(result._meta || {}), analysis_error: analysisText };
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
  }
}
