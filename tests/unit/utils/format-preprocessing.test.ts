import { describe, it, expect } from "vitest";
import { buildSwiftCliArgs } from "../../../Server/src/utils/image-cli-args";

describe("Format Preprocessing in Swift CLI Args", () => {
  it("should use preprocessed format in Swift CLI arguments", async () => {
    // Import and test the schema preprocessing
    const { imageToolSchema } = await import("../../../Server/src/types/index");
    
    // Test that invalid format gets preprocessed correctly
    const inputWithInvalidFormat = { format: "bmp", path: "/tmp/test.png" };
    const preprocessedInput = imageToolSchema.parse(inputWithInvalidFormat);
    
    // Verify preprocessing worked
    expect(preprocessedInput.format).toBe("png");
    
    // Test that buildSwiftCliArgs uses the preprocessed format
    const swiftArgs = buildSwiftCliArgs(preprocessedInput, "/tmp/test.png");
    
    // Should contain --format png, not --format bmp
    expect(swiftArgs).toContain("--format");
    const formatIndex = swiftArgs.indexOf("--format");
    expect(swiftArgs[formatIndex + 1]).toBe("png");
    expect(swiftArgs).not.toContain("bmp");
  });
  
  it("should handle various invalid formats consistently", async () => {
    const { imageToolSchema } = await import("../../../Server/src/types/index");
    
    const invalidFormats = ["bmp", "gif", "webp", "tiff", "xyz"];
    
    for (const invalidFormat of invalidFormats) {
      const input = { format: invalidFormat, path: "/tmp/test.png" };
      const preprocessedInput = imageToolSchema.parse(input);
      
      // All should be preprocessed to png
      expect(preprocessedInput.format).toBe("png");
      
      const swiftArgs = buildSwiftCliArgs(preprocessedInput, "/tmp/test.png");
      const formatIndex = swiftArgs.indexOf("--format");
      
      // All should result in --format png
      expect(swiftArgs[formatIndex + 1]).toBe("png");
      expect(swiftArgs).not.toContain(invalidFormat);
    }
  });
  
  it("should pass through valid formats correctly", async () => {
    const { imageToolSchema } = await import("../../../Server/src/types/index");
    
    const validCases = [
      { input: "png", expected: "png" },
      { input: "PNG", expected: "png" },
      { input: "jpg", expected: "jpg" },
      { input: "JPG", expected: "jpg" },
      { input: "jpeg", expected: "jpg" },
      { input: "JPEG", expected: "jpg" },
    ];
    
    for (const { input, expected } of validCases) {
      const inputObj = { format: input, path: "/tmp/test.png" };
      const preprocessedInput = imageToolSchema.parse(inputObj);
      
      expect(preprocessedInput.format).toBe(expected);
      
      const swiftArgs = buildSwiftCliArgs(preprocessedInput, "/tmp/test.png");
      const formatIndex = swiftArgs.indexOf("--format");
      
      expect(swiftArgs[formatIndex + 1]).toBe(expected);
    }
  });
  
  it("should handle data format for Swift CLI (converts to png)", async () => {
    const { imageToolSchema } = await import("../../../Server/src/types/index");
    
    const input = { format: "data", path: "/tmp/test.png" };
    const preprocessedInput = imageToolSchema.parse(input);
    
    expect(preprocessedInput.format).toBe("data");
    
    // buildSwiftCliArgs should convert data format to png for Swift CLI
    const swiftArgs = buildSwiftCliArgs(preprocessedInput, "/tmp/test.png");
    const formatIndex = swiftArgs.indexOf("--format");
    
    // Should be converted to png for Swift CLI
    expect(swiftArgs[formatIndex + 1]).toBe("png");
  });
});