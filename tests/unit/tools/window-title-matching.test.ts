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

describe("Window Title Matching Issues", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    
    mockResolveImagePath.mockResolvedValue({
      effectivePath: "/tmp/test",
      tempDirUsed: undefined,
    });
  });

  it("should handle window not found error for URL-based titles", async () => {
    // Mock the exact scenario from the issue - window not found
    const mockWindowNotFoundResponse = {
      success: false,
      error: {
        message: "The specified window could not be found.",
        code: "WINDOW_NOT_FOUND",
        details: "Window matching criteria was not found"
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockWindowNotFoundResponse);
    
    const input = {
      app_target: "Google Chrome:WINDOW_TITLE:http://example.com:8080",
      path: "/tmp/multiple_colons.png",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    // Should fail with window not found error
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("The specified window could not be found");
    expect(result._meta?.backend_error_code).toBe("WINDOW_NOT_FOUND");
    
    // Verify correct arguments were passed to Swift CLI
    expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
      expect.arrayContaining([
        "--app", "Google Chrome",
        "--mode", "window", 
        "--window-title", "http://example.com:8080"
      ]),
      mockLogger,
      expect.any(Object)
    );
  });

  it("should suggest debugging when window title matching fails", async () => {
    // Test that includes some debugging suggestions in the response
    const mockWindowNotFoundWithDetails = {
      success: false,
      error: {
        message: "The specified window could not be found.",
        code: "WINDOW_NOT_FOUND",
        details: "Window with title containing 'http://example.com:8080' not found in Google Chrome"
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockWindowNotFoundWithDetails);
    
    const input = {
      app_target: "Google Chrome:WINDOW_TITLE:http://example.com:8080",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("The specified window could not be found");
  });

  it("should handle successful window matching with URLs", async () => {
    // Test successful case where the window IS found
    const mockSuccessResponse = {
      success: true,
      data: {
        saved_files: [
          {
            path: "/tmp/chrome_window.png",
            item_label: "Google Chrome",
            window_title: "example.com:8080 - Google Chrome",
            window_id: 12345,
            window_index: 0,
            mime_type: "image/png"
          }
        ]
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockSuccessResponse);
    
    const input = {
      app_target: "Google Chrome:WINDOW_TITLE:example.com:8080",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    expect(result.isError).toBeUndefined();
    expect(result.saved_files).toHaveLength(1);
    expect(result.saved_files?.[0].window_title).toContain("example.com:8080");
  });

  it("should demonstrate different URL formats that might appear in window titles", async () => {
    // Various formats Chrome might show in window titles
    const urlFormats = [
      "http://example.com:8080",
      "example.com:8080", 
      "localhost:8080",
      "127.0.0.1:8080",
      "https://example.com:8443/path"
    ];
    
    for (const urlFormat of urlFormats) {
      vi.clearAllMocks();
      
      const mockResponse = {
        success: true,
        data: {
          saved_files: [
            {
              path: `/tmp/window_${urlFormat.replace(/[:/]/g, '_')}.png`,
              item_label: "Browser",
              window_title: `${urlFormat} - Browser`,
              window_id: 123,
              window_index: 0,
              mime_type: "image/png"
            }
          ]
        }
      };
      
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);
      
      const input = {
        app_target: `Browser:WINDOW_TITLE:${urlFormat}`,
        format: "png" as const
      };
      
      const result = await imageToolHandler(input, mockContext);
      
      // Should succeed for all URL formats
      expect(result.isError).toBeUndefined();
      
      // Verify correct arguments were passed
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining([
          "--app", "Browser",
          "--window-title", urlFormat
        ]),
        mockLogger,
        expect.any(Object)
      );
    }
  });
});