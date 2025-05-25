import { vi } from "vitest";
import {
  imageToolHandler,
  buildSwiftCliArgs,
} from "../../../src/tools/image";
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

// Mock os
vi.mock("os");

// Mock path
vi.mock("path");

// Mock AI providers instead of performAutomaticAnalysis
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
import { parseAIProviders, analyzeImageWithProvider } from "../../../src/utils/ai-providers";
const mockParseAIProviders = parseAIProviders as vi.MockedFunction<typeof parseAIProviders>;
const mockAnalyzeImageWithProvider = analyzeImageWithProvider as vi.MockedFunction<typeof analyzeImageWithProvider>;

const mockFsReadFile = fs.readFile as vi.MockedFunction<typeof fs.readFile>;
const mockFsUnlink = fs.unlink as vi.MockedFunction<typeof fs.unlink>;
const mockFsMkdtemp = fs.mkdtemp as vi.MockedFunction<typeof fs.mkdtemp>;
const mockFsRmdir = fs.rmdir as vi.MockedFunction<typeof fs.rmdir>;
const mockFsWriteFile = fs.writeFile as vi.MockedFunction<typeof fs.writeFile>;
const mockOsTmpdir = os.tmpdir as vi.MockedFunction<typeof os.tmpdir>;
const mockPathJoin = path.join as vi.MockedFunction<typeof path.join>;
const mockPathDirname = path.dirname as vi.MockedFunction<typeof path.dirname>;

const mockLogger = pino({ level: "silent" });
const mockContext = { logger: mockLogger };

const MOCK_TEMP_DIR = "/tmp";
const MOCK_TEMP_IMAGE_DIR = "/tmp/peekaboo-img-XXXXXX";
const MOCK_TEMP_IMAGE_PATH = "/tmp/peekaboo-img-XXXXXX/capture.png";
const MOCK_TEMP_ANALYSIS_DIR = "/tmp/peekaboo-analysis-XXXXXX";
const MOCK_TEMP_ANALYSIS_PATH = "/tmp/peekaboo-analysis-XXXXXX/image.png";

