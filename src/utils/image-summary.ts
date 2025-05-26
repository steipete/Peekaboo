import { ImageInput, ImageCaptureData } from "../types/index.js";

export function buildImageSummary(
  input: ImageInput,
  data: ImageCaptureData,
  question?: string,
): string {
  if (!data.saved_files || data.saved_files.length === 0) {
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
      // Contains window specifier
      const parts = input.app_target.split(":");
      target = parts[0]; // app name
      mode = "window";
    } else {
      // Just app name, all windows
      target = input.app_target;
      mode = "all windows";
    }
  }

  // Generate summary matching the expected format
  const imageCount = data.saved_files.length;
  let summary = `Captured ${imageCount} image${imageCount > 1 ? 's' : ''}`;

  if (data.saved_files.length === 1) {
    if (!question || (question && input.path)) {
      // Show path if no question or if question with explicit path
      summary += `\nImage saved to: ${data.saved_files[0].path}`;
    }
  } else if (data.saved_files.length > 1) {
    summary += `\n${data.saved_files.length} images saved:`;
    data.saved_files.forEach((file, index) => {
      summary += `\n${index + 1}. ${file.path}`;
      if (file.item_label) {
        summary += ` (${file.item_label})`;
      }
    });
  } else if (input.question && input.path && data.saved_files?.length) {
    summary += `\nImage saved to: ${data.saved_files[0].path}`;
  } else if (input.question && data.saved_files?.length) {
    summary += "\nImage captured to temporary location for analysis.";
  }

  return summary;
}