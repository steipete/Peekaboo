import {
  ToolContext,
  ToolResponse,
} from "../types/index.js";
import { z } from "zod";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";

export const cleanToolSchema = z.object({
  all_sessions: z.boolean().optional().describe(
    "Optional. Remove all session data.",
  ),
  older_than: z.number().optional().describe(
    "Optional. Remove sessions older than specified hours.",
  ),
  session: z.string().optional().describe(
    "Optional. Remove specific session by ID.",
  ),
  dry_run: z.boolean().optional().default(false).describe(
    "Optional. Show what would be deleted without actually deleting.",
  ),
}).refine(
  (data) => {
    const options = [data.all_sessions, data.older_than !== undefined, data.session !== undefined];
    return options.filter(Boolean).length === 1;
  },
  "Specify exactly one of: all_sessions, older_than, or session",
).describe(
  "Cleans up session cache and temporary files. " +
  "Sessions are stored in ~/.peekaboo/session/<PID>/ directories. " +
  "Use this to free up disk space and remove orphaned session data.",
);

interface CleanResult {
  sessions_removed: number;
  bytes_freed: number;
  session_details: Array<{
    session_id: string;
    path: string;
    size: number;
    creation_date?: string;
  }>;
  execution_time: number;
  success: boolean;
}

export type CleanInput = z.infer<typeof cleanToolSchema>;

export async function cleanToolHandler(
  input: CleanInput,
  context: ToolContext,
): Promise<ToolResponse> {
  const { logger } = context;

  try {
    logger.debug({ input }, "Processing peekaboo.clean tool call");

    // Build command arguments
    const args = ["clean"];

    if (input.all_sessions) {
      args.push("--all-sessions");
    } else if (input.older_than !== undefined) {
      args.push("--older-than", input.older_than.toString());
    } else if (input.session) {
      args.push("--session", input.session);
    }

    if (input.dry_run) {
      args.push("--dry-run");
    }

    logger.debug({ args }, "Executing clean command with args");

    // Execute the command
    const result = await executeSwiftCli(args, logger);

    if (!result.success || !result.data) {
      const errorMessage = result.error?.message || "Clean command failed";
      logger.error({ result }, errorMessage);

      return {
        content: [{
          type: "text",
          text: `Failed to clean sessions: ${errorMessage}`,
        }],
        isError: true,
      };
    }

    const cleanData = result.data as CleanResult;

    // Build response text
    const lines: string[] = [];

    if (input.dry_run) {
      lines.push("🔍 Dry run mode - no files were deleted");
      lines.push("");
    }

    const sessionsRemoved = cleanData.sessions_removed ?? 0;
    
    if (sessionsRemoved === 0) {
      lines.push("✅ No sessions to clean");
    } else {
      const action = input.dry_run ? "Would remove" : "Removed";
      lines.push(`🗑️  ${action} ${sessionsRemoved} session${sessionsRemoved === 1 ? "" : "s"}`);
      lines.push(`💾 Space ${input.dry_run ? "to be freed" : "freed"}: ${formatBytes(cleanData.bytes_freed)}`);

      if (cleanData.session_details && cleanData.session_details.length > 0 && cleanData.session_details.length <= 5) {
        lines.push("\nSessions:");
        for (const session of cleanData.session_details) {
          lines.push(`  - ${session.session_id} (${formatBytes(session.size)})`);
        }
      }
    }

    if (cleanData.execution_time !== undefined) {
      lines.push(`\n⏱️  Completed in ${cleanData.execution_time.toFixed(2)}s`);
    }

    return {
      content: [{
        type: "text",
        text: lines.join("\n"),
      }],
    };

  } catch (error) {
    logger.error({ error }, "Clean tool execution failed");

    return {
      content: [{
        type: "text",
        text: `Tool execution failed: ${error instanceof Error ? error.message : String(error)}`,
      }],
      isError: true,
    };
  }
}

function formatBytes(bytes: number | undefined): string {
  if (bytes === undefined || bytes === null) {
    return "0.0 B";
  }
  
  const units = ["B", "KB", "MB", "GB"];
  let size = bytes;
  let unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }

  return `${size.toFixed(1)} ${units[unitIndex]}`;
}