import { describe, it, expect, vi, beforeEach } from "vitest";
import { hotkeyToolHandler, hotkeyToolSchema } from "../../../src/tools/hotkey.js";
import type { ToolContext, HotkeyInput } from "../../../src/types/index.js";
import * as peekabooCliModule from "../../../src/utils/peekaboo-cli.js";

vi.mock("../../../src/utils/peekaboo-cli.js");

describe("hotkey tool", () => {
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
    it("should require keys parameter", () => {
      const input = {};
      const result = hotkeyToolSchema.safeParse(input);
      expect(result.success).toBe(false);
    });

    it("should accept minimal valid input", () => {
      const input: HotkeyInput = { keys: "cmd,c" };
      const result = hotkeyToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      expect(result.data.keys).toBe("cmd,c");
      expect(result.data.hold_duration).toBe(50); // default
    });

    it("should accept custom hold duration", () => {
      const input: HotkeyInput = {
        keys: "cmd,shift,t",
        hold_duration: 100,
      };
      const result = hotkeyToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      expect(result.data.hold_duration).toBe(100);
    });
  });

  describe("tool handler", () => {
    it("should press simple key combination", async () => {
      const input: HotkeyInput = {
        keys: "cmd,c",
      };

      const mockHotkeyResult = {
        success: true,
        data: {
          success: true,
          keys: ["cmd", "c"],
          key_count: 2,
          execution_time: 0.055,
        },
      };

      mockExecuteSwiftCli.mockResolvedValue(mockHotkeyResult);

      const result = await hotkeyToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["hotkey", "--keys", "cmd,c", "--hold-duration", "50", "--json-output"],
        mockContext.logger
      );

      expect(result.isError).toBeFalsy();
      expect(result.content[0].type).toBe("text");
      expect(result.content[0].text).toContain("✅ Hotkey pressed");
      expect(result.content[0].text).toContain("Keys: cmd + c");
      expect(result.content[0].text).toContain("Completed in 0.06s");
    });

    it("should press complex key combination", async () => {
      const input: HotkeyInput = {
        keys: "cmd,shift,option,t",
        hold_duration: 100,
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          keys: ["cmd", "shift", "option", "t"],
          key_count: 4,
          execution_time: 0.11,
        },
      });

      const result = await hotkeyToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["hotkey", "--keys", "cmd,shift,option,t", "--hold-duration", "100", "--json-output"],
        mockContext.logger
      );

      expect(result.content[0].text).toContain("Keys: cmd + shift + option + t");
    });

    it("should handle special keys", async () => {
      const input: HotkeyInput = {
        keys: "cmd,space",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          keys: ["cmd", "space"],
          key_count: 2,
          execution_time: 0.05,
        },
      });

      const result = await hotkeyToolHandler(input, mockContext);

      expect(result.content[0].text).toContain("Keys: cmd + space");
    });

    it("should handle function keys", async () => {
      const input: HotkeyInput = {
        keys: "f11",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          keys: ["f11"],
          key_count: 1,
          execution_time: 0.05,
        },
      });

      const result = await hotkeyToolHandler(input, mockContext);

      expect(result.content[0].text).toContain("Keys: f11");
    });

    it("should handle invalid key error", async () => {
      const input: HotkeyInput = {
        keys: "cmd,xyz",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Unknown key: 'xyz'",
          code: "INVALID_ARGUMENT",
        },
      });

      const result = await hotkeyToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Failed to press hotkey");
      expect(result.content[0].text).toContain("Unknown key: 'xyz'");
    });

    it("should handle empty keys error", async () => {
      const input: HotkeyInput = {
        keys: "",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "No keys specified",
          code: "INVALID_ARGUMENT",
        },
      });

      const result = await hotkeyToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("No keys specified");
    });

    it("should handle exceptions gracefully", async () => {
      const input: HotkeyInput = { keys: "cmd,v" };

      mockExecuteSwiftCli.mockRejectedValue(new Error("Keyboard event failed"));

      const result = await hotkeyToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Tool execution failed: Keyboard event failed");
    });
  });
});