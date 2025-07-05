import {
  ToolContext,
  ToolResponse,
} from "../types/index.js";
import { z } from "zod";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";

export const clickToolSchema = z.object({
  query: z.string().optional().describe(
    "Optional. Element text or query to click. Will search for matching elements."
  ),
  on: z.string().optional().describe(
    "Optional. Element ID to click (e.g., B1, T2) from see command output."
  ),
  coords: z.string().optional().describe(
    "Optional. Click at specific coordinates in format 'x,y' (e.g., '100,200')."
  ),
  session: z.string().optional().describe(
    "Optional. Session ID from see command. Uses latest session if not specified."
  ),
  wait_for: z.number().optional().default(5000).describe(
    "Optional. Maximum milliseconds to wait for element to become actionable. Default: 5000."
  ),
  double: z.boolean().optional().default(false).describe(
    "Optional. Double-click instead of single click."
  ),
  right: z.boolean().optional().default(false).describe(
    "Optional. Right-click (secondary click) instead of left-click."
  ),
}).refine(
  (data) => data.query || data.on || data.coords,
  "Must specify either 'query', 'on', or 'coords'"
).describe(
  "Clicks on UI elements or coordinates. " +
  "Supports element queries, specific IDs from see command, or raw coordinates. " +
  "Includes smart waiting for elements to become actionable. " +
  "Works with sessions created by the see command."
);

interface ClickResult {
  success: boolean;
  clicked_element?: string;
  click_location: {
    x: number;
    y: number;
  };
  wait_time?: number;
  execution_time: number;
}

export type ClickInput = z.infer<typeof clickToolSchema>;

export async function clickToolHandler(
  input: ClickInput,
  context: ToolContext,
): Promise<ToolResponse> {
  const { logger } = context;

  try {
    logger.debug({ input }, "Processing peekaboo.click tool call");

    // Build command arguments
    const args = ["click"];
    
    // Click target
    if (input.query) {
      args.push(input.query);
    }
    
    if (input.on) {
      args.push("--on", input.on);
    }
    
    if (input.coords) {
      args.push("--coords", input.coords);
    }
    
    // Session
    if (input.session) {
      args.push("--session", input.session);
    }
    
    // Wait timeout
    args.push("--wait-for", input.wait_for.toString());
    
    // Click type
    if (input.double) {
      args.push("--double");
    }
    
    if (input.right) {
      args.push("--right");
    }
    
    args.push("--json-output");

    // Execute the command
    const result = await executeSwiftCli(args, logger);

    if (!result.success || !result.data) {
      const errorMessage = result.error?.message || "Click command failed";
      logger.error({ result }, errorMessage);
      
      return {
        content: [{
          type: "text",
          text: `Failed to perform click: ${errorMessage}`,
        }],
        isError: true,
      };
    }

    const clickData = result.data as ClickResult;

    // Build response text
    const lines: string[] = [];
    lines.push("✅ Click successful");
    
    if (clickData.clicked_element) {
      lines.push(`🎯 Clicked: ${clickData.clicked_element}`);
    }
    
    lines.push(`📍 Location: (${Math.round(clickData.click_location.x)}, ${Math.round(clickData.click_location.y)})`);
    
    if (clickData.wait_time && clickData.wait_time > 0) {
      lines.push(`⏳ Waited: ${(clickData.wait_time / 1000).toFixed(1)}s`);
    }
    
    lines.push(`⏱️  Completed in ${clickData.execution_time.toFixed(2)}s`);

    return {
      content: [{
        type: "text",
        text: lines.join("\n"),
      }],
    };

  } catch (error) {
    logger.error({ error }, "Click tool execution failed");
    
    return {
      content: [{
        type: "text",
        text: `Tool execution failed: ${error instanceof Error ? error.message : String(error)}`,
      }],
      isError: true,
    };
  }
}