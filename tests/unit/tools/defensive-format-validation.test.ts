import { describe, it, expect, beforeEach, vi } from "vitest";
import { imageToolHandler } from "../../../src/tools/image";
import { executeSwiftCli } from "../../../src/utils/peekaboo-cli";
import { resolveImagePath } from "../../../src/utils/image-cli-args";
import { mockSwiftCli } from "../../mocks/peekaboo-cli.mock";
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

const MOCK_TEMP_DIR = "/tmp/peekaboo-img-XXXXXX";

describe("Defensive Format Validation", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    
    mockResolveImagePath.mockResolvedValue({
      effectivePath: MOCK_TEMP_DIR,
      tempDirUsed: MOCK_TEMP_DIR,
    });
  });

  it("should catch and fix invalid formats that bypass schema preprocessing", async () => {
    // Mock Swift CLI response
    const mockResponse = mockSwiftCli.captureImage("screen", {
      path: "/tmp/test.png",
      format: "png",
    });
    mockExecuteSwiftCli.mockResolvedValue(mockResponse);
    
    // Create a spy on logger.warn to check if defensive validation triggers
    const loggerWarnSpy = vi.spyOn(mockLogger, "warn");
    
    // Simulate a scenario where somehow an invalid format gets through
    // (this should not happen with proper schema validation, but this is defensive)
    const inputWithInvalidFormat = {
      format: "bmp" as any, // Force an invalid format
      path: "/tmp/test.bmp",
    };
    
    // Bypass schema validation by calling the handler directly
    const result = await imageToolHandler(inputWithInvalidFormat, mockContext);
    
    // Should succeed with PNG fallback
    expect(result.isError).toBeUndefined();
    
    // Should have logged a warning about the invalid format
    expect(loggerWarnSpy).toHaveBeenCalledWith(
      { originalFormat: "bmp", fallbackFormat: "png" },
      "Invalid format 'bmp' detected, falling back to PNG"
    );
    
    // Should call Swift CLI with PNG format, not BMP
    expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
      expect.arrayContaining(["--format", "png"]),
      mockLogger,
      expect.objectContaining({ timeout: expect.any(Number) })
    );
    
    // Should not contain BMP in the arguments
    const swiftCliCall = mockExecuteSwiftCli.mock.calls[0][0];
    expect(swiftCliCall).not.toContain("bmp");
    
    // Should include a warning in the response content
    const allResponseText = result.content.map(item => item.text || "").join(" ");
    expect(allResponseText).toContain("Invalid format 'bmp' was provided");
    expect(allResponseText).toContain("Automatically using PNG format instead");
  });
  
  it("should not trigger defensive validation for valid formats", async () => {
    const mockResponse = mockSwiftCli.captureImage("screen", {
      path: "/tmp/test.png",
      format: "png",
    });
    mockExecuteSwiftCli.mockResolvedValue(mockResponse);
    
    const loggerWarnSpy = vi.spyOn(mockLogger, "warn");
    
    // Use a valid format
    const inputWithValidFormat = {
      format: "png" as any,
      path: "/tmp/test.png",
    };
    
    const result = await imageToolHandler(inputWithValidFormat, mockContext);
    
    // Should succeed
    expect(result.isError).toBeUndefined();
    
    // Should NOT have logged any warning about invalid format
    expect(loggerWarnSpy).not.toHaveBeenCalledWith(
      expect.objectContaining({ originalFormat: expect.any(String) }),
      expect.stringContaining("Invalid format")
    );
    
    // Response should not contain format warning
    const allResponseText = result.content.map(item => item.text || "").join(" ");
    expect(allResponseText).not.toContain("Invalid format");
    expect(allResponseText).not.toContain("Automatically using PNG format instead");
  });
  
  it("should handle various invalid formats defensively", async () => {
    const mockResponse = mockSwiftCli.captureImage("screen", {
      path: "/tmp/test.png",
      format: "png",
    });
    mockExecuteSwiftCli.mockResolvedValue(mockResponse);
    
    const invalidFormats = ["bmp", "gif", "webp", "tiff", "svg", "raw"];
    
    for (const invalidFormat of invalidFormats) {
      vi.clearAllMocks();
      
      const loggerWarnSpy = vi.spyOn(mockLogger, "warn");
      
      const input = {
        format: invalidFormat as any,
        path: `/tmp/test.${invalidFormat}`,
      };
      
      const result = await imageToolHandler(input, mockContext);
      
      // Should succeed with PNG fallback
      expect(result.isError).toBeUndefined();
      
      // Should have logged warning
      expect(loggerWarnSpy).toHaveBeenCalledWith(
        { originalFormat: invalidFormat, fallbackFormat: "png" },
        `Invalid format '${invalidFormat}' detected, falling back to PNG`
      );
      
      // Should call Swift CLI with PNG
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--format", "png"]),
        mockLogger,
        expect.objectContaining({ timeout: expect.any(Number) })
      );
    }
  });
});