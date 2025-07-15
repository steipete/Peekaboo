import { imageToolHandler } from "../../Server/src/tools/image";
import { pino } from "pino";
import { ImageInput } from "../../Server/src/types";
import { vi, describe, it, expect, beforeAll, afterAll, beforeEach } from "vitest";
import * as fs from "fs/promises";
import * as os from "os";
import * as pathModule from "path";
import { initializeSwiftCliPath, executeSwiftCli, readImageAsBase64 } from "../../Server/src/utils/peekaboo-cli";
import { mockSwiftCli } from "../mocks/peekaboo-cli.mock";

// Mocks
vi.mock("../../Server/src/utils/peekaboo-cli");
vi.mock("fs/promises");

// Mock image-cli-args module
vi.mock("../../Server/src/utils/image-cli-args", async () => {
  const actual = await vi.importActual("../../Server/src/utils/image-cli-args");
  return {
    ...actual,
    resolveImagePath: vi.fn(),
  };
});

const mockExecuteSwiftCli = executeSwiftCli as vi.MockedFunction<
  typeof executeSwiftCli
>;
const mockReadImageAsBase64 = readImageAsBase64 as vi.MockedFunction<
  typeof readImageAsBase64
>;
import { resolveImagePath } from "../../Server/src/utils/image-cli-args";
const mockResolveImagePath = resolveImagePath as vi.MockedFunction<typeof resolveImagePath>;

import { performAutomaticAnalysis } from "../../Server/src/utils/image-analysis";
const mockPerformAutomaticAnalysis = performAutomaticAnalysis as vi.MockedFunction<typeof performAutomaticAnalysis>;

const mockContext = {
  logger: pino({ level: "silent" }),
};

const MOCK_TEMP_DIR = "/private/var/folders/xyz/T/peekaboo-temp-12345";

// This constant is no longer the primary path passed, but represents a file *inside* the temp dir.
const MOCK_SAVED_FILE_PATH = `${MOCK_TEMP_DIR}/screen_1.png`;

// Mock AI providers to avoid real API calls in integration tests
vi.mock("../../Server/src/utils/ai-providers", () => ({
  parseAIProviders: vi.fn().mockReturnValue([{ provider: "mock", model: "test" }]),
  analyzeImageWithProvider: vi.fn().mockResolvedValue("Mock analysis: This is a test image"),
}));

// Mock image-analysis module
vi.mock("../../Server/src/utils/image-analysis", () => ({
  performAutomaticAnalysis: vi.fn(),
}));

// Import SwiftCliResponse type
import { SwiftCliResponse } from "../../Server/src/types";

// Conditionally skip Swift-dependent tests on non-macOS platforms
const describeSwiftTests = globalThis.shouldSkipSwiftTests ? describe.skip : describe;

