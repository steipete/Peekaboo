import path from "path";
import fs from "fs/promises";
import os from "os";
import { Logger } from "pino";
import { vi, describe, it, expect, beforeEach, afterEach } from "vitest";

import {
  imageToolHandler,
  listToolHandler,
  imageToolSchema,
  listToolSchema,
} from "../../Server/src/tools"; // Adjusted import path for schemas
import { initializeSwiftCliPath } from "../../Server/src/utils/peekaboo-cli";
import { Result } from "@modelcontextprotocol/sdk/types"; // Corrected SDK import path and type

// Define a more specific type for content items used in Peekaboo
interface PeekabooContentItem {
  type: string;
  text?: string;
  imageUrl?: string;
  data?: any;
}

interface PeekabooWindowItem {
  app_name?: string; // Swift CLI might use app_name
  owningApplication?: string;
  kCGWindowOwnerName?: string; // For flexibility
  window_title?: string; // Swift CLI might use window_title
  windowName?: string;
  windowID?: number; // Made optional to reflect reality
  window_id?: number; // Allow for Swift CLI variant
  windowLevel?: number; // Make optional
  isOnScreen?: boolean; // Make optional
  is_on_screen?: boolean; // Allow for Swift CLI variant
  bounds?: {
    // Make optional
    X: number;
    Y: number;
    Width: number;
    Height: number;
  };
  window_index?: number; // Added based on log
  // Add any other potential fields observed from Swift CLI output
  [key: string]: any; // Allow other fields to be present
}

// Ensure local TestToolResponse interface is removed or commented out
// interface TestToolResponse {
//   isError?: boolean;
//   content?: Array<{ type: string; text?: string; imageUrl?: string; data?: any }>;
//   application_list?: Array<any>;
//   saved_files?: Array<{ path: string; data?: string }>;
//   _meta?: { backend_error_code?: string; [key: string]: any };
//   [key: string]: any;
// }

// Initialize Swift CLI path (assuming 'peekaboo' binary is at project root)
const packageRootDir = path.resolve(__dirname, "..", ".."); // Adjust path from tests/integration to project root
initializeSwiftCliPath(packageRootDir);

const mockLogger: Logger = {
  debug: vi.fn(),
  info: vi.fn(),
  warn: vi.fn(),
  error: vi.fn(),
  fatal: vi.fn(),
  child: vi.fn().mockReturnThis(),
  flush: vi.fn(),
  level: "info",
  levels: { values: { info: 30 }, labels: { "30": "info" } },
} as unknown as Logger; // Still using unknown for simplicity if full mock is too verbose

// Conditionally skip Swift-dependent tests on non-macOS platforms
const describeSwiftTests = globalThis.shouldSkipSwiftTests ? describe.skip : describe;

