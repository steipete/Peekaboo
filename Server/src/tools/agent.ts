import { z } from "zod";
import { ToolResponse } from "../types/index.js";
import { executeSwiftCli } from "../utils/peekaboo-cli.js";
import { Logger } from "pino";

// Zod schema for agent tool
export const agentToolSchema = z.object({
  task: z.string().describe("Natural language description of the task to perform"),
  verbose: z.boolean().optional().describe("Enable verbose output with full JSON debug information"),
  quiet: z.boolean().optional().describe("Quiet mode - only show final result"),
  dry_run: z.boolean().optional().describe("Dry run - show planned steps without executing"),
  max_steps: z.number().int().positive().optional().describe("Maximum number of steps the agent can take"),
  model: z.string().optional().describe("OpenAI model to use (e.g., gpt-4-turbo, gpt-4o)")
});

export type AgentInput = z.infer<typeof agentToolSchema>;

export async function agentToolHandler(
  input: AgentInput,
  context: { logger: Logger }
): Promise<ToolResponse> {
  const { logger } = context;
  
  try {
    logger.debug({ input }, "Agent tool called");

    // Check for OpenAI API key
    if (!process.env.OPENAI_API_KEY) {
      return {
        content: [
          {
            type: "text",
            text: "Agent command requires OPENAI_API_KEY environment variable to be set. Please configure your OpenAI API key to use the agent functionality."
          }
        ],
        isError: true
      };
    }

    // Build command arguments
    const args = ["agent", input.task];
    
    if (input.verbose) {
      args.push("--verbose");
    }
    
    if (input.quiet) {
      args.push("--quiet");
    }
    
    if (input.dry_run) {
      args.push("--dry-run");
    }
    
    if (input.max_steps !== undefined) {
      args.push("--max-steps", input.max_steps.toString());
    }
    
    if (input.model) {
      args.push("--model", input.model);
    }

    // Always use JSON output for MCP integration
    args.push("--json-output");

    logger.debug({ args }, "Executing agent command");

    const result = await executeSwiftCli(args, logger, {
      timeout: 300000, // 5 minute timeout for agent tasks
    });

    logger.debug({ result }, "Agent command completed");

    // Handle Swift CLI response
    if (!result.success) {
      return {
        content: [
          {
            type: "text",
            text: `❌ Agent command failed: ${result.error?.message || "Unknown error"}`
          }
        ],
        isError: true
      };
    }

    // For agent command, the response should already be structured JSON in the data field
    let parsedResult = result.data;
    
    // If data is a string, try to parse it as JSON
    if (typeof result.data === 'string') {
      try {
        parsedResult = JSON.parse(result.data);
      } catch (parseError) {
        // If JSON parsing fails, return the raw output
        logger.warn({ parseError, data: result.data }, "Failed to parse agent JSON output");
        return {
          content: [
            {
              type: "text",
              text: `Agent task completed. Output: ${result.data}`
            }
          ],
          isError: false
        };
      }
    }

    // Handle successful agent execution
    if (parsedResult && typeof parsedResult === 'object' && 'success' in parsedResult) {
      const agentResponse = parsedResult as any;
      
      if (agentResponse.success && agentResponse.data) {
        const agentData = agentResponse.data;
        let responseText = "";

        // Format the response based on agent output
        if (agentData.summary) {
          responseText = `✅ Agent Task Completed\n\n${agentData.summary}`;
        } else {
          responseText = "✅ Agent task completed successfully";
        }

        // Add steps information if available and verbose
        if (input.verbose && agentData.steps && Array.isArray(agentData.steps)) {
          responseText += `\n\nSteps executed (${agentData.steps.length}):`;
          agentData.steps.forEach((step: any, index: number) => {
            responseText += `\n${index + 1}. ${step.description || step.command || "Unknown step"}`;
            if (step.output && step.output.length < 100) {
              responseText += ` → ${step.output}`;
            }
          });
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

      // Handle agent errors
      if (agentResponse.error) {
        const errorMessage = agentResponse.error.message || "Agent execution failed";
        return {
          content: [
            {
              type: "text",
              text: `❌ Agent Error: ${errorMessage}`
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
          text: `Agent execution completed with unexpected response format: ${JSON.stringify(parsedResult)}`
        }
      ],
      isError: false
    };

  } catch (error) {
    logger.error({ error, input }, "Agent tool execution failed");
    
    const errorMessage = error instanceof Error ? error.message : String(error);
    
    // Check for specific error types
    if (errorMessage.includes("OPENAI_API_KEY")) {
      return {
        content: [
          {
            type: "text",
            text: "❌ OpenAI API key missing or invalid. Please set the OPENAI_API_KEY environment variable."
          }
        ],
        isError: true
      };
    }
    
    if (errorMessage.includes("timeout")) {
      return {
        content: [
          {
            type: "text",
            text: "❌ Agent task timed out. The task may be too complex or the system may be unresponsive."
          }
        ],
        isError: true
      };
    }

    return {
      content: [
        {
          type: "text",
          text: `❌ Agent execution failed: ${errorMessage}`
        }
      ],
      isError: true
    };
  }
}