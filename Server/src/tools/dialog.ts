import { z } from "zod";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";
import { ToolContext, ToolResponse } from "../types/index.js";

// Schema for dialog tool
export const dialogToolSchema = z
  .object({
    action: z.enum(["click", "input", "file", "dismiss", "list"]),
    button: z.string().optional(),
    text: z.string().optional(),
    field: z.string().optional(),
    index: z.number().int().optional(),
    clear: z.boolean().optional(),
    path: z.string().optional(),
    name: z.string().optional(),
    select: z.string().optional(),
    window: z.string().optional(),
    force: z.boolean().optional(),
  })
  .strict()
  .refine(
    (data) => {
      // Validate required parameters for each action
      switch (data.action) {
        case "click":
          return !!data.button;
        case "input":
          return !!data.text;
        case "file":
          return !!data.path || !!data.name;
        case "dismiss":
        case "list":
          return true;
        default:
          return false;
      }
    },
    {
      message: "Missing required parameters for action",
    },
  );

export type DialogInput = z.infer<typeof dialogToolSchema>;

interface DialogElement {
  type: string;
  label?: string;
  value?: string;
  enabled: boolean;
}

interface DialogActionOutput {
  action: string;
  button?: string;
  window?: string;
  field?: string;
  path?: string;
  result?: string;
}

interface DialogListOutput {
  windows: Array<{
    title: string;
    type: string;
    elements: DialogElement[];
  }>;
}

export async function dialogToolHandler(
  args: DialogInput,
  context: ToolContext,
): Promise<ToolResponse> {
  context.logger.debug("Performing dialog operation", { args });

  try {
    const commandArgs = ["dialog", args.action];

    // Add action-specific parameters
    switch (args.action) {
      case "click":
        if (args.button) {
          commandArgs.push("--button", args.button);
        }
        break;
      case "input":
        if (args.text) {
          commandArgs.push("--text", args.text);
        }
        if (args.field) {
          commandArgs.push("--field", args.field);
        }
        if (args.index !== undefined) {
          commandArgs.push("--index", args.index.toString());
        }
        if (args.clear) {
          commandArgs.push("--clear");
        }
        break;
      case "file":
        if (args.path) {
          commandArgs.push("--path", args.path);
        }
        if (args.name) {
          commandArgs.push("--name", args.name);
        }
        if (args.select) {
          commandArgs.push("--select", args.select);
        }
        break;
      case "dismiss":
        if (args.force) {
          commandArgs.push("--force");
        }
        break;
    }

    // Add window parameter if provided
    if (args.window) {
      commandArgs.push("--window", args.window);
    }

    // Always use JSON output
    commandArgs.push("--json-output");

    // Execute dialog command
    const result = await executeSwiftCli(
      commandArgs,
      context.logger,
      { timeout: 10000 }
    );

    if (!result.success || !result.data) {
      throw new Error(result.error?.message || "Failed to perform dialog operation");
    }

    // Parse the JSON output
    if (args.action === "list") {
      const listData = result.data as DialogListOutput;
      
      // Format the list response
      const dialogsList = listData.windows
        .map((window) => {
          let windowText = `Dialog: ${window.title} (${window.type})`;
          if (window.elements.length > 0) {
            windowText += "\n  Elements:";
            window.elements.forEach((elem) => {
              windowText += `\n    • ${elem.type}`;
              if (elem.label) {
                windowText += `: "${elem.label}"`;
              }
              if (!elem.enabled) {
                windowText += " (disabled)";
              }
            });
          }
          return windowText;
        })
        .join("\n\n");

      return {
        content: [
          {
            type: "text",
            text: dialogsList || "No dialogs found",
          },
        ],
        metadata: {
          windows: listData.windows,
        },
      };
    } else {
      const actionData = result.data as DialogActionOutput;
      
      // Format action response
      let responseText = "";
      switch (args.action) {
        case "click":
          responseText = `✓ Clicked '${actionData.button || args.button}' button`;
          if (actionData.window) {
            responseText += ` in ${actionData.window}`;
          }
          break;
        case "input":
          responseText = `✓ Entered text`;
          if (actionData.field) {
            responseText += ` in '${actionData.field}' field`;
          }
          break;
        case "file":
          if (args.path) {
            responseText = `✓ Selected file: ${actionData.path || args.path}`;
          } else if (args.name) {
            responseText = `✓ Entered filename: ${args.name}`;
          }
          if (actionData.result) {
            responseText += ` and clicked '${actionData.result}'`;
          }
          break;
        case "dismiss":
          responseText = args.force ? "✓ Force dismissed dialog (ESC)" : "✓ Dismissed dialog";
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
    context.logger.error("Failed to perform dialog operation", { error });
    return {
      content: [
        {
          type: "text",
          text: `Failed to perform dialog operation: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
      isError: true,
    };
  }
}