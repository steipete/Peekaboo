import {
  ToolContext,
  ToolResponse,
} from "../types/index.js";
import { z } from "zod";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";
import * as fs from "fs/promises";

export const runToolSchema = z.object({
  script_path: z.string().describe(
    "Path to .peekaboo.json script file containing automation commands."
  ),
  session: z.string().optional().describe(
    "Optional. Session ID to use for the script execution. Creates new session if not specified."
  ),
  stop_on_error: z.boolean().optional().default(true).describe(
    "Optional. Stop execution if any command fails. Default: true."
  ),
  timeout: z.number().optional().default(300000).describe(
    "Optional. Maximum execution time in milliseconds. Default: 300000 (5 minutes)."
  ),
}).describe(
  "Runs a batch script of Peekaboo commands from a .peekaboo.json file. " +
  "Scripts can automate complex UI workflows by chaining see, click, type, and other commands. " +
  "Each command in the script runs sequentially with shared session state."
);

interface RunResult {
  success: boolean;
  script_path: string;
  commands_executed: number;
  total_commands: number;
  session_id: string;
  execution_time: number;
  errors?: string[];
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
        commandCount: script.commands.length 
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
    
    // Session
    if (input.session) {
      args.push("--session", input.session);
    }
    
    // Stop on error
    if (!input.stop_on_error) {
      args.push("--continue-on-error");
    }
    
    // Timeout
    args.push("--timeout", input.timeout.toString());
    
    args.push("--json-output");

    // Execute the command
    const result = await executeSwiftCli(args, logger);

    if (!result.success || !result.data) {
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
    
    lines.push(`📄 Script: ${runData.script_path}`);
    lines.push(`🔢 Commands executed: ${runData.commands_executed}/${runData.total_commands}`);
    lines.push(`🔖 Session ID: ${runData.session_id}`);
    lines.push(`⏱️  Total time: ${(runData.execution_time / 1000).toFixed(2)}s`);
    
    if (runData.errors && runData.errors.length > 0) {
      lines.push("\n❌ Errors:");
      runData.errors.forEach((error, index) => {
        lines.push(`  ${index + 1}. ${error}`);
      });
    }

    return {
      content: [{
        type: "text",
        text: lines.join("\n"),
      }],
      _meta: {
        session_id: runData.session_id,
        commands_executed: runData.commands_executed,
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