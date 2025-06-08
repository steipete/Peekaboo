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
import { buildSwiftCliArgs, resolveImagePath } from "../utils/image-cli-args.js";
import { parseAIProviders } from "../utils/ai-providers.js";

export { imageToolSchema } from "../types/index.js";

export async function imageToolHandler(
  input: ImageInput,
  context: ToolContext,
): Promise<ToolResponse> {
  const { logger } = context;
  let _tempDirUsed: string | undefined = undefined;
  let finalSavedFiles: SavedFile[] = [];
  let analysisAttempted = false;
  let analysisSucceeded = false;
  let analysisText: string | undefined = undefined;
  let modelUsed: string | undefined = undefined;

  try {
    logger.debug({ input }, "Processing peekaboo.image tool call");

    // Determine effective path and format for Swift CLI
    const swiftFormat = input.format === "data" ? "png" : (input.format || "png");

    // Resolve the effective path using the centralized logic
    const { effectivePath, tempDirUsed: tempDir } = await resolveImagePath(input, logger);
    _tempDirUsed = tempDir;

    const args = buildSwiftCliArgs(input, effectivePath, swiftFormat, logger);

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
      const errorMessage = [
        `Image capture failed. The tool tried to save the image to "${effectivePath}".`,
        "The operation did not complete successfully.",
        "Please check if you have write permissions for this location.",
      ].join(" ");
      logger.error(
        { path: effectivePath },
        "Swift CLI reported success but no data/saved_files were returned.",
      );
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

      const configuredProviders = parseAIProviders(
        process.env.PEEKABOO_AI_PROVIDERS || "",
      );
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
              process.env.PEEKABOO_AI_PROVIDERS || "",
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
            logger.error(
              { error: readError, path: savedFile.path },
              "Failed to read captured image for analysis",
            );
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
          analysisText = analysisResults
            .map(result => `Analysis for ${result.label}:\n${result.text}`)
            .join("\n\n");
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

    // Return base64 data if:
    // 1. Format is explicitly 'data', OR
    // 2. No path was provided AND no question is asked
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
  }
}
