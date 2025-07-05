import { describe, it, expect, vi, beforeEach } from "vitest";
import { seeToolHandler, seeToolSchema } from "../../../src/tools/see.js";
import type { ToolContext, SeeInput } from "../../../src/types/index.js";
import * as peekabooCliModule from "../../../src/utils/peekaboo-cli.js";
import * as imageSummaryModule from "../../../src/utils/image-summary.js";

vi.mock("../../../src/utils/peekaboo-cli.js");
vi.mock("../../../src/utils/image-summary.js");

describe("see tool", () => {
  let mockContext: ToolContext;
  let mockExecuteSwiftCli: ReturnType<typeof vi.fn>;
  let mockReadImageAsBase64: ReturnType<typeof vi.fn>;
  let mockBuildImageSummary: ReturnType<typeof vi.fn>;

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
    mockReadImageAsBase64 = vi.fn();
    mockBuildImageSummary = vi.fn();

    vi.mocked(peekabooCliModule).executeSwiftCli = mockExecuteSwiftCli;
    vi.mocked(peekabooCliModule).readImageAsBase64 = mockReadImageAsBase64;
    vi.mocked(imageSummaryModule).buildImageSummary = mockBuildImageSummary;
  });

  describe("schema validation", () => {
    it("should accept minimal valid input", () => {
      const input = {};
      const result = seeToolSchema.safeParse(input);
      expect(result.success).toBe(true);
    });

    it("should accept all valid parameters", () => {
      const input: SeeInput = {
        app_target: "Safari",
        path: "/tmp/screenshot.png",
        session: "test-session-123",
        annotate: true,
      };
      const result = seeToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      expect(result.data).toEqual(input);
    });

    it("should handle different app_target formats", () => {
      const targets = [
        "screen:0",
        "frontmost",
        "Chrome",
        "PID:1234",
        "Safari:WINDOW_TITLE:GitHub",
        "TextEdit:WINDOW_INDEX:0",
      ];

      targets.forEach((target) => {
        const result = seeToolSchema.safeParse({ app_target: target });
        expect(result.success).toBe(true);
      });
    });
  });

  describe("tool handler", () => {
    it("should capture UI state successfully", async () => {
      const input: SeeInput = {
        app_target: "Safari",
        path: "/tmp/test.png",
        session: "test-123",
        annotate: false,
      };

      const mockSeeResult = {
        success: true,
        data: {
          screenshot_path: "/tmp/test.png",
          session_id: "test-123",
          ui_elements: [
            {
              id: "B1",
              role: "AXButton",
              title: "Save",
              bounds: { x: 100, y: 200, width: 80, height: 30 },
              is_actionable: true,
            },
            {
              id: "T1",
              role: "AXTextField",
              label: "Username",
              bounds: { x: 100, y: 250, width: 200, height: 30 },
              is_actionable: true,
            },
          ],
          application: "Safari",
          window: "GitHub - Home",
          timestamp: new Date().toISOString(),
        },
      };

      mockExecuteSwiftCli.mockResolvedValue(mockSeeResult);

      const result = await seeToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["see", "--app", "Safari", "--path", "/tmp/test.png", "--session", "test-123", "--json-output"]),
        mockContext.logger
      );

      expect(result.isError).toBeFalsy();
      expect(result.content).toHaveLength(1);
      expect(result.content[0].type).toBe("text");
      expect(result.content[0].text).toContain("UI State Captured");
      expect(result.content[0].text).toContain("Session ID: test-123");
      expect(result.content[0].text).toContain("B1");
      expect(result.content[0].text).toContain("T1");
      expect(result._meta?.session_id).toBe("test-123");
      expect(result._meta?.element_count).toBe(2);
      expect(result._meta?.actionable_count).toBe(2);
    });

    it("should include annotated screenshot when requested", async () => {
      const input: SeeInput = {
        annotate: true,
      };

      const mockSeeResult = {
        success: true,
        data: {
          screenshot_path: "/tmp/screenshot.png",
          session_id: "auto-123",
          ui_elements: [],
          timestamp: new Date().toISOString(),
        },
      };

      mockExecuteSwiftCli.mockResolvedValue(mockSeeResult);
      mockReadImageAsBase64.mockResolvedValue("base64imagedata");

      const result = await seeToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["see", "--annotate", "--json-output"]),
        mockContext.logger
      );

      expect(mockReadImageAsBase64).toHaveBeenCalledWith("/tmp/screenshot.png");
      expect(result.content).toHaveLength(2);
      expect(result.content[1].type).toBe("image");
      expect(result.content[1].data).toBe("base64imagedata");
      expect(result.content[1].mimeType).toBe("image/png");
    });

    it("should handle screen capture mode", async () => {
      const input: SeeInput = {
        app_target: "screen:1",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          screenshot_path: "/tmp/screen.png",
          session_id: "screen-session",
          ui_elements: [],
          timestamp: new Date().toISOString(),
        },
      });

      await seeToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["see", "--mode", "screen", "--screen-index", "1", "--json-output"]),
        mockContext.logger
      );
    });

    it("should handle frontmost window capture", async () => {
      const input: SeeInput = {
        app_target: "frontmost",
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          screenshot_path: "/tmp/frontmost.png",
          session_id: "frontmost-session",
          ui_elements: [],
          timestamp: new Date().toISOString(),
        },
      });

      await seeToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["see", "--mode", "frontmost", "--json-output"]),
        mockContext.logger
      );
    });

    it("should handle errors from Swift CLI", async () => {
      const input: SeeInput = {};

      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Screen recording permission denied",
          code: "PERMISSION_DENIED_SCREEN_RECORDING",
        },
      });

      const result = await seeToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Failed to capture UI state");
      expect(result.content[0].text).toContain("Screen recording permission denied");
    });

    it("should handle missing annotated screenshot gracefully", async () => {
      const input: SeeInput = {
        annotate: true,
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          screenshot_path: "/tmp/missing.png",
          session_id: "test-session",
          ui_elements: [],
          timestamp: new Date().toISOString(),
        },
      });

      mockReadImageAsBase64.mockRejectedValue(new Error("File not found"));

      const result = await seeToolHandler(input, mockContext);

      expect(result.isError).toBeFalsy();
      expect(result.content).toHaveLength(1); // Only text, no image
      expect(mockContext.logger.warn).toHaveBeenCalledWith(
        expect.objectContaining({ error: expect.any(Error) }),
        "Failed to read annotated screenshot"
      );
    });
  });

  describe("UI element summary", () => {
    it("should group elements by role", async () => {
      const input: SeeInput = {};

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          screenshot_path: "/tmp/test.png",
          session_id: "test-123",
          ui_elements: [
            { id: "B1", role: "AXButton", title: "Save", bounds: { x: 0, y: 0, width: 50, height: 30 }, is_actionable: true },
            { id: "B2", role: "AXButton", title: "Cancel", bounds: { x: 60, y: 0, width: 50, height: 30 }, is_actionable: true },
            { id: "T1", role: "AXTextField", label: "Name", bounds: { x: 0, y: 40, width: 100, height: 30 }, is_actionable: true },
            { id: "G1", role: "AXGroup", title: "Container", bounds: { x: 0, y: 0, width: 200, height: 100 }, is_actionable: false },
          ],
          timestamp: new Date().toISOString(),
        },
      });

      const result = await seeToolHandler(input, mockContext);

      const text = result.content[0].text!;
      expect(text).toContain("AXButton (2 found, 2 actionable)");
      expect(text).toContain("AXTextField (1 found, 1 actionable)");
      expect(text).toContain("AXGroup (1 found, 0 actionable)");
      expect(text).toContain('[not actionable]');
    });
  });
});