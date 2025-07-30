import { z } from "zod";
import type { ToolContext, ToolResponse } from "../types/index.js";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";

// Schema for dock tool
export const dockToolSchema = z
  .object({
    action: z.enum(["launch", "right-click", "hide", "show", "list"]),
    app: z.string().optional(),
    select: z.string().optional(),
    include_all: z.boolean().optional(), // For list action
  })
  .strict()
  .refine(
    (data) => {
      // launch and right-click require app
      if ((data.action === "launch" || data.action === "right-click") && !data.app) {
        return false;
      }
      // select only valid with right-click
      if (data.select && data.action !== "right-click") {
        return false;
      }
      // include_all only valid with list
      if (data.include_all && data.action !== "list") {
        return false;
      }
      return true;
    },
    {
      message: "Invalid combination of action and parameters",
    }
  );

export type DockInput = z.infer<typeof dockToolSchema>;

interface DockItem {
  title: string;
  type: string;
  bundle_id?: string;
  path?: string;
}

interface DockActionOutput {
  action: string;
  app?: string;
  item?: string;
  result?: string;
}

interface DockListOutput {
  items: DockItem[];
}

export async function dockToolHandler(args: DockInput, context: ToolContext): Promise<ToolResponse> {
  context.logger.debug("Performing dock operation", { args });

  try {
    const commandArgs = ["dock", args.action];

    // Add app parameter for launch and right-click
    if (args.app && (args.action === "launch" || args.action === "right-click")) {
      if (args.action === "launch") {
        commandArgs.push(args.app);
      } else {
        commandArgs.push("--app", args.app);
      }
    }

    // Add select parameter for right-click
    if (args.select && args.action === "right-click") {
      commandArgs.push("--select", args.select);
    }

    // Add include-all for list
    if (args.include_all && args.action === "list") {
      commandArgs.push("--include-all");
    }

    // Always use JSON output
    commandArgs.push("--json-output");

    // Execute dock command
    const result = await executeSwiftCli(commandArgs, context.logger, { timeout: 10000 });

    if (!result.success || !result.data) {
      throw new Error(result.error?.message || "Failed to perform dock operation");
    }

    // Parse the JSON output
    if (args.action === "list") {
      const listData = result.data as DockListOutput;

      // Format the list response
      const itemsList = listData.items
        .map((item) => {
          let itemText = `• ${item.title} (${item.type})`;
          if (item.bundle_id) {
            itemText += ` - ${item.bundle_id}`;
          }
          return itemText;
        })
        .join("\n");

      return {
        content: [
          {
            type: "text",
            text: `Dock items:\n${itemsList}`,
          },
        ],
        metadata: {
          items: listData.items,
        },
      };
    } else {
      const actionData = result.data as DockActionOutput;

      // Format action response
      let responseText = "";
      switch (args.action) {
        case "launch":
          responseText = `✓ Launched ${actionData.app || args.app} from Dock`;
          break;
        case "right-click":
          if (args.select) {
            responseText = `✓ Selected "${args.select}" from ${args.app} context menu`;
          } else {
            responseText = `✓ Right-clicked ${args.app} in Dock`;
          }
          break;
        case "hide":
          responseText = "✓ Dock hidden";
          break;
        case "show":
          responseText = "✓ Dock shown";
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
    context.logger.error("Failed to perform dock operation", { error });
    return {
      content: [
        {
          type: "text",
          text: `Failed to perform dock operation: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
      isError: true,
    };
  }
}
