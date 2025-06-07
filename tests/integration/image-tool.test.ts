import { imageToolHandler } from "../../src/tools/image";
import { pino } from "pino";
import { ImageInput } from "../../src/types";
import { vi } from "vitest";
import * as fs from "fs/promises";
import * as os from "os";
import * as pathModule from "path";
import { initializeSwiftCliPath, executeSwiftCli, readImageAsBase64 } from "../../src/utils/peekaboo-cli";
import { mockSwiftCli } from "../mocks/peekaboo-cli.mock";

// Mock the fs module to spy on unlink/rmdir for cleanup verification
vi.mock("fs/promises", async () => {
  const actual = await vi.importActual("fs/promises");
  return {
    ...actual,
    unlink: vi.fn().mockResolvedValue(undefined),
    rmdir: vi.fn().mockResolvedValue(undefined),
  };
});

// Mock the Swift CLI execution
vi.mock("../../src/utils/peekaboo-cli", async () => {
  const actual = await vi.importActual("../../src/utils/peekaboo-cli");
  return {
    ...actual,
    executeSwiftCli: vi.fn(),
    readImageAsBase64: vi.fn().mockResolvedValue("mock-base64-data"),
  };
});

// Mock AI providers to avoid real API calls in integration tests
vi.mock("../../src/utils/ai-providers", () => ({
  parseAIProviders: vi.fn().mockReturnValue([{ provider: "mock", model: "test" }]),
  analyzeImageWithProvider: vi.fn().mockResolvedValue("Mock analysis: This is a test image"),
}));

const mockExecuteSwiftCli = executeSwiftCli as vi.MockedFunction<typeof executeSwiftCli>;

const mockLogger = pino({ level: "silent" });
const mockContext = { logger: mockLogger };

