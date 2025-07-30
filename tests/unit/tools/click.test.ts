import { describe, it, expect, vi, beforeEach } from "vitest";
import { clickToolHandler, clickToolSchema } from "../../../Server/src/tools/click";
import type { ToolContext, ClickInput } from "../../../Server/src/types/index";
import * as peekabooCliModule from "../../../Server/src/utils/peekaboo-cli";

vi.mock("../../../Server/src/utils/peekaboo-cli");

// Click tests disabled by default to prevent unintended UI interactions
// These tests can click on any UI element when run in full mode
describe.skipIf(globalThis.shouldSkipFullTests)("click tool [full]", () => {
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
    it("should require at least one target parameter", () => {
      const input = {};
      const result = clickToolSchema.safeParse(input);
      expect(result.success).toBe(false);
      expect(result.error?.issues[0].message).toContain("Must specify either 'query', 'on', or 'coords'");
    });

    it("should accept query parameter", () => {
      const input: ClickInput = { query: "Submit Button" };
      const result = clickToolSchema.safeParse(input);
      expect(result.success).toBe(true);
    });

    it("should accept element ID parameter", () => {
      const input: ClickInput = { on: "B1" };
      const result = clickToolSchema.safeParse(input);
      expect(result.success).toBe(true);
    });

    it("should accept coordinates parameter", () => {
      const input: ClickInput = { coords: "100,200" };
      const result = clickToolSchema.safeParse(input);
      expect(result.success).toBe(true);
    });

    it("should accept all valid parameters", () => {
      const input: ClickInput = {
        query: "Login",
        session: "test-123",
        wait_for: 10000,
        double: true,
        right: false,
      };
      const result = clickToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      expect(result.data.wait_for).toBe(10000);
      expect(result.data.double).toBe(true);
    });

    it("should apply default values", () => {
      const input = { on: "B1" };
      const result = clickToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      expect(result.data?.wait_for).toBe(5000);
      expect(result.data?.double).toBe(false);
      expect(result.data?.right).toBe(false);
    });
  });

  describe("tool handler", () => {
    it("should handle click by query successfully", async () => {
      const input: ClickInput = {
        query: "Submit",
        session: "test-123",
      };

      const mockClickResult = {
        success: true,
        data: {
          success: true,
          clicked_element: "AXButton: Submit",
          click_location: { x: 150, y: 250 },
          wait_time: 500,
          execution_time: 0.75,
        },
      };

      mockExecuteSwiftCli.mockResolvedValue(mockClickResult);

      const result = await clickToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["click", "Submit", "--session", "test-123", "--wait-for", "5000"],
        mockContext.logger
      );

      expect(result.isError).toBeFalsy();
      expect(result.content[0].type).toBe("text");
      expect(result.content[0].text).toContain("✅ Click successful");
      expect(result.content[0].text).toContain("AXButton: Submit");
      expect(result.content[0].text).toContain("Location: (150, 250)");
      expect(result.content[0].text).toContain("Waited: 0.5s");
    });

    it("should handle click by element ID", async () => {
      const input: ClickInput = {
        on: "B42",
        wait_for: 10000,
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          clicked_element: "AXButton: Save",
          click_location: { x: 100, y: 200 },
          execution_time: 0.1,
        },
      });

      const result = await clickToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["click", "--on", "B42", "--wait-for", "10000"],
        mockContext.logger
      );

      expect(result.content[0].text).toContain("✅ Click successful");
      expect(result.content[0].text).not.toContain("Waited:"); // No wait time
    });

    it("should handle click by coordinates", async () => {
      const input: ClickInput = {
        coords: "300,400",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          click_location: { x: 300, y: 400 },
          execution_time: 0.05,
        },
      });

      const result = await clickToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["click", "--coords", "300,400", "--wait-for", "5000"],
        mockContext.logger
      );

      expect(result.content[0].text).toContain("Location: (300, 400)");
    });

    it("should handle double-click", async () => {
      const input: ClickInput = {
        on: "L1",
        double: true,
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          clicked_element: "AXLink: Documentation",
          click_location: { x: 50, y: 50 },
          execution_time: 0.1,
        },
      });

      await clickToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--double"]),
        mockContext.logger
      );
    });

    it("should handle right-click", async () => {
      const input: ClickInput = {
        coords: "200,300",
        right: true,
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          click_location: { x: 200, y: 300 },
          execution_time: 0.05,
        },
      });

      await clickToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--right"]),
        mockContext.logger
      );
    });

    it("should handle element not found error", async () => {
      const input: ClickInput = {
        query: "NonExistentButton",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "No actionable element found matching 'NonExistentButton' after 5000ms",
          code: "ELEMENT_NOT_FOUND",
        },
      });

      const result = await clickToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Failed to perform click");
      expect(result.content[0].text).toContain("No actionable element found");
    });

    it("should handle session not found error", async () => {
      const input: ClickInput = {
        on: "B1",
        session: "invalid-session",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Session not found or expired",
          code: "SESSION_NOT_FOUND",
        },
      });

      const result = await clickToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Session not found or expired");
    });

    it("should handle exceptions gracefully", async () => {
      const input: ClickInput = { on: "B1" };

      mockExecuteSwiftCli.mockRejectedValue(new Error("Unexpected error"));

      const result = await clickToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Tool execution failed: Unexpected error");
    });
  });
});