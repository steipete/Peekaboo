import { describe, it, expect, beforeEach, vi } from "vitest";
import { pino } from "pino";
import {
  appToolHandler,
  appToolSchema,
} from "../../../Server/src/tools/app";
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

describe("App Tool", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe("appToolSchema validation", () => {
    it("should validate required parameters", () => {
      const result = appToolSchema.safeParse({
        action: "launch",
        name: "Safari"
      });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.action).toBe("launch");
        expect(result.data.name).toBe("Safari");
      }
    });

    it("should fail without action parameter", () => {
      const result = appToolSchema.safeParse({
        name: "Safari"
      });
      expect(result.success).toBe(false);
    });

    it("should fail without name parameter", () => {
      const result = appToolSchema.safeParse({
        action: "launch"
      });
      expect(result.success).toBe(false);
    });

    it("should validate all action types", () => {
      const actions = ["launch", "quit", "focus", "hide", "unhide", "switch"];
      
      actions.forEach(action => {
        const result = appToolSchema.safeParse({
          action,
          name: "TestApp"
        });
        expect(result.success).toBe(true);
      });
    });

    it("should fail with invalid action", () => {
      const result = appToolSchema.safeParse({
        action: "invalid_action",
        name: "Safari"
      });
      expect(result.success).toBe(false);
    });

    it("should validate optional force parameter", () => {
      const result = appToolSchema.safeParse({
        action: "quit",
        name: "Safari",
        force: true
      });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.force).toBe(true);
      }
    });
  });

  describe("appToolHandler", () => {
    it("should launch application successfully", async () => {
      const mockResponse = {
        app: "Calculator",
        activated: true,
        pid: 12345,
        note: "Application launched successfully with 1 window(s) visible.",
        action: "launch",
        bundle_id: "com.apple.calculator",
        window_count: 1
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await appToolHandler(
        { action: "launch", name: "Calculator" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["app", "launch", "Calculator"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Application 'Calculator' launched successfully");
      expect(result.content[0].text).toContain("Process ID: 12345");
      expect(result.content[0].text).toContain("Window count: 1");
      expect(result.content[0].text).toContain("Active: Yes");
      expect(result.content[0].text).toContain("Bundle ID: com.apple.calculator");
      expect(result.content[0].text).toContain("Application launched successfully with 1 window(s) visible.");
    });

    it("should quit application successfully", async () => {
      const mockResponse = {
        app: "TextEdit",
        action: "quit",
        note: "Application quit successfully"
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await appToolHandler(
        { action: "quit", name: "TextEdit" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["app", "quit", "TextEdit"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Application 'TextEdit' quit successfully");
      expect(result.content[0].text).toContain("Application quit successfully");
    });

    it("should quit application with force flag", async () => {
      const mockResponse = {
        app: "TextEdit",
        action: "quit",
        note: "Application force quit successfully"
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await appToolHandler(
        { action: "quit", name: "TextEdit", force: true },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["app", "quit", "TextEdit", "--force"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Application 'TextEdit' quit successfully");
    });

    it("should focus application successfully", async () => {
      const mockResponse = {
        app: "Safari",
        action: "focus",
        note: "Application focused successfully"
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await appToolHandler(
        { action: "focus", name: "Safari" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["app", "focus", "Safari"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Application 'Safari' focused successfully");
    });

    it("should handle switch action (alias for focus)", async () => {
      const mockResponse = {
        app: "Chrome",
        action: "switch",
        note: "Application switched successfully"
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await appToolHandler(
        { action: "switch", name: "Chrome" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["app", "switch", "Chrome"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Application 'Chrome' focused successfully");
    });

    it("should hide application successfully", async () => {
      const mockResponse = {
        app: "Finder",
        action: "hide",
        note: "Application hidden successfully"
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await appToolHandler(
        { action: "hide", name: "Finder" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Application 'Finder' hidden successfully");
    });

    it("should unhide application successfully", async () => {
      const mockResponse = {
        app: "Terminal",
        action: "unhide",
        note: "Application unhidden successfully"
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await appToolHandler(
        { action: "unhide", name: "Terminal" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Application 'Terminal' unhidden successfully");
    });

    it("should handle application not found error", async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Application 'NonExistentApp' not found",
          code: "APP_NOT_FOUND"
        }
      });

      const result = await appToolHandler(
        { action: "launch", name: "NonExistentApp" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("❌ App command failed");
      expect(result.content[0].text).toContain("Application 'NonExistentApp' not found");
    });

    it("should handle JSON string response data", async () => {
      const mockResponseObj = {
        app: "Preview",
        action: "launch",
        pid: 9876,
        window_count: 0,
        activated: false
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: JSON.stringify(mockResponseObj)
      });

      const result = await appToolHandler(
        { action: "launch", name: "Preview" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Application 'Preview' launched successfully");
      expect(result.content[0].text).toContain("Process ID: 9876");
      expect(result.content[0].text).toContain("Window count: 0");
      expect(result.content[0].text).toContain("Active: No");
    });

    it("should handle malformed JSON response", async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: "Invalid JSON response"
      });

      const result = await appToolHandler(
        { action: "launch", name: "TestApp" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("App launch completed");
      expect(result.content[0].text).toContain("Invalid JSON response");
    });

    it("should handle wrapped success/data response format", async () => {
      const mockResponse = {
        success: true,
        data: {
          app: "Music",
          action: "launch",
          pid: 5555,
          activated: true,
          window_count: 1,
          bundle_id: "com.apple.Music"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await appToolHandler(
        { action: "launch", name: "Music" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Application 'Music' launched successfully");
      expect(result.content[0].text).toContain("Process ID: 5555");
      expect(result.content[0].text).toContain("Bundle ID: com.apple.Music");
    });

    it("should handle error in response data", async () => {
      const mockResponse = {
        error: {
          message: "Application is already running",
          code: "ALREADY_RUNNING"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await appToolHandler(
        { action: "launch", name: "Safari" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("❌ App Error");
      expect(result.content[0].text).toContain("Application is already running");
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

      const result = await appToolHandler(
        { action: "launch", name: "TestApp" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("App launch completed with unexpected response format");
      expect(result.content[0].text).toContain('"unexpected":"format"');
    });

    it("should handle execution errors", async () => {
      mockExecuteSwiftCli.mockRejectedValue(new Error("Command execution failed"));

      const result = await appToolHandler(
        { action: "launch", name: "TestApp" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("❌ App launch failed");
      expect(result.content[0].text).toContain("Command execution failed");
    });

    it("should handle bundle ID as app name", async () => {
      const mockResponse = {
        app: "com.apple.Safari",
        action: "launch",
        pid: 1111,
        activated: true,
        window_count: 1,
        bundle_id: "com.apple.Safari"
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await appToolHandler(
        { action: "launch", name: "com.apple.Safari" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["app", "launch", "com.apple.Safari"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Application 'com.apple.Safari' launched successfully");
    });

    it("should handle PID targeting", async () => {
      const mockResponse = {
        app: "PID:1234",
        action: "quit",
        note: "Process terminated"
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await appToolHandler(
        { action: "quit", name: "PID:1234" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["app", "quit", "PID:1234"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Application 'PID:1234' quit successfully");
    });

    it("should ignore force flag for non-quit actions", async () => {
      const mockResponse = {
        app: "Safari",
        action: "focus",
        note: "Application focused"
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await appToolHandler(
        { action: "focus", name: "Safari", force: true },
        mockContext
      );

      // Force flag should be ignored for focus action
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["app", "focus", "Safari"],
        mockLogger
      );
      expect(result.isError).toBe(false);
    });

    it("should handle response without note field", async () => {
      const mockResponse = {
        app: "Maps",
        action: "launch",
        pid: 7777,
        activated: true,
        window_count: 1
        // No note field
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await appToolHandler(
        { action: "launch", name: "Maps" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Application 'Maps' launched successfully");
      expect(result.content[0].text).toContain("Process ID: 7777");
      // Should not crash without note field
    });
  });
});