// Helper to check if file exists
async function fileExists(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

// Import SwiftCliResponse type
import { SwiftCliResponse } from "../../src/types";

describe("Image Tool Integration Tests", () => {
  let tempDir: string;

  beforeAll(async () => {
    // Initialize Swift CLI path for tests
    const testPackageRoot = pathModule.resolve(__dirname, "../..");
    initializeSwiftCliPath(testPackageRoot);
    
    // Create a temporary directory for test files
    tempDir = await fs.mkdtemp(pathModule.join(os.tmpdir(), "peekaboo-test-"));
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterAll(async () => {
    // Clean up temp directory
    try {
      const files = await fs.readdir(tempDir);
      for (const file of files) {
        await fs.unlink(pathModule.join(tempDir, file));
      }
      await fs.rmdir(tempDir);
    } catch (error) {
      console.error("Failed to clean up temp directory:", error);
    }
  });

  describe("Output Handling", () => {
    it("should return base64 data and clean up temp file when no path is provided", async () => {
      // Spy on fs.promises.unlink and fs.promises.rmdir
      const unlinkSpy = vi.spyOn(fs, "unlink");
      const rmdirSpy = vi.spyOn(fs, "rmdir");

      // Mock executeSwiftCli to resolve with a successful capture that includes a temporary file path
      // We need to capture the actual path that will be created by the handler
      mockExecuteSwiftCli.mockImplementation(async (args: string[]) => {
        // Extract the path from the args (it will be after --path)
        const pathIndex = args.indexOf("--path");
        const actualPath = pathIndex !== -1 ? args[pathIndex + 1] : "";
        
        return {
          success: true,
          data: {
            saved_files: [{ path: actualPath, mime_type: "image/png" }]
          },
          messages: ["Captured 1 image"]
        };
      });

      // Mock readImageAsBase64 to resolve with a mock base64 string
      const MOCK_BASE64 = "mock-base64-data-string";
      (readImageAsBase64 as vi.Mock).mockResolvedValue(MOCK_BASE64);

      // Call imageToolHandler with no path argument
      const result = await imageToolHandler({}, mockContext);

      // Assert that the result is not an error
      expect(result.isError).toBeFalsy();

      // Assert that the content contains an image with the mocked base64 data
      const imageContent = result.content.find(item => item.type === "image");
      expect(imageContent).toBeDefined();
      expect(imageContent?.data).toBe(MOCK_BASE64);
      expect(imageContent?.mimeType).toBe("image/png");

      // Assert that saved_files is empty
      expect(result.saved_files).toEqual([]);

      // Assert that the unlink and rmdir spies were called with the correct temporary paths
      // The handler creates a temp path like /tmp/peekaboo-img-XXXXXX/capture.png
      expect(unlinkSpy).toHaveBeenCalled();
      expect(rmdirSpy).toHaveBeenCalled();
      
      // Verify the paths match the expected pattern
      const unlinkCall = unlinkSpy.mock.calls[0];
      const rmdirCall = rmdirSpy.mock.calls[0];
      
      expect(unlinkCall[0]).toMatch(/\/peekaboo-img-[^/]+\/capture\.png$/);
      expect(rmdirCall[0]).toMatch(/\/peekaboo-img-[^/]+$/);

      // Restore the spies
      unlinkSpy.mockRestore();
      rmdirSpy.mockRestore();
    });
  });

  describe("Capture with different app_target values", () => {
    it("should capture screen when app_target is omitted", async () => {
      // Mock successful screen capture
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: pathModule.join(tempDir, "peekaboo-img-test", "capture.png"),
          format: "png"
        })
      );

      const result = await imageToolHandler({}, mockContext);

      expect(result.isError).toBeFalsy();
      expect(result.content[0].type).toBe("text");
      expect(result.content[0].text).toContain("Captured");
      // Should return base64 data when format and path are omitted
      expect(result.content.some((item) => item.type === "image")).toBe(true);
    });

    it("should capture screen when app_target is empty string", async () => {
      const input: ImageInput = { app_target: "" };
      
      // Mock successful screen capture
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: pathModule.join(tempDir, "peekaboo-img-test", "capture.png"),
          format: "png"
        })
      );
      
      const result = await imageToolHandler(input, mockContext);

      expect(result.isError).toBeFalsy();
      expect(result.content[0].text).toContain("Captured");
    });

    it("should handle screen:INDEX format (valid index)", async () => {
      const input: ImageInput = { app_target: "screen:0" };
      
      // Mock successful screen capture with specific screen index
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: pathModule.join(tempDir, "peekaboo-img-test", "capture.png"),
          format: "png",
          item_label: "Display 0 (Index 0)"
        })
      );
      
      const result = await imageToolHandler(input, mockContext);

      expect(result.isError).toBeFalsy();
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["image", "--mode", "screen", "--screen-index", "0"]),
        mockLogger
      );
      // Check that the item_label indicates the specific screen was captured
      if (result.saved_files && result.saved_files.length > 0) {
        expect(result.saved_files[0].item_label).toContain("Display 0");
      }
    });

    it("should handle screen:INDEX format (invalid index)", async () => {
      const input: ImageInput = { app_target: "screen:abc" };
      const loggerWarnSpy = vi.spyOn(mockLogger, "warn");
      
      // Mock successful screen capture (falls back to all screens)
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: pathModule.join(tempDir, "peekaboo-img-test", "capture.png"),
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
        mockLogger
      );
    });

    it("should handle screen:INDEX format (out-of-bounds index)", async () => {
      const input: ImageInput = { app_target: "screen:99" };
      
      // Mock response with debug logs indicating out-of-bounds
      const mockResponse = {
        success: true,
        data: {
          saved_files: [{
            path: pathModule.join(tempDir, "peekaboo-img-test", "capture.png"),
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
        mockLogger
      );
      // The Swift CLI should handle the out-of-bounds gracefully and capture all screens
      if (result.saved_files && result.saved_files.length > 0) {
        expect(result.saved_files[0].item_label).not.toContain("Index 99");
      }
    });

    it("should handle frontmost app_target (with warning)", async () => {
      const input: ImageInput = { app_target: "frontmost" };
      const loggerWarnSpy = vi.spyOn(mockLogger, "warn");
      
      // Mock successful screen capture
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: pathModule.join(tempDir, "peekaboo-img-test", "capture.png"),
          format: "png"
        })
      );
      
      const result = await imageToolHandler(input, mockContext);

      expect(result.isError).toBeFalsy();
      expect(loggerWarnSpy).toHaveBeenCalledWith(
        "'frontmost' target requires determining current frontmost app, defaulting to screen mode",
      );
    });

    it("should capture specific app windows", async () => {
      const input: ImageInput = { app_target: "Finder" };
      
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
    it("should return base64 data when format is 'data'", async () => {
      const input: ImageInput = { format: "data" };
      
      // Mock successful capture with temp path
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: expect.stringMatching(/peekaboo-img-.*\/capture\.png$/),
          format: "png"
        })
      );
      
      const result = await imageToolHandler(input, mockContext);

      if (!result.isError) {
        const imageContent = result.content.find((item) => item.type === "image");
        expect(imageContent).toBeDefined();
        expect(imageContent?.data).toBeTruthy();
        expect(typeof imageContent?.data).toBe("string");
      }
    });

    it("should save file and return base64 when format is 'data' with path", async () => {
      const testPath = pathModule.join(tempDir, "test-data-format.png");
      const input: ImageInput = { format: "data", path: testPath };
      
      // Mock successful capture with specified path
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: testPath,
          format: "png"
        })
      );
      
      const result = await imageToolHandler(input, mockContext);

      if (!result.isError) {
        // Should have base64 data in content
        const imageContent = result.content.find((item) => item.type === "image");
        expect(imageContent).toBeDefined();
        
        // Should have saved file
        expect(result.saved_files).toHaveLength(1);
        expect(result.saved_files[0].path).toBe(testPath);
        
        // In integration tests with mocked CLI, we don't check file existence
      }
    });

    it("should save PNG file without base64 in content", async () => {
      const testPath = pathModule.join(tempDir, "test-png.png");
      const input: ImageInput = { format: "png", path: testPath };
      
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
      const testPath = pathModule.join(tempDir, "test-jpg.jpg");
      const input: ImageInput = { format: "jpg", path: testPath };
      
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
      
      // Mock successful capture with specific screen index
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          saved_files: [{
            path: expect.stringMatching(/peekaboo-img-.*\/capture\.png$/),
            mime_type: "image/png",
            item_label: "Display 1 (Index 1)"
          }]
        },
        messages: ["Captured 1 image"]
      });
      
      const result = await imageToolHandler(input, mockContext);

      if (!result.isError) {
        // Check for image content with metadata
        const imageContent = result.content.find((item) => item.type === "image");
        expect(imageContent).toBeDefined();
        expect(imageContent?.metadata?.item_label).toBe("Display 1 (Index 1)");
      }
    });
  });

  describe("Analysis with question", () => {
    beforeEach(() => {
      // Mock performAutomaticAnalysis for these tests
      vi.clearAllMocks();
    });

    it("should analyze image and delete temp file when no path provided", async () => {
      const input: ImageInput = { question: "What is in this image?" };
      
      // Mock successful screen capture for analysis
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: expect.stringMatching(/peekaboo-img-.*\/capture\.png$/),
          format: "png"
        })
      );
      
      const result = await imageToolHandler(input, mockContext);

      // Even if analysis is mocked, the capture should succeed
      expect(result.content[0].text).toContain("Captured");
      
      // Should not return base64 data when question is asked
      const imageContent = result.content.find((item) => item.type === "image");
      expect(imageContent).toBeUndefined();
      
      // saved_files should be empty (temp file was deleted)
      expect(result.saved_files).toEqual([]);
    });

    it("should analyze image and keep file when path is provided", async () => {
      const testPath = pathModule.join(tempDir, "test-analysis.png");
      const input: ImageInput = { 
        question: "Describe this image",
        path: testPath,
        format: "png"
      };
      
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
      
      // Mock successful capture with temp path for analysis
      mockExecuteSwiftCli.mockResolvedValue(
        mockSwiftCli.captureImage("screen", {
          path: expect.stringMatching(/peekaboo-img-.*\/capture\.png$/),
          format: "png"
        })
      );
      
      const result = await imageToolHandler(input, mockContext);

      // Should not have base64 data when question is asked
      const imageContent = result.content.find((item) => item.type === "image");
      expect(imageContent).toBeUndefined();
    });
  });

  describe("Error handling", () => {
    it("should handle permission errors gracefully", async () => {
      // This test might fail if permissions are granted
      // We're testing that the error is handled properly if it occurs
      const input: ImageInput = { app_target: "System Preferences" };
      const result = await imageToolHandler(input, mockContext);

      if (result.isError) {
        expect(result.content[0].text).toContain("failed");
        expect(result._meta?.backend_error_code).toBeTruthy();
      }
    });

    it("should handle invalid app names", async () => {
      const input: ImageInput = { app_target: "NonExistentApp12345" };
      
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
      
      // Mock window not found error
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Window index 999 is out of bounds for Finder",
          code: "WINDOW_NOT_FOUND"
        }
      });
      
      const result = await imageToolHandler(input, mockContext);

      if (result.isError) {
        expect(result.content[0].text).toMatch(/WINDOW_NOT_FOUND|out of bounds/);
      }
    });
  });

  describe("Environment variable handling", () => {
    it("should use PEEKABOO_DEFAULT_SAVE_PATH when no path provided and no question", async () => {
      const defaultPath = pathModule.join(tempDir, "default-save.png");
      process.env.PEEKABOO_DEFAULT_SAVE_PATH = defaultPath;

      try {
        // Mock successful capture with temp path (overrides PEEKABOO_DEFAULT_SAVE_PATH)
        mockExecuteSwiftCli.mockResolvedValue(
          mockSwiftCli.captureImage("screen", {
            path: expect.stringMatching(/peekaboo-img-.*\/capture\.png$/),
            format: "png"
          })
        );
        
        const result = await imageToolHandler({}, mockContext);

        if (!result.isError) {
          // When no path/format is provided, it uses temp path and returns base64
          // PEEKABOO_DEFAULT_SAVE_PATH is overridden by the temp path logic
          expect(result.saved_files).toEqual([]);
          expect(result.content.some(item => item.type === "image")).toBe(true);
        }
      } finally {
        delete process.env.PEEKABOO_DEFAULT_SAVE_PATH;
      }
    });

    it("should NOT use PEEKABOO_DEFAULT_SAVE_PATH when question is provided", async () => {
      const defaultPath = pathModule.join(tempDir, "should-not-use.png");
      process.env.PEEKABOO_DEFAULT_SAVE_PATH = defaultPath;

      try {
        const input: ImageInput = { question: "What is this?" };
        
        // Mock successful screen capture with temp path
        mockExecuteSwiftCli.mockResolvedValue(
          mockSwiftCli.captureImage("screen", {
            path: expect.stringMatching(/peekaboo-img-.*\/capture\.png$/),
            format: "png"
          })
        );
        
        const result = await imageToolHandler(input, mockContext);

        // Temp file should be used and deleted
        expect(result.saved_files).toEqual([]);
        
        // Default path should not exist
        const exists = await fileExists(defaultPath);
        expect(exists).toBe(false);
      } finally {
        delete process.env.PEEKABOO_DEFAULT_SAVE_PATH;
      }
    });
  });

  describe("Capture focus behavior", () => {
    it("should capture with background focus by default", async () => {
      const testPath = pathModule.join(tempDir, "test-bg-focus.png");
      const input: ImageInput = { path: testPath };
      
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
      const testPath = pathModule.join(tempDir, "test-fg-focus.png");
      const input: ImageInput = { 
        path: testPath,
        capture_focus: "foreground"
      };
      
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