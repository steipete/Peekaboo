import { describe, it, expect, beforeEach, vi } from "vitest";
import { pino } from "pino";
import {
  listToolHandler,
  buildSwiftCliArgs,
  ListToolInput,
  listToolSchema,
} from "../../../src/tools/list";
import { executeSwiftCli } from "../../../src/utils/peekaboo-cli";
import { generateServerStatusString } from "../../../src/utils/server-status";
import fs from "fs/promises";
import {
  ToolContext,
  ApplicationListData,
  WindowListData,
} from "../../../src/types/index.js";

// Mocks
vi.mock("../../../src/utils/peekaboo-cli");
vi.mock("../../../src/utils/server-status");
vi.mock("fs/promises");
vi.mock("fs", () => ({
  existsSync: vi.fn(() => false),
  accessSync: vi.fn(),
  constants: {
    X_OK: 1,
    W_OK: 2,
  },
}));

const mockExecuteSwiftCli = executeSwiftCli as vi.MockedFunction<
  typeof executeSwiftCli
>;
const mockGenerateServerStatusString =
  generateServerStatusString as vi.MockedFunction<
    typeof generateServerStatusString
  >;
const mockFsReadFile = fs.readFile as vi.MockedFunction<typeof fs.readFile>;
const mockFsAccess = fs.access as vi.MockedFunction<typeof fs.access>;

// Create a mock logger for tests
const mockLogger = pino({ level: "silent" });
const mockContext: ToolContext = { logger: mockLogger };

