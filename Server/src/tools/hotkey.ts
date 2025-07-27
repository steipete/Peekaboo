import {
  ToolContext,
  ToolResponse,
} from "../types/index.js";
import { z } from "zod";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";

export const hotkeyToolSchema = z.object({
  keys: z.string().describe(
    "Comma-separated list of keys to press (e.g., 'cmd,c' for copy, 'cmd,shift,t' for reopen tab). " +
    "Supported keys: cmd, shift, alt/option, ctrl, fn, a-z, 0-9, space, return, tab, escape, delete, " +
    "arrow_up, arrow_down, arrow_left, arrow_right, f1-f12.",
  ),
  hold_duration: z.number().optional().default(50).describe(
    "Optional. Delay between key press and release in milliseconds. Default: 50.",
  ),
}).describe(
  "Presses keyboard shortcuts and key combinations. " +
  "Simulates pressing multiple keys simultaneously like Cmd+C or Ctrl+Shift+T. " +
  "Keys are pressed in order and released in reverse order.",
);

interface HotkeyResult {
  success: boolean;
  keys: string[];
  key_count: number;
  execution_time: number;
}

export type HotkeyInput = z.infer<typeof hotkeyToolSchema>;

export async function hotkeyToolHandler(
  input: HotkeyInput,
  context: ToolContext,
): Promise<ToolResponse> {
  const { logger } = context;

  try {
    logger.debug({ input }, "Processing peekaboo.hotkey tool call");

    // Build command arguments
    const args = ["hotkey"];

    // Keys
    args.push("--keys", input.keys);

    // Hold duration
    const holdDuration = input.hold_duration ?? 50;
    args.push("--hold-duration", holdDuration.toString());



    // Execute the command
    const result = await executeSwiftCli(args, logger);

    if (!result.success || !result.data) {
      const errorMessage = result.error?.message || "Hotkey command failed";
      logger.error({ result }, errorMessage);

      return {
        content: [{
          type: "text",
          text: `Failed to press hotkey: ${errorMessage}`,
        }],
        isError: true,
      };
    }

    const hotkeyData = result.data as HotkeyResult;

    // Build response text
    const lines: string[] = [];
    lines.push("✅ Hotkey pressed");
    lines.push(`🎹 Keys: ${hotkeyData.keys.join(" + ")}`);
    lines.push(`⏱️  Completed in ${hotkeyData.execution_time.toFixed(2)}s`);

    return {
      content: [{
        type: "text",
        text: lines.join("\n"),
      }],
    };

  } catch (error) {
    logger.error({ error }, "Hotkey tool execution failed");

    return {
      content: [{
        type: "text",
        text: `Tool execution failed: ${error instanceof Error ? error.message : String(error)}`,
      }],
      isError: true,
    };
  }
}