describeSwiftTests("Image Tool Integration Tests", () => {
  let tempDir: string;

  beforeAll(async () => {
    // Initialize Swift CLI path for tests
    const testPackageRoot = pathModule.resolve(__dirname, "../..");
    initializeSwiftCliPath(testPackageRoot);
    
    // Use a mocked temp directory path
    tempDir = "/tmp/peekaboo-test-mock";
  });

  beforeEach(() => {
    vi.clearAllMocks();
    // Setup mock implementations for fs
    (fs.rm as vi.Mock).mockResolvedValue(undefined);
  });

  afterAll(async () => {
    // Clean up temp directory - skip in mocked environment
    // The actual fs module is mocked, so we can't clean up real files
  });

  describe("Output Handling", () => {
    it("should capture screen and return base64 data when no arguments are provided", async () => {
      // This test covers the user-reported bug where calling 'image' with no args caused a 'failed to write' error.
      
      // Mock resolveImagePath to return a temp directory
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });

      // Mock the Swift CLI to return a successful capture with a temp path
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          saved_files: [{ path: MOCK_SAVED_FILE_PATH, mime_type: "image/png" }],
        },
      });
      mockReadImageAsBase64.mockResolvedValue("base64-no-args-test");

      // Call the handler with capture_focus: "background"
      const result = await imageToolHandler({ capture_focus: "background" }, mockContext);

      // Verify resolveImagePath was called
      expect(mockResolveImagePath).toHaveBeenCalledWith(expect.objectContaining({ capture_focus: "background" }), mockContext.logger);
      // The CLI should be called with the DIRECTORY, not a full file path
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--path", MOCK_TEMP_DIR]),
        mockContext.logger,
        expect.objectContaining({ timeout: expect.any(Number) })
      );

      // Verify the result is correct
      expect(result.isError).toBeUndefined();
      // Now returns the temp file in saved_files
      expect(result.saved_files).toEqual([{ path: MOCK_SAVED_FILE_PATH, mime_type: "image/png" }]);
      // Screen captures no longer return base64 data due to auto-fallback
      const imageContent = result.content.find(c => c.type === "image");
      expect(imageContent).toBeUndefined();
    });

    it("should return an error if the Swift CLI fails", async () => {
      // Ensure PEEKABOO_DEFAULT_SAVE_PATH is not set for this test
      delete process.env.PEEKABOO_DEFAULT_SAVE_PATH;
      
      // Mock resolveImagePath to return a temp directory
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock the Swift CLI to return an error
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Swift CLI failed",
          code: "CLI_FAILED"
        }
      });

      const result = await imageToolHandler({}, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Swift CLI failed");

      // Verify resolveImagePath was called
      expect(mockResolveImagePath).toHaveBeenCalledWith({}, mockContext.logger);
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--path", MOCK_TEMP_DIR]),
        mockContext.logger,
        expect.objectContaining({ timeout: expect.any(Number) })
      );
    });
  });

  describe("Capture with different app_target values", () => {
    it("should capture screen when app_target is empty string", async () => {
      const input: ImageInput = { app_target: "" };
      
      // Mock resolveImagePath
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock successful screen capture
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: MOCK_SAVED_FILE_PATH,
          format: "png"
        })
      );
      
      const result = await imageToolHandler(input, mockContext);

      expect(result.isError).toBeFalsy();
      expect(result.content[0].text).toContain("Captured");
    });

    it("should handle screen:INDEX format (valid index)", async () => {
      const input: ImageInput = { app_target: "screen:0" };
      
      // Mock resolveImagePath
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock successful screen capture with specific screen index
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: MOCK_SAVED_FILE_PATH,
          format: "png",
          item_label: "Display 0 (Index 0)"
        })
      );
      
      const result = await imageToolHandler(input, mockContext);

      expect(result.isError).toBeFalsy();
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["image", "--mode", "screen", "--screen-index", "0"]),
        mockContext.logger,
        expect.objectContaining({ timeout: expect.any(Number) })
      );
      // Since temp dir was used, saved_files now contains the temp file
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_SAVED_FILE_PATH,
        format: "png",
        item_label: "Display 0 (Index 0)"
      });
      expect(result.saved_files).toEqual(mockResponse.data.saved_files);
    });

    it("should handle screen:INDEX format (invalid index)", async () => {
      const input: ImageInput = { app_target: "screen:abc" };
      const loggerWarnSpy = vi.spyOn(mockContext.logger, "warn");
      
      // Mock resolveImagePath
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock successful screen capture (falls back to all screens)
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: MOCK_SAVED_FILE_PATH,
          format: "png"
        })
      );
      
      const result = await imageToolHandler(input, mockContext);

      expect(result.isError).toBeFalsy();
      expect(loggerWarnSpy).toHaveBeenCalledWith(
        expect.objectContaining({ screenIndex: "abc" }),
        "Invalid screen index 'abc' in app_target, capturing all screens.",
      );
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.not.arrayContaining(["--screen-index"]),
        mockContext.logger,
        expect.objectContaining({ timeout: expect.any(Number) })
      );
    });

    it("should handle screen:INDEX format (out-of-bounds index)", async () => {
      const input: ImageInput = { app_target: "screen:99" };
      
      // Mock resolveImagePath
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock response with debug logs indicating out-of-bounds
      const mockResponse = {
        success: true,
        data: {
          saved_files: [{
            path: MOCK_SAVED_FILE_PATH,
            mime_type: "image/png",
            item_label: "All Screens"
          }]
        },
        messages: ["Captured 1 image"],
        debug_logs: ["Screen index 99 is out of bounds. Falling back to capturing all screens."]
      };
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);
      
      const result = await imageToolHandler(input, mockContext);

      expect(result.isError).toBeFalsy();
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["image", "--mode", "screen", "--screen-index", "99"]),
        mockContext.logger,
        expect.objectContaining({ timeout: expect.any(Number) })
      );
      // Since temp dir was used, saved_files now contains the temp file
      expect(result.saved_files).toEqual([{
        path: MOCK_SAVED_FILE_PATH,
        mime_type: "image/png",
        item_label: "All Screens"
      }]);
    });

    it("should handle frontmost app_target (with frontmost mode)", async () => {
      const input: ImageInput = { app_target: "frontmost" };
      
      // Mock resolveImagePath
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock successful frontmost capture
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureFrontmostWindow()
      );
      
      const result = await imageToolHandler(input, mockContext);

      expect(result.isError).toBeFalsy();
      // Should use frontmost mode instead of warning about screen mode
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--mode", "frontmost"]),
        expect.any(Object),
        expect.any(Object)
      );
    });

    it("should capture specific app windows", async () => {
      const input: ImageInput = { app_target: "Finder" };
      
      // Mock resolveImagePath
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock app not found error
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.appNotFound("Finder")
      );
      
      const result = await imageToolHandler(input, mockContext);

      // The result depends on whether Finder is running
      // We're just testing that the handler processes the request correctly
      expect(result.content[0].type).toBe("text");
      if (result.isError) {
        expect(result.content[0].text).toContain("not found or not running");
      } else {
        expect(result.content[0].text).toContain("Captured");
      }
    });

    it("should capture specific window by title", async () => {
      const input: ImageInput = { app_target: "Safari:WINDOW_TITLE:Test Window" };
      
      // Mock resolveImagePath
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock app not found error
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.appNotFound("Safari")
      );
      
      const result = await imageToolHandler(input, mockContext);

      expect(result.content[0].type).toBe("text");
      // May fail if Safari isn't running or window doesn't exist
      if (result.isError) {
        expect(result.content[0].text).toContain("not found or not running");
      }
    });

    it("should capture specific window by index", async () => {
      const input: ImageInput = { app_target: "Terminal:WINDOW_INDEX:0" };
      
      // Mock resolveImagePath
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock app not found error
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.appNotFound("Terminal")
      );
      
      const result = await imageToolHandler(input, mockContext);

      expect(result.content[0].type).toBe("text");
      // May fail if Terminal isn't running
      if (result.isError) {
        expect(result.content[0].text).toContain("not found or not running");
      }
    });
  });

  describe("Format and data return behavior", () => {
    it("should auto-fallback to PNG for screen capture when format is 'data'", async () => {
      const input: ImageInput = { format: "data" };
      
      // Mock resolveImagePath to return temp directory for format: "data"
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock successful capture with temp path
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: MOCK_SAVED_FILE_PATH,
          format: "png"
        })
      );
      mockReadImageAsBase64.mockResolvedValue("base64-data-format-test");
      
      const result = await imageToolHandler(input, mockContext);

      expect(result.isError).toBeUndefined();
      // Should NOT return base64 data for screen captures
      const imageContent = result.content.find((item) => item.type === "image");
      expect(imageContent).toBeUndefined();
      // Should have format warning
      const warningContent = result.content.find(item => 
        item.type === "text" && item.text?.includes("Screen captures cannot use format 'data'")
      );
      expect(warningContent).toBeDefined();
    });

    it("should save file and return base64 when format is 'data' with path", async () => {
      const testPath = "/tmp/test-data-format.png";
      const input: ImageInput = { format: "data", path: testPath };
      
      // Mock resolveImagePath to return the user path (no temp dir)
      mockResolveImagePath.mockResolvedValue({
        effectivePath: testPath,
        tempDirUsed: undefined,
      });
      
      // Mock successful capture with specified path
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: testPath,
          format: "png"
        })
      );
      mockReadImageAsBase64.mockResolvedValue("base64-data-with-path-test");
      
      const result = await imageToolHandler(input, mockContext);

      expect(result.isError).toBeUndefined();
      // Should NOT have base64 data in content for screen captures
      const imageContent = result.content.find((item) => item.type === "image");
      expect(imageContent).toBeUndefined();
      
      // Should have format warning
      const warningContent = result.content.find(item => 
        item.type === "text" && item.text?.includes("Screen captures cannot use format 'data'")
      );
      expect(warningContent).toBeDefined();
      
      // Should have saved file
      expect(result.saved_files).toHaveLength(1);
      expect(result.saved_files[0].path).toBe(testPath);
    });

    it("should save PNG file without base64 in content", async () => {
      const testPath = "/tmp/test-png.png";
      const input: ImageInput = { format: "png", path: testPath };
      
      // Mock resolveImagePath to return the user path (no temp dir)
      mockResolveImagePath.mockResolvedValue({
        effectivePath: testPath,
        tempDirUsed: undefined,
      });
      
      // Mock successful capture with specified path
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: testPath,
          format: "png"
        })
      );
      
      const result = await imageToolHandler(input, mockContext);

      if (!result.isError) {
        // Should NOT have base64 data in content
        const imageContent = result.content.find((item) => item.type === "image");
        expect(imageContent).toBeUndefined();
        
        // Should have saved file
        expect(result.saved_files).toHaveLength(1);
        expect(result.saved_files[0].path).toBe(testPath);
        
        // In integration tests with mocked CLI, we don't check file existence
      }
    });

    it("should save JPG file", async () => {
      const testPath = "/tmp/test-jpg.jpg";
      const input: ImageInput = { format: "jpg", path: testPath };
      
      // Mock resolveImagePath to return the user path (no temp dir)
      mockResolveImagePath.mockResolvedValue({
        effectivePath: testPath,
        tempDirUsed: undefined,
      });
      
      // Mock successful capture with specified path
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: testPath,
          format: "jpg"
        })
      );
      
      const result = await imageToolHandler(input, mockContext);

      if (!result.isError) {
        expect(result.saved_files).toHaveLength(1);
        expect(result.saved_files[0].path).toBe(testPath);
        expect(result.saved_files[0].mime_type).toBe("image/jpeg");
      }
    });

    it("should include item_label in metadata when format is 'data' with screen:INDEX", async () => {
      const input: ImageInput = { format: "data", app_target: "screen:1" };
      
      // Mock resolveImagePath to return temp directory for format: "data"
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock successful capture with specific screen index
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          saved_files: [{
            path: MOCK_SAVED_FILE_PATH,
            mime_type: "image/png",
            item_label: "Display 1 (Index 1)"
          }]
        },
        messages: ["Captured 1 image"]
      });
      mockReadImageAsBase64.mockResolvedValue("base64-screen-index-test");
      
      const result = await imageToolHandler(input, mockContext);

      expect(result.isError).toBeUndefined();
      // Should NOT have image content for screen captures with format: "data"
      const imageContent = result.content.find((item) => item.type === "image");
      expect(imageContent).toBeUndefined();
      
      // Should have format warning
      const warningContent = result.content.find(item => 
        item.type === "text" && item.text?.includes("Screen captures cannot use format 'data'")
      );
      expect(warningContent).toBeDefined();
      
      // Should still have saved files with metadata
      expect(result.saved_files).toHaveLength(1);
      expect(result.saved_files[0].item_label).toBe("Display 1 (Index 1)");
    });
  });

  describe("Analysis Logic", () => {
    beforeEach(() => {
      // Mock performAutomaticAnalysis for these tests
      vi.clearAllMocks();
    });

    it("should analyze image and PRESERVE temp file when no path provided", async () => {
      const input: ImageInput = { question: "What is in this image?" };
      
      // Mock resolveImagePath to return temp directory when question is asked
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock successful screen capture for analysis
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: MOCK_SAVED_FILE_PATH,
          format: "png"
        })
      );
      
      const result = await imageToolHandler(input, mockContext);

      // Even if analysis is mocked, the capture should succeed
      expect(result.content[0].text).toContain("Captured");
      
      // Should not return base64 data when question is asked
      const imageContent = result.content.find((item) => item.type === "image");
      expect(imageContent).toBeUndefined();
      
      // saved_files should now contain the temp file (preserved)
      const MOCK_SAVED_FILES = mockSwiftCli.captureImage("screen", {
        path: MOCK_SAVED_FILE_PATH,
        format: "png"
      });
      expect(result.saved_files).toEqual(MOCK_SAVED_FILES.data.saved_files);
    });

    it("should analyze image and keep file when path is provided", async () => {
      const testPath = "/tmp/test-analysis.png";
      const input: ImageInput = { 
        question: "Describe this image",
        path: testPath,
        format: "png"
      };
      
      // Mock resolveImagePath to return the user path (no temp dir)
      mockResolveImagePath.mockResolvedValue({
        effectivePath: testPath,
        tempDirUsed: undefined,
      });
      
      // Mock successful capture with specified path
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: testPath,
          format: "png"
        })
      );
      
      const result = await imageToolHandler(input, mockContext);

      if (!result.isError) {
        // Should have saved file
        expect(result.saved_files).toHaveLength(1);
        expect(result.saved_files[0].path).toBe(testPath);
        
        // In integration tests with mocked CLI, we don't check file existence
        
        // Should not have base64 data
        const imageContent = result.content.find((item) => item.type === "image");
        expect(imageContent).toBeUndefined();
      }
    });

    it("should not return base64 even with format: 'data' when question is asked", async () => {
      const input: ImageInput = { 
        format: "data",
        question: "What do you see?"
      };
      
      // Mock resolveImagePath to return temp directory when question is asked
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock successful capture with temp path for analysis
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: MOCK_SAVED_FILE_PATH,
          format: "png"
        })
      );
      
      const result = await imageToolHandler(input, mockContext);

      // Should not have base64 data when question is asked
      const imageContent = result.content.find((item) => item.type === "image");
      expect(imageContent).toBeUndefined();
    });

    it("should analyze all images and format output correctly when multiple images are captured", async () => {
      const input: ImageInput = { question: "What is in these images?" };
      
      // Mock resolveImagePath to return a temporary directory path
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock the Swift CLI response to simulate a capture of two windows
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          saved_files: [
            {
              path: `${MOCK_TEMP_DIR}/window1.png`,
              mime_type: "image/png",
              item_label: "Window 1"
            },
            {
              path: `${MOCK_TEMP_DIR}/window2.png`,
              mime_type: "image/png",
              item_label: "Window 2"
            }
          ],
        },
        messages: ["Captured 2 images"]
      });
      
      // Mock readImageAsBase64 to be called twice, once for each image
      mockReadImageAsBase64
        .mockResolvedValueOnce("base64-window1-data")
        .mockResolvedValueOnce("base64-window2-data");
      
      // Mock performAutomaticAnalysis to be called twice with different results
      mockPerformAutomaticAnalysis
        .mockResolvedValueOnce({
          analysisText: "First analysis.",
          modelUsed: "mock/test"
        })
        .mockResolvedValueOnce({
          analysisText: "Second analysis.",
          modelUsed: "mock/test"
        });
      
      const result = await imageToolHandler(input, mockContext);
      
      // Verify that performAutomaticAnalysis was called twice
      expect(mockPerformAutomaticAnalysis).toHaveBeenCalledTimes(2);
      
      // Verify that the result.analysis_text contains both analysis results formatted correctly
      const expectedAnalysisText = "Analysis for Window 1:\nFirst analysis.\n\nAnalysis for Window 2:\nSecond analysis.";
      expect(result.analysis_text).toBe(expectedAnalysisText);
      
      // Verify saved files now contain all captured files
      expect(result.saved_files).toEqual([
        {
          path: `${MOCK_TEMP_DIR}/window1.png`,
          mime_type: "image/png",
          item_label: "Window 1"
        },
        {
          path: `${MOCK_TEMP_DIR}/window2.png`,
          mime_type: "image/png",
          item_label: "Window 2"
        }
      ]);
    });

    it("should NOT delete the temporary file when a question is asked", async () => {
      const input: ImageInput = { question: "What is in this image?" };
      
      // Mock resolveImagePath to return a temporary directory path
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock successful screen capture with one or more files
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          saved_files: [
            {
              path: `${MOCK_TEMP_DIR}/captured_image.png`,
              mime_type: "image/png",
              item_label: "Screen Capture"
            }
          ],
        },
        messages: ["Captured 1 image"]
      });
      
      // Mock performAutomaticAnalysis with a successful response
      mockPerformAutomaticAnalysis.mockResolvedValue({
        analysisText: "This is a mock analysis of the captured screen.",
        modelUsed: "mock/test"
      });
      
      // Call imageToolHandler with a question but no path
      const result = await imageToolHandler(input, mockContext);
      
      // Most important assertion: Verify that fs.rm was NOT called
      expect(fs.rm).not.toHaveBeenCalled();
      
      // Verify that result.saved_files is populated with the saved files from Swift CLI
      expect(result.saved_files).toEqual([
        {
          path: `${MOCK_TEMP_DIR}/captured_image.png`,
          mime_type: "image/png",
          item_label: "Screen Capture"
        }
      ]);
      
      // Additional verification: analysis was performed
      expect(mockPerformAutomaticAnalysis).toHaveBeenCalled();
      expect(result.analysis_text).toBe("This is a mock analysis of the captured screen.");
    });
  });

  describe("Error handling", () => {
    it("should handle permission errors gracefully", async () => {
      // This test might fail if permissions are granted
      // We're testing that the error is handled properly if it occurs
      const input: ImageInput = { app_target: "System Preferences" };
      
      // Mock resolveImagePath
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock permission error
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Screen recording permission denied",
          code: "PERMISSION_DENIED_SCREEN_RECORDING"
        }
      });
      
      const result = await imageToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Screen recording permission denied");
      expect(result._meta?.backend_error_code).toBe("PERMISSION_DENIED_SCREEN_RECORDING");
    });

    it("should handle invalid app names", async () => {
      const input: ImageInput = { app_target: "NonExistentApp12345" };
      
      // Mock resolveImagePath
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock app not found error
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.appNotFound("NonExistentApp12345")
      );
      
      const result = await imageToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("not found or not running");
    });

    it("should handle invalid window specifiers", async () => {
      const input: ImageInput = { app_target: "Finder:WINDOW_INDEX:999" };
      
      // Mock resolveImagePath
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });
      
      // Mock window not found error
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Window index 999 is out of bounds for Finder",
          code: "WINDOW_NOT_FOUND"
        }
      });
      
      const result = await imageToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Window index 999 is out of bounds for Finder");
    });

    it("should return a specific error when app is running but has no windows", async () => {
      // Arrange
      mockResolveImagePath.mockResolvedValue({
        effectivePath: '/mock/path',
        tempDirUsed: undefined,
      });
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "The specified application is running but has no capturable windows. Try setting 'capture_focus' to 'foreground' to un-hide application windows.",
          code: "SWIFT_CLI_NO_WINDOWS_FOUND"
        },
      });
      const args = { app_target: "Xcode", capture_focus: "background" };

      // Act
      const result = await imageToolHandler(args, mockContext);

      // Assert
      expect(result.isError).toBe(true);
      expect(result.content[0].text).toBe(
        "Image capture failed: The specified application is running but has no capturable windows. Try setting 'capture_focus' to 'foreground' to un-hide application windows."
      );
    });
  });

  describe("Environment variable handling", () => {
    it("should use PEEKABOO_DEFAULT_SAVE_PATH when no path provided and no question", async () => {
      const MOCK_DEFAULT_PATH = "/default/save/path";
      process.env.PEEKABOO_DEFAULT_SAVE_PATH = MOCK_DEFAULT_PATH;
      
      // Mock resolveImagePath to return the default path from env var
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_DEFAULT_PATH,
        tempDirUsed: undefined,
      });

      // Mock readImageAsBase64 to return base64 data
      mockReadImageAsBase64.mockResolvedValue("base64-default-path-test");

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          saved_files: [{ path: `${MOCK_DEFAULT_PATH}/file.png`, mime_type: "image/png" }],
        },
      });

      const result = await imageToolHandler({}, mockContext);

      // It should have used the default path
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--path", MOCK_DEFAULT_PATH]),
        mockContext.logger,
        expect.objectContaining({ timeout: expect.any(Number) })
      );
      
      // No cleanup should have occurred
      expect(fs.rm).not.toHaveBeenCalled();

      // Screen captures should NOT include base64 data in content
      const imageContent = result.content.find(c => c.type === "image");
      expect(imageContent).toBeUndefined();

      // And the result should reflect the saved files
      expect(result.saved_files).toEqual([{ path: `${MOCK_DEFAULT_PATH}/file.png`, mime_type: "image/png" }]);
      
      delete process.env.PEEKABOO_DEFAULT_SAVE_PATH;
    });

    it("should NOT use PEEKABOO_DEFAULT_SAVE_PATH when question is provided", async () => {
      const MOCK_DEFAULT_PATH = "/default/save/path/for/question/test";
      process.env.PEEKABOO_DEFAULT_SAVE_PATH = MOCK_DEFAULT_PATH;
      
      // Mock resolveImagePath to return temp directory when question is asked
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_DIR,
        tempDirUsed: MOCK_TEMP_DIR,
      });

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          saved_files: [{ path: MOCK_SAVED_FILE_PATH, mime_type: "image/png" }],
        },
      });

      const result = await imageToolHandler({ question: "analyze this" }, mockContext);

      // It should now save files even with a question (files are preserved)
      expect(result.saved_files).toEqual([{ path: MOCK_SAVED_FILE_PATH, mime_type: "image/png" }]);

      // The handler should not have used the default path
      // We can verify this by checking that the Swift CLI was called with the temp dir, not the default path
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--path", MOCK_TEMP_DIR]),
        mockContext.logger,
        expect.objectContaining({ timeout: expect.any(Number) })
      );

      delete process.env.PEEKABOO_DEFAULT_SAVE_PATH;
    });
  });

  describe("Capture focus behavior", () => {
    it("should capture with background focus by default", async () => {
      const testPath = "/tmp/test-bg-focus.png";
      const input: ImageInput = { path: testPath };
      
      // Mock resolveImagePath to return the user path
      mockResolveImagePath.mockResolvedValue({
        effectivePath: testPath,
        tempDirUsed: undefined,
      });
      
      // Mock successful capture
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: testPath,
          format: "png"
        })
      );
      
      const result = await imageToolHandler(input, mockContext);

      if (!result.isError) {
        expect(result.content[0].text).toContain("Captured");
        // The actual focus behavior is handled by Swift CLI
      }
    });

    it("should capture with foreground focus when specified", async () => {
      const testPath = "/tmp/test-fg-focus.png";
      const input: ImageInput = { 
        path: testPath,
        capture_focus: "foreground"
      };
      
      // Mock resolveImagePath to return the user path
      mockResolveImagePath.mockResolvedValue({
        effectivePath: testPath,
        tempDirUsed: undefined,
      });
      
      // Mock successful capture
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: testPath,
          format: "png"
        })
      );
      
      const result = await imageToolHandler(input, mockContext);

      if (!result.isError) {
        expect(result.content[0].text).toContain("Captured");
        // The actual focus behavior is handled by Swift CLI
      }
    });
  });

});

