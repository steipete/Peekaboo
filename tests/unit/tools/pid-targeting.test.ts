import { describe, it, expect, beforeEach, vi } from "vitest";
import { imageToolHandler } from "../../../Server/src/tools/image";
import * as peekabooCliModule from "../../../Server/src/utils/peekaboo-cli";
import type { SwiftCliResponse } from "../../../Server/src/types";
import type { ToolContext } from "@modelcontextprotocol/sdk/types";
import pino from "pino";

// Mock the peekaboo-cli module
vi.mock("../../../Server/src/utils/peekaboo-cli");

// Create a mock context
const mockContext: ToolContext = {
  logger: pino({ level: "silent" }),
};

describe("PID Targeting Tests", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("should handle PID targeting correctly", async () => {
    const mockResponse: SwiftCliResponse = {
      success: true,
      data: {
        saved_files: [
          {
            path: "/tmp/test_PID_663.png",
            item_label: "Ghostty",
            mime_type: "image/png",
          },
        ],
      },
    };

    vi.mocked(peekabooCliModule.executeSwiftCli).mockResolvedValue(mockResponse);

    const result = await imageToolHandler(
      {
        app_target: "PID:663",
        path: "/tmp/test.png",
      },
      mockContext,
    );

    expect(result.content).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          type: "text",
          text: expect.stringContaining("Captured 1 image"),
        }),
      ]),
    );
    expect(result.saved_files).toHaveLength(1);
    expect(result.saved_files![0].path).toBe("/tmp/test_PID_663.png");
  });

  it("should handle invalid PID format", async () => {
    const mockResponse: SwiftCliResponse = {
      success: false,
      error: {
        code: "APP_NOT_FOUND",
        message: "Invalid PID format: PID:abc",
      },
    };

    vi.mocked(peekabooCliModule.executeSwiftCli).mockResolvedValue(mockResponse);

    const result = await imageToolHandler(
      {
        app_target: "PID:abc",
      },
      mockContext,
    );

    expect(result.isError).toBe(true);
    expect(result.content[0]).toMatchObject({
      type: "text",
      text: expect.stringContaining("Invalid PID format"),
    });
  });

  it("should handle non-existent PID", async () => {
    const mockResponse: SwiftCliResponse = {
      success: false,
      error: {
        code: "APP_NOT_FOUND",
        message: "No application found with PID: 99999",
      },
    };

    vi.mocked(peekabooCliModule.executeSwiftCli).mockResolvedValue(mockResponse);

    const result = await imageToolHandler(
      {
        app_target: "PID:99999",
      },
      mockContext,
    );

    expect(result.isError).toBe(true);
    expect(result.content[0]).toMatchObject({
      type: "text",
      text: expect.stringContaining("No application found with PID"),
    });
  });

  it("should pass PID targeting to Swift CLI correctly", async () => {
    const mockResponse: SwiftCliResponse = {
      success: true,
      data: {
        images: [
          {
            path: "/tmp/test.png",
            item_label: "Some App",
            mime_type: "image/png",
          },
        ],
      },
    };

    vi.mocked(peekabooCliModule.executeSwiftCli).mockResolvedValue(mockResponse);

    await imageToolHandler(
      {
        app_target: "PID:1234",
        path: "/tmp/test.png",
      },
      mockContext,
    );

    // Verify the Swift CLI was called with the PID target
    expect(peekabooCliModule.executeSwiftCli).toHaveBeenCalledWith(
      expect.arrayContaining(["image", "--app", "PID:1234"]),
      expect.anything(),
      expect.anything(),
    );
  });
});