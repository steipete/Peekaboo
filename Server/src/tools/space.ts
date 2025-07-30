import { z } from "zod";
import type { ToolContext, ToolResponse } from "../types/index.js";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";

// Schema for space tool - includes follow option
export const spaceToolSchema = z
  .object({
    action: z.enum(["list", "switch", "move-window"]),
    to: z.number().int().positive().optional(),
    to_current: z.boolean().optional(),
    app: z.string().optional(),
    window_title: z.string().optional(),
    window_index: z.number().int().optional(),
    detailed: z.boolean().optional(),
    follow: z.boolean().optional(), // Added missing option
  })
  .strict()
  .refine(
    (data) => {
      // switch requires 'to'
      if (data.action === "switch" && !data.to) {
        return false;
      }
      // move-window requires app and either 'to' or 'to_current'
      if (data.action === "move-window") {
        if (!data.app) {
          return false;
        }
        if (!data.to && !data.to_current) {
          return false;
        }
        if (data.to && data.to_current) {
          return false;
        } // Can't have both
      }
      // follow only valid with move-window
      if (data.follow && data.action !== "move-window") {
        return false;
      }
      return true;
    },
    {
      message: "Invalid combination of action and parameters",
    }
  );

export type SpaceInput = z.infer<typeof spaceToolSchema>;

interface SpaceInfo {
  id: number;
  type: string;
  is_active: boolean;
  display_id?: number;
}

interface SpaceListOutput {
  spaces: SpaceInfo[];
}

interface SpaceActionOutput {
  action: string;
  space?: number;
  app?: string;
  window?: string;
  result: string;
}

export async function spaceToolHandler(args: SpaceInput, context: ToolContext): Promise<ToolResponse> {
  context.logger.debug("Performing space operation", { args });

  try {
    const commandArgs = ["space", args.action];

    // Add action-specific parameters
    switch (args.action) {
      case "list":
        if (args.detailed) {
          commandArgs.push("--detailed");
        }
        break;
      case "switch":
        if (args.to) {
          commandArgs.push("--to", args.to.toString());
        }
        break;
      case "move-window":
        if (args.app) {
          commandArgs.push("--app", args.app);
        }
        if (args.to) {
          commandArgs.push("--to", args.to.toString());
        } else if (args.to_current) {
          commandArgs.push("--to-current");
        }
        if (args.window_title) {
          commandArgs.push("--window-title", args.window_title);
        }
        if (args.window_index !== undefined) {
          commandArgs.push("--window-index", args.window_index.toString());
        }
        if (args.follow) {
          commandArgs.push("--follow");
        }
        break;
    }

    // Always use JSON output
    commandArgs.push("--json-output");

    // Execute space command
    const result = await executeSwiftCli(commandArgs, context.logger, { timeout: 10000 });

    if (!result.success || !result.data) {
      throw new Error(result.error?.message || "Failed to perform space operation");
    }

    // Parse the JSON output
    if (args.action === "list") {
      const listData = result.data as SpaceListOutput;

      // Format the list response
      const spacesList = listData.spaces
        .map((space, index) => {
          const marker = space.is_active ? "→" : " ";
          let spaceText = `${marker} Space ${index + 1} [ID: ${space.id}, Type: ${space.type}`;
          if (space.display_id !== undefined) {
            spaceText += `, Display ${space.display_id}`;
          }
          spaceText += "]";
          return spaceText;
        })
        .join("\n");

      return {
        content: [
          {
            type: "text",
            text: `Spaces:\n${spacesList}`,
          },
        ],
        metadata: {
          spaces: listData.spaces,
        },
      };
    } else {
      const actionData = result.data as SpaceActionOutput;

      // Format action response
      let responseText = "";
      switch (args.action) {
        case "switch":
          responseText = `✓ Switched to Space ${actionData.space || args.to}`;
          break;
        case "move-window":
          responseText = `✓ Moved ${actionData.app || args.app}`;
          if (actionData.window) {
            responseText += ` window "${actionData.window}"`;
          }
          if (args.to_current) {
            responseText += " to current Space";
          } else {
            responseText += ` to Space ${actionData.space || args.to}`;
          }
          if (args.follow) {
            responseText += " (and switched to it)";
          }
          break;
      }

      return {
        content: [
          {
            type: "text",
            text: responseText,
          },
        ],
        metadata: actionData,
      };
    }
  } catch (error) {
    context.logger.error("Failed to perform space operation", { error });
    return {
      content: [
        {
          type: "text",
          text: `Failed to perform space operation: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
      isError: true,
    };
  }
}
