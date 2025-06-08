import { describe, it, expect, beforeEach, vi } from "vitest";
import { imageToolHandler } from "../../../src/tools/image";
import { buildSwiftCliArgs, resolveImagePath } from "../../../src/utils/image-cli-args";
import { executeSwiftCli, readImageAsBase64 } from "../../../src/utils/peekaboo-cli";
import { mockSwiftCli } from "../../mocks/peekaboo-cli.mock";
import { pino } from "pino";
import { ImageInput } from "../../../src/types";
import * as fs from "fs/promises";
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

const mockExecuteSwiftCli = executeSwiftCli as vi.MockedFunction<typeof executeSwiftCli>;
const mockReadImageAsBase64 = readImageAsBase64 as vi.MockedFunction<typeof readImageAsBase64>;
const mockPerformAutomaticAnalysis = performAutomaticAnalysis as vi.MockedFunction<typeof performAutomaticAnalysis>;
const mockParseAIProviders = parseAIProviders as vi.MockedFunction<typeof parseAIProviders>;
const mockFsRm = fs.rm as vi.MockedFunction<typeof fs.rm>;
const mockResolveImagePath = resolveImagePath as vi.MockedFunction<typeof resolveImagePath>;

const mockLogger = pino({ level: "silent" });
const mockContext = { logger: mockLogger };

const MOCK_TEMP_DIR = "/tmp";
const MOCK_TEMP_IMAGE_DIR = "/tmp/peekaboo-img-XXXXXX";
const MOCK_SAVED_FILE_PATH = "/tmp/peekaboo-img-XXXXXX/capture.png";

