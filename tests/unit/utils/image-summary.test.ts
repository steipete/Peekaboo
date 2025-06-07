import { describe, it, expect } from "vitest";
import { buildImageSummary } from "../../../src/utils/image-summary";
import { ImageInput, ImageCaptureData } from "../../../src/types";

describe("buildImageSummary", () => {
  it("should return a message if no files were saved", () => {
    const input: ImageInput = { capture_focus: "background" };
    const data: ImageCaptureData = { saved_files: [] };
    const summary = buildImageSummary(input, data);
    expect(summary).toBe(
      "Image capture completed but no files were saved or available for analysis.",
    );
  });

  it("should generate a summary for a single saved file without a question", () => {
    const input: ImageInput = {
      path: "/path/to/image.png",
      capture_focus: "background",
    };
    const data: ImageCaptureData = {
      saved_files: [{ path: "/path/to/image.png", mime_type: "image/png" }],
    };
    const summary = buildImageSummary(input, data);
    expect(summary).toBe(
      "Captured 1 image\nImage saved to: /path/to/image.png",
    );
  });

  it("should generate a summary for a single saved file with a question and path", () => {
    const input: ImageInput = {
      path: "/path/to/image.png",
      capture_focus: "background",
    };
    const data: ImageCaptureData = {
      saved_files: [{ path: "/path/to/image.png", mime_type: "image/png" }],
    };
    const summary = buildImageSummary(input, data, "What is this?");
    expect(summary).toBe(
      "Captured 1 image\nImage saved to: /path/to/image.png",
    );
  });

  it("should generate a summary for a single temporary file with a question", () => {
    const input: ImageInput = { capture_focus: "background" };
    const data: ImageCaptureData = {
      saved_files: [{ path: "/tmp/image.png", mime_type: "image/png" }],
    };
    const summary = buildImageSummary(input, data, "What is this?");
    expect(summary).toBe("Captured 1 image");
  });

  it("should generate a summary for multiple saved files", () => {
    const input: ImageInput = {
      path: "/path/to/",
      capture_focus: "background",
    };
    const data: ImageCaptureData = {
      saved_files: [
        { path: "/path/to/image1.png", mime_type: "image/png" },
        {
          path: "/path/to/image2.png",
          mime_type: "image/png",
          item_label: "Finder",
        },
      ],
    };
    const summary = buildImageSummary(input, data);
    expect(summary).toBe(
      "Captured 2 images\n2 images saved:\n1. /path/to/image1.png\n2. /path/to/image2.png (Finder)",
    );
  });
}); 