import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { zodToJsonSchema } from "../../src/utils/zod-to-json-schema";
import { execSync } from "child_process";
import { join } from "path";
import { existsSync, mkdirSync, rmSync } from "fs";
import { vi } from "vitest";
import { pino } from "pino";

// Mock for a skipped test suite. This aims to be simple and avoid hoisting issues.
vi.mock("../../src/utils/peekaboo-cli", () => ({
  executeSwiftCli: vi
    .fn()
    .mockResolvedValue({
      success: true,
      data: { message: "Mocked Swift CLI for skipped tests" },
    }),
  readImageAsBase64: vi.fn().mockResolvedValue("base64-test-data"),
  initializeSwiftCliPath: vi.fn(), // Mock initializeSwiftCliPath as well if it's called
}));

// Import the actual server components
import { imageToolHandler } from "../../src/tools/image";
import { listToolHandler } from "../../src/tools/list";
import { analyzeToolHandler } from "../../src/tools/analyze";

describe.skip("MCP Server Real Integration Tests", () => {
  const mockLogger = pino({ level: "silent" });
  const mockContext = { logger: mockLogger };
  const testDir = "/tmp/peekaboo-test";

  let mockedExecuteSwiftCli: vi.MockInstance;

  beforeAll(async () => {
    if (!existsSync(testDir)) {
      mkdirSync(testDir, { recursive: true });
    }
    // We need to import the mocked module to get a reference to the vi.fn() instance
    const peekabooCliUtils = await import("../../src/utils/peekaboo-cli");
    mockedExecuteSwiftCli =
      peekabooCliUtils.executeSwiftCli as unknown as vi.MockInstance;
    // peekabooCliUtils.initializeSwiftCliPath(); // Call the mocked version if needed by the test setup
  });

  afterAll(() => {
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true, force: true });
    }
  });

  beforeEach(() => {
    vi.clearAllMocks();
    // Default mock for the tests if they were to run
    mockedExecuteSwiftCli.mockResolvedValue({
      success: true,
      data: { message: "Default beforeEach mock" },
    });
  });

  // afterEach is removed as direct restoration of originalExecuteSwiftCli
  // via mockImplementation is complex with vi.mock factory pattern.
  // Mock behavior is controlled per test or in beforeEach.

  describe("Image Tool Real Execution", () => {
    it("should capture screen with all parameters", async () => {
      const result = await imageToolHandler(
        {
          format: "png",
          return_data: false,
          capture_focus: "background",
        },
        mockContext,
      );

      expect(result.content).toHaveLength(1);
      expect(result.content[0].type).toBe("text");
      expect(result.content[0].text).toContain("Captured 1 image");
      expect(result.saved_files).toBeDefined();
      if (result.saved_files) {
        expect(result.saved_files).toHaveLength(1);
        expect(result.saved_files[0].path).toContain(".png");
        expect(result.saved_files[0].mime_type).toBe("image/png");
      }
    });

    it("should capture with different formats", async () => {
      const formats: Array<"png" | "jpg"> = ["png", "jpg"];

      for (const format of formats) {
        const result = await imageToolHandler(
          {
            format,
            return_data: false,
            capture_focus: "foreground",
          },
          mockContext,
        );

        expect(result.content[0].text).toContain("Captured 1 image");
        if (result.saved_files) {
          expect(result.saved_files[0].path).toContain(`.${format}`);
          expect(result.saved_files[0].mime_type).toBe(
            `image/${format === "jpg" ? "jpeg" : format}`,
          );
        }
      }
    });

    it("should handle window capture by window specifier index", async () => {
      const result = await imageToolHandler(
        {
          app: "Safari",
          window_specifier: { index: 0 },
          format: "png",
          return_data: false,
          capture_focus: "background",
        },
        mockContext,
      );

      expect(result.content[0].text).toContain("Captured 1 image");
      expect(result.content[0].text).toContain("window mode");
    });

    it("should handle application capture by bundle ID", async () => {
      const result = await imageToolHandler(
        {
          app: "com.apple.Safari",
          format: "png",
          return_data: false,
          capture_focus: "background",
        },
        mockContext,
      );

      expect(result.content[0].text).toContain("Captured 1 image");
      expect(result.content[0].text).toContain("application mode");
    });

    it("should handle all capture modes", async () => {
      // Test screen mode
      const screenResult = await imageToolHandler(
        {
          mode: "screen",
          format: "png",
          return_data: false,
          capture_focus: "background",
        },
        mockContext,
      );
      expect(screenResult.content[0].text).toContain("screen mode");

      // Test window mode
      const windowResult = await imageToolHandler(
        {
          app: "Safari",
          mode: "window",
          format: "png",
          return_data: false,
          capture_focus: "background",
        },
        mockContext,
      );
      expect(windowResult.content[0].text).toContain("window mode");

      // Test multi mode
      const multiResult = await imageToolHandler(
        {
          app: "Safari",
          mode: "multi",
          format: "png",
          return_data: false,
          capture_focus: "background",
        },
        mockContext,
      );
      expect(multiResult.content[0].text).toContain("multi mode");
    });
  });

  describe("List Tool Real Execution", () => {
    it("should list running applications with details", async () => {
      const result = await listToolHandler(
        {
          item_type: "running_applications",
        },
        mockContext,
      );

      expect(result.content[0].text).toContain("Found 2 running applications");
      expect(result.content[0].text).toContain("Safari");
      expect(result.content[0].text).toContain("com.apple.Safari");
      expect(result.content[0].text).toContain("[ACTIVE]");
      expect(result.content[0].text).toContain("Windows: 2");
      expect((result as any).application_list).toHaveLength(2);
    });

    it("should list application windows", async () => {
      const result = await listToolHandler(
        {
          item_type: "application_windows",
          app: "Safari",
        },
        mockContext,
      );

      expect(result.content[0].text).toContain("Found 1 window");
      expect(result.content[0].text).toContain("Safari - Main Window");
      expect(result.content[0].text).toContain("ID: 12345");
      expect((result as any).window_list).toHaveLength(1);
      expect((result as any).target_application_info).toBeDefined();
    });

    it("should handle missing app parameter for windows", async () => {
      const result = await listToolHandler(
        {
          item_type: "application_windows",
        },
        mockContext,
      );

      expect((result as any).isError).toBe(true);
      expect(result.content[0].text).toContain("'app' identifier is required");
    });

    // Note: Invalid item_type test removed because Zod validation prevents invalid types from reaching the handler
  });

  describe("Analyze Tool Real Execution", () => {
    beforeEach(() => {
      // Create a test image file
      const imagePath = join(testDir, "analyze-test.png");
      execSync(`touch "${imagePath}"`);
    });

    it("should handle missing AI provider configuration", async () => {
      delete process.env.PEEKABOO_AI_PROVIDERS;

      const result = await analyzeToolHandler(
        {
          image_path: join(testDir, "analyze-test.png"),
          question: "What do you see?",
        },
        mockContext,
      );

      expect((result as any).isError).toBe(true);
      expect(result.content[0].text).toContain("AI analysis not configured");
    });

    it("should validate image file existence", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";

      const result = await analyzeToolHandler(
        {
          image_path: "/non/existent/image.png",
          question: "What do you see?",
        },
        mockContext,
      );

      expect((result as any).isError).toBe(true);
      expect(result.content[0].text).toContain("Failed to read image file");
    });

    it("should handle invalid file extensions", async () => {
      process.env.PEEKABOO_AI_PROVIDERS = "ollama/llava";
      const invalidPath = join(testDir, "test.txt");
      execSync(`touch "${invalidPath}"`);

      const result = await analyzeToolHandler(
        {
          image_path: invalidPath,
          question: "What do you see?",
        },
        mockContext,
      );

      expect((result as any).isError).toBe(true);
      expect(result.content[0].text).toContain("Unsupported image format");
    });
  });

  describe("Tool Schema Generation", () => {
    it("should generate correct JSON schema for image tool", () => {
      const imageSchema = z.object({
        format: z
          .enum(["png", "jpg", "gif", "tiff", "pdf", "bmp"])
          .optional()
          .default("png")
          .describe("The image format to capture"),
        app: z
          .string()
          .optional()
          .describe("Application name or bundle ID to capture"),
        window_id: z.number().optional().describe("Window ID to capture"),
        return_data: z
          .boolean()
          .optional()
          .default(false)
          .describe("Whether to return base64 image data"),
        capture_focus: z
          .enum(["foreground", "background"])
          .optional()
          .default("foreground")
          .describe("Whether to focus the app before capture"),
      });

      const jsonSchema = zodToJsonSchema(imageSchema);

      expect(jsonSchema.type).toBe("object");
      expect(jsonSchema.properties.format.type).toBe("string");
      expect(jsonSchema.properties.format.enum).toEqual([
        "png",
        "jpg",
        "gif",
        "tiff",
        "pdf",
        "bmp",
      ]);
      expect(jsonSchema.properties.format.default).toBe("png");
      expect(jsonSchema.properties.window_id.type).toBe("number");
      expect(jsonSchema.properties.return_data.type).toBe("boolean");
      expect(jsonSchema.properties.return_data.default).toBe(false);
    });

    it("should generate correct JSON schema for list tool", () => {
      const listSchema = z.object({
        item_type: z
          .enum(["running_applications", "application_windows"])
          .describe("What to list"),
        app: z
          .string()
          .optional()
          .describe("Application identifier when listing windows"),
      });

      const jsonSchema = zodToJsonSchema(listSchema);

      expect(jsonSchema.type).toBe("object");
      expect(jsonSchema.properties.item_type.type).toBe("string");
      expect(jsonSchema.properties.item_type.enum).toEqual([
        "running_applications",
        "application_windows",
      ]);
      expect(jsonSchema.properties.app.type).toBe("string");
      expect(jsonSchema.required).toEqual(["item_type"]);
    });

    it("should generate correct JSON schema for analyze tool", () => {
      const analyzeSchema = z.object({
        image_path: z.string().describe("Path to the image file to analyze"),
        question: z
          .string()
          .optional()
          .default("Describe what you see in this image.")
          .describe("Question to ask about the image"),
        ai_provider: z
          .string()
          .optional()
          .describe("Override the default AI provider"),
      });

      const jsonSchema = zodToJsonSchema(analyzeSchema);

      expect(jsonSchema.type).toBe("object");
      expect(jsonSchema.properties.image_path.type).toBe("string");
      expect(jsonSchema.properties.question.type).toBe("string");
      expect(jsonSchema.properties.question.default).toBe(
        "Describe what you see in this image.",
      );
      expect(jsonSchema.properties.ai_provider.type).toBe("string");
      expect(jsonSchema.required).toEqual(["image_path"]);
    });
  });

  describe("Error Recovery and Edge Cases", () => {
    it("should handle Swift CLI timeout gracefully", async () => {
      const { executeSwiftCli } = require("../../src/utils/peekaboo-cli");
      executeSwiftCli.mockImplementationOnce(() => {
        throw new Error("Command timed out");
      });

      const result = await imageToolHandler(
        {
          format: "png",
          return_data: false,
          capture_focus: "background",
        },
        mockContext,
      );

      expect((result as any).isError).toBe(true);
      expect(result.content[0].text).toContain(
        "Unexpected error: Command timed out",
      );
    });

    it("should handle malformed Swift CLI output", async () => {
      const { executeSwiftCli } = require("../../src/utils/peekaboo-cli");
      executeSwiftCli.mockImplementationOnce(() => {
        return { success: true, data: null };
      });

      const result = await listToolHandler(
        {
          item_type: "running_applications",
        },
        mockContext,
      );

      expect((result as any).isError).toBe(true);
      expect(result.content[0].text).toContain("List operation failed");
    });

    it("should handle concurrent tool execution", async () => {
      const promises = [
        imageToolHandler(
          { format: "png", return_data: false, capture_focus: "background" },
          mockContext,
        ),
        listToolHandler({ item_type: "running_applications" }, mockContext),
        imageToolHandler(
          { format: "jpg", return_data: false, capture_focus: "background" },
          mockContext,
        ),
      ];

      const results = await Promise.all(promises);

      expect(results).toHaveLength(3);
      expect(results[0].content[0].text).toContain("Captured 1 image");
      expect(results[1].content[0].text).toContain(
        "Found 2 running applications",
      );
      expect(results[2].content[0].text).toContain("Captured 1 image");
    });
  });
});
