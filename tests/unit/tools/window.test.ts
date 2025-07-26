import { describe, it, expect, beforeEach, vi } from "vitest";
import { pino } from "pino";
import {
  windowToolHandler,
  windowToolSchema,
} from "../../../Server/src/tools/window";
import { executeSwiftCli } from "../../../Server/src/utils/peekaboo-cli";
import { ToolContext } from "../../../Server/src/types/index";

// Mocks
vi.mock("../../../Server/src/utils/peekaboo-cli");

const mockExecuteSwiftCli = executeSwiftCli as vi.MockedFunction<
  typeof executeSwiftCli
>;

// Create a mock logger for tests
const mockLogger = pino({ level: "silent" });
const mockContext: ToolContext = { logger: mockLogger };

describe("Window Tool", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe("windowToolSchema validation", () => {
    it("should validate required action parameter", () => {
      const result = windowToolSchema.safeParse({
        action: "close"
      });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.action).toBe("close");
      }
    });

    it("should fail without action parameter", () => {
      const result = windowToolSchema.safeParse({});
      expect(result.success).toBe(false);
    });

    it("should validate all action types", () => {
      const actions = ["close", "minimize", "maximize", "move", "resize", "focus"];
      
      actions.forEach(action => {
        const result = windowToolSchema.safeParse({
          action
        });
        expect(result.success).toBe(true);
      });
    });

    it("should fail with invalid action", () => {
      const result = windowToolSchema.safeParse({
        action: "invalid_action"
      });
      expect(result.success).toBe(false);
    });

    it("should validate optional parameters", () => {
      const result = windowToolSchema.safeParse({
        action: "move",
        app: "Safari",
        title: "Main Window",
        index: 0,
        x: 100,
        y: 200,
        width: 800,
        height: 600
      });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.app).toBe("Safari");
        expect(result.data.title).toBe("Main Window");
        expect(result.data.index).toBe(0);
        expect(result.data.x).toBe(100);
        expect(result.data.y).toBe(200);
        expect(result.data.width).toBe(800);
        expect(result.data.height).toBe(600);
      }
    });

    it("should fail with negative index", () => {
      const result = windowToolSchema.safeParse({
        action: "close",
        index: -1
      });
      expect(result.success).toBe(false);
    });

    it("should fail with non-integer index", () => {
      const result = windowToolSchema.safeParse({
        action: "close",
        index: 1.5
      });
      expect(result.success).toBe(false);
    });
  });

  describe("windowToolHandler", () => {
    it("should close window successfully", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "close",
          app: "Safari",
          window_title: "Main Window",
          message: "Window closed successfully"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "close", app: "Safari", title: "Main Window" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["window", "close", "--app", "Safari", "--window-title", "Main Window"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Closed 'Main Window' window of Safari");
      expect(result.content[0].text).toContain("Window closed successfully");
    });

    it("should minimize window successfully", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "minimize",
          app: "TextEdit",
          message: "Window minimized"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "minimize", app: "TextEdit" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["window", "minimize", "--app", "TextEdit"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Minimized TextEdit window");
    });

    it("should maximize window successfully", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "maximize",
          app: "Finder"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "maximize", app: "Finder" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["window", "maximize", "--app", "Finder"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Maximized Finder window");
    });

    it("should move window successfully", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "move",
          app: "Calculator",
          x: 100,
          y: 200
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "move", app: "Calculator", x: 100, y: 200 },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["window", "move", "--app", "Calculator", "--x", "100", "--y", "200"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Moved Calculator window to (100, 200)");
    });

    it("should resize window successfully", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "resize",
          app: "Terminal",
          width: 800,
          height: 600
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "resize", app: "Terminal", width: 800, height: 600 },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["window", "resize", "--app", "Terminal", "--width", "800", "--height", "600"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Resized Terminal window to 800×600");
    });

    it("should focus window successfully", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "focus",
          app: "Xcode"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "focus", app: "Xcode" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["window", "focus", "--app", "Xcode"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Focused Xcode window");
    });

    it("should handle window targeting by index", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "close",
          app: "Chrome",
          window_index: 1
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "close", app: "Chrome", index: 1 },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["window", "close", "--app", "Chrome", "--window-index", "1"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Closed Chrome window");
    });

    it("should handle window targeting by title and index", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "focus",
          app: "Safari",
          window_title: "Apple",
          window_index: 0
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "focus", app: "Safari", title: "Apple", index: 0 },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["window", "focus", "--app", "Safari", "--window-title", "Apple", "--window-index", "0"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Focused 'Apple' window of Safari");
    });

    it("should handle move action without coordinates", async () => {
      const result = await windowToolHandler(
        { action: "move", app: "Safari" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toBe("❌ Move action requires both 'x' and 'y' coordinates");
      expect(mockExecuteSwiftCli).not.toHaveBeenCalled();
    });

    it("should handle move action with partial coordinates", async () => {
      const result = await windowToolHandler(
        { action: "move", app: "Safari", x: 100 },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toBe("❌ Move action requires both 'x' and 'y' coordinates");
      expect(mockExecuteSwiftCli).not.toHaveBeenCalled();
    });

    it("should handle resize action without dimensions", async () => {
      const result = await windowToolHandler(
        { action: "resize", app: "Safari" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toBe("❌ Resize action requires both 'width' and 'height' dimensions");
      expect(mockExecuteSwiftCli).not.toHaveBeenCalled();
    });

    it("should handle resize action with partial dimensions", async () => {
      const result = await windowToolHandler(
        { action: "resize", app: "Safari", width: 800 },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toBe("❌ Resize action requires both 'width' and 'height' dimensions");
      expect(mockExecuteSwiftCli).not.toHaveBeenCalled();
    });

    it("should handle window not found error", async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Window not found for application 'NonExistentApp'",
          code: "WINDOW_NOT_FOUND"
        }
      });

      const result = await windowToolHandler(
        { action: "close", app: "NonExistentApp" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("❌ Window command failed");
      expect(result.content[0].text).toContain("Window not found for application 'NonExistentApp'");
    });

    it("should handle application not found error", async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Application 'UnknownApp' not found",
          code: "APP_NOT_FOUND"
        }
      });

      const result = await windowToolHandler(
        { action: "focus", app: "UnknownApp" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("❌ Window command failed");
      expect(result.content[0].text).toContain("Application 'UnknownApp' not found");
    });

    it("should handle JSON string response data", async () => {
      const mockResponseObj = {
        success: true,
        data: {
          action: "maximize",
          app: "Preview",
          message: "Window maximized successfully"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: JSON.stringify(mockResponseObj)
      });

      const result = await windowToolHandler(
        { action: "maximize", app: "Preview" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Maximized Preview window");
      expect(result.content[0].text).toContain("Window maximized successfully");
    });

    it("should handle malformed JSON response", async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: "Invalid JSON response"
      });

      const result = await windowToolHandler(
        { action: "close", app: "TestApp" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("Window close completed");
      expect(result.content[0].text).toContain("Invalid JSON response");
    });

    it("should handle wrapped success/data response format", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "minimize",
          app: "Music",
          window_title: "Library",
          message: "Window minimized"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "minimize", app: "Music", title: "Library" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Minimized 'Library' window of Music");
      expect(result.content[0].text).toContain("Window minimized");
    });

    it("should handle error in response data", async () => {
      const mockResponse = {
        error: {
          message: "Window is already minimized",
          code: "ALREADY_MINIMIZED"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "minimize", app: "Safari" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("❌ Window Error");
      expect(result.content[0].text).toContain("Window is already minimized");
    });

    it("should handle unexpected response format", async () => {
      const mockResponse = {
        unexpected: "format",
        no_recognizable: "fields"
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "focus", app: "TestApp" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("Window focus completed with unexpected response format");
      expect(result.content[0].text).toContain('"unexpected":"format"');
    });

    it("should handle execution errors", async () => {
      mockExecuteSwiftCli.mockRejectedValue(new Error("Command execution failed"));

      const result = await windowToolHandler(
        { action: "close", app: "TestApp" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("❌ Window close failed");
      expect(result.content[0].text).toContain("Command execution failed");
    });

    it("should handle bundle ID as app name", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "focus",
          app: "com.apple.Safari",
          bundle_id: "com.apple.Safari"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "focus", app: "com.apple.Safari" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["window", "focus", "--app", "com.apple.Safari"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Focused com.apple.Safari window");
    });

    it("should handle PID targeting", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "close",
          app: "PID:1234"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "close", app: "PID:1234" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["window", "close", "--app", "PID:1234"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Closed PID:1234 window");
    });

    it("should handle window action without app or title", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "focus",
          message: "Focused frontmost window"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "focus" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["window", "focus"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Focused window");
      expect(result.content[0].text).toContain("Focused frontmost window");
    });

    it("should handle response without message field", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "resize",
          app: "Maps",
          width: 1000,
          height: 800
          // No message field
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "resize", app: "Maps", width: 1000, height: 800 },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Resized Maps window to 1000×800");
      // Should not crash without message field
    });

    it("should handle negative coordinates for move action", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "move",
          app: "Terminal",
          x: -100,
          y: -50
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "move", app: "Terminal", x: -100, y: -50 },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["window", "move", "--app", "Terminal", "--x", "-100", "--y", "-50"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Moved Terminal window to (-100, -50)");
    });

    it("should handle large dimensions for resize action", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "resize",
          app: "Photoshop",
          width: 3840,
          height: 2160
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "resize", app: "Photoshop", width: 3840, height: 2160 },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["window", "resize", "--app", "Photoshop", "--width", "3840", "--height", "2160"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Resized Photoshop window to 3840×2160");
    });

    it("should handle zero index", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "maximize",
          app: "VSCode",
          window_index: 0
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "maximize", app: "VSCode", index: 0 },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["window", "maximize", "--app", "VSCode", "--window-index", "0"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Maximized VSCode window");
    });

    it("should handle window title with special characters", async () => {
      const specialTitle = "Document™ — Edited & Saved©";
      const mockResponse = {
        success: true,
        data: {
          action: "close",
          app: "TextEdit",
          window_title: specialTitle
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "close", app: "TextEdit", title: specialTitle },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["window", "close", "--app", "TextEdit", "--window-title", specialTitle],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain(`✅ Closed '${specialTitle}' window of TextEdit`);
    });

    it("should handle very long window title", async () => {
      const longTitle = "A".repeat(256);
      const mockResponse = {
        success: true,
        data: {
          action: "focus",
          app: "Browser",
          window_title: longTitle
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "focus", app: "Browser", title: longTitle },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain(`✅ Focused '${longTitle}' window of Browser`);
    });

    it("should handle float coordinates and dimensions", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "move",
          app: "Designer",
          x: 123.5,
          y: 456.7
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await windowToolHandler(
        { action: "move", app: "Designer", x: 123.5, y: 456.7 },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["window", "move", "--app", "Designer", "--x", "123.5", "--y", "456.7"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Moved Designer window to (123.5, 456.7)");
    });
  });
});