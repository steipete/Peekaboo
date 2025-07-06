import {
  ToolContext,
  ToolResponse,
} from "../types/index.js";
import { z } from "zod";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";

export const typeToolSchema = z.object({
  text: z.string().describe(
    "The text to type. Supports special keys like {return}, {tab}, {escape}, {delete}."
  ),
  on: z.string().optional().describe(
    "Optional. Element ID to type into (e.g., T1, T2) from see command output. " +
    "If not specified, types at current keyboard focus."
  ),
  session: z.string().optional().describe(
    "Optional. Session ID from see command. Uses latest session if not specified."
  ),
  clear: z.boolean().optional().default(false).describe(
    "Optional. Clear existing text before typing (select all + delete)."
  ),
  delay: z.number().optional().default(50).describe(
    "Optional. Delay between keystrokes in milliseconds. Default: 50."
  ),
  wait_for: z.number().optional().default(5000).describe(
    "Optional. Maximum milliseconds to wait for element to become actionable (if 'on' is specified). Default: 5000."
  ),
}).describe(
  "Types text into UI elements or at current focus. " +
  "Supports special keys and configurable typing speed. " +
  "Can target specific elements from see command or type at current focus. " +
  "Includes smart waiting for elements to become actionable."
);

interface TypeResult {
  success: boolean;
  typed_text: string;
  target_element?: string;
  characters_typed: number;
  execution_time: number;
}

export type TypeInput = z.infer<typeof typeToolSchema>;

export async function typeToolHandler(
  input: TypeInput,
  context: ToolContext,
): Promise<ToolResponse> {
  const { logger } = context;

  try {
    logger.debug({ input }, "Processing peekaboo.type tool call");

    // Build command arguments
    const args = ["type", input.text];
    
    // Target element
    if (input.on) {
      args.push("--on", input.on);
    }
    
    // Session
    if (input.session) {
      args.push("--session", input.session);
    }
    
    // Clear existing text
    if (input.clear) {
      args.push("--clear");
    }
    
    // Typing delay
    const delay = input.delay ?? 50;
    args.push("--delay", delay.toString());
    
    // Wait timeout (only used if 'on' is specified)
    if (input.on) {
      const waitFor = input.wait_for ?? 5000;
      args.push("--wait-for", waitFor.toString());
    }
    
    args.push("--json-output");

    // Execute the command
    const result = await executeSwiftCli(args, logger);

    if (!result.success || !result.data) {
      const errorMessage = result.error?.message || "Type command failed";
      logger.error({ result }, errorMessage);
      
      return {
        content: [{
          type: "text",
          text: `Failed to type text: ${errorMessage}`,
        }],
        isError: true,
      };
    }

    const typeData = result.data as TypeResult;

    // Build response text
    const lines: string[] = [];
    lines.push("✅ Text typed successfully");
    
    if (typeData.target_element) {
      lines.push(`🎯 Target: ${typeData.target_element}`);
    }
    
    lines.push(`⌨️  Characters: ${typeData.characters_typed}`);
    
    // Show a preview of what was typed (truncate if too long)
    const preview = typeData.typed_text.length > 50 
      ? typeData.typed_text.substring(0, 47) + "..."
      : typeData.typed_text;
    lines.push(`📝 Text: "${preview}"`);
    
    lines.push(`⏱️  Completed in ${typeData.execution_time.toFixed(2)}s`);

    return {
      content: [{
        type: "text",
        text: lines.join("\n"),
      }],
    };

  } catch (error) {
    logger.error({ error }, "Type tool execution failed");
    
    return {
      content: [{
        type: "text",
        text: `Tool execution failed: ${error instanceof Error ? error.message : String(error)}`,
      }],
      isError: true,
    };
  }
}