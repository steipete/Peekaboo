import type { Logger } from "pino";
import { z } from "zod";
import type { Menu, MenuErrorResponse, MenuItem, MenuSuccessResponse, ToolResponse } from "../types/index.js";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";

// Zod schema for menu tool
export const menuToolSchema = z.object({
  action: z
    .enum(["list", "click", "click-extra", "list-all"])
    .describe(
      "Action to perform: 'list' to discover menus, 'click' to interact with menu items, 'click-extra' for system menu extras, 'list-all' for all menus"
    ),
  app: z
    .string()
    .optional()
    .describe("Target application name, bundle ID, or process ID (required for list and click actions)"),
  item: z.string().optional().describe("Simple menu item to click (for non-nested items)"),
  path: z.string().optional().describe("Menu path for nested items (e.g., 'File > Save As...' or 'Edit > Copy')"),
  title: z.string().optional().describe("Title of system menu extra (for click-extra action)"),
});

export type MenuInput = z.infer<typeof menuToolSchema>;

export async function menuToolHandler(input: MenuInput, context: { logger: Logger }): Promise<ToolResponse> {
  const { logger } = context;

  try {
    logger.debug({ input }, "Menu tool called");

    // Validate input based on action
    if (input.action === "click") {
      if (!input.item && !input.path) {
        return {
          content: [
            {
              type: "text",
              text: "❌ Click action requires either 'item' or 'path' parameter",
            },
          ],
          isError: true,
        };
      }
      if (input.item && input.path) {
        return {
          content: [
            {
              type: "text",
              text: "❌ Click action cannot have both 'item' and 'path' parameters",
            },
          ],
          isError: true,
        };
      }
      if (!input.app) {
        return {
          content: [
            {
              type: "text",
              text: "❌ Click action requires 'app' parameter",
            },
          ],
          isError: true,
        };
      }
    }

    if (input.action === "list" && !input.app) {
      return {
        content: [
          {
            type: "text",
            text: "❌ List action requires 'app' parameter",
          },
        ],
        isError: true,
      };
    }

    if (input.action === "click-extra" && !input.title) {
      return {
        content: [
          {
            type: "text",
            text: "❌ Click-extra action requires 'title' parameter for the menu extra",
          },
        ],
        isError: true,
      };
    }

    // Build command arguments
    const args = ["menu", input.action];

    if (input.app) {
      args.push("--app", input.app);
    }

    if (input.item) {
      args.push("--item", input.item);
    }

    if (input.path) {
      args.push("--path", input.path);
    }

    if (input.title) {
      args.push("--title", input.title);
    }

    logger.debug({ args }, "Executing menu command");

    const result = await executeSwiftCli(args, logger);

    logger.debug({ result }, "Menu command completed");

    // Handle Swift CLI response
    if (!result.success) {
      return {
        content: [
          {
            type: "text",
            text: `❌ Menu command failed: ${result.error?.message || "Unknown error"}`,
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
        logger.warn({ parseError, data: result.data }, "Failed to parse menu command JSON output");
        return {
          content: [
            {
              type: "text",
              text: `Menu ${input.action} completed. Output: ${result.data}`,
            },
          ],
          isError: false,
        };
      }
    }

    // Handle error responses first
    if (responseData && typeof responseData === "object" && "error" in responseData) {
      const errorResponse = responseData as MenuErrorResponse;
      const errorMessage = errorResponse.error.message || "Menu command failed";
      return {
        content: [
          {
            type: "text",
            text: `❌ Menu Error: ${errorMessage}`,
          },
        ],
        isError: true,
      };
    }

    // Handle successful menu command
    if (responseData && typeof responseData === "object" && "success" in responseData) {
      const menuResponse = responseData as MenuSuccessResponse | MenuErrorResponse;

      if (menuResponse.success && "data" in menuResponse && menuResponse.data) {
        const menuData = menuResponse.data;
        let responseText = "";

        if (input.action === "list") {
          responseText = `✅ Menu structure for ${input.app}:\n\n`;

          if (menuData.menus && Array.isArray(menuData.menus)) {
            menuData.menus.forEach((menu: Menu) => {
              responseText += `**${menu.title || menu.name}**\n`;
              if (menu.items && Array.isArray(menu.items)) {
                menu.items.forEach((item: MenuItem) => {
                  const itemName = item.title || item.name || "Unnamed Item";
                  const separator = item.separator ? " (separator)" : "";
                  const enabled = item.enabled === false ? " (disabled)" : "";
                  responseText += `  • ${itemName}${separator}${enabled}\n`;
                });
              }
              responseText += "\n";
            });
          } else if (menuData.menu_bar && Array.isArray(menuData.menu_bar)) {
            // Alternative format
            menuData.menu_bar.forEach((menu: Menu) => {
              responseText += `**${menu.title}**\n`;
              if (menu.items) {
                menu.items.forEach((item: MenuItem) => {
                  responseText += `  • ${item.title || item.name}\n`;
                });
              }
              responseText += "\n";
            });
          } else {
            responseText += "Menu structure data available but in unexpected format.";
          }
        } else if (input.action === "click") {
          const clickedItem = input.path || input.item || "menu item";
          responseText = `✅ Successfully clicked menu item: ${clickedItem}`;
          if (menuData.message) {
            responseText += `\n${menuData.message}`;
          }
        } else if (input.action === "click-extra") {
          responseText = `✅ Successfully clicked menu extra: ${input.title}`;
          if (menuData.message) {
            responseText += `\n${menuData.message}`;
          }
        } else if (input.action === "list-all") {
          responseText = `✅ All menus listed:\n\n`;
          // Similar structure to list, but for all applications
          if (menuData.menus && Array.isArray(menuData.menus)) {
            menuData.menus.forEach((menu: Menu) => {
              responseText += `**${menu.title || menu.name}**\n`;
              if (menu.items && Array.isArray(menu.items)) {
                menu.items.forEach((item: MenuItem) => {
                  const itemName = item.title || item.name || "Unnamed Item";
                  const separator = item.separator ? " (separator)" : "";
                  const enabled = item.enabled === false ? " (disabled)" : "";
                  responseText += `  • ${itemName}${separator}${enabled}\n`;
                });
              }
              responseText += "\n";
            });
          }
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

      // Handle menu command errors within wrapped response
      if (!menuResponse.success) {
        const errorResponse = menuResponse as MenuErrorResponse;
        const errorMessage = errorResponse.error?.message || "Menu command failed";
        return {
          content: [
            {
              type: "text",
              text: `❌ Menu Error: ${errorMessage}`,
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
          text: `Menu ${input.action} completed with unexpected response format: ${JSON.stringify(responseData)}`,
        },
      ],
      isError: false,
    };
  } catch (error) {
    logger.error({ error, input }, "Menu tool execution failed");

    const errorMessage = error instanceof Error ? error.message : String(error);

    return {
      content: [
        {
          type: "text",
          text: `❌ Menu ${input.action} failed: ${errorMessage}`,
        },
      ],
      isError: true,
    };
  }
}
