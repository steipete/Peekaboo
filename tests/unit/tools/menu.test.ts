import { describe, it, expect, beforeEach, vi } from "vitest";
import { pino } from "pino";
import {
  menuToolHandler,
  menuToolSchema,
} from "../../../Server/src/tools/menu";
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

describe("Menu Tool", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe("menuToolSchema validation", () => {
    it("should validate required parameters", () => {
      const result = menuToolSchema.safeParse({
        action: "list",
        app: "Safari"
      });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.action).toBe("list");
        expect(result.data.app).toBe("Safari");
      }
    });

    it("should fail without action parameter", () => {
      const result = menuToolSchema.safeParse({
        app: "Safari"
      });
      expect(result.success).toBe(false);
    });

    it("should fail without app parameter", () => {
      const result = menuToolSchema.safeParse({
        action: "list"
      });
      expect(result.success).toBe(false);
    });

    it("should validate all action types", () => {
      const actions = ["list", "click"];
      
      actions.forEach(action => {
        const result = menuToolSchema.safeParse({
          action,
          app: "TestApp"
        });
        expect(result.success).toBe(true);
      });
    });

    it("should fail with invalid action", () => {
      const result = menuToolSchema.safeParse({
        action: "invalid_action",
        app: "Safari"
      });
      expect(result.success).toBe(false);
    });

    it("should validate optional path parameter", () => {
      const result = menuToolSchema.safeParse({
        action: "click",
        app: "Safari",
        path: "File > Save As..."
      });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.path).toBe("File > Save As...");
      }
    });
  });

  describe("menuToolHandler", () => {
    it("should list menu structure successfully", async () => {
      const mockResponse = {
        success: true,
        data: {
          app: "TextEdit",
          menus: [
            {
              title: "File",
              items: [
                { title: "New", enabled: true },
                { title: "Open...", enabled: true },
                { title: "Save", enabled: false },
                { separator: true },
                { title: "Print...", enabled: true }
              ]
            },
            {
              title: "Edit",
              items: [
                { title: "Undo", enabled: true },
                { title: "Redo", enabled: false },
                { separator: true },
                { title: "Cut", enabled: true },
                { title: "Copy", enabled: true },
                { title: "Paste", enabled: true }
              ]
            }
          ]
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "list", app: "TextEdit" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["menu", "list", "--app", "TextEdit"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Menu structure for TextEdit:");
      expect(result.content[0].text).toContain("**File**");
      expect(result.content[0].text).toContain("• New");
      expect(result.content[0].text).toContain("• Save (disabled)");
      expect(result.content[0].text).toContain("**Edit**");
      expect(result.content[0].text).toContain("• Undo");
      expect(result.content[0].text).toContain("• Copy");
    });

    it("should click menu item successfully", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "click",
          app: "Safari",
          path: "File > Save As...",
          message: "Menu item clicked successfully"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "click", app: "Safari", path: "File > Save As..." },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["menu", "click", "--app", "Safari", "--path", "File > Save As..."],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Successfully clicked menu item: File > Save As...");
      expect(result.content[0].text).toContain("Menu item clicked successfully");
    });

    it("should handle click action without path parameter", async () => {
      const result = await menuToolHandler(
        { action: "click", app: "Safari" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toBe("❌ Click action requires 'path' parameter (e.g., 'File > Save As...')");
      expect(mockExecuteSwiftCli).not.toHaveBeenCalled();
    });

    it("should handle alternative menu_bar format", async () => {
      const mockResponse = {
        success: true,
        data: {
          app: "Finder",
          menu_bar: [
            {
              title: "Finder",
              items: [
                { title: "About Finder" },
                { title: "Preferences..." },
                { title: "Services" }
              ]
            },
            {
              title: "File",
              items: [
                { title: "New Folder" },
                { title: "New Smart Folder" },
                { title: "New Tab" }
              ]
            }
          ]
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "list", app: "Finder" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Menu structure for Finder:");
      expect(result.content[0].text).toContain("**Finder**");
      expect(result.content[0].text).toContain("• About Finder");
      expect(result.content[0].text).toContain("**File**");
      expect(result.content[0].text).toContain("• New Folder");
    });

    it("should handle menu items with separators", async () => {
      const mockResponse = {
        success: true,
        data: {
          app: "Safari",
          menus: [
            {
              title: "File",
              items: [
                { title: "New Window" },
                { separator: true },
                { title: "Close Window" },
                { title: "Close Tab" }
              ]
            }
          ]
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "list", app: "Safari" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("• New Window");
      expect(result.content[0].text).toContain("(separator)");
      expect(result.content[0].text).toContain("• Close Window");
    });

    it("should handle menu items without titles", async () => {
      const mockResponse = {
        success: true,
        data: {
          app: "TestApp",
          menus: [
            {
              title: "File",
              items: [
                { name: "Item with name" },
                { title: "Item with title" },
                { /* no title or name */ }
              ]
            }
          ]
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "list", app: "TestApp" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("• Item with name");
      expect(result.content[0].text).toContain("• Item with title");
      expect(result.content[0].text).toContain("• Unnamed Item");
    });

    it("should handle application not found error", async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Application 'NonExistentApp' not found",
          code: "APP_NOT_FOUND"
        }
      });

      const result = await menuToolHandler(
        { action: "list", app: "NonExistentApp" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("❌ Menu command failed");
      expect(result.content[0].text).toContain("Application 'NonExistentApp' not found");
    });

    it("should handle menu item not found error", async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Menu item 'File > NonExistent' not found",
          code: "MENU_ITEM_NOT_FOUND"
        }
      });

      const result = await menuToolHandler(
        { action: "click", app: "Safari", path: "File > NonExistent" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("❌ Menu command failed");
      expect(result.content[0].text).toContain("Menu item 'File > NonExistent' not found");
    });

    it("should handle JSON string response data", async () => {
      const mockResponseObj = {
        success: true,
        data: {
          action: "click",
          app: "Preview",
          path: "View > Zoom In",
          message: "Zoom increased"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: JSON.stringify(mockResponseObj)
      });

      const result = await menuToolHandler(
        { action: "click", app: "Preview", path: "View > Zoom In" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Successfully clicked menu item: View > Zoom In");
      expect(result.content[0].text).toContain("Zoom increased");
    });

    it("should handle malformed JSON response", async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: "Invalid JSON response"
      });

      const result = await menuToolHandler(
        { action: "click", app: "TestApp", path: "File > Save" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("Menu click completed");
      expect(result.content[0].text).toContain("Invalid JSON response");
    });

    it("should handle wrapped success/data response format", async () => {
      const mockResponse = {
        success: true,
        data: {
          app: "Music",
          menus: [
            {
              title: "Music",
              items: [
                { title: "About Music" },
                { title: "Preferences..." }
              ]
            }
          ]
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "list", app: "Music" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Menu structure for Music:");
      expect(result.content[0].text).toContain("**Music**");
      expect(result.content[0].text).toContain("• About Music");
    });

    it("should handle error in response data", async () => {
      const mockResponse = {
        error: {
          message: "Menu is not accessible",
          code: "MENU_NOT_ACCESSIBLE"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "list", app: "Safari" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("❌ Menu Error");
      expect(result.content[0].text).toContain("Menu is not accessible");
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

      const result = await menuToolHandler(
        { action: "list", app: "TestApp" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("Menu list completed with unexpected response format");
      expect(result.content[0].text).toContain('"unexpected":"format"');
    });

    it("should handle execution errors", async () => {
      mockExecuteSwiftCli.mockRejectedValue(new Error("Command execution failed"));

      const result = await menuToolHandler(
        { action: "list", app: "TestApp" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("❌ Menu list failed");
      expect(result.content[0].text).toContain("Command execution failed");
    });

    it("should handle bundle ID as app name", async () => {
      const mockResponse = {
        success: true,
        data: {
          app: "com.apple.Safari",
          menus: [
            {
              title: "Safari",
              items: [
                { title: "About Safari" }
              ]
            }
          ]
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "list", app: "com.apple.Safari" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["menu", "list", "--app", "com.apple.Safari"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Menu structure for com.apple.Safari:");
    });

    it("should handle PID targeting", async () => {
      const mockResponse = {
        success: true,
        data: {
          app: "PID:1234",
          menus: [
            {
              title: "Application",
              items: [
                { title: "Quit" }
              ]
            }
          ]
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "list", app: "PID:1234" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["menu", "list", "--app", "PID:1234"],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Menu structure for PID:1234:");
    });

    it("should handle complex menu paths", async () => {
      const complexPath = "File > Export > Export as PDF...";
      const mockResponse = {
        success: true,
        data: {
          action: "click",
          app: "Preview",
          path: complexPath,
          message: "Export dialog opened"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "click", app: "Preview", path: complexPath },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["menu", "click", "--app", "Preview", "--path", complexPath],
        mockLogger
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain(`✅ Successfully clicked menu item: ${complexPath}`);
      expect(result.content[0].text).toContain("Export dialog opened");
    });

    it("should handle menu paths with special characters", async () => {
      const specialPath = "Edit > Special Characters...";
      const mockResponse = {
        success: true,
        data: {
          action: "click",
          app: "TextEdit",
          path: specialPath
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "click", app: "TextEdit", path: specialPath },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain(`✅ Successfully clicked menu item: ${specialPath}`);
    });

    it("should handle click response without message field", async () => {
      const mockResponse = {
        success: true,
        data: {
          action: "click",
          app: "Finder",
          path: "File > New Folder"
          // No message field
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "click", app: "Finder", path: "File > New Folder" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toBe("✅ Successfully clicked menu item: File > New Folder");
      // Should not crash without message field
    });

    it("should handle empty menu structure", async () => {
      const mockResponse = {
        success: true,
        data: {
          app: "EmptyApp",
          menus: []
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "list", app: "EmptyApp" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Menu structure for EmptyApp:");
      // Should handle empty menus array gracefully
    });

    it("should handle menu with no items", async () => {
      const mockResponse = {
        success: true,
        data: {
          app: "TestApp",
          menus: [
            {
              title: "Empty Menu"
              // No items array
            }
          ]
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "list", app: "TestApp" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("**Empty Menu**");
    });

    it("should handle unexpected menu data format", async () => {
      const mockResponse = {
        success: true,
        data: {
          app: "TestApp",
          not_menus_or_menu_bar: "some other format"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "list", app: "TestApp" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("Menu structure data available but in unexpected format.");
    });

    it("should handle very long menu paths", async () => {
      const longPath = "File > Export > Advanced Options > PDF Settings > Quality Settings > Custom...";
      const mockResponse = {
        success: true,
        data: {
          action: "click",
          app: "Designer",
          path: longPath,
          message: "Advanced settings opened"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "click", app: "Designer", path: longPath },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain(`✅ Successfully clicked menu item: ${longPath}`);
      expect(result.content[0].text).toContain("Advanced settings opened");
    });

    it("should handle menu titles with special characters", async () => {
      const mockResponse = {
        success: true,
        data: {
          app: "International App",
          menus: [
            {
              title: "Файл", // Russian "File"
              items: [
                { title: "新建" }, // Chinese "New"
                { title: "打开..." } // Chinese "Open..."
              ]
            },
            {
              title: "編輯", // Chinese "Edit"
              items: [
                { title: "コピー" } // Japanese "Copy"
              ]
            }
          ]
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "list", app: "International App" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("**Файл**");
      expect(result.content[0].text).toContain("• 新建");
      expect(result.content[0].text).toContain("**編輯**");
      expect(result.content[0].text).toContain("• コピー");
    });

    it("should handle menu access permission error", async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Permission denied to access menu bar",
          code: "PERMISSION_DENIED_ACCESSIBILITY"
        }
      });

      const result = await menuToolHandler(
        { action: "list", app: "Safari" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("❌ Menu command failed");
      expect(result.content[0].text).toContain("Permission denied to access menu bar");
    });

    it("should handle disabled menu items correctly", async () => {
      const mockResponse = {
        success: true,
        data: {
          app: "TextEdit",
          menus: [
            {
              title: "Edit",
              items: [
                { title: "Undo", enabled: false },
                { title: "Redo", enabled: false },
                { title: "Cut", enabled: true },
                { title: "Copy", enabled: true },
                { title: "Paste", enabled: false }
              ]
            }
          ]
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockResponse
      });

      const result = await menuToolHandler(
        { action: "list", app: "TextEdit" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("• Undo (disabled)");
      expect(result.content[0].text).toContain("• Redo (disabled)");
      expect(result.content[0].text).toContain("• Cut\n"); // No "(disabled)" suffix
      expect(result.content[0].text).toContain("• Copy\n"); // No "(disabled)" suffix  
      expect(result.content[0].text).toContain("• Paste (disabled)");
    });
  });
});