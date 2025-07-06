import {
  ToolContext,
  ToolResponse,
} from "../types/index.js";
import { z } from "zod";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";

export const swipeToolSchema = z.object({
  from: z.string().describe(
    "Starting coordinates in format 'x,y' (e.g., '100,200')."
  ),
  to: z.string().describe(
    "Ending coordinates in format 'x,y' (e.g., '300,400')."
  ),
  duration: z.number().optional().default(500).describe(
    "Optional. Duration of the swipe in milliseconds. Default: 500."
  ),
  steps: z.number().optional().default(10).describe(
    "Optional. Number of intermediate steps for smooth movement. Default: 10."
  ),
}).describe(
  "Performs a swipe/drag gesture from one point to another. " +
  "Useful for dragging elements, swiping through content, or gesture-based interactions. " +
  "Creates smooth movement with configurable duration and steps."
);

interface SwipeResult {
  success: boolean;
  start_location: {
    x: number;
    y: number;
  };
  end_location: {
    x: number;
    y: number;
  };
  distance: number;
  duration: number;
  execution_time: number;
}

export type SwipeInput = z.infer<typeof swipeToolSchema>;

export async function swipeToolHandler(
  input: SwipeInput,
  context: ToolContext,
): Promise<ToolResponse> {
  const { logger } = context;

  try {
    logger.debug({ input }, "Processing peekaboo.swipe tool call");

    // Build command arguments
    const args = ["swipe"];
    
    // From and to coordinates
    args.push("--from", input.from);
    args.push("--to", input.to);
    
    // Duration
    const duration = input.duration ?? 500;
    args.push("--duration", duration.toString());
    
    // Steps
    const steps = input.steps ?? 10;
    args.push("--steps", steps.toString());
    
    args.push("--json-output");

    // Execute the command
    const result = await executeSwiftCli(args, logger);

    if (!result.success || !result.data) {
      const errorMessage = result.error?.message || "Swipe command failed";
      logger.error({ result }, errorMessage);
      
      return {
        content: [{
          type: "text",
          text: `Failed to perform swipe: ${errorMessage}`,
        }],
        isError: true,
      };
    }

    const swipeData = result.data as SwipeResult;

    // Build response text
    const lines: string[] = [];
    lines.push("✅ Swipe completed");
    lines.push(`📍 From: (${Math.round(swipeData.start_location.x)}, ${Math.round(swipeData.start_location.y)})`);
    lines.push(`📍 To: (${Math.round(swipeData.end_location.x)}, ${Math.round(swipeData.end_location.y)})`);
    lines.push(`📏 Distance: ${Math.round(swipeData.distance)}px`);
    lines.push(`⏱️  Duration: ${swipeData.duration}ms`);
    lines.push(`⏱️  Completed in ${swipeData.execution_time.toFixed(2)}s`);

    return {
      content: [{
        type: "text",
        text: lines.join("\n"),
      }],
    };

  } catch (error) {
    logger.error({ error }, "Swipe tool execution failed");
    
    return {
      content: [{
        type: "text",
        text: `Tool execution failed: ${error instanceof Error ? error.message : String(error)}`,
      }],
      isError: true,
    };
  }
}