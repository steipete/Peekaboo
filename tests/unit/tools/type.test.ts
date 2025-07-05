import { describe, it, expect, vi, beforeEach } from "vitest";
import { typeToolHandler, typeToolSchema } from "../../../src/tools/type.js";
import type { ToolContext, TypeInput } from "../../../src/types/index.js";
import * as peekabooCliModule from "../../../src/utils/peekaboo-cli.js";

vi.mock("../../../src/utils/peekaboo-cli.js");

describe("type tool", () => {
  let mockContext: ToolContext;
  let mockExecuteSwiftCli: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    vi.clearAllMocks();
    
    mockContext = {
      logger: {
        debug: vi.fn(),
        info: vi.fn(),
        warn: vi.fn(),
        error: vi.fn(),
      } as any,
    };

    mockExecuteSwiftCli = vi.fn();
    vi.mocked(peekabooCliModule).executeSwiftCli = mockExecuteSwiftCli;
  });

  describe("schema validation", () => {
    it("should require text parameter", () => {
      const input = {};
      const result = typeToolSchema.safeParse(input);
      expect(result.success).toBe(false);
    });

    it("should accept minimal valid input", () => {
      const input: TypeInput = { text: "Hello, world!" };
      const result = typeToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      expect(result.data.text).toBe("Hello, world!");
    });

    it("should accept all valid parameters", () => {
      const input: TypeInput = {
        text: "user@example.com",
        on: "T1",
        session: "test-123",
        clear: true,
        delay: 100,
        wait_for: 3000,
      };
      const result = typeToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      expect(result.data).toEqual(input);
    });

    it("should apply default values", () => {
      const input = { text: "test" };
      const result = typeToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      expect(result.data?.clear).toBe(false);
      expect(result.data?.delay).toBe(50);
      expect(result.data?.wait_for).toBe(5000);
    });
  });

  describe("tool handler", () => {
    it("should type text at current focus", async () => {
      const input: TypeInput = {
        text: "Hello, world!",
      };

      const mockTypeResult = {
        success: true,
        data: {
          success: true,
          typed_text: "Hello, world!",
          characters_typed: 13,
          execution_time: 0.65,
        },
      };

      mockExecuteSwiftCli.mockResolvedValue(mockTypeResult);

      const result = await typeToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["type", "Hello, world!", "--delay", "50", "--json-output"],
        mockContext.logger
      );

      expect(result.isError).toBeFalsy();
      expect(result.content[0].type).toBe("text");
      expect(result.content[0].text).toContain("✅ Text typed successfully");
      expect(result.content[0].text).toContain("Characters: 13");
      expect(result.content[0].text).toContain('Text: "Hello, world!"');
    });

    it("should type into specific element", async () => {
      const input: TypeInput = {
        text: "john.doe@example.com",
        on: "T2",
        session: "test-123",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          typed_text: "john.doe@example.com",
          target_element: "AXTextField: Email",
          characters_typed: 20,
          execution_time: 1.0,
        },
      });

      const result = await typeToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["type", "john.doe@example.com", "--on", "T2", "--session", "test-123", "--delay", "50", "--wait-for", "5000", "--json-output"],
        mockContext.logger
      );

      expect(result.content[0].text).toContain("Target: AXTextField: Email");
    });

    it("should clear existing text before typing", async () => {
      const input: TypeInput = {
        text: "New Value",
        on: "T1",
        clear: true,
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          typed_text: "New Value",
          target_element: "AXTextField: Name",
          characters_typed: 9,
          execution_time: 0.5,
        },
      });

      await typeToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--clear"]),
        mockContext.logger
      );
    });

    it("should handle custom typing delay", async () => {
      const input: TypeInput = {
        text: "Slow typing",
        delay: 200,
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          typed_text: "Slow typing",
          characters_typed: 11,
          execution_time: 2.2,
        },
      });

      await typeToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--delay", "200"]),
        mockContext.logger
      );
    });

    it("should truncate long text in preview", async () => {
      const longText = "a".repeat(60);
      const input: TypeInput = {
        text: longText,
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          typed_text: longText,
          characters_typed: 60,
          execution_time: 3.0,
        },
      });

      const result = await typeToolHandler(input, mockContext);

      expect(result.content[0].text).toContain('"' + "a".repeat(47) + '..."');
      expect(result.content[0].text).toContain("Characters: 60");
    });

    it("should handle special keys in text", async () => {
      const input: TypeInput = {
        text: "First line{return}Second line{tab}Indented",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          typed_text: "First line{return}Second line{tab}Indented",
          characters_typed: 40,
          execution_time: 2.0,
        },
      });

      const result = await typeToolHandler(input, mockContext);

      expect(result.isError).toBeFalsy();
      expect(result.content[0].text).toContain("Characters: 40");
    });

    it("should handle element not found error", async () => {
      const input: TypeInput = {
        text: "test",
        on: "T99",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Element 'T99' not found or not actionable after 5000ms",
          code: "ELEMENT_NOT_FOUND",
        },
      });

      const result = await typeToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Failed to type text");
      expect(result.content[0].text).toContain("Element 'T99' not found");
    });

    it("should handle exceptions gracefully", async () => {
      const input: TypeInput = { text: "test" };

      mockExecuteSwiftCli.mockRejectedValue(new Error("Keyboard access denied"));

      const result = await typeToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Tool execution failed: Keyboard access denied");
    });

    it("should skip wait-for parameter when no target element", async () => {
      const input: TypeInput = {
        text: "test",
        wait_for: 10000, // This should be ignored when 'on' is not specified
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          typed_text: "test",
          characters_typed: 4,
          execution_time: 0.2,
        },
      });

      await typeToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["type", "test", "--delay", "50", "--json-output"],
        mockContext.logger
      );
      // Note: --wait-for should NOT be included
    });
  });
});