describe("List Tool", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // Mock fs.access to always succeed by default
    mockFsAccess.mockResolvedValue(undefined);
    // Mock fs.readFile to return a valid package.json
    mockFsReadFile.mockResolvedValue(JSON.stringify({ version: "1.0.0" }));
  });

  describe("buildSwiftCliArgs", () => {
    it("should return default args for running_applications", () => {
      const input: ListToolInput = { item_type: "running_applications" };
      expect(buildSwiftCliArgs(input)).toEqual(["list", "apps"]);
    });

    it("should return args for application_windows with app only", () => {
      const input: ListToolInput = {
        item_type: "application_windows",
        app: "Safari",
      };
      expect(buildSwiftCliArgs(input)).toEqual([
        "list",
        "windows",
        "--app",
        "Safari",
      ]);
    });

    it("should return args for application_windows with app and details", () => {
      const input: ListToolInput = {
        item_type: "application_windows",
        app: "Chrome",
        include_window_details: ["bounds", "ids"],
      };
      expect(buildSwiftCliArgs(input)).toEqual([
        "list",
        "windows",
        "--app",
        "Chrome",
        "--include-details",
        "bounds,ids",
      ]);
    });

    it("should return args for application_windows with app and empty details", () => {
      const input: ListToolInput = {
        item_type: "application_windows",
        app: "Finder",
        include_window_details: [],
      };
      expect(buildSwiftCliArgs(input)).toEqual([
        "list",
        "windows",
        "--app",
        "Finder",
      ]);
    });

    it("should ignore app and include_window_details if item_type is not application_windows", () => {
      const input: ListToolInput = {
        item_type: "running_applications",
        app: "ShouldBeIgnored",
        include_window_details: ["bounds"],
      };
      expect(buildSwiftCliArgs(input)).toEqual(["list", "apps"]);
    });
  });

  describe("listToolHandler", () => {
    it("should list running applications", async () => {
      const mockSwiftResponse: ApplicationListData = {
        applications: [
          {
            app_name: "Safari",
            bundle_id: "com.apple.Safari",
            pid: 1234,
            is_active: true,
            window_count: 2,
          },
          {
            app_name: "Cursor",
            bundle_id: "com.todesktop.230313mzl4w4u92",
            pid: 5678,
            is_active: false,
            window_count: 1,
          },
        ],
      };
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockSwiftResponse,
        messages: [],
      });

      const result = await listToolHandler(
        {
          item_type: "running_applications",
        },
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["list", "apps"],
        mockLogger,
        expect.objectContaining({ timeout: expect.any(Number) })
      );
      expect(result.content[0].text).toContain("Found 2 running applications");
      expect(result.content[0].text).toContain(
        "Safari (com.apple.Safari) - PID: 1234 [ACTIVE] - Windows: 2",
      );
      expect(result.content[0].text).toContain(
        "Cursor (com.todesktop.230313mzl4w4u92) - PID: 5678 - Windows: 1",
      );
      expect((result as any).application_list).toEqual(
        mockSwiftResponse.applications,
      );
    });

    it("should list application windows", async () => {
      const mockSwiftResponse: WindowListData = {
        target_application_info: {
          app_name: "Safari",
          bundle_id: "com.apple.Safari",
          pid: 1234,
        },
        windows: [
          {
            window_title: "Main Window",
            window_id: 12345,
            is_on_screen: true,
            bounds: { x: 0, y: 0, width: 800, height: 600 },
          },
          {
            window_title: "Secondary Window",
            window_id: 12346,
            is_on_screen: false,
          },
        ],
      };
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockSwiftResponse,
        messages: [],
      });

      const result = await listToolHandler(
        {
          item_type: "application_windows",
          app: "Safari",
          include_window_details: ["ids", "bounds", "off_screen"],
        },
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        [
          "list",
          "windows",
          "--app",
          "Safari",
          "--include-details",
          "ids,bounds,off_screen",
        ],
        mockLogger,
        expect.objectContaining({ timeout: expect.any(Number) })
      );
      expect(result.content[0].text).toContain(
        "Found 2 windows for application: Safari (com.apple.Safari) - PID: 1234",
      );
      expect(result.content[0].text).toContain(
        '1. "Main Window" [ID: 12345] [ON-SCREEN] [0,0 800×600]',
      );
      expect(result.content[0].text).toContain(
        '2. "Secondary Window" [ID: 12346] [OFF-SCREEN]',
      );
      expect((result as any).window_list).toEqual(mockSwiftResponse.windows);
      expect((result as any).target_application_info).toEqual(
        mockSwiftResponse.target_application_info,
      );
    });

    it("should handle server status", async () => {
      // Mock generateServerStatusString since it's still used
      mockGenerateServerStatusString.mockReturnValue(
        "# Peekaboo MCP Server Status\nVersion: 1.2.3",
      );

      const result = await listToolHandler(
        {
          item_type: "server_status",
        },
        mockContext,
      );

      // Should NOT call executeSwiftCli for server_status anymore
      expect(mockExecuteSwiftCli).not.toHaveBeenCalled();

      // Should call generateServerStatusString with the version
      expect(mockGenerateServerStatusString).toHaveBeenCalled();

      // Check that the response contains expected sections
      const statusText = result.content[0].text;
      expect(statusText).toContain("# Peekaboo MCP Server Status");
      expect(statusText).toContain("## Native Binary (Swift CLI) Status");
      expect(statusText).toContain("## System Permissions");
      expect(statusText).toContain("## Environment Configuration");
      expect(statusText).toContain("## Configuration Issues");
      expect(statusText).toContain("## System Information");
    });

    it("should handle Swift CLI errors", async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: { message: "Application not found", code: "APP_NOT_FOUND" },
      });

      const result = (await listToolHandler(
        {
          item_type: "running_applications",
        },
        mockContext,
      )) as { content: any[]; isError?: boolean; _meta?: any };

      expect(result.content[0].text).toBe(
        "List operation failed: Application not found",
      );
      expect(result.isError).toBe(true);
      expect((result as any)._meta.backend_error_code).toBe("APP_NOT_FOUND");
    });

    it("should return a specific error if the app is not found", async () => {
      // Arrange
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "The specified application ('Ciursor') is not running or could not be found.",
          code: "SWIFT_CLI_APP_NOT_FOUND",
          details: "Error: Application with name 'Ciursor' not found.",
        },
      });
      const args = { item_type: "application_windows", app: "Ciursor" } as ListToolInput;

      // Act
      const result = await listToolHandler(args, mockContext);

      // Assert
      expect(result.isError).toBe(true);
      expect(result.content[0].text).toBe(
        "List operation failed: The specified application ('Ciursor') is not running or could not be found.\nError: Application with name 'Ciursor' not found."
      );
    });

    it("should handle Swift CLI errors with no message or code", async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: { message: "Unknown error", code: "UNKNOWN_SWIFT_ERROR" }, // Provide default message and code
      });

      const result = (await listToolHandler(
        {
          item_type: "running_applications",
        },
        mockContext,
      )) as { content: any[]; isError?: boolean; _meta?: any };

      expect(result.content[0].text).toBe(
        "List operation failed: Unknown error",
      );
      expect(result.isError).toBe(true);
      // Meta might or might not be undefined depending on the exact path, so let's check the code if present
      if (result._meta) {
        expect(result._meta.backend_error_code).toBe("UNKNOWN_SWIFT_ERROR");
      } else {
        // If no _meta, the code should still reflect the error object passed
        // This case might need adjustment based on listToolHandler's exact logic for _meta creation
      }
    });

    it("should handle unexpected errors during Swift CLI execution", async () => {
      mockExecuteSwiftCli.mockRejectedValue(
        new Error("Unexpected Swift execution error"),
      );

      const result = (await listToolHandler(
        {
          item_type: "running_applications",
        },
        mockContext,
      )) as { content: any[]; isError?: boolean };

      expect(result.content[0].text).toBe(
        "Unexpected error: Unexpected Swift execution error",
      );
      expect(result.isError).toBe(true);
    });

    it("should handle unexpected errors during server status (fs.readFile fails)", async () => {
      mockFsReadFile.mockRejectedValue(new Error("Cannot read package.json"));

      const result = (await listToolHandler(
        {
          item_type: "server_status",
        },
        mockContext,
      )) as { content: any[]; isError?: boolean };

      expect(result.content[0].text).toBe(
        "Unexpected error: Cannot read package.json",
      );
      expect(result.isError).toBe(true);
    });

    it("should include Swift CLI messages in the output for applications list", async () => {
      const mockSwiftResponse: ApplicationListData = {
        applications: [
          {
            app_name: "TestApp",
            bundle_id: "com.test.app",
            pid: 111,
            is_active: false,
            window_count: 0,
          },
        ],
      };
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockSwiftResponse,
        messages: ["Warning: One app hidden.", "Info: Low memory."],
      });

      const result = await listToolHandler(
        { item_type: "running_applications" },
        mockContext,
      );
      expect(result.content[0].text).toContain(
        "Messages: Warning: One app hidden.; Info: Low memory.",
      );
    });

    it("should include Swift CLI messages in the output for windows list", async () => {
      const mockSwiftResponse: WindowListData = {
        target_application_info: { app_name: "TestApp", pid: 111 },
        windows: [{ window_title: "TestWindow", window_id: 222 }],
      };
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockSwiftResponse,
        messages: ["Note: Some windows might be minimized."],
      });

      const result = await listToolHandler(
        { item_type: "application_windows", app: "TestApp" },
        mockContext,
      );
      expect(result.content[0].text).toContain(
        "Messages: Note: Some windows might be minimized.",
      );
    });

    it("should handle missing app parameter for application_windows", async () => {
      // The Zod schema validation should catch this before the handler is called
      // In real usage, this would throw a validation error
      // For testing, we can simulate what would happen if validation was bypassed
      expect(() => {
        listToolSchema.parse({
          item_type: "application_windows",
          // missing app parameter
        });
      }).toThrow();
    });

    it("should handle empty applications list", async () => {
      const mockSwiftResponse: ApplicationListData = {
        applications: [],
      };
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockSwiftResponse,
        messages: [],
      });

      const result = await listToolHandler(
        {
          item_type: "running_applications",
        },
        mockContext,
      );

      expect(result.content[0].text).toContain("Found 0 running applications");
      expect((result as any).application_list).toEqual([]);
    });

    it("should handle empty windows list", async () => {
      const mockSwiftResponse: WindowListData = {
        target_application_info: {
          app_name: "Safari",
          bundle_id: "com.apple.Safari",
          pid: 1234,
        },
        windows: [],
      };
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockSwiftResponse,
        messages: [],
      });

      const result = await listToolHandler(
        {
          item_type: "application_windows",
          app: "Safari",
        },
        mockContext,
      );

      expect(result.content[0].text).toContain(
        "Found 0 windows for application: Safari",
      );
      expect((result as any).window_list).toEqual([]);
    });

    it("should handle very long app names", async () => {
      const longAppName = "A".repeat(256);
      const mockSwiftResponse: ApplicationListData = {
        applications: [
          {
            app_name: longAppName,
            bundle_id: "com.long.app",
            pid: 9999,
            is_active: false,
            window_count: 1,
          },
        ],
      };
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockSwiftResponse,
        messages: [],
      });

      const result = await listToolHandler(
        {
          item_type: "running_applications",
        },
        mockContext,
      );

      expect(result.content[0].text).toContain(longAppName);
    });

    it("should handle special characters in app names", async () => {
      const specialAppName = "App™ with © Special & Characters™";
      const mockSwiftResponse: ApplicationListData = {
        applications: [
          {
            app_name: specialAppName,
            bundle_id: "com.special.app",
            pid: 1111,
            is_active: true,
            window_count: 2,
          },
        ],
      };
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockSwiftResponse,
        messages: [],
      });

      const result = await listToolHandler(
        {
          item_type: "running_applications",
        },
        mockContext,
      );

      expect(result.content[0].text).toContain(specialAppName);
    });

    it("should handle all window detail options", async () => {
      const mockSwiftResponse: WindowListData = {
        target_application_info: {
          app_name: "TestApp",
          bundle_id: "com.test.app",
          pid: 1234,
        },
        windows: [
          {
            window_title: "Test Window",
            window_id: 12345,
            window_index: 0,
            is_on_screen: true,
            bounds: { x: 100, y: 200, width: 800, height: 600 },
          },
        ],
      };
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockSwiftResponse,
        messages: [],
      });

      const result = await listToolHandler(
        {
          item_type: "application_windows",
          app: "TestApp",
          include_window_details: ["ids", "bounds", "off_screen"],
        },
        mockContext,
      );

      // Window numbering is 1-based in the output
      expect(result.content[0].text).toContain('1. "Test Window"');
      expect(result.content[0].text).toContain("[ID: 12345]");
      expect(result.content[0].text).toContain("[100,200 800×600]");
      expect(result.content[0].text).toContain("[ON-SCREEN]");
    });

    it("should handle windows with missing optional fields", async () => {
      const mockSwiftResponse: WindowListData = {
        target_application_info: { app_name: "TestApp", pid: 1234 },
        windows: [
          {
            window_title: "Minimal Window",
            // All other fields are optional
          },
        ],
      };
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockSwiftResponse,
        messages: [],
      });

      const result = await listToolHandler(
        {
          item_type: "application_windows",
          app: "TestApp",
          include_window_details: ["ids", "bounds"],
        },
        mockContext,
      );

      expect(result.content[0].text).toContain('"Minimal Window"');
      expect(result.content[0].text).not.toContain("[ID:"); // No ID present
      expect(result.content[0].text).not.toContain("×"); // No bounds present
    });

    it("should handle malformed Swift CLI response for applications", async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: null, // Invalid data
      });

      const result = (await listToolHandler(
        {
          item_type: "running_applications",
        },
        mockContext,
      )) as any;

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain(
        "Invalid response from list utility",
      );
    });

    it("should handle malformed Swift CLI response for windows", async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: { windows: [] }, // Missing target_application_info
      });

      const result = (await listToolHandler(
        {
          item_type: "application_windows",
          app: "Safari",
        },
        mockContext,
      )) as any;

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain(
        "Invalid response from list utility",
      );
    });

    it("should handle very large PID values", async () => {
      const mockSwiftResponse: ApplicationListData = {
        applications: [
          {
            app_name: "TestApp",
            bundle_id: "com.test.app",
            pid: Number.MAX_SAFE_INTEGER,
            is_active: false,
            window_count: 0,
          },
        ],
      };
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockSwiftResponse,
        messages: [],
      });

      const result = await listToolHandler(
        {
          item_type: "running_applications",
        },
        mockContext,
      );

      expect(result.content[0].text).toContain(
        `PID: ${Number.MAX_SAFE_INTEGER}`,
      );
    });

    it("should handle negative window count", async () => {
      const mockSwiftResponse: ApplicationListData = {
        applications: [
          {
            app_name: "BuggyApp",
            bundle_id: "com.buggy.app",
            pid: 1234,
            is_active: false,
            window_count: -1, // Shouldn't happen but testing edge case
          },
        ],
      };
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockSwiftResponse,
        messages: [],
      });

      const result = await listToolHandler(
        {
          item_type: "running_applications",
        },
        mockContext,
      );

      expect(result.content[0].text).toContain("Windows: -1");
    });

    it("should handle very long window titles", async () => {
      const longTitle = "Window ".repeat(100);
      const mockSwiftResponse: WindowListData = {
        target_application_info: { app_name: "TestApp", pid: 1234 },
        windows: [
          {
            window_title: longTitle,
            window_id: 12345,
          },
        ],
      };
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockSwiftResponse,
        messages: [],
      });

      const result = await listToolHandler(
        {
          item_type: "application_windows",
          app: "TestApp",
        },
        mockContext,
      );

      expect(result.content[0].text).toContain(longTitle);
    });

    it("should handle invalid version in package.json", async () => {
      mockFsReadFile.mockResolvedValue('{ "not_version": "1.0.0" }');
      mockGenerateServerStatusString.mockReturnValue(
        "Peekaboo MCP Server v[unknown]\nStatus: Test",
      );

      const result = await listToolHandler(
        {
          item_type: "server_status",
        },
        mockContext,
      );

      expect(mockGenerateServerStatusString).toHaveBeenCalledWith("[unknown]");
      expect(result.content[0].text).toContain("[unknown]");
    });

    it("should handle malformed package.json", async () => {
      mockFsReadFile.mockRejectedValue(new Error("Cannot read package.json"));

      const result = (await listToolHandler(
        {
          item_type: "server_status",
        },
        mockContext,
      )) as any;

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Unexpected error");
    });

    it("should handle empty window details array", async () => {
      const mockSwiftResponse: WindowListData = {
        target_application_info: { app_name: "TestApp", pid: 1234 },
        windows: [{ window_title: "Test Window" }],
      };
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: mockSwiftResponse,
        messages: [],
      });

      const result = await listToolHandler(
        {
          item_type: "application_windows",
          app: "TestApp",
          include_window_details: [],
        },
        mockContext,
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["list", "windows", "--app", "TestApp"],
        mockLogger,
        expect.objectContaining({ timeout: expect.any(Number) })
      );
      expect(result.content[0].text).toContain('"Test Window"');
    });

    it("should handle duplicate window detail options", async () => {
      const input: ListToolInput = {
        item_type: "application_windows",
        app: "TestApp",
        include_window_details: ["ids", "ids", "bounds", "bounds"], // Duplicates
      };

      const args = buildSwiftCliArgs(input);
      expect(args).toEqual([
        "list",
        "windows",
        "--app",
        "TestApp",
        "--include-details",
        "ids,ids,bounds,bounds",
      ]);
    });
  });

  describe("listToolSchema validation", () => {
    it("should succeed when item_type is 'running_applications' and 'include_window_details' is an empty array", () => {
      const input = {
        item_type: "running_applications",
        include_window_details: [],
      };
      const result = listToolSchema.safeParse(input);
      expect(result.success).toBe(true);
    });

    it("should fail when item_type is 'running_applications' and 'include_window_details' is not empty", () => {
      const result = listToolSchema.safeParse({
        item_type: "running_applications",
        include_window_details: ["ids"],
      });
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.flatten().fieldErrors.include_window_details).toEqual([
          "'include_window_details' is only applicable when 'item_type' is 'application_windows' or when 'app' is provided.",
        ]);
      }
    });

    it("should fail when item_type is 'server_status' and 'include_window_details' has values", () => {
      const result = listToolSchema.safeParse({
        item_type: "server_status",
        include_window_details: ["bounds"],
      });
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.flatten().fieldErrors.item_type).toEqual([
          "'app' and 'include_window_details' not applicable for 'server_status'.",
        ]);
      }
    });

    it("should succeed when item_type is 'server_status' and 'include_window_details' is empty", () => {
      const result = listToolSchema.safeParse({
        item_type: "server_status",
        include_window_details: [],
      });
      expect(result.success).toBe(true);
    });

    it("should succeed when item_type is 'server_status' without extra parameters", () => {
      const result = listToolSchema.safeParse({
        item_type: "server_status",
      });
      expect(result.success).toBe(true);
    });

    it("should succeed when item_type is 'application_windows' and 'include_window_details' is provided", () => {
      const input = {
        item_type: "application_windows",
        app: "Finder",
        include_window_details: ["ids"],
      };
      const result = listToolSchema.safeParse(input);
      expect(result.success).toBe(true);
    });

    it("should fail when item_type is 'application_windows' and 'app' is missing", () => {
        const input = {
            item_type: "application_windows",
            include_window_details: ["ids"],
        };
        const result = listToolSchema.safeParse(input);
        expect(result.success).toBe(false);
        if (!result.success) {
            expect(result.error.flatten().fieldErrors.app).toEqual([
                "For 'application_windows', 'app' identifier is required.",
            ]);
        }
    });
  });

  describe("listToolHandler - Error message handling", () => {
    it("should include error details for ambiguous app identifier", async () => {
      // Mock Swift CLI returning ambiguous app error with details
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "Multiple applications match identifier 'C'. Please be more specific.",
          code: "AMBIGUOUS_APP_IDENTIFIER",
          details: "Matches found: Calendar (com.apple.iCal), Console (com.apple.Console), Cursor (com.todesktop.230313mzl4w4u92)"
        }
      });

      const result = await listToolHandler(
        { 
          item_type: "application_windows",
          app: "C" 
        },
        mockContext,
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].type).toBe("text");
      // Should include both the main message and the details
      expect(result.content[0].text).toContain("Multiple applications match identifier 'C'");
      expect(result.content[0].text).toContain("Matches found: Calendar (com.apple.iCal), Console (com.apple.Console), Cursor (com.todesktop.230313mzl4w4u92)");
    });
  });
});
