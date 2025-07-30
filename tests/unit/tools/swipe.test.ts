import { describe, it, expect, vi, beforeEach } from "vitest";
import { swipeToolHandler, swipeToolSchema } from "../../../Server/src/tools/swipe";
import type { ToolContext, SwipeInput } from "../../../Server/src/types/index";
import * as peekabooCliModule from "../../../Server/src/utils/peekaboo-cli";

vi.mock("../../../Server/src/utils/peekaboo-cli");

// Swipe tests disabled by default to prevent unintended gesture input
// These tests can perform swipe gestures on any UI element when run in full mode
describe.skipIf(globalThis.shouldSkipFullTests)("swipe tool [full]", () => {
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
    it("should require from and to parameters", () => {
      const input = {};
      const result = swipeToolSchema.safeParse(input);
      expect(result.success).toBe(false);
    });

    it("should accept minimal valid input", () => {
      const input: SwipeInput = {
        from: "100,200",
        to: "300,400",
      };
      const result = swipeToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      expect(result.data.duration).toBe(500); // default
      expect(result.data.steps).toBe(10); // default
    });

    it("should accept all valid parameters", () => {
      const input: SwipeInput = {
        from: "50,100",
        to: "250,300",
        duration: 1000,
        steps: 20,
      };
      const result = swipeToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      expect(result.data).toEqual(input);
    });
  });

  describe("tool handler", () => {
    it("should perform basic swipe", async () => {
      const input: SwipeInput = {
        from: "100,200",
        to: "300,400",
      };

      const mockSwipeResult = {
        success: true,
        data: {
          success: true,
          start_location: { x: 100, y: 200 },
          end_location: { x: 300, y: 400 },
          distance: 282.84,
          duration: 500,
          execution_time: 0.52,
        },
      };

      mockExecuteSwiftCli.mockResolvedValue(mockSwipeResult);

      const result = await swipeToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["swipe", "--from", "100,200", "--to", "300,400", "--duration", "500", "--steps", "10"],
        mockContext.logger
      );

      expect(result.isError).toBeFalsy();
      expect(result.content[0].type).toBe("text");
      expect(result.content[0].text).toContain("✅ Swipe completed");
      expect(result.content[0].text).toContain("From: (100, 200)");
      expect(result.content[0].text).toContain("To: (300, 400)");
      expect(result.content[0].text).toContain("Distance: 283px");
      expect(result.content[0].text).toContain("Duration: 500ms");
    });

    it("should perform swipe with custom parameters", async () => {
      const input: SwipeInput = {
        from: "0,0",
        to: "100,0",
        duration: 1000,
        steps: 25,
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          start_location: { x: 0, y: 0 },
          end_location: { x: 100, y: 0 },
          distance: 100,
          duration: 1000,
          execution_time: 1.05,
        },
      });

      const result = await swipeToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["swipe", "--from", "0,0", "--to", "100,0", "--duration", "1000", "--steps", "25"],
        mockContext.logger
      );

      expect(result.content[0].text).toContain("Distance: 100px");
      expect(result.content[0].text).toContain("Duration: 1000ms");
    });

    it("should handle negative coordinates", async () => {
      const input: SwipeInput = {
        from: "-50,-50",
        to: "50,50",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          start_location: { x: -50, y: -50 },
          end_location: { x: 50, y: 50 },
          distance: 141.42,
          duration: 500,
          execution_time: 0.51,
        },
      });

      const result = await swipeToolHandler(input, mockContext);

      expect(result.content[0].text).toContain("From: (-50, -50)");
      expect(result.content[0].text).toContain("To: (50, 50)");
      expect(result.content[0].text).toContain("Distance: 141px");
    });

    it("should handle decimal coordinates", async () => {
      const input: SwipeInput = {
        from: "100.5,200.5",
        to: "300.5,400.5",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          start_location: { x: 100.5, y: 200.5 },
          end_location: { x: 300.5, y: 400.5 },
          distance: 282.84,
          duration: 500,
          execution_time: 0.52,
        },
      });

      const result = await swipeToolHandler(input, mockContext);

      expect(result.content[0].text).toContain("From: (101, 201)");
      expect(result.content[0].text).toContain("To: (301, 401)");
    });

    it("should handle invalid coordinate format error", async () => {
      const input: SwipeInput = {
        from: "100,200",
        to: "invalid",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Invalid coordinates format. Use: x,y",
          code: "INVALID_ARGUMENT",
        },
      });

      const result = await swipeToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Failed to perform swipe");
      expect(result.content[0].text).toContain("Invalid coordinates format");
    });

    it("should handle exceptions gracefully", async () => {
      const input: SwipeInput = {
        from: "100,200",
        to: "300,400",
      };

      mockExecuteSwiftCli.mockRejectedValue(new Error("Mouse event failed"));

      const result = await swipeToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Tool execution failed: Mouse event failed");
    });
  });
});