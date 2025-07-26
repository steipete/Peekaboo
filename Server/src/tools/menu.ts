import { z } from "zod";
import { ToolResponse } from "../types/index.js";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";
import { Logger } from "pino";

// Zod schema for menu tool
export const menuToolSchema = z.object({
  action: z.enum(["list", "click"]).describe("Action to perform: 'list' to discover menus, 'click' to interact with menu items"),
  app: z.string().describe("Target application name, bundle ID, or process ID"),
  path: z.string().optional().describe("Menu path to click (e.g., 'File > Save As...' or 'Edit > Copy'). Required for 'click' action."),
});

export type MenuInput = z.infer<typeof menuToolSchema>;

export async function menuToolHandler(
  input: MenuInput,
  context: { logger: Logger }
): Promise<ToolResponse> {
  const { logger } = context;
  
  try {
    logger.debug({ input }, "Menu tool called");

    // Validate input based on action
    if (input.action === "click" && !input.path) {
      return {
        content: [
          {
            type: "text",
            text: "❌ Click action requires 'path' parameter (e.g., 'File > Save As...')"
          }
        ],
        isError: true
      };
    }

    // Build command arguments
    const args = ["menu", input.action, "--app", input.app];
    
    if (input.path) {
      args.push("--path", input.path);
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
            text: `❌ Menu command failed: ${result.error?.message || "Unknown error"}`
          }
        ],
        isError: true
      };
    }

    // Parse the response data
    let responseData = result.data;
    if (typeof result.data === 'string') {
      try {
        responseData = JSON.parse(result.data);
      } catch (parseError) {
        logger.warn({ parseError, data: result.data }, "Failed to parse menu command JSON output");
        return {
          content: [
            {
              type: "text",
              text: `Menu ${input.action} completed. Output: ${result.data}`
            }
          ],
          isError: false
        };
      }
    }

    // Handle error responses first
    if (responseData && typeof responseData === 'object' && 'error' in responseData) {
      const errorMessage = (responseData as any).error.message || "Menu command failed";
      return {
        content: [
          {
            type: "text",
            text: `❌ Menu Error: ${errorMessage}`
          }
        ],
        isError: true
      };
    }

    // Handle successful menu command
    if (responseData && typeof responseData === 'object' && 'success' in responseData) {
      const menuResponse = responseData as any;
      
      if (menuResponse.success && menuResponse.data) {
        const menuData = menuResponse.data;
        let responseText = "";

        if (input.action === "list") {
          responseText = `✅ Menu structure for ${input.app}:\n\n`;
          
          if (menuData.menus && Array.isArray(menuData.menus)) {
            menuData.menus.forEach((menu: any) => {
              responseText += `**${menu.title || menu.name}**\n`;
              if (menu.items && Array.isArray(menu.items)) {
                menu.items.forEach((item: any) => {
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
            menuData.menu_bar.forEach((menu: any) => {
              responseText += `**${menu.title}**\n`;
              if (menu.items) {
                menu.items.forEach((item: any) => {
                  responseText += `  • ${item.title || item.name}\n`;
                });
              }
              responseText += "\n";
            });
          } else {
            responseText += "Menu structure data available but in unexpected format.";
          }
          
        } else if (input.action === "click") {
          responseText = `✅ Successfully clicked menu item: ${input.path}`;
          if (menuData.message) {
            responseText += `\n${menuData.message}`;
          }
        }

        return {
          content: [
            {
              type: "text",
              text: responseText
            }
          ],
          isError: false
        };
      }

      // Handle menu command errors within wrapped response
      if (menuResponse.error) {
        const errorMessage = menuResponse.error.message || "Menu command failed";
        return {
          content: [
            {
              type: "text",
              text: `❌ Menu Error: ${errorMessage}`
            }
          ],
          isError: true
        };
      }
    }

    // Fallback for unexpected response format
    return {
      content: [
        {
          type: "text",
          text: `Menu ${input.action} completed with unexpected response format: ${JSON.stringify(responseData)}`
        }
      ],
      isError: false
    };

  } catch (error) {
    logger.error({ error, input }, "Menu tool execution failed");
    
    const errorMessage = error instanceof Error ? error.message : String(error);
    
    return {
      content: [
        {
          type: "text",
          text: `❌ Menu ${input.action} failed: ${errorMessage}`
        }
      ],
      isError: true
    };
  }
}