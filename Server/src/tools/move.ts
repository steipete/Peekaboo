import { z } from "zod";
import type { ToolContext, ToolResponse } from "../types/index.js";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";

// Schema for move tool
export const moveToolSchema = z
  .object({
    coordinates: z
      .string()
      .regex(/^\d+,\d+$/, "Coordinates must be in format 'x,y'")
      .optional(),
    to: z.string().optional(),
    id: z.string().optional(),
    center: z.boolean().optional(),
    smooth: z.boolean().optional(),
    duration: z.number().int().positive().optional(),
    steps: z.number().int().positive().optional(),
    session: z.string().optional(),
  })
  .strict()
  .refine(
    (data) => {
      // At least one target must be specified
      return data.coordinates || data.to || data.id || data.center;
    },
    {
      message: "Must specify either coordinates, to, id, or center",
    }
  );

export type MoveInput = z.infer<typeof moveToolSchema>;

interface MoveOutput {
  action: string;
  position: {
    x: number;
    y: number;
  };
  target?: string;
  duration?: number;
}

export async function moveToolHandler(args: MoveInput, context: ToolContext): Promise<ToolResponse> {
  context.logger.debug("Moving mouse cursor", { args });

  try {
    const commandArgs = ["move"];

    // Add position arguments
    if (args.coordinates) {
      commandArgs.push(args.coordinates);
    }
    if (args.to) {
      commandArgs.push("--to", args.to);
    }
    if (args.id) {
      commandArgs.push("--id", args.id);
    }
    if (args.center) {
      commandArgs.push("--center");
    }

    // Add movement options
    if (args.smooth) {
      commandArgs.push("--smooth");
    }
    if (args.duration !== undefined) {
      commandArgs.push("--duration", args.duration.toString());
    }
    if (args.steps !== undefined) {
      commandArgs.push("--steps", args.steps.toString());
    }
    if (args.session) {
      commandArgs.push("--session", args.session);
    }

    // Always use JSON output
    commandArgs.push("--json-output");

    // Execute move command
    const result = await executeSwiftCli(
      commandArgs,
      context.logger,
      { timeout: 10000 } // Longer timeout for smooth movements
    );

    if (!result.success || !result.data) {
      throw new Error(result.error?.message || "Failed to move cursor");
    }

    const moveData = result.data as MoveOutput;

    // Format the response
    let responseText = `Moved cursor to (${moveData.position.x}, ${moveData.position.y})`;
    if (moveData.target) {
      responseText += ` on ${moveData.target}`;
    }
    if (args.smooth && moveData.duration) {
      responseText += ` over ${moveData.duration}ms`;
    }

    return {
      content: [
        {
          type: "text",
          text: responseText,
        },
      ],
      metadata: {
        position: moveData.position,
        target: moveData.target,
      },
    };
  } catch (error) {
    context.logger.error("Failed to move cursor", { error });
    return {
      content: [
        {
          type: "text",
          text: `Failed to move cursor: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
      isError: true,
    };
  }
}
