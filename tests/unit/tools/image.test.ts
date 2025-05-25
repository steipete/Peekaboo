import { vi } from "vitest";
import {
  imageToolHandler,
  buildSwiftCliArgs,
  ImageToolInput,
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
  AIProviderConfig,
  ToolResponse,
  AIProvider,
} from "../../../src/types";
import * as fs from "fs/promises";
import * as os from "os";
import * as pathModule from "path";

// Mock the Swift CLI utility
vi.mock("../../../src/utils/peekaboo-cli");

// Mock AI Provider utilities
// Declare the variables that will hold the mock functions first
let mockDetermineProviderAndModel: vi.MockedFunction<any>;
let mockAnalyzeImageWithProvider: vi.MockedFunction<any>;
let mockParseAIProviders: vi.MockedFunction<any>;
let mockIsProviderAvailable: vi.MockedFunction<any>;
let mockGetDefaultModelForProvider: vi.MockedFunction<any>;

vi.mock("../../../src/utils/ai-providers", () => {
  // Create new vi.fn() instances inside the factory
  const determineProviderAndModel = vi.fn();
  const analyzeImageWithProvider = vi.fn();
  const parseAIProviders = vi.fn();
  const isProviderAvailable = vi.fn();
  const getDefaultModelForProvider = vi.fn().mockReturnValue("default-model");

  // Assign them to the outer scope variables so tests can reference them
  // This assignment happens AFTER the vi.mock call is processed by Vitest due to hoisting.
  // We will re-assign these correctly after the mock call using an import.
  return {
    determineProviderAndModel,
    analyzeImageWithProvider,
    parseAIProviders,
    isProviderAvailable,
    getDefaultModelForProvider,
  };
});

// Mock fs/promises for mkdtemp, unlink, rmdir
vi.mock("fs/promises");

// Now, import the mocked module and assign the vi.fn() instances to our variables
// This ensures our variables hold the actual mocks created by Vitest's factory.
import * as ActualAiProvidersMock from "../../../src/utils/ai-providers";
mockDetermineProviderAndModel =
  ActualAiProvidersMock.determineProviderAndModel as vi.MockedFunction<any>;
mockAnalyzeImageWithProvider =
  ActualAiProvidersMock.analyzeImageWithProvider as vi.MockedFunction<any>;
mockParseAIProviders =
  ActualAiProvidersMock.parseAIProviders as vi.MockedFunction<any>;
mockIsProviderAvailable =
  ActualAiProvidersMock.isProviderAvailable as vi.MockedFunction<any>;
mockGetDefaultModelForProvider =
  ActualAiProvidersMock.getDefaultModelForProvider as vi.MockedFunction<any>;

const mockExecuteSwiftCli = executeSwiftCli as vi.MockedFunction<
  typeof executeSwiftCli
>;
const mockReadImageAsBase64 = readImageAsBase64 as vi.MockedFunction<
  typeof readImageAsBase64
>;

const mockFsMkdtemp = fs.mkdtemp as vi.MockedFunction<typeof fs.mkdtemp>;
const mockFsUnlink = fs.unlink as vi.MockedFunction<typeof fs.unlink>;
const mockFsRmdir = fs.rmdir as vi.MockedFunction<typeof fs.rmdir>;

const mockLogger = pino({ level: "silent" });
const mockContext = { logger: mockLogger };

const MOCK_TEMP_DIR_PATH = "/tmp/peekaboo-img-mock";
const MOCK_TEMP_IMAGE_PATH = `${MOCK_TEMP_DIR_PATH}/capture.png`;

