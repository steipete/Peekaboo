import {
  ToolContext,
  ToolResponse,
} from "../types/index.js";
import { z } from "zod";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";

export const scrollToolSchema = z.object({
  direction: z.enum(["up", "down", "left", "right"]).describe(
    "Scroll direction: up (content moves up), down (content moves down), left, or right.",
  ),
  amount: z.number().optional().default(3).describe(
    "Optional. Number of scroll ticks/lines. Default: 3.",
  ),
  on: z.string().optional().describe(
    "Optional. Element ID to scroll on (from see command). If not specified, scrolls at current mouse position.",
  ),
  session: z.string().optional().describe(
    "Optional. Session ID from see command. Uses latest session if not specified.",
  ),
  delay: z.number().optional().default(20).describe(
    "Optional. Delay between scroll ticks in milliseconds. Default: 20.",
  ),
  smooth: z.boolean().optional().default(false).describe(
    "Optional. Use smooth scrolling with smaller increments.",
  ),
}).describe(
  "Scrolls the mouse wheel in any direction. " +
  "Can target specific elements or scroll at current mouse position. " +
  "Supports smooth scrolling and configurable speed.",
);

interface ScrollResult {
  success: boolean;
  direction: string;
  amount: number;
  location: {
    x: number;
    y: number;
  };
  total_ticks: number;
  execution_time: number;
}

export type ScrollInput = z.infer<typeof scrollToolSchema>;

export async function scrollToolHandler(
  input: ScrollInput,
  context: ToolContext,
): Promise<ToolResponse> {
  const { logger } = context;

  try {
    logger.debug({ input }, "Processing peekaboo.scroll tool call");

    // Build command arguments
    const args = ["scroll"];

    // Direction
    args.push("--direction", input.direction);

    // Amount
    const amount = input.amount ?? 3;
    args.push("--amount", amount.toString());

    // Target element
    if (input.on) {
      args.push("--on", input.on);
    }

    // Session
    if (input.session) {
      args.push("--session", input.session);
    }

    // Delay between ticks
    const delay = input.delay ?? 20;
    args.push("--delay", delay.toString());

    // Smooth scrolling
    if (input.smooth) {
      args.push("--smooth");
    }

    

    // Execute the command
    const result = await executeSwiftCli(args, logger);

    if (!result.success || !result.data) {
      const errorMessage = result.error?.message || "Scroll command failed";
      logger.error({ result }, errorMessage);

      return {
        content: [{
          type: "text",
          text: `Failed to perform scroll: ${errorMessage}`,
        }],
        isError: true,
      };
    }

    const scrollData = result.data as ScrollResult;

    // Build response text
    const lines: string[] = [];
    lines.push("✅ Scroll completed");
    lines.push(`🎯 Direction: ${scrollData.direction}`);
    lines.push(`📊 Amount: ${scrollData.amount} ticks`);

    if (input.on) {
      lines.push(`📍 Location: (${Math.round(scrollData.location.x)}, ${Math.round(scrollData.location.y)})`);
    }

    lines.push(`⏱️  Completed in ${scrollData.execution_time.toFixed(2)}s`);

    return {
      content: [{
        type: "text",
        text: lines.join("\n"),
      }],
    };

  } catch (error) {
    logger.error({ error }, "Scroll tool execution failed");

    return {
      content: [{
        type: "text",
        text: `Tool execution failed: ${error instanceof Error ? error.message : String(error)}`,
      }],
      isError: true,
    };
  }
}