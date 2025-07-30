import { describe, it, expect, vi, beforeEach } from "vitest";
import { typeToolHandler, typeToolSchema } from "../../../Server/src/tools/type";
import type { ToolContext, TypeInput } from "../../../Server/src/types/index";
import * as peekabooCliModule from "../../../Server/src/utils/peekaboo-cli";

vi.mock("../../../Server/src/utils/peekaboo-cli");

// Type tests disabled by default to prevent unintended text input
// These tests can type text into any application when run in full mode
describe.skipIf(globalThis.shouldSkipFullTests)("[full] type tool", () => {
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
    it("should accept empty input (for special keys)", () => {
      const input = {};
      const result = typeToolSchema.safeParse(input);
      expect(result.success).toBe(true);
    });

    it("should accept minimal valid input", () => {
      const input = { text: "Hello, world!" };
      const result = typeToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.text).toBe("Hello, world!");
      }
    });

    it("should accept all valid parameters", () => {
      const input = {
        text: "user@example.com",
        session: "test-123",
        clear: true,
        delay: 100,
        press_return: true,
        tab: 2,
        escape: false,
        delete: false,
      };
      const result = typeToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data).toMatchObject(input);
      }
    });

    it("should apply default values", () => {
      const input = { text: "test" };
      const result = typeToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.clear).toBe(false);
        expect(result.data.delay).toBe(5);
        expect(result.data.press_return).toBe(false);
        expect(result.data.escape).toBe(false);
        expect(result.data.delete).toBe(false);
      }
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
        ["type", "Hello, world!", "--delay", "5", "--json-output"],
        mockContext.logger
      );

      expect(result.isError).toBeFalsy();
      expect(result.content[0].type).toBe("text");
      expect(result.content[0].text).toContain("✅ Typing completed successfully");
      expect(result.content[0].text).toContain("⌨️  Key presses: 13");
      expect(result.content[0].text).toContain('📝 Text: "Hello, world!"');
    });

    it("should type with session", async () => {
      const input = {
        text: "john.doe@example.com",
        session: "test-123",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          text_typed: "john.doe@example.com",
          keys_pressed: 20,
          execution_time: 1.0,
        },
      });

      const result = await typeToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["type", "john.doe@example.com", "--on", "T2", "--session", "test-123", "--delay", "50", "--wait-for", "5000"],
        mockContext.logger
      );

      expect(result.content[0].text).toContain("Target: AXTextField: Email");
    });

    it("should clear existing text before typing", async () => {
      const input = {
        text: "New Value",
        clear: true,
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          text_typed: "New Value",
          keys_pressed: 9,
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
      const input = {
        text: "Slow typing",
        delay: 200,
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          text_typed: "Slow typing",
          keys_pressed: 11,
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

      expect(result.content[0].text).toContain('📝 Text: "' + "a".repeat(47) + '..."');
      expect(result.content[0].text).toContain("⌨️  Key presses: 60");
    });

    it("should handle special keys in text", async () => {
      const input = {
        text: "First line{return}Second line{tab}Indented",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          text_typed: "First line{return}Second line{tab}Indented",
          keys_pressed: 40,
          execution_time: 2.0,
        },
      });

      const result = await typeToolHandler(input, mockContext);

      expect(result.isError).toBeFalsy();
      expect(result.content[0].text).toContain("Characters: 40");
    });

    it("should handle element not found error", async () => {
      const input = {
        text: "test",
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
      const input = { text: "test" };

      mockExecuteSwiftCli.mockRejectedValue(new Error("Keyboard access denied"));

      const result = await typeToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Tool execution failed: Keyboard access denied");
    });

    it("should skip wait-for parameter when no target element", async () => {
      const input = {
        text: "test",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          text_typed: "test",
          keys_pressed: 4,
          execution_time: 0.2,
        },
      });

      await typeToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["type", "test", "--delay", "5", "--json-output"],
        mockContext.logger
      );
      // Note: --json-output should be included
    });
  });
});