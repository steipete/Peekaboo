import { Logger } from "pino";
import fs from "fs/promises";
import path from "path";
import os from "os";
import { parseAIProviders, analyzeImageWithProvider } from "./ai-providers.js";

export async function performAutomaticAnalysis(
  base64Image: string,
  question: string,
  logger: Logger,
  availableProvidersEnv: string,
): Promise<{
  analysisText?: string;
  modelUsed?: string;
  error?: string;
}> {
  const providers = parseAIProviders(availableProvidersEnv);

  if (!providers.length) {
    return {
      error: "Analysis skipped: No AI providers configured",
    };
  }

  // Try each provider in order until one succeeds
  for (const provider of providers) {
    try {
      logger.debug(
        { provider: `${provider.provider}/${provider.model}` },
        "Attempting analysis with provider",
      );

      // Create a temporary file for the provider (some providers need file paths)
      const tempDir = await fs.mkdtemp(
        path.join(os.tmpdir(), "peekaboo-analysis-"),
      );
      const tempPath = path.join(tempDir, "image.png");
      const imageBuffer = Buffer.from(base64Image, "base64");
      await fs.writeFile(tempPath, imageBuffer);

      try {
        const analysisText = await analyzeImageWithProvider(
          provider,
          tempPath,
          base64Image,
          question,
          logger,
        );

        // Clean up temp file
        await fs.unlink(tempPath);
        await fs.rmdir(tempDir);

        return {
          analysisText,
          modelUsed: `${provider.provider}/${provider.model}`,
        };
      } finally {
        // Ensure cleanup even if analysis fails
        try {
          await fs.unlink(tempPath);
          await fs.rmdir(tempDir);
        } catch {
          // Ignore cleanup errors
        }
      }
    } catch (error) {
      logger.debug(
        { error, provider: `${provider.provider}/${provider.model}` },
        "Provider failed, trying next",
      );
      // Continue to next provider
    }
  }

  return {
    error: "Analysis failed: All configured AI providers failed or are unavailable",
  };
}