describe("Image Tool", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockFsMkdtemp.mockResolvedValue(MOCK_TEMP_DIR_PATH);
    mockFsUnlink.mockResolvedValue(undefined);
    mockFsRmdir.mockResolvedValue(undefined);
    process.env.PEEKABOO_AI_PROVIDERS = "";

    // Ensure specific mock implementations are reset/re-set for each test or suite as needed
    // The functions themselves are already vi.fn() instances.
    mockDetermineProviderAndModel.mockReset();
    mockAnalyzeImageWithProvider.mockReset();
    mockParseAIProviders.mockReset();
    mockIsProviderAvailable.mockReset();
    mockGetDefaultModelForProvider.mockReset().mockReturnValue("default-model"); // Re-apply default mock behavior if any
  });

  describe("imageToolHandler - Capture Only", () => {
    it("should capture screen with minimal parameters", async () => {
      const mockResponse = mockSwiftCli.captureImage("screen", {});
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const result = await imageToolHandler(
        {
          format: "png",
        return_data: false,
          capture_focus: "background",
        },
        mockContext,
      );

      expect(result.content[0].type).toBe("text");
      expect(result.content[0].text).toContain("Captured 1 image");
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["image", "--mode", "screen"]),
        mockLogger,
      );
      expect(result.saved_files).toEqual(mockResponse.data?.saved_files);
      expect(result.analysis_text).toBeUndefined();
      expect(result.model_used).toBeUndefined();
    });

    it("should return image data when return_data is true and no question is asked", async () => {
      const mockSavedFile: SavedFile = {
        path: "/tmp/test.png",
        mime_type: "image/png",
        item_label: "Screen 1",
      };
      const mockCaptureData: ImageCaptureData = {
        saved_files: [mockSavedFile],
      };
      const mockCliResponse = {
        success: true,
        data: mockCaptureData,
        messages: ["Captured one file"],
      };
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");

      const result = await imageToolHandler(
        {
          format: "png",
          return_data: true,
          capture_focus: "background",
        },
        mockContext,
      );

      expect(result.isError).toBeUndefined();
      expect(result.content).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            type: "text",
            text: expect.stringContaining("Captured 1 image"),
          }),
          expect.objectContaining({ type: "image", data: "base64imagedata" }),
        ]),
      );
      expect(mockReadImageAsBase64).toHaveBeenCalledWith("/tmp/test.png");
      expect(result.saved_files).toEqual([mockSavedFile]);
      expect(result.analysis_text).toBeUndefined();
    });
  });

  describe("imageToolHandler - Capture and Analyze", () => {
    const MOCK_QUESTION = "What is in this image?";
    const MOCK_ANALYSIS_RESPONSE = "This is a cat.";
    const MOCK_PROVIDER_DETAILS: AIProvider = {
      provider: "ollama",
      model: "llava:custom",
    };

    beforeEach(() => {
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava:default" },
      ]);
      mockDetermineProviderAndModel.mockResolvedValue(MOCK_PROVIDER_DETAILS);
      mockAnalyzeImageWithProvider.mockResolvedValue(MOCK_ANALYSIS_RESPONSE);
      mockReadImageAsBase64.mockResolvedValue("base64dataforanalysis");
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava:default";
    });

    it("should capture, analyze, and delete temp image if no path provided", async () => {
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_TEMP_IMAGE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler(
        {
          question: MOCK_QUESTION,
          format: "png",
        },
        mockContext,
      );

      expect(mockFsMkdtemp).toHaveBeenCalled();
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--path", MOCK_TEMP_IMAGE_PATH]),
        mockLogger,
      );
      expect(mockReadImageAsBase64).toHaveBeenCalledWith(MOCK_TEMP_IMAGE_PATH);
      expect(mockDetermineProviderAndModel).toHaveBeenCalled();
      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        MOCK_PROVIDER_DETAILS,
        MOCK_TEMP_IMAGE_PATH,
        "base64dataforanalysis",
        MOCK_QUESTION,
        mockLogger,
      );

      expect(result.analysis_text).toBe(MOCK_ANALYSIS_RESPONSE);
      expect(result.model_used).toBe(
        `${MOCK_PROVIDER_DETAILS.provider}/${MOCK_PROVIDER_DETAILS.model}`,
      );
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
      expect(
        result.content.some((item) => item.type === "image" && item.data),
      ).toBe(false);
      expect(mockFsUnlink).toHaveBeenCalledWith(MOCK_TEMP_IMAGE_PATH);
      expect(mockFsRmdir).toHaveBeenCalledWith(MOCK_TEMP_DIR_PATH);
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

      expect(mockFsMkdtemp).not.toHaveBeenCalled();
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--path", USER_PATH]),
        mockLogger,
      );
      expect(mockReadImageAsBase64).toHaveBeenCalledWith(USER_PATH);
      expect(mockAnalyzeImageWithProvider).toHaveBeenCalled();

      expect(result.analysis_text).toBe(MOCK_ANALYSIS_RESPONSE);
      expect(result.saved_files).toEqual(mockCliResponse.data?.saved_files);
      expect(mockFsUnlink).not.toHaveBeenCalled();
      expect(mockFsRmdir).not.toHaveBeenCalled();
      expect(result.isError).toBeUndefined();
    });

    it("should use provider_config if specified", async () => {
      const specificProviderConfig: AIProviderConfig = {
        type: "openai",
        model: "gpt-4-vision",
      };
      const specificProviderDetails: AIProvider = {
        provider: "openai",
        model: "gpt-4-vision",
      };
      mockDetermineProviderAndModel.mockResolvedValue(specificProviderDetails);
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_TEMP_IMAGE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      await imageToolHandler(
        {
          question: MOCK_QUESTION,
          provider_config: specificProviderConfig,
          format: "png",
        },
        mockContext,
      );

      expect(mockDetermineProviderAndModel).toHaveBeenCalledWith(
        specificProviderConfig,
        expect.any(Array),
        mockLogger,
      );
      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        specificProviderDetails,
        MOCK_TEMP_IMAGE_PATH,
        "base64dataforanalysis",
        MOCK_QUESTION,
        mockLogger,
      );
    });

    it("should handle failure in readImageAsBase64 before analysis", async () => {
      mockReadImageAsBase64.mockRejectedValue(
        new Error("Failed to read image"),
      );
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_TEMP_IMAGE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler(
        { question: MOCK_QUESTION, format: "png" },
        mockContext,
      );

      expect(mockAnalyzeImageWithProvider).not.toHaveBeenCalled();
      expect(result.analysis_text).toContain(
        "Analysis skipped: Failed to read captured image",
      );
      expect(result.isError).toBe(true);
      expect(result.model_used).toBeUndefined();
      expect(mockFsUnlink).toHaveBeenCalledWith(MOCK_TEMP_IMAGE_PATH);
    });

    it("should handle failure in determineProviderAndModel (rejected promise)", async () => {
      mockDetermineProviderAndModel.mockRejectedValue(
        new Error("No provider available error from determine"),
      );
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_TEMP_IMAGE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler(
        { question: MOCK_QUESTION, format: "png" },
        mockContext,
      );

      expect(mockAnalyzeImageWithProvider).not.toHaveBeenCalled();
      expect(result.analysis_text).toContain(
        "AI analysis failed: No provider available error from determine",
      );
      expect(result.isError).toBe(true);
    });

    it("should handle failure when determineProviderAndModel resolves to no provider", async () => {
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: null,
        model: "",
      });
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_TEMP_IMAGE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler(
        { question: MOCK_QUESTION, format: "png" },
        mockContext,
      );

      expect(mockAnalyzeImageWithProvider).not.toHaveBeenCalled();
      expect(result.analysis_text).toContain(
        "Analysis skipped: No AI providers are currently operational",
      );
      expect(result.isError).toBe(true);
    });

    it("should handle failure in analyzeImageWithProvider", async () => {
      mockAnalyzeImageWithProvider.mockRejectedValue(
        new Error("AI API Error from analyze"),
      );
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_TEMP_IMAGE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler(
        { question: MOCK_QUESTION, format: "png" },
        mockContext,
      );

      expect(result.analysis_text).toContain(
        "AI analysis failed: AI API Error from analyze",
      );
      expect(result.isError).toBe(true);
      expect(result.model_used).toBeUndefined();
    });

    it("should correctly report error if PEEKABOO_AI_PROVIDERS is not set and no provider_config given", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "";
      mockParseAIProviders.mockReturnValue([]);
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_TEMP_IMAGE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler(
        { question: MOCK_QUESTION, format: "png" },
        mockContext,
      );

      expect(result.analysis_text).toContain(
        "Analysis skipped: AI analysis not configured on this server",
      );
      expect(result.isError).toBe(true);
      expect(mockAnalyzeImageWithProvider).not.toHaveBeenCalled();
    });

    it("should return isError = true if analysis is attempted but fails, even if capture succeeds", async () => {
      mockAnalyzeImageWithProvider.mockRejectedValue(new Error("AI Error"));
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_TEMP_IMAGE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler(
        { question: MOCK_QUESTION, format: "png" },
        mockContext,
      );
      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Captured 1 image");
      expect(result.content[0].text).toContain("Analysis failed/skipped");
      expect(result.analysis_text).toContain("AI analysis failed: AI Error");
    });

    it("should NOT return base64_data in content if question is asked, even if return_data is true", async () => {
      const mockCliResponse = mockSwiftCli.captureImage("screen", {
        path: MOCK_TEMP_IMAGE_PATH,
        format: "png",
      });
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler(
        {
          question: MOCK_QUESTION,
        return_data: true,
          format: "png",
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
    const defaults = {
      format: "png" as const,
      return_data: false,
      capture_focus: "background" as const,
    };

    it("should default to screen mode if no app provided and no mode specified", () => {
      const args = buildSwiftCliArgs({ ...defaults });
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

    it("should default to window mode if app is provided and no mode specified", () => {
      const args = buildSwiftCliArgs({ ...defaults, app: "Safari" });
      expect(args).toEqual([
        "image",
        "--app",
        "Safari",
        "--mode",
        "window",
        "--format",
        "png",
        "--capture-focus",
        "background",
      ]);
    });

    it("should use specified mode: screen", () => {
      const args = buildSwiftCliArgs({ ...defaults, mode: "screen" });
      expect(args).toEqual(expect.arrayContaining(["--mode", "screen"]));
    });

    it("should use specified mode: window with app", () => {
      const args = buildSwiftCliArgs({
        ...defaults,
        app: "Terminal",
        mode: "window",
      });
      expect(args).toEqual(
        expect.arrayContaining(["--app", "Terminal", "--mode", "window"]),
      );
    });

    it("should use specified mode: multi with app", () => {
      const args = buildSwiftCliArgs({
        ...defaults,
        app: "Finder",
        mode: "multi",
      });
      expect(args).toEqual(
        expect.arrayContaining(["--app", "Finder", "--mode", "multi"]),
      );
    });

    it("should include app", () => {
      const args = buildSwiftCliArgs({ ...defaults, app: "Notes" });
      expect(args).toEqual(expect.arrayContaining(["--app", "Notes"]));
    });

    it("should include path", () => {
      const args = buildSwiftCliArgs({ ...defaults, path: "/tmp/image.jpg" });
      expect(args).toEqual(
        expect.arrayContaining(["--path", "/tmp/image.jpg"]),
      );
    });

    it("should include window_specifier by title", () => {
      const args = buildSwiftCliArgs({
        ...defaults,
        app: "Safari",
        window_specifier: { title: "Apple" },
      });
      expect(args).toEqual(expect.arrayContaining(["--window-title", "Apple"]));
    });

    it("should include window_specifier by index", () => {
      const args = buildSwiftCliArgs({
        ...defaults,
        app: "Safari",
        window_specifier: { index: 0 },
      });
      expect(args).toEqual(expect.arrayContaining(["--window-index", "0"]));
    });

    it("should include format (default png)", () => {
      const args = buildSwiftCliArgs({ ...defaults });
      expect(args).toEqual(expect.arrayContaining(["--format", "png"]));
    });

    it("should include specified format jpg", () => {
      const args = buildSwiftCliArgs({ ...defaults, format: "jpg" });
      expect(args).toEqual(expect.arrayContaining(["--format", "jpg"]));
    });

    it("should include capture_focus (default background)", () => {
      const args = buildSwiftCliArgs({ ...defaults });
      expect(args).toEqual(
        expect.arrayContaining(["--capture-focus", "background"]),
      );
    });

    it("should include specified capture_focus foreground", () => {
      const args = buildSwiftCliArgs({
        ...defaults,
        capture_focus: "foreground",
      });
      expect(args).toEqual(
        expect.arrayContaining(["--capture-focus", "foreground"]),
      );
    });

    it("should handle all options together", () => {
      const input: ImageToolInput = {
        ...defaults, // Ensure all required fields are present
        app: "Preview",
        path: "/users/test/file.tiff",
        mode: "window",
        window_specifier: { index: 1 },
        format: "png",
        capture_focus: "foreground",
      };
      const args = buildSwiftCliArgs(input);
      expect(args).toEqual([
        "image",
        "--app",
        "Preview",
        "--path",
        "/users/test/file.tiff",
        "--mode",
        "window",
        "--window-index",
        "1",
        "--format",
        "png",
        "--capture-focus",
        "foreground",
      ]);
    });

    it("should use input.path if provided, even with a question", () => {
      const input: ImageToolInput = { path: "/my/path.png", question: "test" };
      const args = buildSwiftCliArgs(input);
      expect(args).toContain("--path");
      expect(args).toContain("/my/path.png");
    });

    it("should NOT use PEEKABOO_DEFAULT_SAVE_PATH if a question is asked", () => {
      process.env.PEEKABOO_DEFAULT_SAVE_PATH = "/default/env.png";
      const input: ImageToolInput = { question: "test" };
      const args = buildSwiftCliArgs(input);
      expect(args.includes("--path")).toBe(false);
      delete process.env.PEEKABOO_DEFAULT_SAVE_PATH;
    });

    it("should use PEEKABOO_DEFAULT_SAVE_PATH if no path and no question", () => {
      process.env.PEEKABOO_DEFAULT_SAVE_PATH = "/default/env.png";
      const input: ImageToolInput = {};
      const args = buildSwiftCliArgs(input);
      expect(args).toContain("--path");
      expect(args).toContain("/default/env.png");
      delete process.env.PEEKABOO_DEFAULT_SAVE_PATH;
    });

    it("should use default format and capture_focus if not provided", () => {
      const input: ImageToolInput = {
        format: "png",
        capture_focus: "background",
      };
      const args = buildSwiftCliArgs(input);
      expect(args).toContain("--format");
      expect(args).toContain("png");
      expect(args).toContain("--capture-focus");
      expect(args).toContain("background");
    });
  });
}); 