describe("Image Tool - Edge Cases", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockFsRm.mockResolvedValue(undefined);
    process.env.PEEKABOO_AI_PROVIDERS = "";
  });

  describe("Whitespace trimming in app_target", () => {
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

    it("should trim whitespace in window specifier format", async () => {
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("Safari", {});
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      await imageToolHandler(
        { app_target: "  Safari  :WINDOW_TITLE:Apple" },
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
  });

  describe("Format parameter case-insensitivity and aliases", () => {
    it("should handle uppercase PNG format", async () => {
      const { imageToolSchema } = await import("../../../src/types/index.js");
      
      mockResolveImagePath.mockResolvedValue({
        effectivePath: "/tmp/test.png",
        tempDirUsed: undefined,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: "/tmp/test.png",
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const parsedInput = imageToolSchema.parse({ format: "PNG", path: "/tmp/test.png" });
      await imageToolHandler(parsedInput, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--format", "png"]),
        mockLogger,
      );
    });

    it("should handle mixed case JPG format", async () => {
      const { imageToolSchema } = await import("../../../src/types/index.js");
      
      mockResolveImagePath.mockResolvedValue({
        effectivePath: "/tmp/test.jpg",
        tempDirUsed: undefined,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: "/tmp/test.jpg",
        format: "jpg",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const parsedInput = imageToolSchema.parse({ format: "JpG", path: "/tmp/test.jpg" });
      await imageToolHandler(parsedInput, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--format", "jpg"]),
        mockLogger,
      );
    });

    it("should handle 'jpeg' as alias for 'jpg'", async () => {
      const { imageToolSchema } = await import("../../../src/types/index.js");
      
      mockResolveImagePath.mockResolvedValue({
        effectivePath: "/tmp/test.jpg",
        tempDirUsed: undefined,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: "/tmp/test.jpg",
        format: "jpg",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const parsedInput = imageToolSchema.parse({ format: "jpeg", path: "/tmp/test.jpg" });
      await imageToolHandler(parsedInput, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--format", "jpg"]),
        mockLogger,
      );
    });

    it("should handle uppercase 'JPEG' alias", async () => {
      const { imageToolSchema } = await import("../../../src/types/index.js");
      
      mockResolveImagePath.mockResolvedValue({
        effectivePath: "/tmp/test.jpg",
        tempDirUsed: undefined,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: "/tmp/test.jpg",
        format: "jpg",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const parsedInput = imageToolSchema.parse({ format: "JPEG", path: "/tmp/test.jpg" });
      await imageToolHandler(parsedInput, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--format", "jpg"]),
        mockLogger,
      );
    });

    it("should handle 'DATA' in uppercase", async () => {
      const { imageToolSchema } = await import("../../../src/types/index.js");
      
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("Safari", {
        path: MOCK_SAVED_FILE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);
      mockReadImageAsBase64.mockResolvedValue("base64data");

      const parsedInput = imageToolSchema.parse({ format: "DATA", app_target: "Safari" });
      await imageToolHandler(parsedInput, mockContext);

      // Should be processed as 'data' format
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--format", "png"]),
        mockLogger,
      );
    });
  });

  describe("Empty question to analyze", () => {
    it("should skip analysis for empty string question", async () => {
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
        { question: "" },
        mockContext,
      );

      // Empty question is falsy, so analysis is skipped
      expect(mockPerformAutomaticAnalysis).not.toHaveBeenCalled();
      
      // No analysis should be performed
      expect(result.analysis_text).toBeUndefined();
      expect(result.model_used).toBeUndefined();
      
      // Should just capture the image
      expect(result.saved_files).toEqual(mockResponse.data.saved_files);
    });

    it("should handle whitespace-only question", async () => {
      mockResolveImagePath.mockResolvedValue({
        effectivePath: MOCK_TEMP_IMAGE_DIR,
        tempDirUsed: MOCK_TEMP_IMAGE_DIR,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_SAVED_FILE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);
      mockReadImageAsBase64.mockResolvedValue("base64data");
      
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava:latest" }
      ]);
      
      mockPerformAutomaticAnalysis.mockResolvedValue({
        analysisText: "No response from Ollama",
        modelUsed: "ollama/llava:latest",
      });
      
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava:latest";

      const result = await imageToolHandler(
        { question: "   " },
        mockContext,
      );

      expect(mockPerformAutomaticAnalysis).toHaveBeenCalledWith(
        "base64data",
        "   ",
        mockLogger,
        "ollama/llava:latest",
      );
      
      expect(result.analysis_text).toBe("No response from Ollama");
    });
  });

  describe("Screen index parsing edge cases", () => {
    it("should handle float screen indices by parsing as integer", async () => {
      const args = buildSwiftCliArgs({ app_target: "screen:1.5" }, undefined, undefined, mockLogger);
      
      // Should parse 1.5 as 1
      expect(args).toEqual(
        expect.arrayContaining(["--mode", "screen", "--screen-index", "1"]),
      );
    });

    it("should handle hex screen indices as 0", async () => {
      const args = buildSwiftCliArgs({ app_target: "screen:0x1" }, undefined, undefined, mockLogger);
      
      // parseInt("0x1", 10) returns 0, so it's actually valid and parsed as screen 0
      expect(args).toEqual(
        expect.arrayContaining(["--mode", "screen", "--screen-index", "0"]),
      );
    });

    it("should handle negative screen indices as invalid", async () => {
      const loggerWarnSpy = vi.spyOn(mockLogger, "warn");
      const args = buildSwiftCliArgs({ app_target: "screen:-1" }, undefined, undefined, mockLogger);
      
      expect(args).toEqual(
        expect.arrayContaining(["--mode", "screen"]),
      );
      expect(args).not.toContain("--screen-index");
      expect(loggerWarnSpy).toHaveBeenCalledWith(
        expect.objectContaining({ screenIndex: "-1" }),
        "Invalid screen index '-1' in app_target, capturing all screens.",
      );
    });

    it("should handle very large screen indices", async () => {
      const args = buildSwiftCliArgs({ app_target: "screen:999999" }, undefined, undefined, mockLogger);
      
      // Large numbers should be passed through
      expect(args).toEqual(
        expect.arrayContaining(["--mode", "screen", "--screen-index", "999999"]),
      );
    });

    it("should handle screen index with leading zeros", async () => {
      const args = buildSwiftCliArgs({ app_target: "screen:001" }, undefined, undefined, mockLogger);
      
      // Should parse 001 as 1
      expect(args).toEqual(
        expect.arrayContaining(["--mode", "screen", "--screen-index", "1"]),
      );
    });
  });

  describe("Special filesystem characters in filenames", () => {
    it("should allow pipe character in filename", async () => {
      const pathWithPipe = "/tmp/test|file.png";
      mockResolveImagePath.mockResolvedValue({
        effectivePath: pathWithPipe,
        tempDirUsed: undefined,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: pathWithPipe,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      await imageToolHandler(
        { path: pathWithPipe },
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--path", pathWithPipe]),
        mockLogger,
      );
    });

    it("should allow colon character in filename", async () => {
      const pathWithColon = "/tmp/test:file.png";
      mockResolveImagePath.mockResolvedValue({
        effectivePath: pathWithColon,
        tempDirUsed: undefined,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: pathWithColon,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      await imageToolHandler(
        { path: pathWithColon },
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--path", pathWithColon]),
        mockLogger,
      );
    });

    it("should allow asterisk character in filename", async () => {
      const pathWithAsterisk = "/tmp/test*file.png";
      mockResolveImagePath.mockResolvedValue({
        effectivePath: pathWithAsterisk,
        tempDirUsed: undefined,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: pathWithAsterisk,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      await imageToolHandler(
        { path: pathWithAsterisk },
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--path", pathWithAsterisk]),
        mockLogger,
      );
    });

    it("should handle multiple special characters in filename", async () => {
      const complexPath = "/tmp/test|file:with*special.png";
      mockResolveImagePath.mockResolvedValue({
        effectivePath: complexPath,
        tempDirUsed: undefined,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: complexPath,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      await imageToolHandler(
        { path: complexPath },
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--path", complexPath]),
        mockLogger,
      );
    });

    it("should handle spaces in path", async () => {
      const pathWithSpaces = "/tmp/my folder/test file.png";
      mockResolveImagePath.mockResolvedValue({
        effectivePath: pathWithSpaces,
        tempDirUsed: undefined,
      });
      
      const mockResponse = mockSwiftCli.captureImage("screen", {
        path: pathWithSpaces,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      await imageToolHandler(
        { path: pathWithSpaces },
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--path", pathWithSpaces]),
        mockLogger,
      );
    });
  });

  describe("buildSwiftCliArgs edge cases", () => {
    it("should handle window title with colons", async () => {
      const args = buildSwiftCliArgs({ 
        app_target: "Chrome:WINDOW_TITLE:https://example.com:8080" 
      }, undefined);
      
      expect(args).toEqual(
        expect.arrayContaining([
          "--app", "Chrome",
          "--mode", "window",
          "--window-title", "https://example.com:8080"
        ]),
      );
    });

    it("should handle malformed window specifier", async () => {
      const loggerWarnSpy = vi.spyOn(mockLogger, "warn");
      const args = buildSwiftCliArgs({ 
        app_target: "Safari:InvalidSpecifier" 
      }, undefined, undefined, mockLogger);
      
      expect(args).toEqual(
        expect.arrayContaining([
          "--app", "Safari:InvalidSpecifier",
          "--mode", "multi"
        ]),
      );
      expect(loggerWarnSpy).toHaveBeenCalledWith(
        expect.objectContaining({ app_target: "Safari:InvalidSpecifier" }),
        "Malformed window specifier, treating as app name",
      );
    });

    it("should handle unknown window specifier type", async () => {
      const loggerWarnSpy = vi.spyOn(mockLogger, "warn");
      const args = buildSwiftCliArgs({ 
        app_target: "Safari:UNKNOWN_TYPE:value" 
      }, undefined, undefined, mockLogger);
      
      expect(args).toEqual(
        expect.arrayContaining([
          "--app", "Safari",
          "--mode", "window"
        ]),
      );
      expect(loggerWarnSpy).toHaveBeenCalledWith(
        expect.objectContaining({ specifierType: "UNKNOWN_TYPE" }),
        "Unknown window specifier type, defaulting to main window",
      );
    });
  });
});