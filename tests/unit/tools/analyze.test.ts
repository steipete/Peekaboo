import { vi, beforeEach, describe, it, expect } from "vitest";
import { pino } from "pino";
import {
  analyzeToolHandler,
  analyzeToolSchema,
  AnalyzeToolInput,
} from "../../../src/tools/analyze";
import { readImageAsBase64 } from "../../../src/utils/peekaboo-cli";
import {
  parseAIProviders,
  isProviderAvailable,
  analyzeImageWithProvider,
  getDefaultModelForProvider,
  determineProviderAndModel,
} from "../../../src/utils/ai-providers";
import { ToolContext, AIProvider } from "../../../src/types";
import path from "path"; // Import path for extname

// Mocks
vi.mock("../../../src/utils/peekaboo-cli");
vi.mock("../../../src/utils/ai-providers");

const mockReadImageAsBase64 = readImageAsBase64 as vi.MockedFunction<
  typeof readImageAsBase64
>;
const mockParseAIProviders = parseAIProviders as vi.MockedFunction<
  typeof parseAIProviders
>;
const mockIsProviderAvailable = isProviderAvailable as vi.MockedFunction<
  typeof isProviderAvailable
>;
const mockAnalyzeImageWithProvider =
  analyzeImageWithProvider as vi.MockedFunction<
    typeof analyzeImageWithProvider
  >;
const mockGetDefaultModelForProvider =
  getDefaultModelForProvider as vi.MockedFunction<
    typeof getDefaultModelForProvider
  >;
const mockDetermineProviderAndModel =
  determineProviderAndModel as vi.MockedFunction<
    typeof determineProviderAndModel
  >;

// Create a mock logger for tests
const mockLogger = pino({ level: "silent" });
const mockContext: ToolContext = { logger: mockLogger };

const MOCK_IMAGE_BASE64 = "base64imagedata";

