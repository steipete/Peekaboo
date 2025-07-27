import { describe, it, expect, vi, beforeEach } from "vitest";
import { scrollToolHandler, scrollToolSchema } from "../../../Server/src/tools/scroll";
import type { ToolContext } from "../../../Server/src/types/index";
import type { ScrollInput } from "../../../Server/src/tools/scroll";
import * as peekabooCliModule from "../../../Server/src/utils/peekaboo-cli";

vi.mock("../../../Server/src/utils/peekaboo-cli");

describe("scroll tool", () => {
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
    it("should require direction parameter", () => {
      const input = {};
      const result = scrollToolSchema.safeParse(input);
      expect(result.success).toBe(false);
    });

    it("should accept valid directions", () => {
      const directions = ["up", "down", "left", "right"];
      directions.forEach((direction) => {
        const result = scrollToolSchema.safeParse({ direction });
        expect(result.success).toBe(true);
      });
    });

    it("should reject invalid directions", () => {
      const result = scrollToolSchema.safeParse({ direction: "diagonal" });
      expect(result.success).toBe(false);
    });

    it("should accept all valid parameters", () => {
      const input: ScrollInput = {
        direction: "down",
        amount: 5,
        on: "G1",
        session: "test-123",
        delay: 30,
        smooth: true,
      };
      const result = scrollToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      expect(result.data).toEqual(input);
    });

    it("should apply default values", () => {
      const input = { direction: "up" };
      const result = scrollToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      expect(result.data?.amount).toBe(3);
      expect(result.data?.delay).toBe(2);
      expect(result.data?.smooth).toBe(false);
    });
  });

  describe("tool handler", () => {
    it("should scroll at current mouse position", async () => {
      const input: ScrollInput = {
        direction: "down",
        amount: 5,
      };

      const mockScrollResult = {
        success: true,
        data: {
          success: true,
          direction: "down",
          amount: 5,
          location: { x: 500, y: 300 },
          total_ticks: 5,
          execution_time: 0.15,
        },
      };

      mockExecuteSwiftCli.mockResolvedValue(mockScrollResult);

      const result = await scrollToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["scroll", "--direction", "down", "--amount", "5", "--delay", "2"],
        mockContext.logger
      );

      expect(result.isError).toBeFalsy();
      expect(result.content[0].type).toBe("text");
      expect(result.content[0].text).toContain("✅ Scroll completed");
      expect(result.content[0].text).toContain("Direction: down");
      expect(result.content[0].text).toContain("Amount: 5 ticks");
      expect(result.content[0].text).not.toContain("Location:"); // No location when not targeting element
    });

    it("should scroll on specific element", async () => {
      const input: ScrollInput = {
        direction: "up",
        on: "G2",
        session: "test-123",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          direction: "up",
          amount: 3,
          location: { x: 250, y: 400 },
          total_ticks: 3,
          execution_time: 0.09,
        },
      });

      const result = await scrollToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["scroll", "--direction", "up", "--amount", "3", "--on", "G2", "--session", "test-123", "--delay", "2"],
        mockContext.logger
      );

      expect(result.content[0].text).toContain("Location: (250, 400)");
    });

    it("should handle smooth scrolling", async () => {
      const input: ScrollInput = {
        direction: "right",
        amount: 2,
        smooth: true,
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          direction: "right",
          amount: 2,
          location: { x: 600, y: 350 },
          total_ticks: 6, // smooth scrolling multiplies ticks
          execution_time: 0.18,
        },
      });

      await scrollToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--smooth"]),
        mockContext.logger
      );
    });

    it("should handle custom delay", async () => {
      const input: ScrollInput = {
        direction: "left",
        delay: 50,
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          direction: "left",
          amount: 3,
          location: { x: 300, y: 200 },
          total_ticks: 3,
          execution_time: 0.15,
        },
      });

      await scrollToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--delay", "50"]),
        mockContext.logger
      );
    });

    it("should handle element not found error", async () => {
      const input: ScrollInput = {
        direction: "down",
        on: "G99",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Element not found",
          code: "ELEMENT_NOT_FOUND",
        },
      });

      const result = await scrollToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Failed to perform scroll");
      expect(result.content[0].text).toContain("Element not found");
    });

    it("should handle exceptions gracefully", async () => {
      const input: ScrollInput = { direction: "up" };

      mockExecuteSwiftCli.mockRejectedValue(new Error("Scroll event failed"));

      const result = await scrollToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Tool execution failed: Scroll event failed");
    });
  });
});