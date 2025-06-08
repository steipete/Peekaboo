import { z } from "zod";
import {
  ToolContext,
  ApplicationListData,
  WindowListData,
  ApplicationInfo,
  WindowInfo,
  TargetApplicationInfo,
  SwiftCliResponse,
  ToolResponse,
} from "../types/index.js";
import { executeSwiftCli, execPeekaboo } from "../utils/peekaboo-cli.js";
import { generateServerStatusString } from "../utils/server-status.js";
import fs from "fs/promises";
import path from "path";
import { existsSync, accessSync, constants } from "fs";
import os from "os";
import { fileURLToPath } from "url";
import { Logger } from "pino";

export const listToolSchema = z
  .object({
    item_type: z
      .enum(["running_applications", "application_windows", "server_status", ""])
      .optional()
      .describe(
        "Specifies the type of items to list. If omitted or empty, it defaults to 'application_windows' if 'app' is provided, otherwise 'running_applications'. Valid options are:\n" +
          "- `running_applications`: Lists all currently running applications.\n" +
          "- `application_windows`: Lists open windows for a specific application. Requires the `app` parameter.\n" +
          "- `server_status`: Returns information about the Peekaboo MCP server.",
      ),
    app: z
      .string()
      .optional()
      .describe(
        "Required when `item_type` is `application_windows`. " +
        "Specifies the target application by its name (e.g., \"Safari\", \"TextEdit\") or bundle ID. " +
        "Fuzzy matching is used, so partial names may work.",
      ),
    include_window_details: z
      .array(z.enum(["off_screen", "bounds", "ids"]))
      .optional()
      .describe(
        "Optional, only applicable when `item_type` is `application_windows`. " +
        "Specifies additional details to include for each window. Provide an array of strings. Example: `[\"bounds\", \"ids\"]`.\n" +
        "- `ids`: Include window ID.\n" +
        "- `bounds`: Include window position and size (x, y, width, height).\n" +
        "- `off_screen`: Indicate if the window is currently off-screen.",
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
      !data.include_window_details ||
      data.include_window_details.length === 0 ||
      data.item_type === "application_windows" ||
      (data.app !== undefined && data.app.trim() !== ""),
    {
      message:
        "'include_window_details' is only applicable when 'item_type' is 'application_windows' or when 'app' is provided.",
      path: ["include_window_details"],
    },
  )
  .refine(
    (data) =>
      data.item_type !== "server_status" ||
      (data.app === undefined &&
       (data.include_window_details === undefined || data.include_window_details.length === 0)),
    {
      message:
        "'app' and 'include_window_details' not applicable for 'server_status'.",
      path: ["item_type"],
    },
  )
  .describe(
    "Lists various system items, providing situational awareness. " +
    "The `item_type` is optional and will be inferred if omitted (defaults to 'application_windows' if 'app' is provided, else 'running_applications'). " +
    "App identifier uses fuzzy matching for convenience.",
  );

export type ListToolInput = z.infer<typeof listToolSchema>;

export async function listToolHandler(
  input: ListToolInput,
  context: ToolContext,
): Promise<ToolResponse> {
  const { logger } = context;

  try {
    logger.debug({ input }, "Processing peekaboo.list tool call");

    // Handle server_status directly without calling Swift CLI
    if (input.item_type === "server_status") {
      // Get package version and root directory
      const __filename = fileURLToPath(import.meta.url);
      const __dirname = path.dirname(__filename);
      const packageRootDir = path.resolve(__dirname, "../..");
      const packageJsonPath = path.join(packageRootDir, "package.json");
      const packageJson = JSON.parse(
        await fs.readFile(packageJsonPath, "utf-8"),
      );
      const version = packageJson.version || "[unknown]";
      return await handleServerStatus(version, packageRootDir, logger);
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
            type: "text" as const,
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
            type: "text" as const,
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
    const effective_item_type = input.item_type || (input.app ? "application_windows" : "running_applications");

    if (effective_item_type === "running_applications") {
      return handleApplicationsList(
        swiftResponse.data as ApplicationListData,
        swiftResponse,
      );
    } else if (effective_item_type === "application_windows") {
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
          type: "text" as const,
          text: "List operation completed with unknown item type.",
        },
      ],
    };
  } catch (error) {
    logger.error({ error }, "Unexpected error in list tool handler");
    return {
      content: [
        {
          type: "text" as const,
          text: `Unexpected error: ${error instanceof Error ? error.message : "Unknown error"}`,
        },
      ],
      isError: true,
    };
  }
}

async function handleServerStatus(
  version: string,
  packageRootDir: string,
  logger: Logger,
): Promise<ToolResponse> {
  const statusSections: string[] = [];

  // 1. Server version and AI providers
  statusSections.push(generateServerStatusString(version));

  // 2. Native Binary Status
  statusSections.push("\n## Native Binary Status");

  // Use the same platform detection logic as the main CLI path determination
  let cliPath: string;
  const envPath = process.env.PEEKABOO_CLI_PATH;
  if (envPath) {
    cliPath = envPath;
  } else {
    // Detect platform and use appropriate binary
    const platform = process.platform;

    if (platform === "darwin") {
      // macOS - use Swift binary
      cliPath = path.join(packageRootDir, "peekaboo");
    } else if (platform === "linux") {
      // Linux - use Rust binary
      const linuxBinaryPath = path.resolve(packageRootDir, "peekaboo-linux", "target", "release", "peekaboo");
      if (existsSync(linuxBinaryPath)) {
        cliPath = linuxBinaryPath;
      } else {
        // Fallback to debug build if release doesn't exist
        const debugBinaryPath = path.resolve(packageRootDir, "peekaboo-linux", "target", "debug", "peekaboo");
        cliPath = debugBinaryPath;
      }
    } else {
      // Unsupported platform
      cliPath = path.join(packageRootDir, "peekaboo");
    }
  }

  const binaryType = process.platform === "linux" ? "Rust" : "Swift";
  statusSections.push(`\n## Native Binary (${binaryType} CLI) Status`);

  let cliStatus = "\u274c Not found";
  let cliVersion = "Unknown";
  let cliExecutable = false;

  if (existsSync(cliPath)) {
    try {
      accessSync(cliPath, constants.X_OK);
      cliExecutable = true;

      // Try to get CLI version
      const versionResult = await execPeekaboo(
        ["--version"],
        packageRootDir,
        { expectSuccess: false },
      );

      if (versionResult.success && versionResult.data) {
        cliVersion = versionResult.data.trim();
        // Extract just the version number if it includes the binary name
        const versionMatch = cliVersion.match(/(\d+\.\d+\.\d+(?:-[a-zA-Z0-9.-]+)?)/);
        if (versionMatch) {
          cliVersion = versionMatch[1];
        }
        cliStatus = "\u2714 Found and executable";
      } else {
        cliStatus = "\u26a0 Found but version check failed";
      }
    } catch (_error) {
      cliStatus = "\u26a0 Found but not executable";
    }
  }

  statusSections.push(`- Location: ${cliPath}`);
  statusSections.push(`- Status: ${cliStatus}`);
  statusSections.push(`- Version: ${cliVersion}`);
  statusSections.push(`- Executable: ${cliExecutable ? "Yes" : "No"}`);

  // 3. Permissions Status
  statusSections.push("\n## System Permissions");

  if (cliExecutable) {
    try {
      const permissionsResult = await execPeekaboo(
        ["list", "server_status", "--json-output"],
        packageRootDir,
        { expectSuccess: false },
      );

      if (permissionsResult.success && permissionsResult.data) {
        const status = JSON.parse(permissionsResult.data);
        if (status.data?.permissions) {
          const perms = status.data.permissions;
          statusSections.push(`- Screen Recording: ${perms.screen_recording ? "\u2714 Granted" : "\u274c Not granted"}`);
          statusSections.push(`- Accessibility: ${perms.accessibility ? "\u2714 Granted" : "\u274c Not granted"}`);
        } else {
          statusSections.push("- Unable to determine permissions status");
        }
      } else {
        statusSections.push("- Unable to check permissions (CLI error)");
      }
    } catch (error) {
      statusSections.push(`- Unable to check permissions: ${error}`);
    }
  } else {
    statusSections.push("- Unable to check permissions (CLI not available)");
  }

  // 4. Environment Configuration
  statusSections.push("\n## Environment Configuration");

  const logFile = process.env.PEEKABOO_LOG_FILE || path.join(os.homedir(), "Library/Logs/peekaboo-mcp.log");
  const logLevel = process.env.PEEKABOO_LOG_LEVEL || "info";
  const consoleLogging = process.env.PEEKABOO_CONSOLE_LOGGING === "true";
  const aiProviders = process.env.PEEKABOO_AI_PROVIDERS || "None configured";
  const customCliPath = process.env.PEEKABOO_CLI_PATH;
  const defaultSavePath = process.env.PEEKABOO_DEFAULT_SAVE_PATH || "Not set";

  statusSections.push(`- Log File: ${logFile}`);

  // Check log file accessibility
  try {
    const logDir = path.dirname(logFile);
    await fs.access(logDir, constants.W_OK);
    statusSections.push("  Status: ✅ Directory writable");
  } catch (_error) {
    statusSections.push("  Status: ❌ Directory not writable");
  }

  statusSections.push(`- Log Level: ${logLevel}`);
  statusSections.push(`- Console Logging: ${consoleLogging ? "Enabled" : "Disabled"}`);
  statusSections.push(`- AI Providers: ${aiProviders}`);
  statusSections.push(`- Custom CLI Path: ${customCliPath || "Not set (using default)"}`);
  statusSections.push(`- Default Save Path: ${defaultSavePath}`);

  // 5. Configuration Issues
  statusSections.push("\n## Configuration Issues");

  const issues: string[] = [];

  if (!cliExecutable) {
    issues.push("❌ Swift CLI not found or not executable");
  }

  if (cliVersion !== version && cliVersion !== "Unknown") {
    issues.push(`⚠️ Version mismatch: Server ${version} vs CLI ${cliVersion}`);
  }

  if (!aiProviders || aiProviders === "None configured") {
    issues.push("⚠️ No AI providers configured (analysis features will be limited)");
  }

  // Check if log directory is writable
  try {
    const logDir = path.dirname(logFile);
    await fs.access(logDir, constants.W_OK);
  } catch {
    issues.push(`❌ Log directory not writable: ${path.dirname(logFile)}`);
  }

  if (issues.length === 0) {
    statusSections.push("✅ No configuration issues detected");
  } else {
    issues.forEach(issue => statusSections.push(issue));
  }

  // 6. System Information
  statusSections.push("\n## System Information");
  statusSections.push(`- Platform: ${os.platform()}`);
  statusSections.push(`- Architecture: ${os.arch()}`);
  statusSections.push(`- OS Version: ${os.release()}`);
  statusSections.push(`- Node.js Version: ${process.version}`);

  const fullStatus = statusSections.join("\n");

  logger.info({ status: fullStatus }, "Server status info generated");

  return {
    content: [
      {
        type: "text" as const,
        text: fullStatus,
      },
    ],
  };
}

export function buildSwiftCliArgs(input: ListToolInput): string[] {
  const args = ["list"];
  const itemType = input.item_type || (input.app ? "application_windows" : "running_applications");

  if (itemType === "running_applications") {
    args.push("apps");
  } else if (itemType === "application_windows") {
    args.push("windows");
    if (input.app) {
      args.push("--app", input.app);
    }
    if (
      input.include_window_details &&
      input.include_window_details.length > 0
    ) {
      args.push("--include-details", input.include_window_details.join(","));
    }
  } else if (itemType === "server_status") {
    args.push("server_status");
  }

  return args;
}

function handleApplicationsList(
  data: ApplicationListData,
  swiftResponse: SwiftCliResponse,
): ToolResponse & { application_list: ApplicationInfo[] } {
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
        type: "text" as const,
        text: summary,
      },
    ],
    application_list: apps,
  };
}

function handleWindowsList(
  data: WindowListData,
  input: ListToolInput,
  swiftResponse: SwiftCliResponse,
): ToolResponse & {
  window_list?: WindowInfo[];
  target_application_info?: TargetApplicationInfo;
} {
  const windows = data.windows || [];
  const appInfo = data.target_application_info;

  // Validate required fields
  if (!appInfo) {
    return {
      content: [
        {
          type: "text" as const,
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
        type: "text" as const,
        text: summary,
      },
    ],
    window_list: windows,
    target_application_info: appInfo,
  };
}