describe("Analyze Tool", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // Reset environment variables
    delete process.env.PEEKABOO_AI_PROVIDERS;
    mockReadImageAsBase64.mockResolvedValue(MOCK_IMAGE_BASE64); // Default mock for successful read
  });


  describe("analyzeToolHandler", () => {
    const validInput: AnalyzeToolInput = {
      image_path: "/path/to/image.png",
      question: "What is this?",
    };

    it("should analyze image successfully with auto provider selection", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava,openai/gpt-4o";
      const parsedProviders: AIProvider[] = [
        { provider: "ollama", model: "llava" },
        { provider: "openai", model: "gpt-4o" },
      ];
      mockParseAIProviders.mockReturnValue(parsedProviders);
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "openai",
        model: "gpt-4o",
      });
      mockAnalyzeImageWithProvider.mockResolvedValue(
        "AI says: It is an apple.",
      );

      const result = await analyzeToolHandler(validInput, mockContext);

      expect(mockReadImageAsBase64).toHaveBeenCalledWith(validInput.image_path);
      expect(mockParseAIProviders).toHaveBeenCalledWith(
        process.env.PEEKABOO_AI_PROVIDERS,
      );
      expect(mockDetermineProviderAndModel).toHaveBeenCalledWith(
        undefined,
        parsedProviders,
        mockLogger,
      );
      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        { provider: "openai", model: "gpt-4o" }, // Determined provider/model
        validInput.image_path,
        MOCK_IMAGE_BASE64,
        validInput.question,
        mockLogger,
      );
      expect(result.content[0].text).toBe("AI says: It is an apple.");
      expect(result.content[1].text).toMatch(/👻 Peekaboo: Analyzed image with openai\/gpt-4o in \d+\.\d+s\./);
      expect(result.analysis_text).toBe("AI says: It is an apple.");
      expect((result as any).model_used).toBe("openai/gpt-4o");
      expect(result.isError).toBeUndefined();
    });

    it("should use specific provider and model if provided and available", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "openai/gpt-4-turbo";
      const parsedProviders: AIProvider[] = [
        { provider: "openai", model: "gpt-4-turbo" },
      ];
      mockParseAIProviders.mockReturnValue(parsedProviders);
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "openai",
        model: "gpt-custom-model",
      });
      mockAnalyzeImageWithProvider.mockResolvedValue("GPT-Turbo says hi.");

      const inputWithProvider: AnalyzeToolInput = {
        ...validInput,
        provider_config: { type: "openai", model: "gpt-custom-model" },
      };
      const result = await analyzeToolHandler(inputWithProvider, mockContext);

      expect(mockDetermineProviderAndModel).toHaveBeenCalledWith(
        inputWithProvider.provider_config,
        parsedProviders,
        mockLogger,
      );
      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        { provider: "openai", model: "gpt-custom-model" },
        validInput.image_path,
        MOCK_IMAGE_BASE64,
        validInput.question,
        mockLogger,
      );
      expect(result.content[0].text).toBe("GPT-Turbo says hi.");
      expect(result.content[1].text).toMatch(/👻 Peekaboo: Analyzed image with openai\/gpt-custom-model in \d+\.\d+s\./);      
      expect((result as any).model_used).toBe("openai/gpt-custom-model");
      expect(result.isError).toBeUndefined();
    });

    it("should return error for unsupported image format", async () => {
      const result = (await analyzeToolHandler(
        { ...validInput, image_path: "/path/image.gif" },
        mockContext,
      )) as any;
      expect(result.content[0].text).toContain(
        "Unsupported image format: .gif",
      );
      expect(result.isError).toBe(true);
    });

    it("should return error if PEEKABOO_AI_PROVIDERS env is not set", async () => {
      const result = (await analyzeToolHandler(validInput, mockContext)) as any;
      expect(result.content[0].text).toContain(
        "AI analysis not configured on this server",
      );
      expect(result.isError).toBe(true);
    });

    it("should return error if PEEKABOO_AI_PROVIDERS env has no valid providers", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "invalid/";
      mockParseAIProviders.mockReturnValue([]);
      const result = (await analyzeToolHandler(validInput, mockContext)) as any;
      expect(result.content[0].text).toContain("No valid AI providers found");
      expect(result.isError).toBe(true);
    });

    it("should return error if no configured providers are operational (auto mode)", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava" },
      ]);
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: null,
        model: "",
      });
      const result = (await analyzeToolHandler(validInput, mockContext)) as any;
      expect(result.content[0].text).toContain(
        "No configured AI providers are currently operational",
      );
      expect(result.isError).toBe(true);
    });

    it("should return error if specific provider in config is not enabled on server", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava"; // Server only has ollama
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava" },
      ]);
      mockDetermineProviderAndModel.mockRejectedValue(
        new Error(
          "Provider 'openai' is not enabled in server's PEEKABOO_AI_PROVIDERS configuration."
        )
      );
      // User requests openai
      const inputWithProvider: AnalyzeToolInput = {
        ...validInput,
        provider_config: { type: "openai" },
      };
      const result = (await analyzeToolHandler(
        inputWithProvider,
        mockContext,
      )) as any;
      // This error is now caught by determineProviderAndModel and then re-thrown, so analyzeToolHandler catches it
      expect(result.content[0].text).toContain(
        "Provider 'openai' is not enabled in server's PEEKABOO_AI_PROVIDERS configuration",
      );
      expect(result.isError).toBe(true);
    });

    it("should return error if specific provider is configured but not available", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava" },
      ]);
      mockDetermineProviderAndModel.mockRejectedValue(
        new Error(
          "Provider 'ollama' is configured but not currently available."
        )
      );
      const inputWithProvider: AnalyzeToolInput = {
        ...validInput,
        provider_config: { type: "ollama" },
      };
      const result = (await analyzeToolHandler(
        inputWithProvider,
        mockContext,
      )) as any;
      expect(result.content[0].text).toContain(
        "Provider 'ollama' is configured but not currently available",
      );
      expect(result.isError).toBe(true);
    });

    it("should return error if readImageAsBase64 fails", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava" },
      ]);
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava",
      });
      mockReadImageAsBase64.mockRejectedValue(new Error("Cannot access file"));
      const result = (await analyzeToolHandler(validInput, mockContext)) as any;
      expect(result.content[0].text).toContain(
        "Failed to read image file: Cannot access file",
      );
      expect(result.isError).toBe(true);
    });

    it("should return error if analyzeImageWithProvider fails", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava" },
      ]);
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava",
      });
      mockAnalyzeImageWithProvider.mockRejectedValue(new Error("AI exploded"));
      const result = (await analyzeToolHandler(validInput, mockContext)) as any;
      expect(result.content[0].text).toContain(
        "AI analysis failed: AI exploded",
      );
      expect(result.isError).toBe(true);
      expect(result._meta.backend_error_code).toBe("AI_PROVIDER_ERROR");
    });

    it("should handle unexpected errors gracefully", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";
      mockParseAIProviders.mockImplementation(() => {
        throw new Error("Unexpected parse error");
      }); // Force an error
      const result = (await analyzeToolHandler(validInput, mockContext)) as any;
      expect(result.content[0].text).toContain(
        "Unexpected error: Unexpected parse error",
      );
      expect(result.isError).toBe(true);
    });

    it("should handle very long file paths", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava" },
      ]);
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava",
      });
      mockAnalyzeImageWithProvider.mockResolvedValue("Analysis complete");

      const longPath =
        "/very/long/path/that/goes/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/image.png";
      const result = await analyzeToolHandler(
        { ...validInput, image_path: longPath },
        mockContext,
      );

      expect(mockReadImageAsBase64).toHaveBeenCalledWith(longPath);
      expect(result.isError).toBeUndefined();
    });

    it("should handle special characters in file paths", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava" },
      ]);
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava",
      });
      mockAnalyzeImageWithProvider.mockResolvedValue("Analysis complete");

      const specialPath = "/path/with spaces/and-special_chars/image (1).png";
      const result = await analyzeToolHandler(
        { ...validInput, image_path: specialPath },
        mockContext,
      );

      expect(mockReadImageAsBase64).toHaveBeenCalledWith(specialPath);
      expect(result.isError).toBeUndefined();
    });

    it("should handle empty question gracefully", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava" },
      ]);
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava",
      });
      mockAnalyzeImageWithProvider.mockResolvedValue(
        "General image description",
      );

      const result = await analyzeToolHandler(
        {
          image_path: validInput.image_path,
          question: "",
        },
        mockContext,
      );

      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        expect.any(Object),
        validInput.image_path,
        MOCK_IMAGE_BASE64,
        "",
        mockLogger,
      );
      expect(result.isError).toBeUndefined();
    });

    it("should handle very long questions", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava" },
      ]);
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava",
      });
      mockAnalyzeImageWithProvider.mockResolvedValue("Long answer");

      const longQuestion = "What ".repeat(1000) + "is in this image?";
      const result = await analyzeToolHandler(
        {
          ...validInput,
          question: longQuestion,
        },
        mockContext,
      );

      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        expect.any(Object),
        validInput.image_path,
        MOCK_IMAGE_BASE64,
        longQuestion,
        mockLogger,
      );
      expect(result.isError).toBeUndefined();
    });

    it("should handle mixed case file extensions", async () => {
      const upperCasePath = "/path/to/image.PNG";
      const mixedCasePath = "/path/to/image.JpG";

      const result1 = await analyzeToolHandler(
        { ...validInput, image_path: upperCasePath },
        mockContext,
      );
      const result2 = await analyzeToolHandler(
        { ...validInput, image_path: mixedCasePath },
        mockContext,
      );

      // Should not return unsupported format error for valid extensions with different cases
      expect(result1.content[0].text).not.toContain("Unsupported image format");
      expect(result2.content[0].text).not.toContain("Unsupported image format");
    });

    it("should handle null or undefined in error messages", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava" },
      ]);
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava",
      });
      mockAnalyzeImageWithProvider.mockRejectedValue(null);

      const result = (await analyzeToolHandler(validInput, mockContext)) as any;
      expect(result.content[0].text).toContain("AI analysis failed");
      expect(result.isError).toBe(true);
    });

    it("should handle provider returning empty string", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava" },
      ]);
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava",
      });
      mockAnalyzeImageWithProvider.mockResolvedValue("");

      const result = await analyzeToolHandler(validInput, mockContext);
      expect(result.content[0].text).toBe("");
      expect(result.content[1].text).toMatch(/👻 Peekaboo: Analyzed image with ollama\/llava in \d+\.\d+s\./);            
      expect(result.analysis_text).toBe("");
      expect(result.isError).toBeUndefined();
    });

    it("should handle multiple providers where all fail", async () => {
      process.env.PEEKABOO_AI_PROVIDERS =
        "ollama/llava,openai/gpt-4o,anthropic/claude-3";
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava" },
        { provider: "openai", model: "gpt-4o" },
        { provider: "anthropic", model: "claude-3" },
      ]);
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: null,
        model: "",
      });

      const result = (await analyzeToolHandler(validInput, mockContext)) as any;
      expect(result.content[0].text).toContain(
        "No configured AI providers are currently operational",
      );
      expect(mockDetermineProviderAndModel).toHaveBeenCalledWith(
        undefined,
        expect.arrayContaining([
          { provider: "ollama", model: "llava" },
          { provider: "openai", model: "gpt-4o" },
          { provider: "anthropic", model: "claude-3" },
        ]),
        mockLogger,
      );
    });

    it("should validate file extension case-insensitively", async () => {
      const validExtensions = [
        ".PNG",
        ".Png",
        ".pNg",
        ".JPEG",
        ".Jpg",
        ".JPG",
        ".WebP",
        ".WEBP",
      ];
      const invalidExtensions = [".tiff", ".TIFF", ".Bmp", ".gif"];

      // Valid extensions should pass
      for (const ext of validExtensions) {
        const result = await analyzeToolHandler(
          {
            ...validInput,
            image_path: `/path/to/image${ext}`,
          },
          mockContext,
        );

        // Should proceed to check AI_PROVIDERS (not return unsupported format)
        expect(result.content[0].text).not.toContain(
          "Unsupported image format",
        );
      }

      // Invalid extensions should fail
      for (const ext of invalidExtensions) {
        const result = await analyzeToolHandler(
          {
            ...validInput,
            image_path: `/path/to/image${ext}`,
          },
          mockContext,
        );

        expect(result.content[0].text).toContain("Unsupported image format");
        expect(result.isError).toBe(true);
      }
    });

    it("should work with 'path' parameter as alias for 'image_path'", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava" },
      ]);
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava",
      });
      mockAnalyzeImageWithProvider.mockResolvedValue("Analysis complete");

      const inputWithPath: AnalyzeToolInput = {
        path: "/path/to/image.png",
        question: "What is this?",
      };

      const result = await analyzeToolHandler(inputWithPath, mockContext);

      expect(mockReadImageAsBase64).toHaveBeenCalledWith("/path/to/image.png");
      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        { provider: "ollama", model: "llava" },
        "/path/to/image.png",
        MOCK_IMAGE_BASE64,
        "What is this?",
        mockLogger,
      );
      expect(result.content[0].text).toBe("Analysis complete");
      expect(result.isError).toBeUndefined();
    });

    it("should prioritize 'image_path' over 'path' when both are provided", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava" },
      ]);
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava",
      });
      mockAnalyzeImageWithProvider.mockResolvedValue("Analysis complete");

      const inputWithBoth: AnalyzeToolInput = {
        image_path: "/priority/image.png",
        path: "/fallback/image.png",
        question: "What is this?",
      };

      const result = await analyzeToolHandler(inputWithBoth, mockContext);

      expect(mockReadImageAsBase64).toHaveBeenCalledWith("/priority/image.png");
      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        { provider: "ollama", model: "llava" },
        "/priority/image.png",
        MOCK_IMAGE_BASE64,
        "What is this?",
        mockLogger,
      );
      expect(result.content[0].text).toBe("Analysis complete");
      expect(result.isError).toBeUndefined();
    });
  });

  describe("Schema Validation", () => {
    it("should validate successfully with image_path", () => {
      const input = {
        image_path: "/path/to/image.png",
        question: "What is this?",
      };
      
      const result = analyzeToolSchema.safeParse(input);
      expect(result.success).toBe(true);
    });

    it("should validate successfully with path as silent fallback", () => {
      const input = {
        path: "/path/to/image.png",
        question: "What is this?",
      };
      
      const result = analyzeToolSchema.safeParse(input);
      expect(result.success).toBe(true);
    });

    it("should validate successfully when both image_path and path are provided", () => {
      const input = {
        image_path: "/priority/image.png",
        path: "/fallback/image.png",
        question: "What is this?",
      };
      
      const result = analyzeToolSchema.safeParse(input);
      expect(result.success).toBe(true);
    });

    it("should fail validation when neither image_path nor path is provided", () => {
      const input = {
        question: "What is this?",
      };
      
      const result = analyzeToolSchema.safeParse(input);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.errors[0].message).toBe("image_path is required");
        expect(result.error.errors[0].path).toEqual(["image_path"]);
      }
    });

    it("should fail validation when question is missing", () => {
      const input = {
        image_path: "/path/to/image.png",
      };
      
      const result = analyzeToolSchema.safeParse(input);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.errors[0].message).toBe("Required");
        expect(result.error.errors[0].path).toEqual(["question"]);
      }
    });

    it("should validate optional provider_config correctly", () => {
      const inputWithoutProvider = {
        image_path: "/path/to/image.png",
        question: "What is this?",
      };
      
      const inputWithProvider = {
        image_path: "/path/to/image.png",
        question: "What is this?",
        provider_config: {
          type: "openai" as const,
          model: "gpt-4o",
        },
      };
      
      expect(analyzeToolSchema.safeParse(inputWithoutProvider).success).toBe(true);
      expect(analyzeToolSchema.safeParse(inputWithProvider).success).toBe(true);
    });

    it("should accept hidden path parameter for backward compatibility", () => {
      // Test that the hidden 'path' parameter is accepted and works
      const inputWithPath = {
        path: "/path/to/image.png",
        question: "What is this?",
      };
      
      const inputWithBothPaths = {
        image_path: "/path/to/primary.png",
        path: "/path/to/fallback.png",
        question: "What is this?",
      };
      
      // Both should pass validation
      expect(analyzeToolSchema.safeParse(inputWithPath).success).toBe(true);
      expect(analyzeToolSchema.safeParse(inputWithBothPaths).success).toBe(true);
      
      // When both are provided, image_path should take precedence
      const parsedWithBoth = analyzeToolSchema.parse(inputWithBothPaths);
      expect(parsedWithBoth.image_path).toBe("/path/to/primary.png");
      expect((parsedWithBoth as any).path).toBe("/path/to/fallback.png");
    });

    it("should handle hidden path parameter in tool handler", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava" },
      ]);
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava",
      });
      mockAnalyzeImageWithProvider.mockResolvedValue("Analysis complete");

      // Test with only path parameter (should use fallback)
      const inputWithOnlyPath: any = {
        path: "/path/to/fallback.png",
        question: "What is this?",
      };

      const result = await analyzeToolHandler(inputWithOnlyPath, mockContext);

      expect(mockReadImageAsBase64).toHaveBeenCalledWith("/path/to/fallback.png");
      expect(result.isError).toBeUndefined();
    });

    it("should handle empty provider_config gracefully", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava" },
      ]);
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava",
      });
      mockAnalyzeImageWithProvider.mockResolvedValue("Analysis complete");

      const inputWithEmptyProviderConfig: AnalyzeToolInput = {
        image_path: "/path/to/image.png",
        question: "What is this?",
        provider_config: {} as any, // Empty object should be handled gracefully
      };

      const result = await analyzeToolHandler(inputWithEmptyProviderConfig, mockContext);

      expect(result.isError).toBeUndefined();
      expect(result.analysis_text).toBe("Analysis complete");
      // Should call determineProviderAndModel with empty object that gets treated as "auto"
      expect(mockDetermineProviderAndModel).toHaveBeenCalledWith(
        {},
        expect.arrayContaining([{ provider: "ollama", model: "llava" }]),
        mockLogger,
      );
    });

    it("should handle null provider_config gracefully", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava" },
      ]);
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava",
      });
      mockAnalyzeImageWithProvider.mockResolvedValue("Analysis complete");

      const inputWithNullProviderConfig: AnalyzeToolInput = {
        image_path: "/path/to/image.png",
        question: "What is this?",
        provider_config: null as any, // null should be handled gracefully
      };

      const result = await analyzeToolHandler(inputWithNullProviderConfig, mockContext);

      expect(result.isError).toBeUndefined();
      expect(result.analysis_text).toBe("Analysis complete");
      // Should call determineProviderAndModel with null
      expect(mockDetermineProviderAndModel).toHaveBeenCalledWith(
        null,
        expect.arrayContaining([{ provider: "ollama", model: "llava" }]),
        mockLogger,
      );
    });
  });
});