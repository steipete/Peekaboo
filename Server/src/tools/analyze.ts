import path from "path";
import { z } from "zod";
import type { ToolContext, ToolResponse } from "../types/index.js";
import { analyzeImageWithProvider, determineProviderAndModel, parseAIProviders } from "../utils/ai-providers.js";
import { getAIProvidersConfig } from "../utils/config-loader.js";
import { readImageAsBase64 } from "../utils/peekaboo-cli.js";

export const analyzeToolSchema = z
  .object({
    image_path: z
      .string()
      .optional()
      .describe("Required. Absolute path to image file (.png, .jpg, .webp) to be analyzed."),
    question: z.string().describe("Required. Question for the AI about the image."),
    provider_config: z
      .object({
        type: z
          .enum(["auto", "ollama", "openai"])
          .default("auto")
          .describe(
            "AI provider, default: auto. 'auto' uses server's PEEKABOO_AI_PROVIDERS environment preference. Specific provider must be enabled in server's PEEKABOO_AI_PROVIDERS."
          ),
        model: z
          .string()
          .optional()
          .describe(
            "Optional. Model name. If omitted, uses model from server's PEEKABOO_AI_PROVIDERS for chosen provider, or an internal default for that provider."
          ),
      })
      .optional()
      .describe("Optional. Explicit provider/model. Validated against server's PEEKABOO_AI_PROVIDERS."),
  })
  .passthrough() // Allow unknown properties (for the hidden `path` parameter)
  .refine(
    (data: unknown) => {
      const typedData = data as { image_path?: string; path?: string };
      return typedData.image_path || typedData.path;
    },
    {
      message: "image_path is required",
      path: ["image_path"],
    }
  );

export type AnalyzeToolInput = z.infer<typeof analyzeToolSchema> & {
  path?: string; // Hidden parameter for backward compatibility
};

export async function analyzeToolHandler(input: AnalyzeToolInput, context: ToolContext): Promise<ToolResponse> {
  const { logger } = context;

  try {
    // Determine the effective image path (prioritize image_path, fallback to path)
    const effectiveImagePath = input.image_path || input.path || "";

    logger.debug(
      { input: { ...input, effectiveImagePath: effectiveImagePath.split("/").pop() } },
      "Processing peekaboo.analyze tool call"
    );

    // Validate image file extension
    const ext = path.extname(effectiveImagePath).toLowerCase();
    if (![".png", ".jpg", ".jpeg", ".webp"].includes(ext)) {
      return {
        content: [
          {
            type: "text" as const,
            text: `Unsupported image format: ${ext}. Supported formats: .png, .jpg, .jpeg, .webp`,
          },
        ],
        isError: true,
      };
    }

    // Check AI providers configuration
    const aiProvidersEnv = await getAIProvidersConfig(logger);
    if (!aiProvidersEnv || !aiProvidersEnv.trim()) {
      logger.error("PEEKABOO_AI_PROVIDERS not configured in environment or config file");
      return {
        content: [
          {
            type: "text" as const,
            text: "AI analysis not configured on this server. Set the PEEKABOO_AI_PROVIDERS environment variable or configure it in ~/.peekaboo/config.json",
          },
        ],
        isError: true,
      };
    }

    // Parse configured providers
    const configuredProviders = parseAIProviders(aiProvidersEnv);
    if (configuredProviders.length === 0) {
      return {
        content: [
          {
            type: "text" as const,
            text: "No valid AI providers found in PEEKABOO_AI_PROVIDERS configuration.",
          },
        ],
        isError: true,
      };
    }

    // Determine provider and model
    const { provider, model } = await determineProviderAndModel(input.provider_config, configuredProviders, logger);

    if (!provider) {
      return {
        content: [
          {
            type: "text" as const,
            text: "No configured AI providers are currently operational.",
          },
        ],
        isError: true,
      };
    }

    // Read image as base64
    let imageBase64: string;
    try {
      imageBase64 = await readImageAsBase64(effectiveImagePath);
    } catch (error) {
      logger.error({ error, path: effectiveImagePath }, "Failed to read image file");
      return {
        content: [
          {
            type: "text" as const,
            text: `Failed to read image file: ${error instanceof Error ? error.message : "Unknown error"}`,
          },
        ],
        isError: true,
      };
    }

    // Analyze image
    let analysisResult: string;
    const startTime = Date.now(); // Record start time
    try {
      analysisResult = await analyzeImageWithProvider(
        { provider, model },
        effectiveImagePath,
        imageBase64,
        input.question,
        logger
      );
    } catch (error) {
      logger.error({ error, provider, model }, "AI analysis failed");
      return {
        content: [
          {
            type: "text" as const,
            text: `AI analysis failed: ${error instanceof Error ? error.message : "Unknown error"}`,
          },
        ],
        isError: true,
        _meta: {
          backend_error_code: "AI_PROVIDER_ERROR",
        },
      };
    }

    const endTime = Date.now(); // Record end time
    const durationMs = endTime - startTime;
    const durationSeconds = (durationMs / 1000).toFixed(2);

    const analysisTimeMessage = `👻 Peekaboo: Analyzed image with ${provider}/${model} in ${durationSeconds}s.`;

    return {
      content: [
        {
          type: "text" as const,
          text: analysisResult,
        },
        {
          type: "text" as const,
          text: analysisTimeMessage, // Add the timing message
        },
      ],
      analysis_text: analysisResult,
      model_used: `${provider}/${model}`,
    };
  } catch (error) {
    logger.error({ error }, "Unexpected error in analyze tool handler");
    return {
      content: [
        {
          type: "text" as const,
          text: `Unexpected error: ${error instanceof Error ? error.message : "Unknown error"}`,
        },
      ],
      isError: true,
    };
  }
}
