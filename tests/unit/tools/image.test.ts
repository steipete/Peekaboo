import { vi } from "vitest";
import { imageToolHandler } from "../../../src/tools/image";
import { buildSwiftCliArgs, resolveImagePath } from "../../../src/utils/image-cli-args";
import {
  executeSwiftCli,
  readImageAsBase64,
} from "../../../src/utils/peekaboo-cli";
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

const mockExecuteSwiftCli = executeSwiftCli as vi.MockedFunction<
  typeof executeSwiftCli
>;
const mockReadImageAsBase64 = readImageAsBase64 as vi.MockedFunction<
  typeof readImageAsBase64
>;
import { performAutomaticAnalysis } from "../../../src/utils/image-analysis";
const mockPerformAutomaticAnalysis = performAutomaticAnalysis as vi.MockedFunction<typeof performAutomaticAnalysis>;

import { parseAIProviders } from "../../../src/utils/ai-providers";
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
      
      // When format is omitted and path is omitted, behaves like format: "data"
      expect(result.content).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ type: "text" }),
          expect.objectContaining({ type: "image", data: "base64imagedata" }),
        ]),
      );
      expect(result.saved_files).toEqual([]);
      expect(result.analysis_text).toBeUndefined();
      expect(result.model_used).toBeUndefined();
      
      // Verify cleanup with fs.rm
      expect(mockFsRm).toHaveBeenCalledWith(MOCK_TEMP_IMAGE_DIR, { recursive: true, force: true });
    });

    it("should capture screen with format: 'data'", async () => {
      // Mock resolveImagePath to return a temp directory for format: "data"
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

      const result = await imageToolHandler(
        { format: "data" },
        mockContext,
      );

      expect(result.content).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ type: "text" }),
          expect.objectContaining({ type: "image", data: "base64imagedata" }),
        ]),
      );
      expect(result.saved_files).toEqual([]);
      
      // Verify cleanup
      expect(mockFsRm).toHaveBeenCalledWith(MOCK_TEMP_IMAGE_DIR, { recursive: true, force: true });
    });

    it("should save file and return base64 when format: 'data' with path", async () => {
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
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");

      const result = await imageToolHandler(
        { format: "data", path: userPath },
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

    it("should capture, analyze, and delete temp image if no path provided", async () => {
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
      expect(result.saved_files).toEqual([]);
      // No base64 in content when question is asked
      expect(
        result.content.some((item) => item.type === "image" && item.data),
      ).toBe(false);
      expect(mockFsRm).toHaveBeenCalledWith(MOCK_TEMP_IMAGE_DIR, { recursive: true, force: true });
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
      expect(mockFsRm).toHaveBeenCalledWith(MOCK_TEMP_IMAGE_DIR, { recursive: true, force: true });
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
      
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_SAVED_FILE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler(
        {
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
      
      // Verify that the temporary directory is cleaned up
      expect(mockFsRm).toHaveBeenCalledWith(MOCK_TEMP_IMAGE_DIR, { recursive: true, force: true });
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
});