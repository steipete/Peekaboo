import { describe, it, expect, beforeEach, vi } from "vitest";
import { pino } from "pino";
import {
  agentToolHandler,
  agentToolSchema,
} from "../../../Server/src/tools/agent";
import { executeSwiftCli } from "../../../Server/src/utils/peekaboo-cli";
import { ToolContext } from "../../../Server/src/types/index";

// Mocks
vi.mock("../../../Server/src/utils/peekaboo-cli");

const mockExecuteSwiftCli = executeSwiftCli as vi.MockedFunction<
  typeof executeSwiftCli
>;

// Create a mock logger for tests
const mockLogger = pino({ level: "silent" });
const mockContext: ToolContext = { logger: mockLogger };

// Agent tests disabled by default to prevent unintended system interactions
// These tests can perform arbitrary actions on your system when run in full mode
describe.skipIf(globalThis.shouldSkipFullTests)("Agent Tool [full]", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // Remove any existing OPENAI_API_KEY mock
    delete process.env.OPENAI_API_KEY;
  });

  describe("agentToolSchema validation", () => {
    it("should validate required task parameter", () => {
      const result = agentToolSchema.safeParse({
        task: "Open Safari and navigate to apple.com"
      });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.task).toBe("Open Safari and navigate to apple.com");
      }
    });

    it("should allow list-sessions without task parameter", () => {
      const result = agentToolSchema.safeParse({
        listSessions: true
      });
      expect(result.success).toBe(true);
    });

    it("should validate optional parameters", () => {
      const result = agentToolSchema.safeParse({
        task: "Test task",
        verbose: true,
        quiet: false,
        dry_run: true,
        max_steps: 10,
        model: "gpt-4-turbo"
      });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.verbose).toBe(true);
        expect(result.data.quiet).toBe(false);
        expect(result.data.dry_run).toBe(true);
        expect(result.data.max_steps).toBe(10);
        expect(result.data.model).toBe("gpt-4-turbo");
      }
    });

    it("should fail with invalid max_steps", () => {
      const result = agentToolSchema.safeParse({
        task: "Test task",
        max_steps: -1
      });
      expect(result.success).toBe(false);
    });

    it("should fail with non-integer max_steps", () => {
      const result = agentToolSchema.safeParse({
        task: "Test task",
        max_steps: 5.5
      });
      expect(result.success).toBe(false);
    });
  });

  describe("agentToolHandler", () => {
    it("should return error when OPENAI_API_KEY is missing", async () => {
      const result = await agentToolHandler(
        { task: "Test task" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("OPENAI_API_KEY or ANTHROPIC_API_KEY environment variable");
      expect(mockExecuteSwiftCli).not.toHaveBeenCalled();
    });

    it("should execute agent task with minimal parameters", async () => {
      process.env.OPENAI_API_KEY = "test-key";
      
      const mockResponse = {
        success: true,
        data: {
          steps: [
            {
              description: "Take screenshot",
              command: "see",
              output: "Screenshot captured"
            }
          ],
          summary: "Task completed successfully",
          success: true
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: JSON.stringify(mockResponse)
      });

      const result = await agentToolHandler(
        { task: "Take a screenshot" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["agent", "Take a screenshot", "--json-output"],
        mockLogger,
        { timeout: 300000 }
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Agent Task Completed");
      expect(result.content[0].text).toContain("Task completed successfully");
    });

    it("should execute agent task with all parameters", async () => {
      process.env.OPENAI_API_KEY = "test-key";
      
      const mockResponse = {
        success: true,
        data: {
          steps: [
            {
              description: "Launch Safari",
              command: "app launch Safari",
              output: "Safari launched"
            },
            {
              description: "Navigate to URL",
              command: "type apple.com",
              output: "Text typed"
            }
          ],
          summary: "Opened Safari and navigated to apple.com",
          success: true
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: JSON.stringify(mockResponse)
      });

      const result = await agentToolHandler(
        {
          task: "Open Safari and go to apple.com",
          verbose: true,
          quiet: false,
          dry_run: false,
          max_steps: 15,
          model: "gpt-4o"
        },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        [
          "agent",
          "Open Safari and go to apple.com",
          "--verbose",
          "--max-steps",
          "15",
          "--model",
          "gpt-4o",
          "--json-output"
        ],
        mockLogger,
        { timeout: 300000 }
      );
      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Agent Task Completed");
      expect(result.content[0].text).toContain("Opened Safari and navigated to apple.com");
      expect(result.content[0].text).toContain("Steps executed (2):");
      expect(result.content[0].text).toContain("1. Launch Safari");
      expect(result.content[0].text).toContain("2. Navigate to URL");
    });

    it("should handle quiet mode flag", async () => {
      process.env.OPENAI_API_KEY = "test-key";
      
      const mockResponse = {
        success: true,
        data: {
          steps: [],
          summary: "Task completed quietly",
          success: true
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: JSON.stringify(mockResponse)
      });

      const result = await agentToolHandler(
        {
          task: "Test task",
          quiet: true
        },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["agent", "Test task", "--quiet", "--json-output"],
        mockLogger,
        { timeout: 300000 }
      );
      expect(result.content[0].text).toContain("Task completed quietly");
    });

    it("should handle dry run flag", async () => {
      process.env.OPENAI_API_KEY = "test-key";
      
      const mockResponse = {
        success: true,
        data: {
          steps: [
            {
              description: "Would take screenshot",
              command: "see --dry-run",
              output: "Dry run - no action taken"
            }
          ],
          summary: "Dry run completed - no actions were taken",
          success: true
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: JSON.stringify(mockResponse)
      });

      const result = await agentToolHandler(
        {
          task: "Take a screenshot",
          dry_run: true
        },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["agent", "Take a screenshot", "--dry-run", "--json-output"],
        mockLogger,
        { timeout: 300000 }
      );
      expect(result.content[0].text).toContain("Dry run completed");
    });

    it("should handle Swift CLI errors", async () => {
      process.env.OPENAI_API_KEY = "test-key";
      
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: {
          message: "OpenAI API key is invalid",
          code: "INVALID_API_KEY"
        }
      });

      const result = await agentToolHandler(
        { task: "Test task" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("❌ Agent command failed");
      expect(result.content[0].text).toContain("OpenAI API key is invalid");
    });

    it("should handle JSON parsing errors from Swift CLI", async () => {
      process.env.OPENAI_API_KEY = "test-key";
      
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: "Invalid JSON response"
      });

      const result = await agentToolHandler(
        { task: "Test task" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("Agent task completed");
      expect(result.content[0].text).toContain("Invalid JSON response");
    });

    it("should handle agent errors in parsed response", async () => {
      process.env.OPENAI_API_KEY = "test-key";
      
      const mockResponse = {
        success: false,
        error: {
          message: "Task execution failed after 3 attempts",
          code: "TASK_EXECUTION_FAILED"
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: JSON.stringify(mockResponse)
      });

      const result = await agentToolHandler(
        { task: "Impossible task" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("❌ Agent Error");
      expect(result.content[0].text).toContain("Task execution failed after 3 attempts");
    });

    it("should handle successful task without summary", async () => {
      process.env.OPENAI_API_KEY = "test-key";
      
      const mockResponse = {
        success: true,
        data: {
          steps: [
            {
              description: "Click button",
              command: "click",
              output: "Button clicked"
            }
          ],
          success: true
          // No summary field
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: JSON.stringify(mockResponse)
      });

      const result = await agentToolHandler(
        { task: "Click a button" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Agent task completed successfully");
    });

    it("should handle verbose mode with steps", async () => {
      process.env.OPENAI_API_KEY = "test-key";
      
      const mockResponse = {
        success: true,
        data: {
          steps: [
            {
              description: "peekaboo_see",
              command: '{"app": "Safari"}',
              output: "Screenshot taken"
            },
            {
              description: "peekaboo_click", 
              command: '{"element": "B1"}',
              output: "Element clicked"
            }
          ],
          summary: "Completed automation workflow",
          success: true
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: JSON.stringify(mockResponse)
      });

      const result = await agentToolHandler(
        {
          task: "Automate workflow",
          verbose: true
        },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("Steps executed (2):");
      expect(result.content[0].text).toContain("1. peekaboo_see");
      expect(result.content[0].text).toContain("2. peekaboo_click");
      expect(result.content[0].text).toContain("→ Screenshot taken");
      expect(result.content[0].text).toContain("→ Element clicked");
    });

    it("should handle unexpected response format", async () => {
      process.env.OPENAI_API_KEY = "test-key";
      
      const mockResponse = {
        unexpected: "format",
        not_success: true
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: JSON.stringify(mockResponse)
      });

      const result = await agentToolHandler(
        { task: "Test task" },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("Agent execution completed with unexpected response format");
      expect(result.content[0].text).toContain('"unexpected":"format"');
    });

    it("should handle execution timeout errors", async () => {
      process.env.OPENAI_API_KEY = "test-key";
      
      mockExecuteSwiftCli.mockRejectedValue(new Error("Command timed out after 300000ms"));

      const result = await agentToolHandler(
        { task: "Very long task" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("❌ Agent execution failed");
    });

    it("should handle OpenAI API key errors specifically", async () => {
      process.env.OPENAI_API_KEY = "test-key";
      
      mockExecuteSwiftCli.mockRejectedValue(new Error("OPENAI_API_KEY is invalid"));

      const result = await agentToolHandler(
        { task: "Test task" },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("❌ OpenAI API key missing or invalid");
    });

    it("should handle non-verbose mode without steps", async () => {
      process.env.OPENAI_API_KEY = "test-key";
      
      const mockResponse = {
        success: true,
        data: {
          steps: [
            {
              description: "Step 1",
              command: "command 1",
              output: "output 1"
            }
          ],
          summary: "Task completed in non-verbose mode",
          success: true
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: JSON.stringify(mockResponse)
      });

      const result = await agentToolHandler(
        {
          task: "Test task",
          verbose: false
        },
        mockContext
      );

      expect(result.isError).toBe(false);
      expect(result.content[0].text).toContain("✅ Agent Task Completed");
      expect(result.content[0].text).toContain("Task completed in non-verbose mode");
      expect(result.content[0].text).not.toContain("Steps executed");
    });

    it("should pass correct timeout to executeSwiftCli", async () => {
      process.env.OPENAI_API_KEY = "test-key";
      
      const mockResponse = {
        success: true,
        data: {
          steps: [],
          summary: "Quick task",
          success: true
        }
      };

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: JSON.stringify(mockResponse)
      });

      await agentToolHandler(
        { task: "Quick task" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["agent", "Quick task", "--json-output"],
        mockLogger,
        { timeout: 300000 } // 5 minute timeout
      );
    });
  });
});