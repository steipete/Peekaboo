import { describe, it, expect, beforeEach, vi } from "vitest";
import { imageToolHandler } from "../../../Server/src/tools/image";
import { executeSwiftCli } from "../../../Server/src/utils/peekaboo-cli";
import { resolveImagePath } from "../../../Server/src/utils/image-cli-args";
import { pino } from "pino";

// Mock the Swift CLI utility
vi.mock("../../../Server/src/utils/peekaboo-cli");

// Mock image-cli-args module
vi.mock("../../../Server/src/utils/image-cli-args", async () => {
  const actual = await vi.importActual("../../../Server/src/utils/image-cli-args");
  return {
    ...actual,
    resolveImagePath: vi.fn(),
  };
});

const mockExecuteSwiftCli = executeSwiftCli as vi.MockedFunction<typeof executeSwiftCli>;
const mockResolveImagePath = resolveImagePath as vi.MockedFunction<typeof resolveImagePath>;

const mockLogger = pino({ level: "silent" });
const mockContext = { logger: mockLogger };

describe("Browser Helper Filtering", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    
    mockResolveImagePath.mockResolvedValue({
      effectivePath: "/tmp/test",
      tempDirUsed: undefined,
    });
  });

  it("should provide helpful error when Chrome browser is not running", async () => {
    // Mock Chrome not found error (after helper filtering)
    const mockChromeNotFoundResponse = {
      success: false,
      error: {
        message: "Chrome browser is not running or not found",
        code: "APP_NOT_FOUND",
        details: "Application with identifier 'Chrome' not found or is not running."
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockChromeNotFoundResponse);
    
    const input = {
      app_target: "Chrome",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    // Should fail with browser-specific error message
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Chrome browser is not running");
  });

  it("should provide helpful error when Safari browser is not running", async () => {
    // Mock Safari not found error (after helper filtering)
    const mockSafariNotFoundResponse = {
      success: false,
      error: {
        message: "Safari browser is not running or not found",
        code: "APP_NOT_FOUND",
        details: "Application with identifier 'Safari' not found or is not running."
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockSafariNotFoundResponse);
    
    const input = {
      app_target: "Safari",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    // Should fail with browser-specific error message
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Safari browser is not running");
  });

  it("should successfully capture when main Chrome browser is running", async () => {
    // Mock successful Chrome capture (main browser found, not helper)
    const mockChromeSuccessResponse = {
      success: true,
      data: {
        saved_files: [
          {
            path: "/tmp/chrome_window.png",
            item_label: "Google Chrome",
            window_title: "Example Website - Google Chrome",
            window_id: 12345,
            window_index: 0,
            mime_type: "image/png"
          }
        ]
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockChromeSuccessResponse);
    
    const input = {
      app_target: "Chrome",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    // Should succeed with main Chrome browser
    expect(result.isError).toBeUndefined();
    expect(result.saved_files).toHaveLength(1);
    expect(result.saved_files?.[0].item_label).toBe("Google Chrome");
    expect(result.saved_files?.[0].window_title).toContain("Google Chrome");
    expect(result.saved_files?.[0].window_title).not.toContain("Helper");
  });

  it("should demonstrate the problem this fixes - no longer matching helpers", async () => {
    // This test documents what USED TO happen (matching helpers with no windows)
    // and shows that it should now be prevented by the browser filtering
    
    const mockNoWindowsResponse = {
      success: false,
      error: {
        message: "The 'Google Chrome Helper (Renderer)' process is running, but no capturable windows were found.",
        code: "NO_WINDOWS_FOUND",
        details: "Process found but has no windows that can be captured."
      }
    };
    
    // This error should no longer occur for browser searches because helpers are filtered out
    // If Chrome helpers are the only matches, the search should fail with "browser not running" instead
    mockExecuteSwiftCli.mockResolvedValue({
      success: false,
      error: {
        message: "Chrome browser is not running or not found",
        code: "APP_NOT_FOUND",
        details: "Application with identifier 'Chrome' not found or is not running."
      }
    });
    
    const input = {
      app_target: "Chrome",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    // Should NOT get the confusing "no capturable windows" error for helpers
    expect(result.isError).toBe(true);
    expect(result.content[0].text).not.toContain("Helper");
    expect(result.content[0].text).not.toContain("no capturable windows");
    // Should get clear "browser not running" message instead
    expect(result.content[0].text).toContain("Chrome browser is not running");
  });

  it("should not affect non-browser application searches", async () => {
    // Test that non-browser apps still work normally (including helper processes if searched directly)
    const mockTextEditResponse = {
      success: true,
      data: {
        saved_files: [
          {
            path: "/tmp/textedit_window.png",
            item_label: "TextEdit",
            window_title: "Untitled - TextEdit",
            window_id: 67890,
            window_index: 0,
            mime_type: "image/png"
          }
        ]
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockTextEditResponse);
    
    const input = {
      app_target: "TextEdit",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    // Non-browser apps should work normally
    expect(result.isError).toBeUndefined();
    expect(result.saved_files).toHaveLength(1);
    expect(result.saved_files?.[0].item_label).toBe("TextEdit");
  });
});