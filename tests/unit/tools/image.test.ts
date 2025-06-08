import { describe, it, expect, beforeEach, vi } from "vitest";
import { imageToolHandler } from "../../../src/tools/image";
import { buildSwiftCliArgs, resolveImagePath } from "../../../src/utils/image-cli-args";
import { executeSwiftCli, readImageAsBase64 } from "../../../src/utils/peekaboo-cli";
import { mockSwiftCli } from "../../mocks/peekaboo-cli.mock";
import { pino } from "pino";
import {
  SavedFile,
  ImageCaptureData,
  ToolResponse,
  AIProvider,
  ImageInput,
} from "../../../src/types";
import * as fs from "fs/promises";
import * as os from "os";
import * as path from "path";

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

// Mock image-analysis module
vi.mock("../../../src/utils/image-analysis", () => ({
  performAutomaticAnalysis: vi.fn(),
}));

// Mock AI providers
vi.mock("../../../src/utils/ai-providers", () => ({
  parseAIProviders: vi.fn(),
  analyzeImageWithProvider: vi.fn(),
}));

import { performAutomaticAnalysis } from "../../../src/utils/image-analysis";
import { parseAIProviders } from "../../../src/utils/ai-providers";

const mockExecuteSwiftCli = executeSwiftCli as vi.MockedFunction<
  typeof executeSwiftCli
>;
const mockReadImageAsBase64 = readImageAsBase64 as vi.MockedFunction<
  typeof readImageAsBase64
>;
const mockPerformAutomaticAnalysis = performAutomaticAnalysis as vi.MockedFunction<typeof performAutomaticAnalysis>;
const mockParseAIProviders = parseAIProviders as vi.MockedFunction<typeof parseAIProviders>;

const mockFsRm = fs.rm as vi.MockedFunction<typeof fs.rm>;
const mockResolveImagePath = resolveImagePath as vi.MockedFunction<typeof resolveImagePath>;

const mockLogger = pino({ level: "silent" });
const mockContext = { logger: mockLogger };

const MOCK_TEMP_DIR = "/tmp";
const MOCK_TEMP_IMAGE_DIR = "/tmp/peekaboo-img-XXXXXX";
const MOCK_SAVED_FILE_PATH = "/tmp/peekaboo-img-XXXXXX/capture.png";

