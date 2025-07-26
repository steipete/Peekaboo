import { z } from "zod";
import { ToolResponse } from "../types/index.js";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";
import { Logger } from "pino";

// Zod schema for app tool
export const appToolSchema = z.object({
  action: z.enum(["launch", "quit", "focus", "hide", "unhide", "switch"]).describe("The action to perform on the application"),
  name: z.string().describe("Application name, bundle ID, or process ID (e.g., 'Safari', 'com.apple.Safari', 'PID:663')"),
  force: z.boolean().optional().describe("Force quit the application (only applicable for 'quit' action)"),
});

export type AppInput = z.infer<typeof appToolSchema>;

export async function appToolHandler(
  input: AppInput,
  context: { logger: Logger }
): Promise<ToolResponse> {
  const { logger } = context;
  
  try {
    logger.debug({ input }, "App tool called");

    // Build command arguments
    const args = ["app", input.action, input.name];
    
    if (input.force && input.action === "quit") {
      args.push("--force");
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
            text: `❌ App command failed: ${result.error?.message || "Unknown error"}`
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
        logger.warn({ parseError, data: result.data }, "Failed to parse app command JSON output");
        return {
          content: [
            {
              type: "text",
              text: `App ${input.action} completed. Output: ${result.data}`
            }
          ],
          isError: false
        };
      }
    }

    // Handle successful app command - the response format can vary
    if (responseData && typeof responseData === 'object') {
      let appData = responseData as any;
      
      // Check if it's wrapped in success/data structure
      if ('success' in appData && appData.success && appData.data) {
        appData = appData.data;
      }
      
      // Check for direct response format (which seems to be what we're getting)
      if (appData.action || appData.app || appData.pid) {
        let responseText = "";

        // Format the response based on action
        switch (input.action) {
          case "launch":
            responseText = `✅ Application '${input.name}' launched successfully`;
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
            responseText = `✅ Application '${input.name}' quit successfully`;
            break;
            
          case "focus":
          case "switch":
            responseText = `✅ Application '${input.name}' focused successfully`;
            break;
            
          case "hide":
            responseText = `✅ Application '${input.name}' hidden successfully`;
            break;
            
          case "unhide":
            responseText = `✅ Application '${input.name}' unhidden successfully`;
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
              text: responseText
            }
          ],
          isError: false
        };
      }

      // Handle app command errors
      if ('error' in appData) {
        const errorMessage = appData.error.message || "App command failed";
        return {
          content: [
            {
              type: "text",
              text: `❌ App Error: ${errorMessage}`
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
          text: `App ${input.action} completed with unexpected response format: ${JSON.stringify(responseData)}`
        }
      ],
      isError: false
    };

  } catch (error) {
    logger.error({ error, input }, "App tool execution failed");
    
    const errorMessage = error instanceof Error ? error.message : String(error);
    
    return {
      content: [
        {
          type: "text",
          text: `❌ App ${input.action} failed: ${errorMessage}`
        }
      ],
      isError: true
    };
  }
}