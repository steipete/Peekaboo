import { z } from "zod";
import {
  ToolContext,
  ApplicationListData,
  WindowListData,
} from "../types/index.js";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";
import { generateServerStatusString } from "../utils/server-status.js";
import fs from "fs/promises";
import path from "path";

export const listToolSchema = z
  .object({
    item_type: z
      .enum(["running_applications", "application_windows", "server_status"])
      .default("running_applications")
      .describe("What to list. 'server_status' returns Peekaboo server info."),
    app: z
      .string()
      .optional()
      .describe(
        "Required if 'item_type' is 'application_windows'. Target application. Uses fuzzy matching.",
      ),
    include_window_details: z
      .array(z.enum(["off_screen", "bounds", "ids"]))
      .optional()
      .describe(
        "Optional, for 'application_windows'. Additional window details. Example: ['bounds', 'ids']",
      ),
  })
  .refine(
    (data) =>
      data.item_type !== "application_windows" ||
      (data.app !== undefined && data.app.trim() !== ""),
    {
      message: "For 'application_windows', 'app' identifier is required.",
      path: ["app"],
    },
  )
  .refine(
    (data) =>
      !data.include_window_details || data.item_type === "application_windows",
    {
      message: "'include_window_details' only for 'application_windows'.",
      path: ["include_window_details"],
    },
  )
  .refine(
    (data) =>
      data.item_type !== "server_status" ||
      (data.app === undefined && data.include_window_details === undefined),
    {
      message:
        "'app' and 'include_window_details' not applicable for 'server_status'.",
      path: ["item_type"],
    },
  );

export type ListToolInput = z.infer<typeof listToolSchema>;

export async function listToolHandler(
  input: ListToolInput,
  context: ToolContext,
) {
  const { logger } = context;

  try {
    logger.debug({ input }, "Processing peekaboo.list tool call");

    // Handle server_status directly without calling Swift CLI
    if (input.item_type === "server_status") {
      // Get package version
      const packageJsonPath = path.join(process.cwd(), "package.json");
      const packageJson = JSON.parse(
        await fs.readFile(packageJsonPath, "utf-8"),
      );
      const version = packageJson.version || "[unknown]";
      return await handleServerStatus(version);
    }

    // Build Swift CLI arguments
    const args = buildSwiftCliArgs(input);

    // Execute Swift CLI
    const swiftResponse = await executeSwiftCli(args, logger);

    if (!swiftResponse.success) {
      logger.error({ error: swiftResponse.error }, "Swift CLI returned error");
      return {
        content: [
          {
            type: "text",
            text: `List operation failed: ${swiftResponse.error?.message || "Unknown error"}`,
          },
        ],
        isError: true,
        _meta: {
          backend_error_code: swiftResponse.error?.code,
        },
      };
    }

    // Check if data is null or undefined
    if (!swiftResponse.data) {
      logger.error("Swift CLI reported success but no data was returned.");
      return {
        content: [
          {
            type: "text",
            text: "List operation failed: Invalid response from list utility (no data).",
          },
        ],
        isError: true,
        _meta: {
          backend_error_code: "INVALID_RESPONSE_NO_DATA",
        },
      };
    }

    // Process the response based on item type
    if (input.item_type === "running_applications") {
      return handleApplicationsList(
        swiftResponse.data as ApplicationListData,
        swiftResponse,
      );
    } else if (input.item_type === "application_windows") {
      return handleWindowsList(
        swiftResponse.data as WindowListData,
        input,
        swiftResponse,
      );
    }

    // Fallback
    return {
      content: [
        {
          type: "text",
          text: "List operation completed with unknown item type.",
        },
      ],
    };
  } catch (error) {
    logger.error({ error }, "Unexpected error in list tool handler");
    return {
      content: [
        {
          type: "text",
          text: `Unexpected error: ${error instanceof Error ? error.message : "Unknown error"}`,
        },
      ],
      isError: true,
    };
  }
}

async function handleServerStatus(
  version: string,
): Promise<{ content: { type: string; text: string }[] }> {
  const statusString = generateServerStatusString(version);

  return {
    content: [
      {
        type: "text",
        text: statusString,
      },
    ],
  };
}

export function buildSwiftCliArgs(input: ListToolInput): string[] {
  const args = ["list"];

  if (input.item_type === "running_applications") {
    args.push("apps");
  } else if (input.item_type === "application_windows") {
    args.push("windows");
    args.push("--app", input.app!);

    if (
      input.include_window_details &&
      input.include_window_details.length > 0
    ) {
      args.push("--include-details", input.include_window_details.join(","));
    }
  }

  return args;
}

function handleApplicationsList(
  data: ApplicationListData,
  swiftResponse: any,
): { content: { type: string; text: string }[]; application_list: any[] } {
  const apps = data.applications || [];

  let summary = `Found ${apps.length} running application${apps.length !== 1 ? "s" : ""}`;

  if (apps.length > 0) {
    summary += ":\n\n";
    apps.forEach((app, index) => {
      summary += `${index + 1}. ${app.app_name}`;
      if (app.bundle_id) {
        summary += ` (${app.bundle_id})`;
      }
      summary += ` - PID: ${app.pid}`;
      if (app.is_active) {
        summary += " [ACTIVE]";
      }
      summary += ` - Windows: ${app.window_count}\n`;
    });
  }

  // Add messages from Swift CLI if any
  if (swiftResponse.messages?.length) {
    summary += `\nMessages: ${swiftResponse.messages.join("; ")}`;
  }

  return {
    content: [
      {
        type: "text",
        text: summary,
      },
    ],
    application_list: apps,
  };
}

function handleWindowsList(
  data: WindowListData,
  input: ListToolInput,
  swiftResponse: any,
): {
  content: { type: string; text: string }[];
  window_list?: any[];
  target_application_info?: any;
  isError?: boolean;
  _meta?: any;
} {
  const windows = data.windows || [];
  const appInfo = data.target_application_info;

  // Validate required fields
  if (!appInfo) {
    return {
      content: [
        {
          type: "text",
          text: "List operation failed: Invalid response from list utility (missing application info).",
        },
      ],
      isError: true,
      _meta: {
        backend_error_code: "INVALID_RESPONSE_MISSING_APP_INFO",
      },
    };
  }

  let summary = `Found ${windows.length} window${windows.length !== 1 ? "s" : ""} for application: ${appInfo.app_name}`;

  if (appInfo.bundle_id) {
    summary += ` (${appInfo.bundle_id})`;
  }
  summary += ` - PID: ${appInfo.pid}`;

  if (windows.length > 0) {
    summary += "\n\nWindows:\n";
    windows.forEach((window, index) => {
      summary += `${index + 1}. "${window.window_title}"`;

      if (window.window_id !== undefined) {
        summary += ` [ID: ${window.window_id}]`;
      }

      if (window.is_on_screen !== undefined) {
        summary += window.is_on_screen ? " [ON-SCREEN]" : " [OFF-SCREEN]";
      }

      if (window.bounds) {
        summary += ` [${window.bounds.x},${window.bounds.y} ${window.bounds.width}×${window.bounds.height}]`;
      }

      summary += "\n";
    });
  }

  // Add messages from Swift CLI if any
  if (swiftResponse.messages?.length) {
    summary += `\nMessages: ${swiftResponse.messages.join("; ")}`;
  }

  return {
    content: [
      {
        type: "text",
        text: summary,
      },
    ],
    window_list: windows,
    target_application_info: appInfo,
  };
}
