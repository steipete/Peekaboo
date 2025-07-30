import type { Logger } from "pino";
import { z } from "zod";
import type { AppInfo, AppResponseData, AppSuccessResponse, ToolResponse } from "../types/index.js";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";

// Zod schema for app tool
export const appToolSchema = z.object({
  action: z
    .enum(["launch", "quit", "relaunch", "focus", "hide", "unhide", "switch", "list"])
    .describe("The action to perform on the application"),
  name: z
    .string()
    .optional()
    .describe("Application name, bundle ID, or process ID (e.g., 'Safari', 'com.apple.Safari', 'PID:663')"),
  bundleId: z.string().optional().describe("Launch by bundle identifier instead of name (for 'launch' action)"),
  waitUntilReady: z
    .boolean()
    .optional()
    .describe("Wait for the application to be ready (for 'launch' and 'relaunch' actions)"),
  force: z.boolean().optional().describe("Force quit the application (for 'quit' and 'relaunch' actions)"),
  all: z.boolean().optional().describe("Quit all applications (for 'quit' action)"),
  except: z
    .string()
    .optional()
    .describe("Comma-separated list of apps to exclude when using --all (for 'quit' action)"),
  to: z.string().optional().describe("Application to switch to (for 'switch' action)"),
  cycle: z.boolean().optional().describe("Cycle to next application like Cmd+Tab (for 'switch' action)"),
  wait: z
    .number()
    .optional()
    .describe("Wait time in seconds between quit and launch (for 'relaunch' action, default: 2)"),
});

export type AppInput = z.infer<typeof appToolSchema>;

