import { describe, it, expect, beforeEach, vi } from "vitest";
import { analyzeToolHandler } from "../../../src/tools/analyze";
import { readImageAsBase64 } from "../../../src/utils/peekaboo-cli";
import { 
  parseAIProviders, 
  analyzeImageWithProvider,
  determineProviderAndModel 
} from "../../../src/utils/ai-providers";
import { pino } from "pino";
import * as fs from "fs/promises";
import * as path from "path";

// Mock peekaboo-cli
vi.mock("../../../src/utils/peekaboo-cli", () => ({
  readImageAsBase64: vi.fn(),
}));

// Mock AI providers
vi.mock("../../../src/utils/ai-providers", () => ({
  parseAIProviders: vi.fn(),
  analyzeImageWithProvider: vi.fn(),
  determineProviderAndModel: vi.fn(),
}));

const mockReadImageAsBase64 = readImageAsBase64 as vi.MockedFunction<typeof readImageAsBase64>;
const mockParseAIProviders = parseAIProviders as vi.MockedFunction<typeof parseAIProviders>;
const mockAnalyzeImageWithProvider = analyzeImageWithProvider as vi.MockedFunction<typeof analyzeImageWithProvider>;
const mockDetermineProviderAndModel = determineProviderAndModel as vi.MockedFunction<typeof determineProviderAndModel>;

const mockLogger = pino({ level: "silent" });
const mockContext = { logger: mockLogger };

