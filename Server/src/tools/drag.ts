import { z } from "zod";
import type { ToolContext, ToolResponse } from "../types/index.js";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";

// Schema for drag tool - includes focus options from CLI
export const dragToolSchema = z
  .object({
    from: z.string().optional(),
    from_coords: z
      .string()
      .regex(/^\d+,\d+$/, "Coordinates must be in format 'x,y'")
      .optional(),
    to: z.string().optional(),
    to_coords: z
      .string()
      .regex(/^\d+,\d+$/, "Coordinates must be in format 'x,y'")
      .optional(),
    to_app: z.string().optional(),
    session: z.string().optional(),
    duration: z.number().int().positive().optional(),
    steps: z.number().int().positive().optional(),
    modifiers: z.string().optional(),
    // Focus options
    auto_focus: z.boolean().optional(),
    space_switch: z.boolean().optional(),
    bring_to_current_space: z.boolean().optional(),
  })
  .strict()
  .refine(
    (data) => {
      // Must have a starting point
      const hasStart = data.from || data.from_coords;
      // Must have an ending point
      const hasEnd = data.to || data.to_coords || data.to_app;
      return hasStart && hasEnd;
    },
    {
      message: "Must specify both starting point (from/from_coords) and ending point (to/to_coords/to_app)",
    }
  );

export type DragInput = z.infer<typeof dragToolSchema>;

interface DragOutput {
  action: string;
  from: {
    x: number;
    y: number;
    element?: string;
  };
  to: {
    x: number;
    y: number;
    element?: string;
    app?: string;
  };
  duration: number;
}

export async function dragToolHandler(args: DragInput, context: ToolContext): Promise<ToolResponse> {
  context.logger.debug("Performing drag operation", { args });

  try {
    const commandArgs = ["drag"];

    // Add starting point
    if (args.from) {
      commandArgs.push("--from", args.from);
    }
    if (args.from_coords) {
      commandArgs.push("--from-coords", args.from_coords);
    }

    // Add ending point
    if (args.to) {
      commandArgs.push("--to", args.to);
    }
    if (args.to_coords) {
      commandArgs.push("--to-coords", args.to_coords);
    }
    if (args.to_app) {
      commandArgs.push("--to-app", args.to_app);
    }

    // Add options
    if (args.session) {
      commandArgs.push("--session", args.session);
    }
    if (args.duration !== undefined) {
      commandArgs.push("--duration", args.duration.toString());
    }
    if (args.steps !== undefined) {
      commandArgs.push("--steps", args.steps.toString());
    }
    if (args.modifiers) {
      commandArgs.push("--modifiers", args.modifiers);
    }

    // Add focus options
    if (args.auto_focus !== undefined) {
      commandArgs.push("--auto-focus", args.auto_focus.toString());
    }
    if (args.space_switch) {
      commandArgs.push("--space-switch");
    }
    if (args.bring_to_current_space) {
      commandArgs.push("--bring-to-current-space");
    }

    // Always use JSON output
    commandArgs.push("--json-output");

    // Execute drag command
    const result = await executeSwiftCli(
      commandArgs,
      context.logger,
      { timeout: 15000 } // Longer timeout for drag operations
    );

    if (!result.success || !result.data) {
      throw new Error(result.error?.message || "Failed to perform drag");
    }

    const dragData = result.data as DragOutput;

    // Format the response
    let responseText = `Dragged from (${dragData.from.x}, ${dragData.from.y})`;
    if (dragData.from.element) {
      responseText = `Dragged from ${dragData.from.element}`;
    }

    responseText += ` to (${dragData.to.x}, ${dragData.to.y})`;
    if (dragData.to.element) {
      responseText += ` on ${dragData.to.element}`;
    } else if (dragData.to.app) {
      responseText += ` to ${dragData.to.app}`;
    }

    responseText += ` over ${dragData.duration}ms`;

    return {
      content: [
        {
          type: "text",
          text: responseText,
        },
      ],
      metadata: {
        from: dragData.from,
        to: dragData.to,
        duration: dragData.duration,
      },
    };
  } catch (error) {
    context.logger.error("Failed to perform drag", { error });
    return {
      content: [
        {
          type: "text",
          text: `Failed to perform drag: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
      isError: true,
    };
  }
}
