import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { generateServerStatusString } from "../../../Server/src/utils/server-status";

describe("Server Status AI Providers", () => {
  let originalEnv: NodeJS.ProcessEnv;

  beforeEach(() => {
    originalEnv = { ...process.env };
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  describe("generateServerStatusString", () => {
    it("should show no providers when env var is empty", () => {
      delete process.env.PEEKABOO_AI_PROVIDERS;
      
      const result = generateServerStatusString("1.1.0-beta.1");
      
      expect(result).toBe("Peekaboo MCP 1.1.0-beta.1 using None Configured. Set PEEKABOO_AI_PROVIDERS ENV.");
    });

    it("should show no providers when env var is whitespace", () => {
      process.env.PEEKABOO_AI_PROVIDERS = "   ";
      
      const result = generateServerStatusString("1.1.0-beta.1");
      
      expect(result).toBe("Peekaboo MCP 1.1.0-beta.1 using None Configured. Set PEEKABOO_AI_PROVIDERS ENV.");
    });

    it("should show single provider", () => {
      process.env.PEEKABOO_AI_PROVIDERS = "openai/gpt-4o";
      
      const result = generateServerStatusString("1.1.0-beta.1");
      
      expect(result).toBe("Peekaboo MCP 1.1.0-beta.1 using openai/gpt-4o");
    });

    it("should show multiple providers", () => {
      process.env.PEEKABOO_AI_PROVIDERS = "openai/gpt-4o,ollama/llava:latest";
      
      const result = generateServerStatusString("1.1.0-beta.1");
      
      expect(result).toBe("Peekaboo MCP 1.1.0-beta.1 using openai/gpt-4o, ollama/llava:latest");
    });

    it("should handle providers with extra whitespace", () => {
      process.env.PEEKABOO_AI_PROVIDERS = " openai/gpt-4o , ollama/llava:latest ";
      
      const result = generateServerStatusString("1.1.0-beta.1");
      
      expect(result).toBe("Peekaboo MCP 1.1.0-beta.1 using openai/gpt-4o, ollama/llava:latest");
    });

    it("should filter out empty provider entries", () => {
      process.env.PEEKABOO_AI_PROVIDERS = "openai/gpt-4o,,ollama/llava:latest,";
      
      const result = generateServerStatusString("1.1.0-beta.1");
      
      expect(result).toBe("Peekaboo MCP 1.1.0-beta.1 using openai/gpt-4o, ollama/llava:latest");
    });

    it("should handle semicolon separators", () => {
      process.env.PEEKABOO_AI_PROVIDERS = "openai/gpt-4o;ollama/llava:latest";
      
      const result = generateServerStatusString("1.1.0-beta.1");
      
      expect(result).toBe("Peekaboo MCP 1.1.0-beta.1 using openai/gpt-4o, ollama/llava:latest");
    });

    it("should handle mixed comma and semicolon separators", () => {
      process.env.PEEKABOO_AI_PROVIDERS = "openai/gpt-4o,ollama/llava:latest;anthropic/claude-3-sonnet";
      
      const result = generateServerStatusString("1.1.0-beta.1");
      
      expect(result).toBe("Peekaboo MCP 1.1.0-beta.1 using openai/gpt-4o, ollama/llava:latest, anthropic/claude-3-sonnet");
    });
  });
});