describe("Analyze Tool - Edge Cases", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava:latest";
  });

  describe("Empty question handling", () => {
    it("should handle empty string question", async () => {
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava:latest" }
      ]);
      
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava:latest"
      });
      
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");
      
      // Mock Ollama returning "No response from Ollama" for empty question
      mockAnalyzeImageWithProvider.mockResolvedValue("No response from Ollama");

      const result = await analyzeToolHandler(
        { 
          image_path: "/tmp/test.png",
          question: ""
        },
        mockContext,
      );

      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        { provider: "ollama", model: "llava:latest" },
        "/tmp/test.png",
        "base64imagedata",
        "",
        mockLogger,
      );

      expect(result.content[0].type).toBe("text");
      expect(result.content[0].text).toBe("No response from Ollama");
      expect(result.model_used).toBe("ollama/llava:latest");
    });

    it("should handle whitespace-only question", async () => {
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava:latest" }
      ]);
      
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava:latest"
      });
      
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");
      mockAnalyzeImageWithProvider.mockResolvedValue("No response from Ollama");

      const result = await analyzeToolHandler(
        { 
          image_path: "/tmp/test.png",
          question: "   "
        },
        mockContext,
      );

      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        { provider: "ollama", model: "llava:latest" },
        "/tmp/test.png",
        "base64imagedata",
        "   ",
        mockLogger,
      );

      expect(result.content[0].text).toBe("No response from Ollama");
    });

    it("should handle question with only newlines", async () => {
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava:latest" }
      ]);
      
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava:latest"
      });
      
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");
      mockAnalyzeImageWithProvider.mockResolvedValue("No response from Ollama");

      const result = await analyzeToolHandler(
        { 
          image_path: "/tmp/test.png",
          question: "\n\n\n"
        },
        mockContext,
      );

      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        { provider: "ollama", model: "llava:latest" },
        "/tmp/test.png",
        "base64imagedata",
        "\n\n\n",
        mockLogger,
      );

      expect(result.content[0].text).toBe("No response from Ollama");
    });
  });

  describe("Model provider edge cases", () => {
    it("should handle when no AI providers are configured", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "";
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");

      const result = await analyzeToolHandler(
        { 
          image_path: "/tmp/test.png",
          question: "What is this?"
        },
        mockContext,
      );

      expect(result.content[0].text).toBe(
        "AI analysis not configured on this server. Set the PEEKABOO_AI_PROVIDERS environment variable."
      );
      expect(result.isError).toBe(true);
    });

    it("should handle whitespace in PEEKABOO_AI_PROVIDERS", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "   ";
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");

      const result = await analyzeToolHandler(
        { 
          image_path: "/tmp/test.png",
          question: "What is this?"
        },
        mockContext,
      );

      expect(result.content[0].text).toBe(
        "AI analysis not configured on this server. Set the PEEKABOO_AI_PROVIDERS environment variable."
      );
      expect(result.isError).toBe(true);
    });

    it("should handle when no providers are operational", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava:latest";
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava:latest" }
      ]);
      
      // No provider is operational
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: null,
        model: null
      });
      
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");

      const result = await analyzeToolHandler(
        { 
          image_path: "/tmp/test.png",
          question: "What is this?"
        },
        mockContext,
      );

      expect(result.content[0].text).toBe(
        "No configured AI providers are currently operational."
      );
      expect(result.isError).toBe(true);
    });
  });

  describe("File handling edge cases", () => {
    it("should reject unsupported image formats", async () => {
      const result = await analyzeToolHandler(
        { 
          image_path: "/tmp/test.txt",
          question: "What is this?"
        },
        mockContext,
      );

      expect(result.content[0].text).toBe(
        "Unsupported image format: .txt. Supported formats: .png, .jpg, .jpeg, .webp"
      );
      expect(result.isError).toBe(true);
    });

    it("should handle file read errors", async () => {
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava:latest" }
      ]);
      
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava:latest"
      });
      
      mockReadImageAsBase64.mockRejectedValue(new Error("File not found"));

      const result = await analyzeToolHandler(
        { 
          image_path: "/tmp/nonexistent.png",
          question: "What is this?"
        },
        mockContext,
      );

      expect(result.content[0].text).toBe(
        "Failed to read image file: File not found"
      );
      expect(result.isError).toBe(true);
    });

    it("should handle the silent fallback 'path' parameter", async () => {
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava:latest" }
      ]);
      
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava:latest"
      });
      
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");
      mockAnalyzeImageWithProvider.mockResolvedValue("This is an image");

      const result = await analyzeToolHandler(
        { 
          path: "/tmp/test.png", // Using path instead of image_path
          question: "What is this?"
        },
        mockContext,
      );

      expect(mockReadImageAsBase64).toHaveBeenCalledWith("/tmp/test.png");
      expect(result.content[0].text).toBe("This is an image");
    });
  });

  describe("Very long questions", () => {
    it("should handle extremely long questions", async () => {
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava:latest" }
      ]);
      
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava:latest"
      });
      
      const veryLongQuestion = "A".repeat(10000); // 10k character question
      
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");
      mockAnalyzeImageWithProvider.mockResolvedValue("Analysis of the image");

      const result = await analyzeToolHandler(
        { 
          image_path: "/tmp/test.png",
          question: veryLongQuestion
        },
        mockContext,
      );

      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        { provider: "ollama", model: "llava:latest" },
        "/tmp/test.png",
        "base64imagedata",
        veryLongQuestion,
        mockLogger,
      );

      expect(result.content[0].text).toBe("Analysis of the image");
    });
  });

  describe("Special characters in responses", () => {
    it("should handle responses with special formatting characters", async () => {
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava:latest" }
      ]);
      
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava:latest"
      });
      
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");
      mockAnalyzeImageWithProvider.mockResolvedValue(
        "This image contains:\n- Item 1\n- Item 2\n\nWith **bold** and *italic* text"
      );

      const result = await analyzeToolHandler(
        { 
          image_path: "/tmp/test.png",
          question: "What's in the image?"
        },
        mockContext,
      );

      expect(result.content[0].text).toBe(
        "This image contains:\n- Item 1\n- Item 2\n\nWith **bold** and *italic* text"
      );
    });

    it("should handle responses with unicode characters", async () => {
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava:latest" }
      ]);
      
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava:latest"
      });
      
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");
      mockAnalyzeImageWithProvider.mockResolvedValue("This image contains: 🐱 猫 القط");

      const result = await analyzeToolHandler(
        { 
          image_path: "/tmp/test.png",
          question: "What's in the image?"
        },
        mockContext,
      );

      expect(result.content[0].text).toBe("This image contains: 🐱 猫 القط");
    });
  });

  describe("Error handling edge cases", () => {
    it("should handle analyzeImageWithProvider throwing an exception", async () => {
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava:latest" }
      ]);
      
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "ollama",
        model: "llava:latest"
      });
      
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");
      mockAnalyzeImageWithProvider.mockRejectedValue(new Error("Connection timeout"));

      const result = await analyzeToolHandler(
        { 
          image_path: "/tmp/test.png",
          question: "What is this?"
        },
        mockContext,
      );

      expect(result.content[0].text).toBe("AI analysis failed: Connection timeout");
      expect(result.isError).toBe(true);
      expect(result._meta?.backend_error_code).toBe("AI_PROVIDER_ERROR");
    });

    it("should handle unexpected errors gracefully", async () => {
      // Make parseAIProviders throw to trigger the catch block
      mockParseAIProviders.mockImplementation(() => {
        throw new Error("Unexpected error");
      });

      const result = await analyzeToolHandler(
        { 
          image_path: "/tmp/test.png",
          question: "What is this?"
        },
        mockContext,
      );

      expect(result.content[0].text).toBe("Unexpected error: Unexpected error");
      expect(result.isError).toBe(true);
    });
  });

  describe("Provider config edge cases", () => {
    it("should handle explicit provider config", async () => {
      mockParseAIProviders.mockReturnValue([
        { provider: "ollama", model: "llava:latest" },
        { provider: "openai", model: "gpt-4-vision-preview" }
      ]);
      
      mockDetermineProviderAndModel.mockResolvedValue({
        provider: "openai",
        model: "gpt-4-vision-preview"
      });
      
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");
      mockAnalyzeImageWithProvider.mockResolvedValue("Analysis from OpenAI");

      const result = await analyzeToolHandler(
        { 
          image_path: "/tmp/test.png",
          question: "What is this?",
          provider_config: {
            type: "openai",
            model: "gpt-4-vision-preview"
          }
        },
        mockContext,
      );

      expect(result.model_used).toBe("openai/gpt-4-vision-preview");
      expect(result.content[0].text).toBe("Analysis from OpenAI");
    });
  });
});