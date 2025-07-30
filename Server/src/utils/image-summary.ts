import type { ImageCaptureData, ImageInput } from "../types/index.js";

export function buildImageSummary(input: ImageInput, data: ImageCaptureData, question?: string): string {
  if (!data.saved_files || data.saved_files.length === 0) {
    return "Image capture completed but no files were saved or available for analysis.";
  }

  // Determine mode and target from app_target (removed since we're not using them anymore)
  // The summary now just shows the count of images captured

  // Generate summary matching the expected format
  const imageCount = data.saved_files.length;
  let summary = `Captured ${imageCount} image${imageCount > 1 ? "s" : ""}`;

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
