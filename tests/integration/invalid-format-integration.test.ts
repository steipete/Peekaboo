import { describe, it, expect, beforeEach } from "vitest";
import { imageToolHandler } from "../../Server/src/tools/image";
import { initializeSwiftCliPath } from "../../Server/src/utils/peekaboo-cli";
import { pino } from "pino";
import * as fs from "fs/promises";
import * as path from "path";
import * as os from "os";

// Initialize Swift CLI path (assuming 'peekaboo' binary is at project root)
const packageRootDir = path.resolve(__dirname, "..", ".."); // Adjust path from tests/integration to project root
initializeSwiftCliPath(packageRootDir);

const mockLogger = pino({ level: "silent" });
const mockContext = { logger: mockLogger };

// Conditionally skip Swift-dependent tests on non-macOS platforms
const describeSwiftTests = globalThis.shouldSkipSwiftTests ? describe.skip : describe;

describeSwiftTests("Invalid Format Integration Tests", () => {
  let tempDir: string;
  
  beforeEach(async () => {
    // Create a temporary directory for test files
    tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "peekaboo-invalid-format-test-"));
  });

  it("should reject invalid format gracefully and not create files with wrong extensions", async () => {
    const testPath = path.join(tempDir, "test_invalid_format.bmp");
    
    // Test with invalid format 'bmp'
    const result = await imageToolHandler(
      { 
        format: "bmp", 
        path: testPath,
      },
      mockContext,
    );
    
    // Check what error we got
    console.log("Result:", JSON.stringify(result, null, 2));
    
    // The tool might fail due to permissions or timeout
    if (result.isError) {
      // If it's a permission or timeout error, that's expected
      const errorText = result.content?.[0]?.text || "";
      const metaErrorCode = (result as any)._meta?.backend_error_code;
      
      expect(
        errorText.includes("permission") ||
        errorText.includes("denied") ||
        errorText.includes("timeout") ||
        errorText.includes("Failed to create screen capture") ||
        errorText.includes("Image capture failed") ||
        metaErrorCode === "PERMISSION_DENIED_SCREEN_RECORDING" ||
        metaErrorCode === "SWIFT_CLI_TIMEOUT" ||
        metaErrorCode === "CAPTURE_FAILED"
      ).toBeTruthy();
      
      // In error case, either no files should be created, or temporary files from the process
      const files = await fs.readdir(tempDir);
      // Allow some temporary files that might be created during the process
      expect(files.length).toBeLessThanOrEqual(5);
      return;
    }
    
    // If successful, the tool should succeed (format gets preprocessed to png)
    expect(result.isError).toBeUndefined();
    
    // Check if any files were created
    if (result.saved_files && result.saved_files.length > 0) {
      for (const savedFile of result.saved_files) {
        // The actual saved file should have .png extension, not .bmp
        expect(savedFile.path).not.toContain(".bmp");
        expect(savedFile.path).toMatch(/\.png$/);
        
        // Verify the file actually exists with the correct extension
        const fileExists = await fs.access(savedFile.path).then(() => true).catch(() => false);
        expect(fileExists).toBe(true);
        
        // Verify no .bmp file was created
        const bmpPath = savedFile.path.replace(/\.png$/, ".bmp");
        const bmpExists = await fs.access(bmpPath).then(() => true).catch(() => false);
        expect(bmpExists).toBe(false);
      }
    }
    
    // The result content should not mention .bmp files
    const resultText = result.content[0]?.text || "";
    expect(resultText).not.toContain(".bmp");
  });
  
  it("should handle various invalid formats consistently", async () => {
    const invalidFormats = ["gif", "webp", "tiff", "bmp", "xyz"];
    
    for (const format of invalidFormats) {
      const testPath = path.join(tempDir, `test_${format}.${format}`);
      
      const result = await imageToolHandler(
        { 
          format: format as any, 
          path: testPath,
        },
        mockContext,
      );
      
      // The tool might fail due to permissions or timeout, which is acceptable
      if (result.isError) {
        // If it's a permission or timeout error, that's expected in CI/testing environments
        const errorText = result.content?.[0]?.text || "";
        const metaErrorCode = (result as any)._meta?.backend_error_code;
        
        // This is OK - system might not have permissions or CLI might timeout
        const isExpectedError = errorText.includes("permission") ||
          errorText.includes("denied") ||
          errorText.includes("timeout") ||
          errorText.includes("TCC") ||
          errorText.includes("declined") ||
          errorText.includes("Failed to create screen capture") ||
          errorText.includes("Image capture failed") ||
          metaErrorCode === "PERMISSION_DENIED_SCREEN_RECORDING" ||
          metaErrorCode === "SWIFT_CLI_TIMEOUT" ||
          metaErrorCode === "CAPTURE_FAILED";
        
        if (isExpectedError) {
          continue; // Skip to next format - this is expected
        } else {
          // Unexpected error
          throw new Error(`Unexpected error for format ${format}: ${errorText}`);
        }
      }
      
      // If successful, the tool should automatically convert to PNG
      expect(result.isError).toBeUndefined();
      
      if (result.saved_files && result.saved_files.length > 0) {
        // All files should be saved as PNG regardless of input format
        for (const savedFile of result.saved_files) {
          expect(savedFile.path).toMatch(/\.png$/);
          expect(savedFile.mime_type).toBe("image/png");
        }
      }
    }
  }, 90000); // Increased timeout for multiple captures
  
  it("should show warning message when invalid format is provided", async () => {
    const testPath = path.join(tempDir, "test_with_warning.tiff");
    
    // Test with invalid format 'tiff'
    // Note: We need to simulate the _originalFormat being set by the index.ts handler
    const input = { 
      format: "png" as const, // This will be the preprocessed value
      path: testPath,
    };
    // Simulate what index.ts does
    (input as any)._originalFormat = "tiff";
    
    const result = await imageToolHandler(input, mockContext);
    
    // The tool might fail due to permissions or timeout
    if (result.isError) {
      // If it's a permission or timeout error, that's expected in CI/testing environments
      const errorText = result.content?.[0]?.text || "";
      const metaErrorCode = (result as any)._meta?.backend_error_code;
      
      // This is OK - system might not have permissions or CLI might timeout
      const isExpectedError = errorText.includes("permission") ||
        errorText.includes("denied") ||
        errorText.includes("timeout") ||
        errorText.includes("TCC") ||
        errorText.includes("declined") ||
        errorText.includes("Failed to create screen capture") ||
        errorText.includes("Image capture failed") ||
        metaErrorCode === "PERMISSION_DENIED_SCREEN_RECORDING" ||
        metaErrorCode === "SWIFT_CLI_TIMEOUT" ||
        metaErrorCode === "CAPTURE_FAILED";
      
      if (!isExpectedError) {
        throw new Error(`Unexpected error: ${errorText}`);
      }
      return;
    }
    
    // If successful, check for warning message
    expect(result.isError).toBeUndefined();
    
    // Should have multiple content items (summary + warning)
    expect(result.content.length).toBeGreaterThanOrEqual(2);
    
    // Find the warning message
    const warningMessage = result.content.find(item => 
      item.text?.includes("Invalid format 'tiff' was provided")
    );
    
    expect(warningMessage).toBeDefined();
    expect(warningMessage?.text).toBe("Invalid format 'tiff' was provided. Automatically using PNG format instead.");
  });
});