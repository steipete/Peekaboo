import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { 
  parseAIProviders, 
  getProviderStatus,
  ProviderStatus 
} from "../../../src/utils/ai-providers.js";
import { Logger } from "pino";

// Mock fetch globally
const mockFetch = vi.fn();
global.fetch = mockFetch;

// Mock OpenAI
vi.mock("openai", () => {
  return {
    default: vi.fn().mockImplementation((config) => ({
      models: {
        list: vi.fn(),
      },
    })),
  };
});

describe("AI Provider Status Tests", () => {
  let mockLogger: Logger;

  beforeEach(() => {
    mockLogger = {
      debug: vi.fn(),
      warn: vi.fn(),
      error: vi.fn(),
    } as any;
    
    // Reset environment variables
    delete process.env.OPENAI_API_KEY;
    delete process.env.ANTHROPIC_API_KEY;
    delete process.env.PEEKABOO_OLLAMA_BASE_URL;
    
    // Reset mocks
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe("parseAIProviders", () => {
    it("should parse valid provider strings", () => {
      const result = parseAIProviders("openai/gpt-4o,ollama/llava:latest");
      expect(result).toEqual([
        { provider: "openai", model: "gpt-4o" },
        { provider: "ollama", model: "llava:latest" },
      ]);
    });

    it("should handle empty or invalid provider strings", () => {
      expect(parseAIProviders("")).toEqual([]);
      expect(parseAIProviders("   ")).toEqual([]);
      expect(parseAIProviders("invalid")).toEqual([]);
      expect(parseAIProviders("openai/")).toEqual([]);
      expect(parseAIProviders("/gpt-4o")).toEqual([]);
    });

    it("should filter out invalid entries", () => {
      const result = parseAIProviders("openai/gpt-4o,invalid,ollama/llava:latest,/incomplete");
      expect(result).toEqual([
        { provider: "openai", model: "gpt-4o" },
        { provider: "ollama", model: "llava:latest" },
      ]);
    });

    it("should handle semicolon separators", () => {
      const result = parseAIProviders("openai/gpt-4o;ollama/llava:latest");
      expect(result).toEqual([
        { provider: "openai", model: "gpt-4o" },
        { provider: "ollama", model: "llava:latest" },
      ]);
    });

    it("should handle mixed comma and semicolon separators", () => {
      const result = parseAIProviders("openai/gpt-4o,ollama/llava:latest;anthropic/claude-3-sonnet");
      expect(result).toEqual([
        { provider: "openai", model: "gpt-4o" },
        { provider: "ollama", model: "llava:latest" },
        { provider: "anthropic", model: "claude-3-sonnet" },
      ]);
    });
  });

  describe("OpenAI Provider Status", () => {
    it("should return unavailable when API key is missing", async () => {
      const result = await getProviderStatus(
        { provider: "openai", model: "gpt-4o" },
        mockLogger
      );

      expect(result).toEqual({
        available: false,
        error: "OpenAI API key not configured (OPENAI_API_KEY environment variable missing)",
        details: {
          apiKeyPresent: false,
        },
      });
    });

    it("should return available when API key is valid", async () => {
      process.env.OPENAI_API_KEY = "sk-test-key";
      
      const { default: OpenAI } = await import("openai");
      const mockOpenAI = OpenAI as any;
      const mockList = vi.fn().mockResolvedValue({
        data: [
          { id: "gpt-4o" },
          { id: "gpt-3.5-turbo" },
          { id: "davinci-002" },
        ],
      });
      
      mockOpenAI.mockImplementation(() => ({
        models: { list: mockList },
      }));

      const result = await getProviderStatus(
        { provider: "openai", model: "gpt-4o" },
        mockLogger
      );

      expect(result.available).toBe(true);
      expect(result.details?.apiKeyPresent).toBe(true);
      expect(result.details?.serverReachable).toBe(true);
      expect(result.details?.modelAvailable).toBe(true);
      expect(result.details?.modelList).toContain("gpt-4o");
    });

    it("should handle API errors gracefully", async () => {
      process.env.OPENAI_API_KEY = "sk-invalid-key";
      
      const { default: OpenAI } = await import("openai");
      const mockOpenAI = OpenAI as any;
      const mockList = vi.fn().mockRejectedValue(new Error("401 Unauthorized"));
      
      mockOpenAI.mockImplementation(() => ({
        models: { list: mockList },
      }));

      const result = await getProviderStatus(
        { provider: "openai", model: "gpt-4o" },
        mockLogger
      );

      expect(result.available).toBe(false);
      expect(result.error).toContain("Invalid OpenAI API key");
      expect(result.details?.apiKeyPresent).toBe(true);
      expect(result.details?.serverReachable).toBe(true);
    });

    it("should handle network errors", async () => {
      process.env.OPENAI_API_KEY = "sk-test-key";
      
      const { default: OpenAI } = await import("openai");
      const mockOpenAI = OpenAI as any;
      const mockList = vi.fn().mockRejectedValue(new Error("fetch failed"));
      
      mockOpenAI.mockImplementation(() => ({
        models: { list: mockList },
      }));

      const result = await getProviderStatus(
        { provider: "openai", model: "gpt-4o" },
        mockLogger
      );

      expect(result.available).toBe(false);
      expect(result.error).toContain("Cannot reach OpenAI API");
      expect(result.details?.serverReachable).toBe(false);
    });
  });

  describe("Ollama Provider Status", () => {
    it("should return unavailable when server is not reachable", async () => {
      mockFetch.mockRejectedValue(new Error("fetch failed"));

      const result = await getProviderStatus(
        { provider: "ollama", model: "llava:latest" },
        mockLogger
      );

      expect(result.available).toBe(false);
      expect(result.error).toContain("Ollama server not reachable");
      expect(result.details?.serverReachable).toBe(false);
    });

    it("should return unavailable when server returns error", async () => {
      mockFetch.mockResolvedValue({
        ok: false,
        status: 500,
      });

      const result = await getProviderStatus(
        { provider: "ollama", model: "llava:latest" },
        mockLogger
      );

      expect(result.available).toBe(false);
      expect(result.error).toContain("Ollama server returned 500");
      expect(result.details?.serverReachable).toBe(false);
    });

    it("should return unavailable when model is not found", async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({
          models: [
            { name: "llama2:latest" },
            { name: "codellama:7b" },
          ],
        }),
      });

      const result = await getProviderStatus(
        { provider: "ollama", model: "llava:latest" },
        mockLogger
      );

      expect(result.available).toBe(false);
      expect(result.error).toContain("Model 'llava:latest' not found");
      expect(result.details?.serverReachable).toBe(true);
      expect(result.details?.modelAvailable).toBe(false);
      expect(result.details?.modelList).toEqual(["llama2:latest", "codellama:7b"]);
    });

    it("should return available when model is found", async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({
          models: [
            { name: "llava:latest" },
            { name: "llama2:latest" },
          ],
        }),
      });

      const result = await getProviderStatus(
        { provider: "ollama", model: "llava:latest" },
        mockLogger
      );

      expect(result.available).toBe(true);
      expect(result.details?.serverReachable).toBe(true);
      expect(result.details?.modelAvailable).toBe(true);
      expect(result.details?.modelList).toContain("llava:latest");
    });

    it("should match model variants correctly", async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({
          models: [
            { name: "llava:7b" },
            { name: "llava:13b" },
          ],
        }),
      });

      const result = await getProviderStatus(
        { provider: "ollama", model: "llava" },
        mockLogger
      );

      expect(result.available).toBe(true);
      expect(result.details?.modelAvailable).toBe(true);
    });

    it("should use custom Ollama base URL", async () => {
      process.env.PEEKABOO_OLLAMA_BASE_URL = "http://custom:11434";
      
      mockFetch.mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ models: [{ name: "llava:latest" }] }),
      });

      await getProviderStatus(
        { provider: "ollama", model: "llava:latest" },
        mockLogger
      );

      expect(mockFetch).toHaveBeenCalledWith(
        "http://custom:11434/api/tags",
        expect.objectContaining({
          signal: expect.any(AbortSignal),
        })
      );
    });
  });

  describe("Anthropic Provider Status", () => {
    it("should return unavailable when API key is missing", async () => {
      const result = await getProviderStatus(
        { provider: "anthropic", model: "claude-3-sonnet" },
        mockLogger
      );

      expect(result).toEqual({
        available: false,
        error: "Anthropic API key not configured (ANTHROPIC_API_KEY environment variable missing)",
        details: {
          apiKeyPresent: false,
        },
      });
    });

    it("should return unavailable when not implemented", async () => {
      process.env.ANTHROPIC_API_KEY = "test-key";

      const result = await getProviderStatus(
        { provider: "anthropic", model: "claude-3-sonnet" },
        mockLogger
      );

      expect(result).toEqual({
        available: false,
        error: "Anthropic support not yet implemented",
        details: {
          apiKeyPresent: true,
        },
      });
    });
  });

  describe("Unknown Provider", () => {
    it("should return unavailable for unknown providers", async () => {
      const result = await getProviderStatus(
        { provider: "unknown", model: "test" },
        mockLogger
      );

      expect(result).toEqual({
        available: false,
        error: "Unknown provider: unknown",
      });
    });
  });

  describe("Error Handling", () => {
    it("should handle unexpected errors", async () => {
      mockFetch.mockImplementation(() => {
        throw new Error("Unexpected error");
      });

      const result = await getProviderStatus(
        { provider: "ollama", model: "llava:latest" },
        mockLogger
      );

      expect(result.available).toBe(false);
      expect(result.error).toContain("Unexpected error");
    });
  });
});