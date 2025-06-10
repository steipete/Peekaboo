import { describe, it, expect, beforeEach, vi } from "vitest";
import { imageToolHandler } from "../../../src/tools/image";
import { executeSwiftCli, readImageAsBase64 } from "../../../src/utils/peekaboo-cli";
import { resolveImagePath } from "../../../src/utils/image-cli-args";
import { mockSwiftCli } from "../../mocks/peekaboo-cli.mock";
import { pino } from "pino";

// Mock the Swift CLI utility
vi.mock("../../../src/utils/peekaboo-cli");

// Mock fs/promises
vi.mock("fs/promises");

// Mock image-cli-args module
vi.mock("../../../src/utils/image-cli-args", async () => {
  const actual = await vi.importActual("../../../src/utils/image-cli-args");
  return {
    ...actual,
    resolveImagePath: vi.fn(),
  };
});

const mockExecuteSwiftCli = executeSwiftCli as vi.MockedFunction<
  typeof executeSwiftCli
>;
const mockResolveImagePath = resolveImagePath as vi.MockedFunction<typeof resolveImagePath>;

const mockLogger = pino({ level: "silent" });
const mockContext = { logger: mockLogger };

const MOCK_TEMP_DIR = "/tmp/peekaboo-img-XXXXXX";
const MOCK_SAVED_FILE_PATH = "/tmp/test_invalid_format.png";

describe("Invalid Format Handling", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    
    // Mock resolveImagePath to return a temp directory
    mockResolveImagePath.mockResolvedValue({
      effectivePath: MOCK_TEMP_DIR,
      tempDirUsed: MOCK_TEMP_DIR,
    });
  });

  it("should fallback invalid format 'bmp' to 'png' and show warning message", async () => {
    // Import schema to test preprocessing
    const { imageToolSchema } = await import("../../../src/types/index.js");
    
    // Mock Swift CLI response with PNG format (fallback)
    const mockResponse = mockSwiftCli.captureImage("screen", {
      path: MOCK_SAVED_FILE_PATH,
      format: "png",
    });
    
    // Ensure the saved file has .png extension, not .bmp
    const savedFileWithCorrectExtension = {
      ...mockResponse.data.saved_files[0],
      path: "/tmp/test_invalid_format.png",  // Should be .png, not .bmp
    };
    
    const correctedResponse = {
      ...mockResponse,
      data: {
        ...mockResponse.data,
        saved_files: [savedFileWithCorrectExtension],
      },
    };
    
    mockExecuteSwiftCli.mockResolvedValue(correctedResponse);
    
    // Test with invalid format 'bmp' - schema should preprocess to 'png'
    const parsedInput = imageToolSchema.parse({ 
      format: "bmp", 
      path: "/tmp/test_invalid_format.bmp" 
    });
    
    // Validate that schema preprocessing worked
    expect(parsedInput.format).toBe("png");
    
    // Simulate the _originalFormat being set by the handler
    (parsedInput as any)._originalFormat = "bmp";
    
    const result = await imageToolHandler(parsedInput, mockContext);
    
    expect(result.isError).toBeUndefined();
    
    // Should have called Swift CLI with PNG format, not BMP
    expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
      expect.arrayContaining(["--format", "png"]),
      mockLogger,
      expect.objectContaining({ timeout: expect.any(Number) }),
    );
    
    // The saved file should have .png extension
    expect(result.saved_files?.[0]?.path).toBe("/tmp/test_invalid_format.png");
    expect(result.saved_files?.[0]?.path).not.toContain(".bmp");
    
    // Check that the warning message is included
    expect(result.content).toHaveLength(2); // Summary + warning
    expect(result.content[1]?.text).toBe("Invalid format 'bmp' was provided. Automatically using PNG format instead.");
  });
  
  it("should handle other invalid formats correctly", async () => {
    const { imageToolSchema } = await import("../../../src/types/index.js");
    
    const invalidFormats = ["gif", "webp", "tiff", "xyz", "bmp"];
    
    for (const invalidFormat of invalidFormats) {
      const parsedInput = imageToolSchema.parse({ format: invalidFormat });
      
      // All invalid formats should be preprocessed to 'png'
      expect(parsedInput.format).toBe("png");
    }
    
    // Empty string should become undefined (which will use default)
    const emptyInput = imageToolSchema.parse({ format: "" });
    expect(emptyInput.format).toBeUndefined();
  });
  
  it("should preserve valid formats", async () => {
    const { imageToolSchema } = await import("../../../src/types/index.js");
    
    const validFormats = [
      { input: "png", expected: "png" },
      { input: "PNG", expected: "png" },  // case insensitive
      { input: "jpg", expected: "jpg" },
      { input: "JPG", expected: "jpg" },  // case insensitive
      { input: "jpeg", expected: "jpg" }, // alias
      { input: "JPEG", expected: "jpg" }, // alias + case insensitive
      { input: "data", expected: "data" },
    ];
    
    for (const { input, expected } of validFormats) {
      const parsedInput = imageToolSchema.parse({ format: input });
      expect(parsedInput.format).toBe(expected);
    }
  });
});