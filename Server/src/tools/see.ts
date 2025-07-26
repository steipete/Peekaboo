import {
  ToolContext,
  ToolResponse,
} from "../types/index.js";
import { z } from "zod";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";
import { readImageAsBase64 } from "../utils/peekaboo-cli.js";
import * as path from "path";
import * as os from "os";

export const seeToolSchema = z.object({
  app_target: z.string().optional().describe(
    "Optional. Specifies the capture target (same as image tool).\n" +
    "For example:\n" +
    "Omit or use an empty string (e.g., `''`) for all screens.\n" +
    "Use `'screen:INDEX'` (e.g., `'screen:0'`) for a specific display.\n" +
    "Use `'frontmost'` for all windows of the current foreground application.\n" +
    "Use `'AppName'` (e.g., `'Safari'`) for all windows of that application.\n" +
    "Use `'PID:PROCESS_ID'` (e.g., `'PID:663'`) to target a specific process by its PID.",
  ),
  path: z.string().optional().describe(
    "Optional. Path to save the screenshot. If not provided, uses a temporary file.",
  ),
  session: z.string().optional().describe(
    "Optional. Session ID for UI automation state tracking. Creates new session if not provided.",
  ),
  annotate: z.boolean().optional().default(false).describe(
    "Optional. If true, generates an annotated screenshot with interaction markers and IDs.",
  ),
}).describe(
  "Captures a screenshot and analyzes UI elements for automation. " +
  "Returns UI element map with Peekaboo IDs (B1 for buttons, T1 for text fields, etc.) " +
  "that can be used with click, type, and other interaction commands. " +
  "Creates or updates a session for tracking UI state.",
);

interface SeeResult {
  screenshot_path: string;
  session_id: string;
  ui_elements: Array<{
    id: string;
    role: string;
    title?: string;
    label?: string;
    value?: string;
    bounds: {
      x: number;
      y: number;
      width: number;
      height: number;
    };
    is_actionable: boolean;
  }>;
  application?: string;
  window?: string;
  timestamp: string;
}

export type SeeInput = z.infer<typeof seeToolSchema>;

export async function seeToolHandler(
  input: SeeInput,
  context: ToolContext,
): Promise<ToolResponse> {
  const { logger } = context;

  try {
    logger.debug({ input }, "Processing peekaboo.see tool call");

    // Build command arguments
    const args = ["see"];

    if (input.app_target) {
      // Parse app_target similar to image tool
      const [targetType, ...targetParts] = input.app_target.split(":");

      if (targetType === "screen" && targetParts.length > 0) {
        args.push("--mode", "screen", "--screen-index", targetParts[0]);
      } else if (targetType === "frontmost") {
        args.push("--mode", "frontmost");
      } else if (targetType.startsWith("PID") && targetParts.length > 0) {
        args.push("--app", `PID:${targetParts[0]}`);
      } else if (targetParts.length === 0) {
        args.push("--app", targetType);
      } else if (targetParts[0] === "WINDOW_TITLE" && targetParts.length > 1) {
        args.push("--app", targetType, "--window-title", targetParts.slice(1).join(":"));
      } else if (targetParts[0] === "WINDOW_INDEX" && targetParts.length > 1) {
        args.push("--app", targetType, "--window-index", targetParts[1]);
      }
    }

    // Output path
    const outputPath = input.path || path.join(os.tmpdir(), `peekaboo-see-${Date.now()}.png`);
    args.push("--path", outputPath);

    // Session management
    if (input.session) {
      args.push("--session", input.session);
    }

    // Annotation
    if (input.annotate) {
      args.push("--annotate");
    }

    // Execute the command
    const result = await executeSwiftCli(args, logger);

    if (!result.success || !result.data) {
      const errorMessage = result.error?.message || "See command failed";
      logger.error({ result }, errorMessage);

      return {
        content: [{
          type: "text",
          text: `Failed to capture UI state: ${errorMessage}`,
        }],
        isError: true,
      };
    }

    const seeData = result.data as SeeResult;

    // Build response
    const responseContent: Array<{ type: "text" | "image"; text?: string; data?: string; mimeType?: string }> = [];

    // Add text summary
    const summary = buildSeeSummary(seeData);
    responseContent.push({
      type: "text",
      text: summary,
    });

    // If annotated, include the screenshot as base64
    if (input.annotate && seeData.screenshot_path) {
      try {
        const base64Data = await readImageAsBase64(seeData.screenshot_path);
        responseContent.push({
          type: "image",
          data: base64Data,
          mimeType: "image/png",
        });
      } catch (err) {
        logger.warn({ error: err }, "Failed to read annotated screenshot");
      }
    }

    return {
      content: responseContent,
      _meta: {
        session_id: seeData.session_id,
        element_count: seeData.ui_elements.length,
        actionable_count: seeData.ui_elements.filter(el => el.is_actionable).length,
      },
    };

  } catch (error) {
    logger.error({ error }, "See tool execution failed");

    return {
      content: [{
        type: "text",
        text: `Tool execution failed: ${error instanceof Error ? error.message : String(error)}`,
      }],
      isError: true,
    };
  }
}

function buildSeeSummary(data: SeeResult): string {
  const lines: string[] = [];

  lines.push("📸 UI State Captured");
  lines.push(`Session ID: ${data.session_id}`);

  if (data.application) {
    lines.push(`Application: ${data.application}`);
  }
  if (data.window) {
    lines.push(`Window: ${data.window}`);
  }

  lines.push(`Screenshot: ${data.screenshot_path}`);
  lines.push(`Elements found: ${data.ui_elements.length}`);

  // Group elements by type
  const elementsByRole = new Map<string, typeof data.ui_elements>();
  for (const elem of data.ui_elements) {
    const roleElems = elementsByRole.get(elem.role) || [];
    roleElems.push(elem);
    elementsByRole.set(elem.role, roleElems);
  }

  lines.push("\nUI Elements:");

  // Sort roles for consistent output
  const sortedRoles = Array.from(elementsByRole.keys()).sort();

  for (const role of sortedRoles) {
    const elements = elementsByRole.get(role);
    if (!elements) {
      continue;
    }
    const actionableCount = elements.filter(el => el.is_actionable).length;

    lines.push(`\n${role} (${elements.length} found, ${actionableCount} actionable):`);

    for (const elem of elements) {
      const parts = [`  ${elem.id}`];

      if (elem.title) {
        parts.push(`"${elem.title}"`);
      } else if (elem.label) {
        parts.push(`"${elem.label}"`);
      } else if (elem.value) {
        parts.push(`value: "${elem.value}"`);
      }

      parts.push(`at (${Math.round(elem.bounds.x)}, ${Math.round(elem.bounds.y)})`);

      if (!elem.is_actionable) {
        parts.push("[not actionable]");
      }

      lines.push(parts.join(" - "));
    }
  }

  lines.push("\nUse element IDs (B1, T1, etc.) with click, type, and other interaction commands.");

  return lines.join("\n");
}