import {
  ToolContext,
  ToolResponse,
} from "../types/index.js";
import { z } from "zod";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";
import * as fs from "fs/promises";

export const runToolSchema = z.object({
  script_path: z.string().describe(
    "Path to .peekaboo.json script file containing automation commands.",
  ),
  output: z.string().optional().describe(
    "Optional. Save results to file instead of stdout.",
  ),
  no_fail_fast: z.boolean().optional().default(false).describe(
    "Optional. Continue execution even if a step fails. Default: false.",
  ),
  verbose: z.boolean().optional().default(false).describe(
    "Optional. Show detailed step execution. Default: false.",
  ),
}).describe(
  "Runs a batch script of Peekaboo commands from a .peekaboo.json file. " +
  "Scripts can automate complex UI workflows by chaining see, click, type, and other commands. " +
  "Each command in the script runs sequentially.",
);

interface RunResult {
  success: boolean;
  scriptPath: string;
  description?: string;
  totalSteps: number;
  completedSteps: number;
  failedSteps: number;
  executionTime: number;
  steps: Array<{
    stepNumber: number;
    command: string;
    success: boolean;
    error?: string;
  }>;
}

interface PeekabooScript {
  name?: string;
  description?: string;
  commands: Array<{
    command: string;
    args?: string[];
    comment?: string;
  }>;
}

export type RunInput = z.infer<typeof runToolSchema>;

export async function runToolHandler(
  input: RunInput,
  context: ToolContext,
): Promise<ToolResponse> {
  const { logger } = context;

  try {
    logger.debug({ input }, "Processing peekaboo.run tool call");

    // Validate script file exists and is readable
    try {
      const scriptContent = await fs.readFile(input.script_path, "utf-8");
      const script: PeekabooScript = JSON.parse(scriptContent);

      if (!script.commands || !Array.isArray(script.commands)) {
        throw new Error("Script must contain a 'commands' array");
      }

      logger.info({
        scriptName: script.name,
        commandCount: script.commands.length,
      }, "Loaded Peekaboo script");

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      return {
        content: [{
          type: "text",
          text: `Failed to load script: ${errorMessage}`,
        }],
        isError: true,
      };
    }

    // Build command arguments
    const args = ["run", input.script_path];

    // Output file
    if (input.output) {
      args.push("--output", input.output);
    }

    // No fail fast flag
    if (input.no_fail_fast) {
      args.push("--no-fail-fast");
    }

    // Verbose flag
    if (input.verbose) {
      args.push("--verbose");
    }

    // Always request JSON output for parsing
    args.push("--json-output");

    // Execute the command
    const result = await executeSwiftCli(args, logger);

    if (!result.data) {
      const errorMessage = result.error?.message || "Run command failed";
      logger.error({ result }, errorMessage);

      return {
        content: [{
          type: "text",
          text: `Failed to execute script: ${errorMessage}`,
        }],
        isError: true,
      };
    }

    const runData = result.data as RunResult;

    // Build response text
    const lines: string[] = [];

    if (runData.success) {
      lines.push("✅ Script executed successfully");
    } else {
      lines.push("❌ Script execution failed");
    }

    lines.push(`📄 Script: ${runData.scriptPath}`);
    if (runData.description) {
      lines.push(`📝 Description: ${runData.description}`);
    }
    lines.push(`🔢 Total steps: ${runData.totalSteps}`);
    lines.push(`✅ Completed: ${runData.completedSteps}`);
    lines.push(`❌ Failed: ${runData.failedSteps}`);
    lines.push(`⏱️  Total time: ${runData.executionTime.toFixed(2)}s`);

    // Show failed steps
    const failedSteps = runData.steps.filter(step => !step.success);
    if (failedSteps.length > 0) {
      lines.push("\n❌ Failed steps:");
      failedSteps.forEach(step => {
        lines.push(`  - Step ${step.stepNumber} (${step.command}): ${step.error || "Unknown error"}`);
      });
    }

    return {
      content: [{
        type: "text",
        text: lines.join("\n"),
      }],
      _meta: {
        script_path: runData.scriptPath,
        completed_steps: runData.completedSteps,
        total_steps: runData.totalSteps,
        success: runData.success,
      },
    };

  } catch (error) {
    logger.error({ error }, "Run tool execution failed");

    return {
      content: [{
        type: "text",
        text: `Tool execution failed: ${error instanceof Error ? error.message : String(error)}`,
      }],
      isError: true,
    };
  }
}