describeSwiftTests("Swift CLI Integration Tests", () => {
  describe("listToolHandler", () => {
    it("should return server_status correctly", async () => {
      const args = listToolSchema.parse({ item_type: "server_status" });
      const response: Result = await listToolHandler(args, {
        logger: mockLogger,
      });

      expect(response.isError).not.toBe(true);
      expect(response.content).toBeDefined();
      // Ensure content is an array and has at least one item before accessing it
      if (
        response.content &&
        Array.isArray(response.content) &&
        response.content.length > 0
      ) {
        const firstContentItem = response.content[0] as PeekabooContentItem;
        expect(firstContentItem.type).toBe("text");
        expect(firstContentItem.text).toContain("Peekaboo MCP");
      } else {
        expect(
          false,
          "Response content was not in the expected format for server_status",
        ).toBe(true);
      }
    });

    it("should call Swift CLI for running_applications and return a structured response", async () => {
      const args = listToolSchema.parse({ item_type: "running_applications" });
      const response: Result = await listToolHandler(args, {
        logger: mockLogger,
      });

      if (response.isError) {
        console.error(
          "listToolHandler running_applications error:",
          JSON.stringify(response),
        );
      }
      expect(response.isError).not.toBe(true);

      if (!response.isError) {
        expect(response).toHaveProperty("application_list");
        expect((response as any).application_list).toBeInstanceOf(Array);
        // Optionally, check if at least one app is returned if any are expected to be running
        if ((response as any).application_list.length === 0) {
          console.warn(
            "listToolHandler for running_applications returned an empty list.",
          );
        }
      }
    }, 15000);

    it("should list windows for a known application (Finder) without details by default", async () => {
      const args = listToolSchema.parse({
        item_type: "application_windows",
        app: "Finder",
        // No include_window_details passed
      });
      const response: Result = await listToolHandler(args, {
        logger: mockLogger,
      });

      if (response.isError) {
        console.error(
          "listToolHandler Finder windows error response:",
          JSON.stringify(response),
        );
      }
      expect(response.isError).not.toBe(true);

      if (!response.isError) {
        expect(response).toHaveProperty("window_list");
        expect(response).toHaveProperty("target_application_info");

        const targetAppInfo = (response as any).target_application_info;
        expect(targetAppInfo).toBeDefined();
        expect(targetAppInfo.app_name).toBe("Finder");

        const windowList = (response as any)
          .window_list as PeekabooWindowItem[];
        expect(windowList).toBeInstanceOf(Array);

        if (windowList.length > 0) {
          const firstWindow = windowList[0];
          // console.log('First window object from Finder (no details requested):', JSON.stringify(firstWindow, null, 2));
          expect(firstWindow).toHaveProperty("window_title"); // Expect basic info
          expect(firstWindow).toHaveProperty("window_index"); // Expect basic info
          // Should NOT have detailed info unless requested
          expect(firstWindow.windowID).toBeUndefined();
          expect(firstWindow.window_id).toBeUndefined();
          expect(firstWindow.bounds).toBeUndefined();
        } else {
          console.warn(
            "listToolHandler for Finder windows returned an empty list. This might be normal.",
          );
        }
      }
    }, 15000);

    it("should return an error when listing windows for a non-existent application", async () => {
      const nonExistentApp = "DefinitelyNotAnApp123ABC";
      const args = listToolSchema.parse({
        item_type: "application_windows",
        app: nonExistentApp,
      });
      const response: Result = await listToolHandler(args, {
        logger: mockLogger,
      });

      expect(response.isError).toBe(true);
      if (
        response.content &&
        Array.isArray(response.content) &&
        response.content.length > 0
      ) {
        const firstContentItem = response.content[0] as PeekabooContentItem;
        // Expect the specific failure message from the handler when Swift CLI fails
        expect(firstContentItem.text?.toLowerCase()).toMatch(
          /list operation failed: (swift cli execution failed|an unknown error occurred|.*could not be found|no running applications found matching identifier|application with identifier.*not found or is not running)/i,
        );
      }
    }, 15000);

    describe("List Tool Leniency", () => {
      it("should default to 'running_applications' when item_type is empty", async () => {
        const args = listToolSchema.parse({ item_type: "" });
        const response: Result = await listToolHandler(args, { logger: mockLogger });
        expect(response.isError).not.toBe(true);
        expect((response as any).application_list).toBeInstanceOf(Array);
      });

      it("should default to 'running_applications' when no args are provided", async () => {
        const args = listToolSchema.parse({});
        const response: Result = await listToolHandler(args, { logger: mockLogger });
        expect(response.isError).not.toBe(true);
        expect((response as any).application_list).toBeInstanceOf(Array);
      });

      it("should default to 'application_windows' when only 'app' is provided", async () => {
        const args = listToolSchema.parse({ app: "Finder" });
        const response: Result = await listToolHandler(args, { logger: mockLogger });
        expect(response.isError).not.toBe(true);
        expect((response as any).window_list).toBeInstanceOf(Array);
        expect((response as any).target_application_info.app_name).toBe("Finder");
      });

      it("should default to 'application_windows' when item_type is empty and 'app' is provided", async () => {
        const args = listToolSchema.parse({ item_type: "", app: "Finder" });
        const response: Result = await listToolHandler(args, { logger: mockLogger });
        expect(response.isError).not.toBe(true);
        expect((response as any).window_list).toBeInstanceOf(Array);
        expect((response as any).target_application_info.app_name).toBe("Finder");
      });

      it("should default to 'application_windows' and accept details when only 'app' and 'details' are provided", async () => {
        const args = listToolSchema.parse({
          app: "Finder",
          include_window_details: ["bounds", "ids"],
        });
        const response: Result = await listToolHandler(args, { logger: mockLogger });

        expect(response.isError).not.toBe(true);
        const windowList = (response as any).window_list;
        expect(windowList).toBeInstanceOf(Array);
        if (windowList.length > 0) {
          expect(windowList[0]).toHaveProperty("bounds");
          expect(windowList[0]).toHaveProperty("window_id");
        }
      });
    });
  });

  describe("imageToolHandler", () => {
    let tempImagePath: string;

    beforeEach(() => {
      tempImagePath = path.join(
        os.tmpdir(),
        `peekaboo-test-image-${Date.now()}.png`,
      );
    });

    afterEach(async () => {
      try {
        await fs.unlink(tempImagePath);
      } catch (error) {
        // Ignore
      }
    });

    it("should attempt to capture screen and save to a file", async () => {
      const args = imageToolSchema.parse({
        mode: "screen",
        path: tempImagePath,
        format: "png",
        return_data: false,
      });
      const response: Result = await imageToolHandler(args, {
        logger: mockLogger,
      });

      if (response.isError) {
        let errorText = "";
        if (
          response.content &&
          Array.isArray(response.content) &&
          response.content.length > 0
        ) {
          const firstContentItem = response.content[0] as PeekabooContentItem;
          errorText = firstContentItem.text?.toLowerCase() ?? "";
        }
        const metaErrorCode = (response._meta as any)?.backend_error_code;
        // console.log('Image tool error response:', JSON.stringify(response));

        expect(
          errorText.includes("permission") ||
            errorText.includes("denied") ||
            errorText.includes("timeout") ||
            metaErrorCode === "PERMISSION_DENIED_SCREEN_RECORDING" ||
            metaErrorCode === "SWIFT_CLI_TIMEOUT" ||
            errorText.includes("capture failed"),
        ).toBeTruthy();

        await expect(fs.access(tempImagePath)).rejects.toThrow();
      } else {
        expect(response.isError).toBeUndefined();
        expect(response).toHaveProperty("saved_files");
        const successResponse = response as Result & {
          saved_files?: { path: string }[];
        };
        expect(successResponse.saved_files).toBeInstanceOf(Array);
        if (
          successResponse.saved_files &&
          successResponse.saved_files.length > 0
        ) {
          // With new path handling, the CLI appends screen identifiers for multiple screen capture
          // The actual path will be something like tempImagePath with _1_timestamp added
          const actualPath = successResponse.saved_files[0]?.path;
          expect(actualPath).toBeDefined();
          // Check that the path starts with the base path (without extension) and ends with .png
          const basePath = tempImagePath.replace(/\.png$/, '');
          // The path might be the exact tempImagePath or have a suffix
          expect(actualPath).toMatch(new RegExp(`^${basePath.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(_\\d+_\\d{8}_\\d{6})?\\.png$`));
          
          // Verify the actual file exists at the returned path
          await expect(fs.access(actualPath!)).resolves.toBeUndefined();
        }
      }
    }, 35000); // Increased timeout to handle screen capture permission dialogs
  });
});
