import { describe, it, expect, beforeEach, vi } from "vitest";
import { imageToolHandler } from "../../../Server/src/tools/image";
import { executeSwiftCli } from "../../../Server/src/utils/peekaboo-cli";
import { resolveImagePath } from "../../../Server/src/utils/image-cli-args";
import { mockSwiftCli } from "../../mocks/peekaboo-cli.mock";
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

const MOCK_TEMP_DIR = "/tmp/peekaboo-img-XXXXXX";

describe("Multiple App Matches", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    
    mockResolveImagePath.mockResolvedValue({
      effectivePath: MOCK_TEMP_DIR,
      tempDirUsed: MOCK_TEMP_DIR,
    });
  });

  it("should capture all windows when multiple exact app matches exist", async () => {
    // Simulate capturing "claude" when both "claude" and "Claude" apps exist
    const mockMultipleAppResponse = {
      success: true,
      data: {
        saved_files: [
          {
            path: "/tmp/claude_window_0_20250608_120000.png",
            item_label: "claude",
            window_title: "Chat - Claude",
            window_id: 1001,
            window_index: 0,
            mime_type: "image/png"
          },
          {
            path: "/tmp/claude_window_1_20250608_120001.png", 
            item_label: "claude",
            window_title: "Settings - Claude",
            window_id: 1002,
            window_index: 1,
            mime_type: "image/png"
          },
          {
            path: "/tmp/Claude_window_2_20250608_120002.png",
            item_label: "Claude", 
            window_title: "Main Window - Claude",
            window_id: 2001,
            window_index: 2,
            mime_type: "image/png"
          },
          {
            path: "/tmp/Claude_window_3_20250608_120003.png",
            item_label: "Claude",
            window_title: "Preferences - Claude", 
            window_id: 2002,
            window_index: 3,
            mime_type: "image/png"
          }
        ]
      },
      messages: [],
      debug_logs: ["Multiple applications match 'claude', capturing all windows from all matches"]
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockMultipleAppResponse);
    
    const input = {
      app_target: "claude",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    // Should succeed and return all windows from both apps
    expect(result.isError).toBeUndefined();
    expect(result.saved_files).toHaveLength(4);
    
    // Verify we got windows from both "claude" and "Claude" apps
    const claudeLowerItems = result.saved_files?.filter(f => f.item_label === "claude") || [];
    const claudeUpperItems = result.saved_files?.filter(f => f.item_label === "Claude") || [];
    
    expect(claudeLowerItems).toHaveLength(2);
    expect(claudeUpperItems).toHaveLength(2);
    
    // Verify all windows have sequential indices
    const windowIndices = result.saved_files?.map(f => f.window_index).sort() || [];
    expect(windowIndices).toEqual([0, 1, 2, 3]);
    
    // Should have called Swift CLI with the app name
    expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
      expect.arrayContaining(["--app", "claude"]),
      mockLogger,
      expect.any(Object)
    );
  });

  it("should handle single window mode with multiple app matches", async () => {
    // When using window mode (not multi mode), should still capture from all matching apps
    const mockSingleWindowResponse = {
      success: true,
      data: {
        saved_files: [
          {
            path: "/tmp/claude_Chat_20250608_120000.png",
            item_label: "claude",
            window_title: "Chat - Claude",
            window_id: 1001,
            window_index: 0,
            mime_type: "image/png"
          },
          {
            path: "/tmp/Claude_Main_20250608_120001.png",
            item_label: "Claude",
            window_title: "Main Window - Claude", 
            window_id: 2001,
            window_index: 1,
            mime_type: "image/png"
          }
        ]
      },
      messages: [],
      debug_logs: ["Multiple applications match 'claude', capturing all windows from all matches"]
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockSingleWindowResponse);
    
    const input = {
      app_target: "claude:WINDOW_INDEX:0", // Requesting specific window but multiple apps match
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    expect(result.isError).toBeUndefined();
    expect(result.saved_files).toHaveLength(2);
    
    // Should have called Swift CLI with specific window parameters
    expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
      expect.arrayContaining(["--app", "claude", "--window-index", "0"]),
      mockLogger,
      expect.any(Object)
    );
  });

  it("should handle case where some matching apps have no windows", async () => {
    const mockPartialWindowResponse = {
      success: true,
      data: {
        saved_files: [
          {
            path: "/tmp/Claude_window_0_20250608_120000.png",
            item_label: "Claude",
            window_title: "Main Window - Claude",
            window_id: 2001,
            window_index: 0,
            mime_type: "image/png"
          }
        ]
      },
      messages: [],
      debug_logs: [
        "Multiple applications match 'claude', capturing all windows from all matches",
        "No windows found for app: claude"
      ]
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockPartialWindowResponse);
    
    const input = {
      app_target: "claude",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    expect(result.isError).toBeUndefined();
    expect(result.saved_files).toHaveLength(1);
    expect(result.saved_files?.[0].item_label).toBe("Claude");
  });

  it("should handle case where no matching apps have windows", async () => {
    const mockNoWindowsResponse = {
      success: false,
      error: {
        message: "No windows found for any matching applications of 'claude'",
        code: "WINDOW_NOT_FOUND",
        details: "No windows found for any matching applications"
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockNoWindowsResponse);
    
    const input = {
      app_target: "claude",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("No windows found for any matching applications of 'claude'");
  });

  it("should maintain proper file naming for multiple apps", async () => {
    const mockNamingResponse = {
      success: true,
      data: {
        saved_files: [
          {
            path: "/tmp/VSCode_window_0_20250608_120000.png",
            item_label: "Visual Studio Code",
            window_title: "main.ts - peekaboo",
            window_id: 3001,
            window_index: 0,
            mime_type: "image/png"
          },
          {
            path: "/tmp/vscode_window_1_20250608_120001.png",
            item_label: "vscode",
            window_title: "Extension Host",
            window_id: 4001, 
            window_index: 1,
            mime_type: "image/png"
          }
        ]
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockNamingResponse);
    
    const input = {
      app_target: "vscode", // Matches both "Visual Studio Code" and "vscode"
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    expect(result.isError).toBeUndefined();
    expect(result.saved_files).toHaveLength(2);
    
    // Verify proper naming conventions are maintained
    const file1 = result.saved_files?.[0];
    const file2 = result.saved_files?.[1];
    
    expect(file1?.path).toContain("VSCode_window_0");
    expect(file2?.path).toContain("vscode_window_1");
    
    // Verify sequential indexing across apps
    expect(file1?.window_index).toBe(0);
    expect(file2?.window_index).toBe(1);
  });

  it("should preserve individual app identification in saved files", async () => {
    const mockAppIdResponse = {
      success: true,
      data: {
        saved_files: [
          {
            path: "/tmp/finder_window_0_20250608_120000.png",
            item_label: "Finder",
            window_title: "Desktop",
            window_id: 5001,
            window_index: 0,
            mime_type: "image/png"
          },
          {
            path: "/tmp/FINDER_window_1_20250608_120001.png",
            item_label: "FINDER",
            window_title: "Applications",
            window_id: 5002,
            window_index: 1, 
            mime_type: "image/png"
          }
        ]
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockAppIdResponse);
    
    const input = {
      app_target: "finder",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    expect(result.isError).toBeUndefined();
    expect(result.saved_files).toHaveLength(2);
    
    // Each saved file should preserve its source app's actual name
    expect(result.saved_files?.[0].item_label).toBe("Finder");
    expect(result.saved_files?.[1].item_label).toBe("FINDER");
    
    // But window indices should be sequential across all matches
    expect(result.saved_files?.[0].window_index).toBe(0);
    expect(result.saved_files?.[1].window_index).toBe(1);
  });
});