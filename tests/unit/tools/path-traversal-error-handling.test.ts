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

describe("Path Traversal Error Handling", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    
    mockResolveImagePath.mockResolvedValue({
      effectivePath: "/tmp/test",
      tempDirUsed: undefined,
    });
  });

  it("should return proper file write error for path traversal attempts, not screen recording error", async () => {
    // Mock Swift CLI response for path traversal attempt that fails with file write error
    const mockPathTraversalResponse = {
      success: false,
      error: {
        message: "Failed to write capture file to path: ../../../../../../../etc/passwd. Directory does not exist - ensure the parent directory exists.",
        code: "FILE_IO_ERROR",
        details: "Directory does not exist - ensure the parent directory exists."
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockPathTraversalResponse);
    
    const input = {
      path: "../../../../../../../etc/passwd",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    // Should fail with file I/O error, NOT screen recording permission error
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Failed to write capture file to path");
    expect(result.content[0].text).toContain("../../../../../../../etc/passwd");
    expect(result.content[0].text).not.toContain("Screen recording permission");
    expect(result.content[0].text).not.toContain("Privacy & Security > Screen Recording");
    
    // Should have FILE_IO_ERROR code, not PERMISSION_ERROR_SCREEN_RECORDING
    expect(result._meta?.backend_error_code).toBe("FILE_IO_ERROR");
  });

  it("should handle absolute path to system directory with proper error message", async () => {
    const mockSystemPathResponse = {
      success: false,
      error: {
        message: "Failed to write capture file to path: /etc/passwd. Permission denied - check that the directory is writable and the application has necessary permissions.",
        code: "FILE_IO_ERROR",
        details: "Permission denied - check that the directory is writable and the application has necessary permissions."
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockSystemPathResponse);
    
    const input = {
      path: "/etc/passwd",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    // Should fail with file I/O error about file system permissions, not screen recording
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Failed to write capture file to path");
    expect(result.content[0].text).toContain("/etc/passwd");
    expect(result.content[0].text).toContain("Permission denied");
    expect(result.content[0].text).not.toContain("Screen recording permission");
    
    expect(result._meta?.backend_error_code).toBe("FILE_IO_ERROR");
  });

  it("should handle relative path that resolves to invalid location", async () => {
    const mockRelativePathResponse = {
      success: false,
      error: {
        message: "Failed to write capture file to path: ../../sensitive/file.png. Directory does not exist - ensure the parent directory exists.",
        code: "FILE_IO_ERROR", 
        details: "Directory does not exist - ensure the parent directory exists."
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockRelativePathResponse);
    
    const input = {
      path: "../../sensitive/file.png",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Failed to write capture file to path");
    expect(result.content[0].text).toContain("../../sensitive/file.png");
    expect(result.content[0].text).toContain("Directory does not exist");
    expect(result.content[0].text).not.toContain("Screen recording permission");
    
    expect(result._meta?.backend_error_code).toBe("FILE_IO_ERROR");
  });

  it("should still correctly identify actual screen recording permission errors", async () => {
    // Mock a real screen recording permission error
    const mockScreenRecordingResponse = {
      success: false,
      error: {
        message: "Screen recording permission is required. Please grant it in System Settings > Privacy & Security > Screen Recording.",
        code: "PERMISSION_ERROR_SCREEN_RECORDING",
        details: "Screen recording permission denied"
      }
    };
    
    mockExecuteSwiftCli.mockResolvedValue(mockScreenRecordingResponse);
    
    const input = {
      path: "/tmp/valid_path.png",
      format: "png" as const
    };
    
    const result = await imageToolHandler(input, mockContext);
    
    // Should correctly identify as screen recording permission error
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Screen recording permission is required");
    expect(result.content[0].text).toContain("System Settings > Privacy & Security > Screen Recording");
    
    expect(result._meta?.backend_error_code).toBe("PERMISSION_ERROR_SCREEN_RECORDING");
  });

  it("should handle various path traversal patterns", async () => {
    const pathTraversalPatterns = [
      "../../../etc/passwd",
      "..\\..\\..\\windows\\system32\\",
      "/../../../../root/.ssh/id_rsa", 
      "folder/../../../etc/hosts"
    ];
    
    for (const pattern of pathTraversalPatterns) {
      vi.clearAllMocks();
      
      const mockResponse = {
        success: false,
        error: {
          message: `Failed to write capture file to path: ${pattern}. Directory does not exist - ensure the parent directory exists.`,
          code: "FILE_IO_ERROR",
          details: "Directory does not exist - ensure the parent directory exists."
        }
      };
      
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);
      
      const input = {
        path: pattern,
        format: "png" as const
      };
      
      const result = await imageToolHandler(input, mockContext);
      
      // All should be file I/O errors, not screen recording errors
      expect(result.isError).toBe(true);
      expect(result.content[0].text).not.toContain("Screen recording permission");
      expect(result._meta?.backend_error_code).toBe("FILE_IO_ERROR");
    }
  });
});