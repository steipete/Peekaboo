import { z } from "zod";
import { ToolResponse } from "../types/index.js";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";
import { Logger } from "pino";

// Zod schema for window tool
export const windowToolSchema = z.object({
  action: z.enum(["close", "minimize", "maximize", "move", "resize", "set-bounds", "focus"]).describe("The action to perform on the window"),
  app: z.string().optional().describe("Target application name, bundle ID, or process ID"),
  title: z.string().optional().describe("Window title to target (partial matching supported)"),
  index: z.number().int().nonnegative().optional().describe("Window index (0-based) for multi-window applications"),
  x: z.number().optional().describe("X coordinate for move or set-bounds action"),
  y: z.number().optional().describe("Y coordinate for move or set-bounds action"),
  width: z.number().optional().describe("Width for resize or set-bounds action"),
  height: z.number().optional().describe("Height for resize or set-bounds action"),
});

export type WindowInput = z.infer<typeof windowToolSchema>;

export async function windowToolHandler(
  input: WindowInput,
  context: { logger: Logger },
): Promise<ToolResponse> {
  const { logger } = context;

  try {
    logger.debug({ input }, "Window tool called");

    // Build command arguments
    const args = ["window", input.action];

    if (input.app) {
      args.push("--app", input.app);
    }

    if (input.title) {
      args.push("--window-title", input.title);
    }

    if (input.index !== undefined) {
      args.push("--window-index", input.index.toString());
    }

    // Add position/size arguments for move and resize actions
    if (input.action === "move") {
      if (input.x === undefined || input.y === undefined) {
        return {
          content: [
            {
              type: "text",
              text: "❌ Move action requires both 'x' and 'y' coordinates",
            },
          ],
          isError: true,
        };
      }
      args.push("--x", input.x.toString(), "--y", input.y.toString());
    }

    if (input.action === "resize") {
      if (input.width === undefined || input.height === undefined) {
        return {
          content: [
            {
              type: "text",
              text: "❌ Resize action requires both 'width' and 'height' dimensions",
            },
          ],
          isError: true,
        };
      }
      args.push("--width", input.width.toString(), "--height", input.height.toString());
    }

    if (input.action === "set-bounds") {
      if (input.x === undefined || input.y === undefined || input.width === undefined || input.height === undefined) {
        return {
          content: [
            {
              type: "text",
              text: "❌ Set-bounds action requires all parameters: 'x', 'y', 'width', and 'height'",
            },
          ],
          isError: true,
        };
      }
      args.push("--x", input.x.toString(), "--y", input.y.toString(), "--width", input.width.toString(), "--height", input.height.toString());
    }

    logger.debug({ args }, "Executing window command");

    const result = await executeSwiftCli(args, logger);

    logger.debug({ result }, "Window command completed");

    // Handle Swift CLI response
    if (!result.success) {
      return {
        content: [
          {
            type: "text",
            text: `❌ Window command failed: ${result.error?.message || "Unknown error"}`,
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
        logger.warn({ parseError, data: result.data }, "Failed to parse window command JSON output");
        return {
          content: [
            {
              type: "text",
              text: `Window ${input.action} completed. Output: ${result.data}`,
            },
          ],
          isError: false,
        };
      }
    }

    // Handle error responses first
    if (responseData && typeof responseData === "object" && "error" in responseData) {
      const errorMessage = (responseData as any).error.message || "Window command failed";
      return {
        content: [
          {
            type: "text",
            text: `❌ Window Error: ${errorMessage}`,
          },
        ],
        isError: true,
      };
    }

    // Handle successful window command
    if (responseData && typeof responseData === "object" && "success" in responseData) {
      const windowResponse = responseData as any;

      if (windowResponse.success && windowResponse.data) {
        const windowData = windowResponse.data;
        let responseText = "";

        // Format the response based on action
        const targetDesc = input.app ? (input.title ? `'${input.title}' window of ${input.app}` : `${input.app} window`) : "window";

        switch (input.action) {
          case "close":
            responseText = `✅ Closed ${targetDesc}`;
            break;

          case "minimize":
            responseText = `✅ Minimized ${targetDesc}`;
            break;

          case "maximize":
            responseText = `✅ Maximized ${targetDesc}`;
            break;

          case "move":
            responseText = `✅ Moved ${targetDesc} to (${input.x}, ${input.y})`;
            break;

          case "resize":
            responseText = `✅ Resized ${targetDesc} to ${input.width}×${input.height}`;
            break;

          case "set-bounds":
            responseText = `✅ Set bounds of ${targetDesc} to (${input.x}, ${input.y}) with size ${input.width}×${input.height}`;
            break;

          case "focus":
            responseText = `✅ Focused ${targetDesc}`;
            break;

          default:
            responseText = `✅ Window ${input.action} completed successfully`;
        }

        if (windowData.message) {
          responseText += `\n${windowData.message}`;
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

      // Handle window command errors within wrapped response
      if (windowResponse.error) {
        const errorMessage = windowResponse.error.message || "Window command failed";
        return {
          content: [
            {
              type: "text",
              text: `❌ Window Error: ${errorMessage}`,
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
          text: `Window ${input.action} completed with unexpected response format: ${JSON.stringify(responseData)}`,
        },
      ],
      isError: false,
    };

  } catch (error) {
    logger.error({ error, input }, "Window tool execution failed");

    const errorMessage = error instanceof Error ? error.message : String(error);

    return {
      content: [
        {
          type: "text",
          text: `❌ Window ${input.action} failed: ${errorMessage}`,
        },
      ],
      isError: true,
    };
  }
}