describe("Image Tool", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockOsTmpdir.mockReturnValue(MOCK_TEMP_DIR);
    mockPathJoin.mockImplementation((...paths) => paths.join("/"));
    mockPathDirname.mockImplementation((p) => {
      const lastSlash = p.lastIndexOf("/");
      return lastSlash === -1 ? "." : p.substring(0, lastSlash);
    });
    mockFsUnlink.mockResolvedValue(undefined);
    mockFsRmdir.mockResolvedValue(undefined);
    mockFsWriteFile.mockResolvedValue(undefined);
    mockFsReadFile.mockResolvedValue(Buffer.from("fake-image-data"));
    mockFsMkdtemp.mockImplementation((prefix) => {
      if (prefix.includes("peekaboo-img-")) {
        return Promise.resolve(MOCK_TEMP_IMAGE_DIR);
      } else if (prefix.includes("peekaboo-analysis-")) {
        return Promise.resolve(MOCK_TEMP_ANALYSIS_DIR);
      }
      return Promise.resolve(prefix + "XXXXXX");
    });
    process.env.PEEKABOO_AI_PROVIDERS = "";
  });

  describe("imageToolHandler - Capture Only", () => {
    it("should capture screen with minimal parameters (format omitted, path omitted)", async () => {
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_TEMP_IMAGE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");

      const result = await imageToolHandler({}, mockContext);

      expect(result.content[0].type).toBe("text");
      expect(result.content[0].text).toContain("Captured 1 image");
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["image", "--mode", "screen", "--path", MOCK_TEMP_IMAGE_PATH, "--format", "png"]),
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
    });

    it("should capture screen with format: 'data'", async () => {
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_TEMP_IMAGE_PATH,
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
    });

    it("should save file and return base64 when format: 'data' with path", async () => {
      const userPath = "/user/test.png";
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
    });

    it("should save file without base64 when format: 'png' with path", async () => {
      const userPath = "/user/test.png";
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

    it("should handle app_target: 'screen:1' with warning", async () => {
      const mockResponse = mockSwiftCli.captureImage("screen", {});
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const loggerWarnSpy = vi.spyOn(mockLogger, "warn");

      await imageToolHandler(
        { app_target: "screen:1" },
        mockContext,
      );

      expect(loggerWarnSpy).toHaveBeenCalledWith(
        expect.objectContaining({ screenIndex: "1" }),
        "Screen index specification not yet supported by Swift CLI, capturing all screens",
      );
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--mode", "screen"]),
        mockLogger,
      );
    });

    it("should handle app_target: 'frontmost' with warning", async () => {
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
      mockAnalyzeImageWithProvider.mockResolvedValue(MOCK_ANALYSIS_RESPONSE);
      mockReadImageAsBase64.mockResolvedValue("base64dataforanalysis");
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava:latest";
    });

    it("should capture, analyze, and delete temp image if no path provided", async () => {
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_TEMP_IMAGE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler(
        { question: MOCK_QUESTION },
        mockContext,
      );

      // The new implementation creates a temp dir first, then joins with capture.png
      expect(mockPathJoin).toHaveBeenCalledWith(
        expect.stringMatching(/^\/tmp\/peekaboo-img-/),
        "capture.png",
      );
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--path", MOCK_TEMP_IMAGE_PATH]),
        mockLogger,
      );
      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        expect.objectContaining({ provider: "ollama", model: "llava:latest" }),
        MOCK_TEMP_ANALYSIS_PATH,
        "base64dataforanalysis",
        MOCK_QUESTION,
        mockLogger,
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
      expect(mockFsUnlink).toHaveBeenCalledWith(MOCK_TEMP_IMAGE_PATH);
      expect(mockFsRmdir).toHaveBeenCalledWith(MOCK_TEMP_IMAGE_DIR);
      expect(result.isError).toBeUndefined();
    });

    it("should capture, analyze, and keep image if path IS provided", async () => {
      const USER_PATH = "/user/specified/path.jpg";
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

      // Path.join is called for the analysis temp path
      expect(mockPathJoin).toHaveBeenCalledWith(
        expect.stringMatching(/^\/tmp\/peekaboo-analysis-/),
        "image.png",
      );
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--path", USER_PATH, "--format", "jpg"]),
        mockLogger,
      );
      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        expect.objectContaining({ provider: "ollama", model: "llava:latest" }),
        MOCK_TEMP_ANALYSIS_PATH,
        "base64dataforanalysis",
        MOCK_QUESTION,
        mockLogger,
      );

      expect(result.analysis_text).toBe(MOCK_ANALYSIS_RESPONSE);
      expect(result.saved_files).toEqual(mockCliResponse.data?.saved_files);
      // Analysis temp file is cleaned up
      expect(mockFsUnlink).toHaveBeenCalledWith(MOCK_TEMP_ANALYSIS_PATH);
      expect(mockFsRmdir).toHaveBeenCalledWith(MOCK_TEMP_ANALYSIS_DIR);
      expect(result.isError).toBeUndefined();
    });

    it("should handle failure in AI provider", async () => {
      mockAnalyzeImageWithProvider.mockRejectedValue(
        new Error("AI analysis failed"),
      );
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_TEMP_IMAGE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler(
        { question: MOCK_QUESTION },
        mockContext,
      );

      expect(result.analysis_text).toContain(
        "Analysis failed: All configured AI providers failed or are unavailable",
      );
      expect(result.isError).toBe(true);
      expect(result.model_used).toBeUndefined();
      expect(mockFsUnlink).toHaveBeenCalledWith(MOCK_TEMP_IMAGE_PATH);
      expect(mockFsRmdir).toHaveBeenCalledWith(MOCK_TEMP_IMAGE_DIR);
    });

    it("should handle when AI provider returns empty analysisText", async () => {
      mockAnalyzeImageWithProvider.mockResolvedValue("");
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_TEMP_IMAGE_PATH,
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
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_TEMP_IMAGE_PATH,
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
  });

  describe("buildSwiftCliArgs", () => {
    it("should default to screen mode if no app_target", () => {
      const args = buildSwiftCliArgs({});
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
      const args = buildSwiftCliArgs({ app_target: "" });
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

    it("should handle app_target: 'screen:1'", () => {
      const loggerWarnSpy = vi.spyOn(mockLogger, "warn");
      const args = buildSwiftCliArgs({ app_target: "screen:1" }, mockLogger);
      expect(args).toEqual(
        expect.arrayContaining(["--mode", "screen"]),
      );
      expect(args).not.toContain("--app");
      expect(loggerWarnSpy).toHaveBeenCalled();
    });

    it("should handle app_target: 'frontmost'", () => {
      const loggerWarnSpy = vi.spyOn(mockLogger, "warn");
      const args = buildSwiftCliArgs({ app_target: "frontmost" }, mockLogger);
      expect(args).toEqual(
        expect.arrayContaining(["--mode", "screen"]),
      );
      expect(args).not.toContain("--app");
      expect(loggerWarnSpy).toHaveBeenCalled();
    });

    it("should handle simple app name", () => {
      const args = buildSwiftCliArgs({ app_target: "Safari" });
      expect(args).toEqual(
        expect.arrayContaining(["--app", "Safari", "--mode", "multi"]),
      );
    });

    it("should handle app with window title", () => {
      const args = buildSwiftCliArgs({ app_target: "Safari:WINDOW_TITLE:Apple Website" });
      expect(args).toEqual(
        expect.arrayContaining([
          "--app", "Safari",
          "--mode", "window",
          "--window-title", "Apple Website"
        ]),
      );
    });

    it("should handle app with window index", () => {
      const args = buildSwiftCliArgs({ app_target: "Terminal:WINDOW_INDEX:2" });
      expect(args).toEqual(
        expect.arrayContaining([
          "--app", "Terminal",
          "--mode", "window",
          "--window-index", "2"
        ]),
      );
    });

    it("should include path when provided", () => {
      const args = buildSwiftCliArgs({ path: "/tmp/image.jpg" });
      expect(args).toEqual(
        expect.arrayContaining(["--path", "/tmp/image.jpg"]),
      );
    });

    it("should handle format: 'data' as png for Swift CLI", () => {
      const args = buildSwiftCliArgs({ format: "data" });
      expect(args).toEqual(expect.arrayContaining(["--format", "png"]));
    });

    it("should include format jpg", () => {
      const args = buildSwiftCliArgs({ format: "jpg" });
      expect(args).toEqual(expect.arrayContaining(["--format", "jpg"]));
    });

    it("should include capture_focus", () => {
      const args = buildSwiftCliArgs({ capture_focus: "foreground" });
      expect(args).toEqual(
        expect.arrayContaining(["--capture-focus", "foreground"]),
      );
    });

    it("should use PEEKABOO_DEFAULT_SAVE_PATH if no path and no question", () => {
      process.env.PEEKABOO_DEFAULT_SAVE_PATH = "/default/env.png";
      const args = buildSwiftCliArgs({});
      expect(args).toContain("--path");
      expect(args).toContain("/default/env.png");
      delete process.env.PEEKABOO_DEFAULT_SAVE_PATH;
    });

    it("should NOT use PEEKABOO_DEFAULT_SAVE_PATH if effectivePath is provided", () => {
      process.env.PEEKABOO_DEFAULT_SAVE_PATH = "/default/env.png";
      // When effectivePath is provided (which happens when question is asked), it overrides PEEKABOO_DEFAULT_SAVE_PATH
      const args = buildSwiftCliArgs({}, undefined, "/tmp/temp-path.png");
      expect(args).toContain("--path");
      expect(args).toContain("/tmp/temp-path.png");
      expect(args).not.toContain("/default/env.png");
      delete process.env.PEEKABOO_DEFAULT_SAVE_PATH;
    });

    it("should handle all options together", () => {
      const input: ImageInput = {
        app_target: "Preview:WINDOW_INDEX:1",
        path: "/users/test/file.png",
        format: "png",
        capture_focus: "foreground",
      };
      const args = buildSwiftCliArgs(input);
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