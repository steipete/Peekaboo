import { describe, it, expect, beforeEach, vi } from "vitest";
import { imageToolHandler } from "../../../src/tools/image";
import { executeSwiftCli } from "../../../src/utils/peekaboo-cli";
import { resolveImagePath } from "../../../src/utils/image-cli-args";
import { pino } from "pino";

// Mock the Swift CLI utility
vi.mock("../../../src/utils/peekaboo-cli");

// Mock image-cli-args module
vi.mock("../../../src/utils/image-cli-args", async () => {
  const actual = await vi.importActual("../../../src/utils/image-cli-args");
  return {
    ...actual,
    resolveImagePath: vi.fn(),
  };
});

const mockExecuteSwiftCli = executeSwiftCli as vi.MockedFunction<typeof executeSwiftCli>;
const mockResolveImagePath = resolveImagePath as vi.MockedFunction<typeof resolveImagePath>;

const mockLogger = pino({ level: "silent" });
const mockContext = { logger: mockLogger };

describe("Improved Window Error Messages", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    
    mockResolveImagePath.mockResolvedValue({
      effectivePath: "/tmp/test",
      tempDirUsed: undefined,
    });
  });

  it("should provide helpful error message with available window titles when window not found", async () => {
    // Mock detailed window not found error with available titles
    const mockDetailedWindowNotFoundResponse = {
      success: false,
      error: {
        message: "Window with title containing 'http://example.com:8080' not found in Google Chrome. Available windows: \"example.com:8080 - Google Chrome\", \"New Tab - Google Chrome\". Note: For URLs, try without the protocol (e.g., 'example.com:8080' instead of 'http://example.com:8080').",
        code: "WINDOW_NOT_FOUND",
        details: "Window title matching failed with suggested alternatives"
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockDetailedWindowNotFoundResponse);
    
    const input = {
      app_target: "Google Chrome:WINDOW_TITLE:http://example.com:8080",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    // Should fail with detailed error message
    expect(result.isError).toBe(true);
    
    const errorText = result.content[0].text;
    expect(errorText).toContain("Window with title containing 'http://example.com:8080' not found");
    expect(errorText).toContain("Available windows:");
    expect(errorText).toContain("example.com:8080 - Google Chrome");
    expect(errorText).toContain("New Tab - Google Chrome");
    expect(errorText).toContain("try without the protocol");
    expect(errorText).toContain("'example.com:8080' instead of 'http://example.com:8080'");
  });

  it("should handle case where app has no windows matching title", async () => {
    const mockNoMatchingWindowsResponse = {
      success: false,
      error: {
        message: "Window with title containing 'nonexistent-page' not found in Safari. Available windows: \"Apple - Google Search - Safari\", \"GitHub - Safari\". Note: For URLs, try without the protocol (e.g., 'example.com:8080' instead of 'http://example.com:8080').",
        code: "WINDOW_NOT_FOUND",
        details: "No windows match the specified title"
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockNoMatchingWindowsResponse);
    
    const input = {
      app_target: "Safari:WINDOW_TITLE:nonexistent-page",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    expect(result.isError).toBe(true);
    
    const errorText = result.content[0].text;
    expect(errorText).toContain("Window with title containing 'nonexistent-page' not found in Safari");
    expect(errorText).toContain("Available windows:");
    expect(errorText).toContain("Apple - Google Search - Safari");
    expect(errorText).toContain("GitHub - Safari");
  });

  it("should provide guidance for URL-based searches", async () => {
    const mockURLGuidanceResponse = {
      success: false,
      error: {
        message: "Window with title containing 'https://localhost:3000/app' not found in Firefox. Available windows: \"localhost:3000/app - Mozilla Firefox\", \"about:blank - Mozilla Firefox\". Note: For URLs, try without the protocol (e.g., 'example.com:8080' instead of 'http://example.com:8080').",
        code: "WINDOW_NOT_FOUND",
        details: "URL matching guidance provided"
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockURLGuidanceResponse);
    
    const input = {
      app_target: "Firefox:WINDOW_TITLE:https://localhost:3000/app",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    expect(result.isError).toBe(true);
    
    const errorText = result.content[0].text;
    expect(errorText).toContain("localhost:3000/app - Mozilla Firefox");
    expect(errorText).toContain("Note: For URLs, try without the protocol");
  });

  it("should handle case where no similar windows exist", async () => {
    const mockNoSimilarWindowsResponse = {
      success: false,
      error: {
        message: "Window with title containing 'very-specific-search' not found in Code. Available windows: \"ImageCommand.swift - peekaboo\", \"main.swift - peekaboo\". Note: For URLs, try without the protocol (e.g., 'example.com:8080' instead of 'http://example.com:8080').",
        code: "WINDOW_NOT_FOUND",
        details: "No similar windows found"
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockNoSimilarWindowsResponse);
    
    const input = {
      app_target: "Code:WINDOW_TITLE:very-specific-search",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    expect(result.isError).toBe(true);
    
    const errorText = result.content[0].text;
    expect(errorText).toContain("Window with title containing 'very-specific-search' not found in Code");
    expect(errorText).toContain("ImageCommand.swift - peekaboo");
    expect(errorText).toContain("main.swift - peekaboo");
  });

  it("should handle successful window matching after applying guidance", async () => {
    // Test successful case when user follows the guidance
    const mockSuccessfulMatchResponse = {
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
    
    mockExecuteSwiftCli.mockResolvedValue(mockSuccessfulMatchResponse);
    
    const input = {
      app_target: "Google Chrome:WINDOW_TITLE:example.com:8080",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    expect(result.isError).toBeUndefined();
    expect(result.saved_files).toHaveLength(1);
    expect(result.saved_files?.[0].window_title).toBe("example.com:8080 - Google Chrome");
  });

  it("should provide appropriate guidance for different URL patterns", async () => {
    const urlPatterns = [
      {
        input: "http://localhost:8080",
        suggestion: "localhost:8080"
      },
      {
        input: "https://api.example.com:443/v1",
        suggestion: "api.example.com:443/v1"
      },
      {
        input: "ftp://files.example.com:21",
        suggestion: "files.example.com:21"
      }
    ];

    for (const pattern of urlPatterns) {
      vi.clearAllMocks();
      
      const mockResponse = {
        success: false,
        error: {
          message: `Window with title containing '${pattern.input}' not found in Browser. Available windows: \"${pattern.suggestion} - Browser\". Note: For URLs, try without the protocol (e.g., 'example.com:8080' instead of 'http://example.com:8080').`,
          code: "WINDOW_NOT_FOUND",
          details: "URL pattern guidance"
        }
      };
      
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);
      
      const input = {
        app_target: `Browser:WINDOW_TITLE:${pattern.input}`,
        format: "png" as const
      };
      
      const result = await imageToolHandler(input, mockContext);
      
      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain(`Window with title containing '${pattern.input}' not found`);
      expect(result.content[0].text).toContain(`${pattern.suggestion} - Browser`);
      expect(result.content[0].text).toContain("try without the protocol");
    }
  });
});