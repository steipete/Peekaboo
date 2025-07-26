import { describe, it, expect, vi, beforeEach } from "vitest";
import { sleepToolHandler, sleepToolSchema } from "../../../Server/src/tools/sleep";
import type { ToolContext, SleepInput } from "../../../Server/src/types/index";
import * as peekabooCliModule from "../../../Server/src/utils/peekaboo-cli";

vi.mock("../../../Server/src/utils/peekaboo-cli");

describe("sleep tool", () => {
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
    it("should require duration parameter", () => {
      const input = {};
      const result = sleepToolSchema.safeParse(input);
      expect(result.success).toBe(false);
    });

    it("should accept valid duration", () => {
      const input: SleepInput = { duration: 1000 };
      const result = sleepToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      expect(result.data.duration).toBe(1000);
    });

    it("should accept zero duration", () => {
      const input: SleepInput = { duration: 0 };
      const result = sleepToolSchema.safeParse(input);
      expect(result.success).toBe(true);
    });

    it("should reject negative duration", () => {
      const input = { duration: -100 };
      const result = sleepToolSchema.safeParse(input);
      expect(result.success).toBe(false);
    });

    it("should accept string duration that can be parsed as number", () => {
      const input = { duration: "500" };
      const result = sleepToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      expect(result.data?.duration).toBe(500);
    });
  });

  describe("tool handler", () => {
    it("should sleep for specified duration", async () => {
      const input: SleepInput = {
        duration: 1000,
      };

      const mockSleepResult = {
        success: true,
        data: {
          success: true,
          requested_duration: 1000,
          actual_duration: 1001.5,
        },
      };

      mockExecuteSwiftCli.mockResolvedValue(mockSleepResult);

      const result = await sleepToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["sleep", "1000"],
        mockContext.logger
      );

      expect(result.isError).toBeFalsy();
      expect(result.content[0].type).toBe("text");
      expect(result.content[0].text).toBe("⏸️  Paused for 1.0s");
    });

    it("should handle sub-second durations", async () => {
      const input: SleepInput = {
        duration: 500,
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          requested_duration: 500,
          actual_duration: 501.2,
        },
      });

      const result = await sleepToolHandler(input, mockContext);

      expect(result.content[0].text).toBe("⏸️  Paused for 0.5s");
    });

    it("should handle multi-second durations", async () => {
      const input: SleepInput = {
        duration: 2500,
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          requested_duration: 2500,
          actual_duration: 2502.3,
        },
      });

      const result = await sleepToolHandler(input, mockContext);

      expect(result.content[0].text).toBe("⏸️  Paused for 2.5s");
    });

    it("should handle zero duration", async () => {
      const input: SleepInput = {
        duration: 0,
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          requested_duration: 0,
          actual_duration: 0.5, // Small overhead
        },
      });

      const result = await sleepToolHandler(input, mockContext);

      expect(result.content[0].text).toBe("⏸️  Paused for 0.0s");
    });

    it("should handle sleep failure", async () => {
      const input: SleepInput = {
        duration: 1000,
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Sleep interrupted",
          code: "SLEEP_INTERRUPTED",
        },
      });

      const result = await sleepToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Failed to sleep");
      expect(result.content[0].text).toContain("Sleep interrupted");
    });

    it("should handle exceptions gracefully", async () => {
      const input: SleepInput = { duration: 1000 };

      mockExecuteSwiftCli.mockRejectedValue(new Error("Unexpected error during sleep"));

      const result = await sleepToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Tool execution failed: Unexpected error during sleep");
    });

    it("should format long durations correctly", async () => {
      const input: SleepInput = {
        duration: 10000, // 10 seconds
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          requested_duration: 10000,
          actual_duration: 10002.1,
        },
      });

      const result = await sleepToolHandler(input, mockContext);

      expect(result.content[0].text).toBe("⏸️  Paused for 10.0s");
    });
  });
});