export async function appToolHandler(input: AppInput, context: { logger: Logger }): Promise<ToolResponse> {
  const { logger } = context;

  try {
    logger.debug({ input }, "App tool called");

    // Validate input based on action
    if (input.action === "launch" && !input.name && !input.bundleId) {
      return {
        content: [
          {
            type: "text",
            text: "❌ Launch action requires either 'name' or 'bundleId' parameter",
          },
        ],
        isError: true,
      };
    }

    if (input.action === "switch" && !input.to && !input.cycle) {
      return {
        content: [
          {
            type: "text",
            text: "❌ Switch action requires either 'to' parameter or 'cycle' flag",
          },
        ],
        isError: true,
      };
    }

    if (
      (input.action === "quit" || input.action === "focus" || input.action === "hide" || input.action === "unhide") &&
      !input.name &&
      !input.all
    ) {
      return {
        content: [
          {
            type: "text",
            text: `❌ ${input.action} action requires 'name' parameter${input.action === "quit" ? " or 'all' flag" : ""}`,
          },
        ],
        isError: true,
      };
    }

    // Build command arguments
    const args = ["app", input.action];

    if (input.name) {
      args.push(input.name);
    }

    if (input.bundleId && input.action === "launch") {
      args.push("--bundle-id", input.bundleId);
    }

    if (input.waitUntilReady && input.action === "launch") {
      args.push("--wait-until-ready");
    }

    if (input.force && input.action === "quit") {
      args.push("--force");
    }

    if (input.all && input.action === "quit") {
      args.push("--all");
    }

    if (input.except && input.action === "quit") {
      args.push("--except", input.except);
    }

    if (input.to && input.action === "switch") {
      args.push("--to", input.to);
    }

    if (input.cycle && input.action === "switch") {
      args.push("--cycle");
    }

    logger.debug({ args }, "Executing app command");

    const result = await executeSwiftCli(args, logger);

    logger.debug({ result }, "App command completed");

    // Handle Swift CLI response
    if (!result.success) {
      return {
        content: [
          {
            type: "text",
            text: `❌ App command failed: ${result.error?.message || "Unknown error"}`,
          },
        ],
        isError: true,
      };
    }

    // Parse the response data
    let responseData = result.data;
    if (typeof result.data === "string") {
      try {
        responseData = JSON.parse(result.data);
      } catch (parseError) {
        logger.warn({ parseError, data: result.data }, "Failed to parse app command JSON output");
        return {
          content: [
            {
              type: "text",
              text: `App ${input.action} completed. Output: ${result.data}`,
            },
          ],
          isError: false,
        };
      }
    }

    // Handle successful app command - the response format can vary
    if (responseData && typeof responseData === "object") {
      let appData = responseData as AppResponseData | AppSuccessResponse;

      // Check if it's wrapped in success/data structure
      if ("success" in appData && appData.success && appData.data) {
        appData = appData.data;
      } else {
        appData = appData as AppResponseData;
      }

      // Check for direct response format (which seems to be what we're getting)
      if (appData.action || appData.app || appData.pid) {
        let responseText = "";

        // Format the response based on action
        switch (input.action) {
          case "launch":
            responseText = `✅ Application '${input.bundleId || input.name}' launched successfully`;
            if (appData.pid) {
              responseText += `\nProcess ID: ${appData.pid}`;
            }
            if (appData.window_count !== undefined) {
              responseText += `\nWindow count: ${appData.window_count}`;
            }
            if (appData.activated !== undefined) {
              responseText += `\nActive: ${appData.activated ? "Yes" : "No"}`;
            }
            if (appData.bundle_id) {
              responseText += `\nBundle ID: ${appData.bundle_id}`;
            }
            break;

          case "quit":
            if (input.all) {
              responseText = `✅ All applications quit successfully`;
              if (input.except) {
                responseText += ` (except: ${input.except})`;
              }
            } else {
              responseText = `✅ Application '${input.name}' quit successfully`;
            }
            break;

          case "focus":
            responseText = `✅ Application '${input.name}' focused successfully`;
            break;

          case "switch":
            if (input.cycle) {
              responseText = `✅ Cycled to next application`;
            } else if (input.to) {
              responseText = `✅ Switched to application '${input.to}'`;
            } else {
              responseText = `✅ Application switch completed`;
            }
            break;

          case "hide":
            responseText = `✅ Application '${input.name}' hidden successfully`;
            break;

          case "unhide":
            responseText = `✅ Application '${input.name}' unhidden successfully`;
            break;

          case "list":
            responseText = "✅ Running applications:\n";
            if (appData.applications && Array.isArray(appData.applications)) {
              appData.applications.forEach((app: AppInfo) => {
                responseText += `\n• ${app.name || app.localizedName}`;
                if (app.bundleIdentifier) {
                  responseText += ` (${app.bundleIdentifier})`;
                }
                if (app.processIdentifier) {
                  responseText += ` - PID: ${app.processIdentifier}`;
                }
                if (app.isActive) {
                  responseText += " [Active]";
                }
                if (app.isHidden) {
                  responseText += " [Hidden]";
                }
              });
            }
            break;

          default:
            responseText = `✅ App ${input.action} completed successfully`;
        }

        if (appData.note) {
          responseText += `\n${appData.note}`;
        }

        return {
          content: [
            {
              type: "text",
              text: responseText,
            },
          ],
          isError: false,
        };
      }

      // Handle app command errors
      if ("error" in appData && appData.error) {
        const errorMessage =
          typeof appData.error === "string"
            ? appData.error
            : typeof appData.error === "object" && appData.error !== null && "message" in appData.error
              ? String((appData.error as { message: unknown }).message)
              : "App command failed";
        return {
          content: [
            {
              type: "text",
              text: `❌ App Error: ${errorMessage}`,
            },
          ],
          isError: true,
        };
      }
    }

    // Fallback for unexpected response format
    return {
      content: [
        {
          type: "text",
          text: `App ${input.action} completed with unexpected response format: ${JSON.stringify(responseData)}`,
        },
      ],
      isError: false,
    };
  } catch (error) {
    logger.error({ error, input }, "App tool execution failed");

    const errorMessage = error instanceof Error ? error.message : String(error);

    return {
      content: [
        {
          type: "text",
          text: `❌ App ${input.action} failed: ${errorMessage}`,
        },
      ],
      isError: true,
    };
  }
}