describe("Image Tool", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockFsRm.mockResolvedValue(undefined);
    process.env.PEEKABOO_AI_PROVIDERS = "";
  });

  describe("imageToolHandler - Capture Only", () => {
    it("should capture screen with minimal parameters (format omitted, path omitted)", async () => {
      // Mock resolveImagePath to return a temp directory
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_SAVED_FILE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");

      const result = await imageToolHandler({}, mockContext);

      expect(result.content[0].type).toBe("text");
      expect(result.content[0].text).toContain("Captured 1 image");
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["image", "--mode", "screen", "--path", MOCK_TEMP_IMAGE_DIR, "--format", "png"]),
        mockLogger,
      );
      
      // When format is omitted, it defaults to "png", not "data"
      // So no warning is shown and no base64 data is returned for screen captures
      expect(result.content.some((item) => item.type === "image")).toBe(false);
      expect(result.saved_files).toEqual(mockResponse.data.saved_files);
      expect(result.analysis_text).toBeUndefined();
      expect(result.model_used).toBeUndefined();
      
      // Verify no cleanup - files are preserved
      expect(mockFsRm).not.toHaveBeenCalled();
    });

    it("should auto-fallback screen capture with format: 'data' to PNG", async () => {
      // Mock resolveImagePath to return a temp directory
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_SAVED_FILE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const result = await imageToolHandler(
        { format: "data" },
        mockContext,
      );

      // Should succeed but with a warning
      expect(result.isError).toBeUndefined();
      expect(result.content[0].type).toBe("text");
      expect(result.content[0].text).toContain("Captured 1 image");
      
      // Should have format warning
      const warningContent = result.content.find(item => 
        item.type === "text" && item.text?.includes("Screen captures cannot use format 'data'")
      );
      expect(warningContent).toBeDefined();
      expect(warningContent?.text).toContain("Automatically using PNG format instead");
      
      // Should have called Swift CLI with PNG format
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--format", "png"]),
        mockLogger,
      );
      
      // Should NOT return base64 data for screen captures
      expect(result.content.some((item) => item.type === "image")).toBe(false);
    });

    it("should allow app capture with format: 'data'", async () => {
      // Mock resolveImagePath to return a temp directory for format: "data"
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("Safari", {
        path: MOCK_SAVED_FILE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");

      const result = await imageToolHandler(
        { app_target: "Safari", format: "data" },
        mockContext,
      );

      expect(result.content).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ type: "text" }),
          expect.objectContaining({ type: "image", data: "base64imagedata" }),
        ]),
      );
      expect(result.saved_files).toEqual(mockResponse.data.saved_files);
      
      // Verify no cleanup - files are preserved
      expect(mockFsRm).not.toHaveBeenCalled();
    });

    it("should save file and return base64 when format: 'data' with path for app capture", async () => {
      const userPath = "/user/test.png";
      // Mock resolveImagePath to return the user path (no temp dir)
      mockResolveImagePath.mockResolvedValue({
        effectivePath: userPath,
        tempDirUsed: undefined,
      });
      
      const mockSavedFile: SavedFile = {
        path: userPath,
        mime_type: "image/png",
        item_label: "Safari",
      };
      const mockResponse = {
        success: true,
        data: { saved_files: [mockSavedFile] },
        messages: ["Captured one file"],
      };
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");

      const result = await imageToolHandler(
        { app_target: "Safari", format: "data", path: userPath },
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--path", userPath, "--format", "png"]),
        mockLogger,
      );
      expect(result.content).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ type: "text" }),
          expect.objectContaining({ type: "image", data: "base64imagedata" }),
        ]),
      );
      expect(result.saved_files).toEqual([mockSavedFile]);
      
      // No cleanup when path is provided
      expect(mockFsRm).not.toHaveBeenCalled();
    });

    it("should save file without base64 when format: 'png' with path", async () => {
      const userPath = "/user/test.png";
      // Mock resolveImagePath to return the user path (no temp dir)
      mockResolveImagePath.mockResolvedValue({
        effectivePath: userPath,
        tempDirUsed: undefined,
      });
      
      const mockSavedFile: SavedFile = {
        path: userPath,
        mime_type: "image/png",
        item_label: "Screen 1",
      };
      const mockResponse = {
        success: true,
        data: { saved_files: [mockSavedFile] },
        messages: ["Captured one file"],
      };
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const result = await imageToolHandler(
        { format: "png", path: userPath },
        mockContext,
      );

      expect(result.content[0]).toEqual(
        expect.objectContaining({
          type: "text",
          text: expect.stringContaining("Captured 1 image"),
        }),
      );
      // Check for capture messages if present
      if (result.content.length > 1) {
        expect(result.content[1]).toEqual(
          expect.objectContaining({
            type: "text",
            text: expect.stringContaining("Capture Messages"),
          }),
        );
      }
      // No base64 in content
      expect(result.content.some((item) => item.type === "image")).toBe(false);
      expect(result.saved_files).toEqual([mockSavedFile]);
    });

    it("should handle app_target: 'screen:1' with --screen-index", async () => {
      // Mock resolveImagePath for minimal case
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {
        item_label: "Display 0 (Index 1)",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      await imageToolHandler(
        { app_target: "screen:1" },
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--mode", "screen", "--screen-index", "1"]),
        mockLogger,
      );
    });

    it("should handle app_target: 'screen:abc' with warning about invalid index", async () => {
      // Mock resolveImagePath for minimal case
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {});
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const loggerWarnSpy = vi.spyOn(mockLogger, "warn");

      await imageToolHandler(
        { app_target: "screen:abc" },
        mockContext,
      );

      expect(loggerWarnSpy).toHaveBeenCalledWith(
        expect.objectContaining({ screenIndex: "abc" }),
        "Invalid screen index 'abc' in app_target, capturing all screens.",
      );
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--mode", "screen"]),
        mockLogger,
      );
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.not.arrayContaining(["--screen-index"]),
        mockLogger,
      );
    });

    it("should handle case-insensitive format values", async () => {
      // Import schema to test preprocessing
      const { imageToolSchema } = await import("../../../src/types/index.js");
      
      // Mock resolveImagePath for minimal case
      mockResolveImagePath.mockResolvedValue({
        effectivePath: "/tmp/test.png",
        tempDirUsed: undefined,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: "/tmp/test.png",
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      // Test uppercase PNG - parse through schema first
      const parsedInput = imageToolSchema.parse({ format: "PNG", path: "/tmp/test.png" });
      await imageToolHandler(
        parsedInput,
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--format", "png"]),
        mockLogger,
      );
    });

    it("should handle jpeg alias for jpg format", async () => {
      // Import schema to test preprocessing
      const { imageToolSchema } = await import("../../../src/types/index.js");
      
      // Mock resolveImagePath for minimal case
      mockResolveImagePath.mockResolvedValue({
        effectivePath: "/tmp/test.jpg",
        tempDirUsed: undefined,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: "/tmp/test.jpg",
        format: "jpg",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      // Test jpeg alias - parse through schema first
      const parsedInput = imageToolSchema.parse({ format: "jpeg", path: "/tmp/test.jpg" });
      await imageToolHandler(
        parsedInput,
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--format", "jpg"]),
        mockLogger,
      );
    });

    it("should handle app_target: 'frontmost' with warning", async () => {
      // Mock resolveImagePath for minimal case
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {});
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const loggerWarnSpy = vi.spyOn(mockLogger, "warn");

      await imageToolHandler(
        { app_target: "frontmost" },
        mockContext,
      );

      expect(loggerWarnSpy).toHaveBeenCalledWith(
        "'frontmost' target requires determining current frontmost app, defaulting to screen mode",
      );
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--mode", "screen"]),
        mockLogger,
      );
    });

    it("should handle app_target: 'AppName'", async () => {
      // Mock resolveImagePath for minimal case
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("Safari", {});
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      await imageToolHandler(
        { app_target: "Safari" },
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--app", "Safari", "--mode", "multi"]),
        mockLogger,
      );
    });

    it("should handle app_target: 'AppName:WINDOW_TITLE:Title'", async () => {
      // Mock resolveImagePath for minimal case
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("Safari", {});
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      await imageToolHandler(
        { app_target: "Safari:WINDOW_TITLE:Apple" },
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining([
          "--app", "Safari",
          "--mode", "window",
          "--window-title", "Apple"
        ]),
        mockLogger,
      );
    });

    it("should handle app_target: 'AppName:WINDOW_INDEX:2'", async () => {
      // Mock resolveImagePath for minimal case
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("Safari", {});
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      await imageToolHandler(
        { app_target: "Safari:WINDOW_INDEX:2" },
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining([
          "--app", "Safari",
          "--mode", "window",
          "--window-index", "2"
        ]),
        mockLogger,
      );
    });

    it("should handle capture_focus parameter", async () => {
      // Mock resolveImagePath for minimal case
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {});
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      await imageToolHandler(
        { capture_focus: "foreground" },
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--capture-focus", "foreground"]),
        mockLogger,
      );
    });

    it("should handle capture_focus auto mode", async () => {
      // Mock resolveImagePath for minimal case
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {});
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      await imageToolHandler(
        { capture_focus: "auto" },
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--capture-focus", "auto"]),
        mockLogger,
      );
    });

    it("should default to background capture_focus when not specified", async () => {
      // Mock resolveImagePath for minimal case
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {});
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      await imageToolHandler(
        {},
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--capture-focus", "background"]),
        mockLogger,
      );
    });
  });

  describe("imageToolHandler - Capture and Analyze", () => {
    const MOCK_QUESTION = "What is in this image?";
    const MOCK_ANALYSIS_RESPONSE = "This is a cat.";
    const MOCK_MODEL_USED = "ollama/llava:latest";

    beforeEach(() => {
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava:latest" }
      ]);
      mockPerformAutomaticAnalysis.mockResolvedValue({
        analysisText: MOCK_ANALYSIS_RESPONSE,
        modelUsed: MOCK_MODEL_USED,
      });
      mockReadImageAsBase64.mockResolvedValue("base64dataforanalysis");
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava:latest";
    });

    it("should capture, analyze, and PRESERVE temp image if no path provided", async () => {
      // Mock resolveImagePath to return temp directory when question is asked
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_SAVED_FILE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler(
        { question: MOCK_QUESTION },
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--path", MOCK_TEMP_IMAGE_DIR]),
        mockLogger,
      );
      expect(mockPerformAutomaticAnalysis).toHaveBeenCalledWith(
        "base64dataforanalysis",
        MOCK_QUESTION,
        mockLogger,
        "ollama/llava:latest",
      );

      expect(result.analysis_text).toBe(MOCK_ANALYSIS_RESPONSE);
      expect(result.model_used).toBe(MOCK_MODEL_USED);
      expect(result.content).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            text: expect.stringContaining("Captured 1 image"),
          }),
          expect.objectContaining({
            text: expect.stringContaining("Analysis succeeded"),
          }),
          expect.objectContaining({
            text: `Analysis Result: ${MOCK_ANALYSIS_RESPONSE}`,
          }),
        ]),
      );
      expect(result.saved_files).toEqual(mockCliResponse.data.saved_files);
      // No base64 in content when question is asked
      expect(
        result.content.some((item) => item.type === "image" && item.data),
      ).toBe(false);
      // File is no longer removed even when no path provided
      expect(mockFsRm).not.toHaveBeenCalled();
      expect(result.isError).toBeUndefined();
    });

    it("should capture, analyze, and keep image if path IS provided", async () => {
      const USER_PATH = "/user/specified/path.jpg";
      // Mock resolveImagePath to return the user-provided path (no temp dir)
      mockResolveImagePath.mockResolvedValue({
        effectivePath: USER_PATH,
        tempDirUsed: undefined,
      });
      
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: USER_PATH,
        format: "jpg",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler(
        {
          path: USER_PATH,
          question: MOCK_QUESTION,
          format: "jpg",
        },
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--path", USER_PATH, "--format", "jpg"]),
        mockLogger,
      );
      expect(mockPerformAutomaticAnalysis).toHaveBeenCalledWith(
        "base64dataforanalysis",
        MOCK_QUESTION,
        mockLogger,
        "ollama/llava:latest",
      );

      expect(result.analysis_text).toBe(MOCK_ANALYSIS_RESPONSE);
      expect(result.saved_files).toEqual(mockCliResponse.data?.saved_files);
      // No cleanup when path is provided
      expect(mockFsRm).not.toHaveBeenCalled();
      expect(result.isError).toBeUndefined();
    });

    it("should handle failure in AI provider", async () => {
      // Mock resolveImagePath to return temp directory when question is asked
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      mockPerformAutomaticAnalysis.mockResolvedValue({
        error: "Analysis failed: All configured AI providers failed or are unavailable",
      });
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_SAVED_FILE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler(
        { question: MOCK_QUESTION },
        mockContext,
      );

      expect(result.analysis_text).toBe(
        "Analysis failed: All configured AI providers failed or are unavailable",
      );
      expect(result.isError).toBe(true);
      expect(result.model_used).toBeUndefined();
      // File is no longer removed on analysis failure
      expect(mockFsRm).not.toHaveBeenCalled();
    });

    it("should handle when AI analysis is not configured", async () => {
      // Mock resolveImagePath to return temp directory when question is asked
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      mockParseAIProviders.mockReturnValue([]);
      process.env.PEEKABOO_AI_PROVIDERS = "";
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_SAVED_FILE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler(
        { question: MOCK_QUESTION },
        mockContext,
      );

      expect(result.analysis_text).toBe(
        "Analysis skipped: AI analysis not configured on this server (PEEKABOO_AI_PROVIDERS is not set or empty).",
      );
      expect(result.isError).toBe(true);
    });

    it("should handle when AI provider returns empty analysisText", async () => {
      // Mock resolveImagePath to return temp directory when question is asked
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      mockPerformAutomaticAnalysis.mockResolvedValue({
        analysisText: "",
        modelUsed: MOCK_MODEL_USED,
      });
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_SAVED_FILE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler(
        { question: MOCK_QUESTION },
        mockContext,
      );

      // When AI provider returns empty string, it's still considered a "success"
      expect(result.analysis_text).toBe("");
      expect(result.isError).toBeUndefined();
    });

    it("should NOT return base64 data in content if question is asked", async () => {
      // Mock resolveImagePath to return temp directory when question is asked
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockCliResponse = mockSwiftCli.captureImage("Safari", {
        path: MOCK_SAVED_FILE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler(
        {
          app_target: "Safari", // Use app capture to allow format: "data"
          question: MOCK_QUESTION,
          format: "data", // Even with format: "data"
        },
        mockContext,
      );

      expect(
        result.content.some((item) => item.type === "image" && item.data),
      ).toBe(false);
      expect(result.analysis_text).toBe(MOCK_ANALYSIS_RESPONSE);
    });

    it("should analyze all images when capture results in multiple files", async () => {
      // Mock resolveImagePath to return a temporary directory path
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      // Mock executeSwiftCli with two saved files
      const mockFile1: SavedFile = {
        path: "/tmp/peekaboo-img-XXXXXX/window1.png",
        mime_type: "image/png",
        item_label: "Window 1",
      };
      const mockFile2: SavedFile = {
        path: "/tmp/peekaboo-img-XXXXXX/window2.png",
        mime_type: "image/png",
        item_label: "Window 2",
      };
      const mockResponse = {
        success: true,
        data: { saved_files: [mockFile1, mockFile2] },
        messages: ["Captured 2 windows"],
      };
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);
      
      // Mock readImageAsBase64 to return different base64 strings
      mockReadImageAsBase64
        .mockResolvedValueOnce("base64dataforwindow1")
        .mockResolvedValueOnce("base64dataforwindow2");
      
      // Mock performAutomaticAnalysis to return different analysis for each call
      mockPerformAutomaticAnalysis
        .mockResolvedValueOnce({
          analysisText: "Analysis for window 1.",
          modelUsed: MOCK_MODEL_USED,
        })
        .mockResolvedValueOnce({
          analysisText: "Analysis for window 2.",
          modelUsed: MOCK_MODEL_USED,
        });

      // Call imageToolHandler with a question
      const result = await imageToolHandler(
        { question: MOCK_QUESTION },
        mockContext,
      );

      // Verify performAutomaticAnalysis was called twice
      expect(mockPerformAutomaticAnalysis).toHaveBeenCalledTimes(2);
      expect(mockPerformAutomaticAnalysis).toHaveBeenNthCalledWith(
        1,
        "base64dataforwindow1",
        MOCK_QUESTION,
        mockLogger,
        "ollama/llava:latest",
      );
      expect(mockPerformAutomaticAnalysis).toHaveBeenNthCalledWith(
        2,
        "base64dataforwindow2",
        MOCK_QUESTION,
        mockLogger,
        "ollama/llava:latest",
      );
      
      // Verify readImageAsBase64 was called twice
      expect(mockReadImageAsBase64).toHaveBeenCalledTimes(2);
      expect(mockReadImageAsBase64).toHaveBeenNthCalledWith(1, mockFile1.path);
      expect(mockReadImageAsBase64).toHaveBeenNthCalledWith(2, mockFile2.path);
      
      // Verify the final analysis_text contains both results with headers
      expect(result.analysis_text).toBe(
        "Analysis for Window 1:\nAnalysis for window 1.\n\nAnalysis for Window 2:\nAnalysis for window 2."
      );
      
      // Verify that the temporary directory is no longer cleaned up (files preserved)
      expect(mockFsRm).not.toHaveBeenCalled();
    });

    it("should use window titles for analysis labels when capturing multiple windows", async () => {
      // Mock resolveImagePath to return a temporary directory path
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      // Mock executeSwiftCli with two saved files that have window titles
      const mockFile1: SavedFile = {
        path: "/tmp/peekaboo-img-XXXXXX/chrome_window1.png",
        mime_type: "image/png",
        item_label: "Google Chrome",
        window_title: "MCP Inspector",
        window_index: 0,
        window_id: 123,
      };
      const mockFile2: SavedFile = {
        path: "/tmp/peekaboo-img-XXXXXX/chrome_window2.png", 
        mime_type: "image/png",
        item_label: "Google Chrome",
        window_title: "(9) Home / X",
        window_index: 1,
        window_id: 124,
      };
      const mockResponse = {
        success: true,
        data: { saved_files: [mockFile1, mockFile2] },
        messages: ["Captured 2 Chrome windows"],
      };
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);
      
      // Mock readImageAsBase64 to return different base64 strings
      mockReadImageAsBase64
        .mockResolvedValueOnce("base64dataforwindow1")
        .mockResolvedValueOnce("base64dataforwindow2");
      
      // Mock performAutomaticAnalysis to return different analysis for each call
      mockPerformAutomaticAnalysis
        .mockResolvedValueOnce({
          analysisText: "This shows the MCP Inspector interface.",
          modelUsed: MOCK_MODEL_USED,
        })
        .mockResolvedValueOnce({
          analysisText: "This shows the X (Twitter) home page.",
          modelUsed: MOCK_MODEL_USED,
        });

      // Call imageToolHandler with a question
      const result = await imageToolHandler(
        { question: "What is shown in each window?" },
        mockContext,
      );

      // Verify the final analysis_text uses window titles instead of app names
      expect(result.analysis_text).toBe(
        'Analysis for "MCP Inspector":\nThis shows the MCP Inspector interface.\n\nAnalysis for "(9) Home / X":\nThis shows the X (Twitter) home page.'
      );
      
      // Verify that the temporary directory is no longer cleaned up (files preserved)
      expect(mockFsRm).not.toHaveBeenCalled();
    });

    it("should fallback to window index when no window title is available", async () => {
      // Mock resolveImagePath to return a temporary directory path
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      // Mock executeSwiftCli with two saved files without window titles
      const mockFile1: SavedFile = {
        path: "/tmp/peekaboo-img-XXXXXX/app_window1.png",
        mime_type: "image/png",
        item_label: "Some App",
        window_index: 0,
        window_id: 123,
      };
      const mockFile2: SavedFile = {
        path: "/tmp/peekaboo-img-XXXXXX/app_window2.png", 
        mime_type: "image/png",
        item_label: "Some App",
        window_index: 1,
        window_id: 124,
      };
      const mockResponse = {
        success: true,
        data: { saved_files: [mockFile1, mockFile2] },
        messages: ["Captured 2 app windows"],
      };
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);
      
      // Mock readImageAsBase64 to return different base64 strings
      mockReadImageAsBase64
        .mockResolvedValueOnce("base64dataforwindow1")
        .mockResolvedValueOnce("base64dataforwindow2");
      
      // Mock performAutomaticAnalysis to return different analysis for each call
      mockPerformAutomaticAnalysis
        .mockResolvedValueOnce({
          analysisText: "Analysis for first window.",
          modelUsed: MOCK_MODEL_USED,
        })
        .mockResolvedValueOnce({
          analysisText: "Analysis for second window.",
          modelUsed: MOCK_MODEL_USED,
        });

      // Call imageToolHandler with a question
      const result = await imageToolHandler(
        { question: "What is shown in each window?" },
        mockContext,
      );

      // Verify the final analysis_text uses window index fallback
      expect(result.analysis_text).toBe(
        "Analysis for Some App (Window 1):\nAnalysis for first window.\n\nAnalysis for Some App (Window 2):\nAnalysis for second window."
      );
      
      // Verify that the temporary directory is no longer cleaned up (files preserved)
      expect(mockFsRm).not.toHaveBeenCalled();
    });
  });

  describe("buildSwiftCliArgs", () => {
    it("should default to screen mode if no app_target", () => {
      const args = buildSwiftCliArgs({}, undefined);
      expect(args).toEqual([
        "image",
        "--mode",
        "screen",
        "--format",
        "png",
        "--capture-focus",
        "background",
      ]);
    });

    it("should handle empty app_target", () => {
      const args = buildSwiftCliArgs({ app_target: "" }, undefined);
      expect(args).toEqual([
        "image",
        "--mode",
        "screen",
        "--format",
        "png",
        "--capture-focus",
        "background",
      ]);
    });

    it("should handle app_target: 'screen:1' with --screen-index", () => {
      const args = buildSwiftCliArgs({ app_target: "screen:1" }, undefined, undefined, mockLogger);
      expect(args).toEqual(
        expect.arrayContaining(["--mode", "screen", "--screen-index", "1"]),
      );
      expect(args).not.toContain("--app");
    });

    it("should handle app_target: 'screen:0' with --screen-index", () => {
      const args = buildSwiftCliArgs({ app_target: "screen:0" }, undefined, undefined, mockLogger);
      expect(args).toEqual(
        expect.arrayContaining(["--mode", "screen", "--screen-index", "0"]),
      );
      expect(args).not.toContain("--app");
    });

    it("should handle app_target: 'screen:abc' with warning", () => {
      const loggerWarnSpy = vi.spyOn(mockLogger, "warn");
      const args = buildSwiftCliArgs({ app_target: "screen:abc" }, undefined, undefined, mockLogger);
      expect(args).toEqual(
        expect.arrayContaining(["--mode", "screen"]),
      );
      expect(args).not.toContain("--screen-index");
      expect(args).not.toContain("--app");
      expect(loggerWarnSpy).toHaveBeenCalledWith(
        expect.objectContaining({ screenIndex: "abc" }),
        "Invalid screen index 'abc' in app_target, capturing all screens.",
      );
    });

    it("should handle app_target: 'frontmost'", () => {
      const loggerWarnSpy = vi.spyOn(mockLogger, "warn");
      const args = buildSwiftCliArgs({ app_target: "frontmost" }, undefined, undefined, mockLogger);
      expect(args).toEqual(
        expect.arrayContaining(["--mode", "screen"]),
      );
      expect(args).not.toContain("--app");
      expect(loggerWarnSpy).toHaveBeenCalled();
    });

    it("should handle simple app name", () => {
      const args = buildSwiftCliArgs({ app_target: "Safari" }, undefined);
      expect(args).toEqual(
        expect.arrayContaining(["--app", "Safari", "--mode", "multi"]),
      );
    });

    it("should handle app with window title", () => {
      const args = buildSwiftCliArgs({ app_target: "Safari:WINDOW_TITLE:Apple Website" }, undefined);
      expect(args).toEqual(
        expect.arrayContaining([
          "--app", "Safari",
          "--mode", "window",
          "--window-title", "Apple Website"
        ]),
      );
    });

    it("should handle app with window index", () => {
      const args = buildSwiftCliArgs({ app_target: "Terminal:WINDOW_INDEX:2" }, undefined);
      expect(args).toEqual(
        expect.arrayContaining([
          "--app", "Terminal",
          "--mode", "window",
          "--window-index", "2"
        ]),
      );
    });

    it("should include path when provided", () => {
      const args = buildSwiftCliArgs({ path: "/tmp/image.jpg" }, "/tmp/image.jpg");
      expect(args).toEqual(
        expect.arrayContaining(["--path", "/tmp/image.jpg"]),
      );
    });

    it("should handle format: 'data' as png for Swift CLI", () => {
      const args = buildSwiftCliArgs({ format: "data" }, undefined);
      expect(args).toEqual(expect.arrayContaining(["--format", "png"]));
    });

    it("should include format jpg", () => {
      const args = buildSwiftCliArgs({ format: "jpg" }, undefined);
      expect(args).toEqual(expect.arrayContaining(["--format", "jpg"]));
    });

    it("should include capture_focus", () => {
      const args = buildSwiftCliArgs({ capture_focus: "foreground" }, undefined);
      expect(args).toEqual(
        expect.arrayContaining(["--capture-focus", "foreground"]),
      );
    });

    it("should default to background focus when capture_focus is an empty string", () => {
      const args = buildSwiftCliArgs({ capture_focus: "" }, undefined);
      expect(args).toEqual([
        "image",
        "--mode",
        "screen",
        "--format",
        "png",
        "--capture-focus",
        "background"
      ]);
    });

    it("should include capture_focus auto mode", () => {
      const args = buildSwiftCliArgs({ capture_focus: "auto" }, undefined);
      expect(args).toEqual(
        expect.arrayContaining(["--capture-focus", "auto"]),
      );
    });

    it("should default to background focus when capture_focus is not provided", () => {
      const args = buildSwiftCliArgs({}, undefined);
      expect(args).toEqual(
        expect.arrayContaining(["--capture-focus", "background"]),
      );
    });

    it("should include effectivePath when provided", () => {
      const args = buildSwiftCliArgs({ format: "png" }, "/some/path.png");
      expect(args).toContain("--path");
      expect(args).toContain("/some/path.png");
    });

    it("should handle effectivePath for temp directory", () => {
      const args = buildSwiftCliArgs({}, "/tmp/temp-path");
      expect(args).toContain("--path");
      expect(args).toContain("/tmp/temp-path");
    });

    it("should handle all options together", () => {
      const input: ImageInput = {
        app_target: "Preview:WINDOW_INDEX:1",
        path: "/users/test/file.png",
        format: "png",
        capture_focus: "foreground",
      };
      const args = buildSwiftCliArgs(input, "/users/test/file.png");
      expect(args).toEqual([
        "image",
        "--app",
        "Preview",
        "--mode",
        "window",
        "--window-index",
        "1",
        "--path",
        "/users/test/file.png",
        "--format",
        "png",
        "--capture-focus",
        "foreground",
      ]);
    });
  });

  describe("imageToolHandler - Invalid format handling", () => {
    it("should fall back to PNG when format is empty string", async () => {
      // Mock resolveImagePath
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_SAVED_FILE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      // Test with empty string format - schema should preprocess to undefined
      const result = await imageToolHandler(
        { format: "" as any },
        mockContext,
      );

      expect(result.isError).toBeUndefined();
      // Should use PNG format
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--format", "png"]),
        mockLogger,
      );
    });

    it("should fall back to PNG when format is an invalid value", async () => {
      // Import schema to test preprocessing
      const { imageToolSchema } = await import("../../../src/types/index.js");
      
      // Mock resolveImagePath
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_SAVED_FILE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      // Test with invalid format - schema should preprocess to 'png'
      const parsedInput = imageToolSchema.parse({ format: "invalid" });
      const result = await imageToolHandler(
        parsedInput,
        mockContext,
      );

      expect(result.isError).toBeUndefined();
      // Should use PNG format
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--format", "png"]),
        mockLogger,
      );
    });
  });

  describe("imageToolHandler - Error message handling", () => {
    it("should include error details for ambiguous app identifier", async () => {
      // Mock resolveImagePath
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      // Mock Swift CLI returning ambiguous app error with details
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Multiple applications match identifier 'C'. Please be more specific.",
          code: "AMBIGUOUS_APP_IDENTIFIER",
          details: "Matches found: Calendar (com.apple.iCal), Console (com.apple.Console), Cursor (com.todesktop.230313mzl4w4u92)"
        }
      });

      const result = await imageToolHandler(
        { app_target: "C" },
        mockContext,
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].type).toBe("text");
      // Should include both the main message and the details
      expect(result.content[0].text).toContain("Multiple applications match identifier 'C'");
      expect(result.content[0].text).toContain("Matches found: Calendar (com.apple.iCal), Console (com.apple.Console), Cursor (com.todesktop.230313mzl4w4u92)");
    });

    it("should handle errors without details gracefully", async () => {
      // Mock resolveImagePath
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      // Mock Swift CLI returning error without details
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Application not found",
          code: "APP_NOT_FOUND"
        }
      });

      const result = await imageToolHandler(
        { app_target: "NonExistent" },
        mockContext,
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].type).toBe("text");
      // Should only include the main message
      expect(result.content[0].text).toBe("Image capture failed: Application not found");
    });
  });

  describe("imageToolHandler - Whitespace trimming", () => {
    it("should trim leading and trailing whitespace from app_target", async () => {
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("Spotify", {
        path: MOCK_SAVED_FILE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      await imageToolHandler(
        { app_target: "   Spotify   " },
        mockContext,
      );

      // Check that the Swift CLI was called with trimmed app name
      const callArgs = mockExecuteSwiftCli.mock.calls[0][0];
      const appIndex = callArgs.indexOf("--app");
      expect(callArgs[appIndex + 1]).toBe("Spotify"); // Should be trimmed
    });
  });
});