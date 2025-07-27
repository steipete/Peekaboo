import {
  ToolContext,
  ToolResponse,
} from "../types/index.js";
import { z } from "zod";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";

export const typeToolSchema = z.object({
  text: z.string().optional().describe(
    "The text to type. If not specified, can use special key flags instead.",
  ),
  on: z.string().optional().describe(
    "Optional. Element ID to type into (from see command). If not specified, types at current focus.",
  ),
  session: z.string().optional().describe(
    "Optional. Session ID from see command. Uses latest session if not specified.",
  ),
  delay: z.number().optional().default(5).describe(
    "Optional. Delay between keystrokes in milliseconds. Default: 5.",
  ),
  press_return: z.boolean().optional().default(false).describe(
    "Optional. Press return/enter after typing.",
  ),
  tab: z.number().optional().describe(
    "Optional. Press tab N times.",
  ),
  escape: z.boolean().optional().default(false).describe(
    "Optional. Press escape key.",
  ),
  delete: z.boolean().optional().default(false).describe(
    "Optional. Press delete/backspace key.",
  ),
  clear: z.boolean().optional().default(false).describe(
    "Optional. Clear the field before typing (Cmd+A, Delete).",
  ),
}).describe(
  "Types text or sends special keys. " +
  "Can type text, press special keys, or combine both actions. " +
  "Types at current keyboard focus.",
);

interface TypeResult {
  success: boolean;
  text_typed?: string;
  keys_pressed: number;
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
    const args = ["type"];

    // Add text if provided
    if (input.text) {
      args.push(input.text);
    }

    // Session
    if (input.session) {
      args.push("--session", input.session);
    }

    // Element target
    if (input.on) {
      args.push("--on", input.on);
    }

    // Delay
    const delay = input.delay ?? 5;
    args.push("--delay", delay.toString());

    // Press return flag
    if (input.press_return) {
      args.push("--press-return");
    }

    // Tab count
    if (input.tab) {
      args.push("--tab", input.tab.toString());
    }

    // Escape flag
    if (input.escape) {
      args.push("--escape");
    }

    // Delete flag
    if (input.delete) {
      args.push("--delete");
    }

    // Clear flag
    if (input.clear) {
      args.push("--clear");
    }

    // Always request JSON output for parsing
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
    lines.push("✅ Typing completed successfully");

    if (typeData.text_typed) {
      // Show a preview of what was typed (truncate if too long)
      const preview = typeData.text_typed.length > 50
        ? typeData.text_typed.substring(0, 47) + "..."
        : typeData.text_typed;
      lines.push(`📝 Text: "${preview}"`);
    }

    lines.push(`⌨️  Key presses: ${typeData.keys_pressed}`);
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