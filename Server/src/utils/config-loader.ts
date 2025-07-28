import * as fs from "fs/promises";
import * as path from "path";
import * as os from "os";
import { Logger } from "pino";

interface PeekabooConfig {
  aiProviders?: {
    providers?: string;
  };
  agent?: {
    defaultModel?: string;
    maxTokens?: number;
    temperature?: number;
  };
  logging?: {
    level?: string;
    path?: string;
  };
  defaults?: {
    savePath?: string;
    imageFormat?: string;
    captureMode?: string;
    captureFocus?: string;
  };
}

interface PeekabooCredentials {
  [key: string]: string;
}

/**
 * Loads Peekaboo configuration from the config file
 */
export async function loadPeekabooConfig(logger: Logger): Promise<PeekabooConfig> {
  const configPath = path.join(os.homedir(), ".peekaboo", "config.json");
  
  try {
    const configContent = await fs.readFile(configPath, "utf-8");
    // Remove comments for JSONC support
    const jsonContent = configContent.replace(/\/\/.*$/gm, "").replace(/\/\*[\s\S]*?\*\//g, "");
    const config = JSON.parse(jsonContent) as PeekabooConfig;
    logger.debug({ configPath }, "Loaded Peekaboo config file");
    return config;
  } catch (error) {
    if ((error as any).code === "ENOENT") {
      logger.debug({ configPath }, "Peekaboo config file not found");
    } else {
      logger.warn({ error, configPath }, "Failed to load Peekaboo config file");
    }
    return {};
  }
}

/**
 * Loads Peekaboo credentials from the credentials file
 */
export async function loadPeekabooCredentials(logger: Logger): Promise<PeekabooCredentials> {
  const credentialsPath = path.join(os.homedir(), ".peekaboo", "credentials");
  
  try {
    const credentialsContent = await fs.readFile(credentialsPath, "utf-8");
    const credentials: PeekabooCredentials = {};
    
    // Parse key=value format
    const lines = credentialsContent.split("\n");
    for (const line of lines) {
      const trimmedLine = line.trim();
      if (trimmedLine && !trimmedLine.startsWith("#")) {
        const [key, ...valueParts] = trimmedLine.split("=");
        if (key && valueParts.length > 0) {
          credentials[key.trim()] = valueParts.join("=").trim();
        }
      }
    }
    
    logger.debug({ credentialsPath, count: Object.keys(credentials).length }, "Loaded Peekaboo credentials");
    return credentials;
  } catch (error) {
    if ((error as any).code === "ENOENT") {
      logger.debug({ credentialsPath }, "Peekaboo credentials file not found");
    } else {
      logger.warn({ error, credentialsPath }, "Failed to load Peekaboo credentials");
    }
    return {};
  }
}

/**
 * Gets AI providers configuration from environment or config file
 */
export async function getAIProvidersConfig(logger: Logger): Promise<string | undefined> {
  // Priority 1: Environment variable
  if (process.env.PEEKABOO_AI_PROVIDERS) {
    return process.env.PEEKABOO_AI_PROVIDERS;
  }
  
  // Priority 2: Config file
  const config = await loadPeekabooConfig(logger);
  if (config.aiProviders?.providers) {
    logger.info("Using AI providers from Peekaboo config file");
    return config.aiProviders.providers;
  }
  
  return undefined;
}

/**
 * Sets up environment variables from credentials file if not already set
 */
export async function setupEnvironmentFromCredentials(logger: Logger): Promise<void> {
  const credentials = await loadPeekabooCredentials(logger);
  
  // Only set environment variables if they're not already set
  for (const [key, value] of Object.entries(credentials)) {
    if (!process.env[key]) {
      process.env[key] = value;
      logger.debug({ key }, "Set environment variable from credentials");
    }
  }
}