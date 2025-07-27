import { describe, it, expect, vi, beforeEach } from "vitest";
import { runToolHandler, runToolSchema } from "../../../Server/src/tools/run";
import type { ToolContext } from "../../../Server/src/types/index";
import * as peekabooCliModule from "../../../Server/src/utils/peekaboo-cli";
import * as fs from "fs/promises";

vi.mock("../../../Server/src/utils/peekaboo-cli");
vi.mock("fs/promises");

describe("run tool", () => {
  let mockContext: ToolContext;
  let mockExecuteSwiftCli: ReturnType<typeof vi.fn>;
  let mockReadFile: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    vi.clearAllMocks();
    
    mockContext = {
      logger: {
        debug: vi.fn(),
        info: vi.fn(),
        warn: vi.fn(),
        error: vi.fn(),
      } as any,
    };

    mockExecuteSwiftCli = vi.fn();
    mockReadFile = vi.fn();

    vi.mocked(peekabooCliModule).executeSwiftCli = mockExecuteSwiftCli;
    vi.mocked(fs).readFile = mockReadFile;
  });

  describe("schema validation", () => {
    it("should require script_path parameter", () => {
      const input = {};
      const result = runToolSchema.safeParse(input);
      expect(result.success).toBe(false);
    });

    it("should accept minimal valid input", () => {
      const input = {
        script_path: "/path/to/script.peekaboo.json",
      };
      const result = runToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.no_fail_fast).toBe(false); // default
        expect(result.data.verbose).toBe(false); // default
      }
    });

    it("should accept all valid parameters", () => {
      const input = {
        script_path: "/tmp/automation.peekaboo.json",
        output: "/tmp/output.json",
        no_fail_fast: true,
        verbose: true,
      };
      const result = runToolSchema.safeParse(input);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data).toEqual(input);
      }
    });
  });

  describe("tool handler", () => {
    it("should run script successfully", async () => {
      const input = {
        script_path: "/tmp/test.peekaboo.json",
      };

      const scriptContent = JSON.stringify({
        name: "Test Script",
        description: "A test automation script",
        commands: [
          { command: "see", args: ["--app", "Safari"] },
          { command: "click", args: ["Login"] },
          { command: "type", args: ["user@example.com"] },
        ],
      });

      mockReadFile.mockResolvedValue(scriptContent);

      const mockRunResult = {
        success: true,
        data: {
          success: true,
          scriptPath: "/tmp/test.peekaboo.json",
          totalSteps: 3,
          completedSteps: 3,
          failedSteps: 0,
          executionTime: 5.5,
          steps: [],
        },
      };

      mockExecuteSwiftCli.mockResolvedValue(mockRunResult);

      const result = await runToolHandler(input, mockContext);

      expect(mockReadFile).toHaveBeenCalledWith("/tmp/test.peekaboo.json", "utf-8");
      expect(mockContext.logger.info).toHaveBeenCalledWith(
        { scriptName: "Test Script", commandCount: 3 },
        "Loaded Peekaboo script"
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["run", "/tmp/test.peekaboo.json", "--json-output"],
        mockContext.logger
      );

      expect(result.isError).toBeFalsy();
      expect(result.content[0].type).toBe("text");
      expect(result.content[0].text).toContain("✅ Script executed successfully");
      expect(result.content[0].text).toContain("📄 Script: /tmp/test.peekaboo.json");
      expect(result.content[0].text).toContain("🔢 Total steps: 3");
      expect(result.content[0].text).toContain("✅ Completed: 3");
      expect(result.content[0].text).toContain("❌ Failed: 0");
      expect(result.content[0].text).toContain("⏱️  Total time: 5.50s");
    });

    it("should handle partial script execution with errors", async () => {
      const input = {
        script_path: "/tmp/failing.peekaboo.json",
      };

      const scriptContent = JSON.stringify({
        name: "Failing Script",
        commands: [
          { command: "see" },
          { command: "click", args: ["NonExistent"] },
          { command: "type", args: ["test"] },
        ],
      });

      mockReadFile.mockResolvedValue(scriptContent);

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: false,
          scriptPath: "/tmp/failing.peekaboo.json",
          totalSteps: 3,
          completedSteps: 1,
          failedSteps: 2,
          executionTime: 2.5,
          steps: [
            { stepNumber: 1, command: "see", success: true },
            { stepNumber: 2, command: "click", success: false, error: "Element not found" },
            { stepNumber: 3, command: "type", success: false, error: "Previous command failed" },
          ],
        },
      });

      const result = await runToolHandler(input, mockContext);

      expect(result.content[0].text).toContain("❌ Script execution failed");
      expect(result.content[0].text).toContain("📄 Script: /tmp/failing.peekaboo.json");
      expect(result.content[0].text).toContain("🔢 Total steps: 3");
      expect(result.content[0].text).toContain("✅ Completed: 1");
      expect(result.content[0].text).toContain("❌ Failed: 2");
      expect(result.content[0].text).toContain("⏱️  Total time: 2.50s");
      expect(result.content[0].text).toContain("Step 2 (click)");
      expect(result.content[0].text).toContain("Element not found");
    });

    it("should continue on error when specified", async () => {
      const input: RunInput = {
        script_path: "/tmp/script.peekaboo.json",
        stop_on_error: false,
      };

      mockReadFile.mockResolvedValue(JSON.stringify({
        commands: [{ command: "see" }],
      }));

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          script_path: "/tmp/script.peekaboo.json",
          commands_executed: 1,
          total_commands: 1,
          session_id: "auto-123",
          execution_time: 1.0,
        },
      });

      await runToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--continue-on-error"]),
        mockContext.logger
      );
    });

    it("should handle custom timeout", async () => {
      const input = {
        script_path: "/tmp/script.peekaboo.json",
        verbose: true,
      };

      mockReadFile.mockResolvedValue(JSON.stringify({
        commands: [{ command: "see" }],
      }));

      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          success: true,
          scriptPath: "/tmp/script.peekaboo.json",
          totalSteps: 1,
          completedSteps: 1,
          failedSteps: 0,
          executionTime: 1.0,
          steps: [{ stepNumber: 1, command: "see", success: true }],
        },
      });

      await runToolHandler(input, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(["--verbose"]),
        mockContext.logger
      );
    });

    it("should handle invalid script file", async () => {
      const input = {
        script_path: "/tmp/invalid.peekaboo.json",
      };

      mockReadFile.mockRejectedValue(new Error("ENOENT: no such file or directory"));

      const result = await runToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Failed to load script");
      expect(result.content[0].text).toContain("ENOENT: no such file or directory");
    });

    it("should handle invalid JSON in script", async () => {
      const input: RunInput = {
        script_path: "/tmp/malformed.peekaboo.json",
      };

      mockReadFile.mockResolvedValue("{ invalid json");

      const result = await runToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Failed to load script");
    });

    it("should handle script without commands array", async () => {
      const input: RunInput = {
        script_path: "/tmp/empty.peekaboo.json",
      };

      mockReadFile.mockResolvedValue(JSON.stringify({
        name: "Empty Script",
      }));

      const result = await runToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Failed to load script");
      expect(result.content[0].text).toContain("Script must contain a 'commands' array");
    });

    it("should handle exceptions gracefully", async () => {
      const input: RunInput = {
        script_path: "/tmp/script.peekaboo.json",
      };

      mockReadFile.mockResolvedValue(JSON.stringify({
        commands: [{ command: "see" }],
      }));

      mockExecuteSwiftCli.mockRejectedValue(new Error("Script execution failed"));

      const result = await runToolHandler(input, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Tool execution failed: Script execution failed");
    });
  });
});