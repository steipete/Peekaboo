import {
  ToolContext,
  ToolResponse,
} from "../types/index.js";
import { z } from "zod";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";

export const sleepToolSchema = z.object({
  duration: z.preprocess(
    (val) => {
      // Convert string to number if possible
      if (typeof val === "string") {
        const num = parseFloat(val);
        return isNaN(num) ? val : num;
      }
      return val;
    },
    z.number().min(0)
  ).describe(
    "Sleep duration in milliseconds."
  ),
}).describe(
  "Pauses execution for a specified duration. " +
  "Useful for waiting between UI actions, allowing animations to complete, " +
  "or pacing automated workflows."
);

interface SleepResult {
  success: boolean;
  requested_duration: number;
  actual_duration: number;
}

export type SleepInput = z.infer<typeof sleepToolSchema>;

export async function sleepToolHandler(
  input: SleepInput,
  context: ToolContext,
): Promise<ToolResponse> {
  const { logger } = context;

  try {
    logger.debug({ input }, "Processing peekaboo.sleep tool call");

    // Build command arguments
    const args = ["sleep", input.duration.toString(), "--json-output"];

    // Execute the command
    const result = await executeSwiftCli(args, logger);

    if (!result.success || !result.data) {
      const errorMessage = result.error?.message || "Sleep command failed";
      logger.error({ result }, errorMessage);
      
      return {
        content: [{
          type: "text",
          text: `Failed to sleep: ${errorMessage}`,
        }],
        isError: true,
      };
    }

    const sleepData = result.data as SleepResult;

    // Build response text
    const durationSeconds = sleepData.actual_duration / 1000;
    
    return {
      content: [{
        type: "text",
        text: `⏸️  Paused for ${durationSeconds.toFixed(1)}s`,
      }],
    };

  } catch (error) {
    logger.error({ error }, "Sleep tool execution failed");
    
    return {
      content: [{
        type: "text",
        text: `Tool execution failed: ${error instanceof Error ? error.message : String(error)}`,
      }],
      isError: true,
    };
  }
}