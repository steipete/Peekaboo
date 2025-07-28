import { z } from "zod";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";
import { ToolContext, ToolResponse } from "../types/index.js";

// Schema for permissions tool
export const permissionsToolSchema = z.object({}).strict();

export type PermissionsInput = z.infer<typeof permissionsToolSchema>;

interface PermissionsOutput {
  screen_recording: boolean;
  accessibility: boolean;
  screen_recording_message?: string;
  accessibility_message?: string;
}

export async function permissionsToolHandler(
  args: PermissionsInput,
  context: ToolContext,
): Promise<ToolResponse> {
  context.logger.debug("Checking macOS permissions");

  try {
    // Execute permissions command with JSON output
    const result = await executeSwiftCli(
      ["permissions", "--json-output"],
      context.logger,
      { timeout: 5000 }
    );

    if (!result.success || !result.data) {
      throw new Error(result.error?.message || "Failed to get permissions");
    }
    
    const permissionsData = result.data as PermissionsOutput;

    // Format the response
    const statusText = [
      `Screen Recording: ${permissionsData.screen_recording ? "✅ Granted" : "❌ Not granted"}`,
      permissionsData.screen_recording_message || "",
      `Accessibility: ${permissionsData.accessibility ? "✅ Granted" : "❌ Not granted"}`,
      permissionsData.accessibility_message || "",
    ]
      .filter(Boolean)
      .join("\n");

    return {
      content: [
        {
          type: "text",
          text: statusText,
        },
      ],
      metadata: {
        permissions: permissionsData,
      },
    };
  } catch (error) {
    context.logger.error("Failed to check permissions", { error });
    return {
      content: [
        {
          type: "text",
          text: `Failed to check permissions: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
      isError: true,
    };
  }
}