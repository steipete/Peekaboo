import { ImageInput } from "../types/index.js";
import { Logger } from "pino";
import * as fs from "fs/promises";
import * as path from "path";
import * as os from "os";

export interface ResolvedImagePath {
  effectivePath: string | undefined;
  tempDirUsed: string | undefined;
}

export async function resolveImagePath(
  input: ImageInput,
  logger: Logger,
): Promise<ResolvedImagePath> {
  // If input.path is provided, use it directly
  if (input.path) {
    return { effectivePath: input.path, tempDirUsed: undefined };
  }

  // Check if a temporary directory is required
  // A temp dir is needed if:
  // 1. A question is present
  // 2. Format is explicitly set to 'data'
  const needsTempDir = input.question || input.format === "data";

  if (needsTempDir) {
    // Create a temporary directory
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "peekaboo-img-"));
    logger.debug({ tempPath: tempDir }, "Created temporary directory for capture");
    return { effectivePath: tempDir, tempDirUsed: tempDir };
  }

  // Check for PEEKABOO_DEFAULT_SAVE_PATH environment variable
  const defaultSavePath = process.env.PEEKABOO_DEFAULT_SAVE_PATH;
  if (defaultSavePath) {
    return { effectivePath: defaultSavePath, tempDirUsed: undefined };
  }

  // Final fallback: create a temporary directory
  // This happens when: no path, no question, no explicit 'data' format, no env var
  const fallbackTempDir = await fs.mkdtemp(path.join(os.tmpdir(), "peekaboo-img-"));
  logger.debug({ tempPath: fallbackTempDir }, "Created fallback temporary directory for capture");
  return { effectivePath: fallbackTempDir, tempDirUsed: fallbackTempDir };
}

export function buildSwiftCliArgs(
  input: ImageInput,
  effectivePath: string | undefined,
  swiftFormat?: string,
  logger?: Logger,
): string[] {
  const args = ["image"];

  // Use provided format or derive from input
  // Format validation is already handled by the schema preprocessor
  const inputFormat = input.format || "png";
  const actualFormat = swiftFormat || (inputFormat === "data" ? "png" : inputFormat);

  // Create a logger if not provided (for backward compatibility)
  const log = logger || {
    warn: (_msg: unknown) => {},
    error: (_msg: unknown) => {},
    debug: (_msg: unknown) => {},
  };

  // Parse app_target to determine Swift CLI arguments
  if (!input.app_target || input.app_target === "") {
    // Omitted/empty: All screens
    args.push("--mode", "screen");
  } else if (input.app_target.startsWith("screen:")) {
    // 'screen:INDEX': Specific display
    const screenIndexStr = input.app_target.substring(7);
    const screenIndex = parseInt(screenIndexStr, 10);
    if (isNaN(screenIndex) || screenIndex < 0) {
      log.warn(
        { screenIndex: screenIndexStr },
        `Invalid screen index '${screenIndexStr}' in app_target, capturing all screens.`,
      );
      args.push("--mode", "screen");
    } else {
      args.push("--mode", "screen", "--screen-index", screenIndex.toString());
    }
  } else if (input.app_target.toLowerCase() === "frontmost") {
    // 'frontmost': Capture the frontmost window of the frontmost app
    // This requires special handling to first find the frontmost app, then capture its frontmost window
    log.debug("Using frontmost mode - will attempt to capture frontmost window");
    args.push("--mode", "frontmost");
  } else if (input.app_target.includes(":")) {
    // 'AppName:WINDOW_TITLE:Title' or 'AppName:WINDOW_INDEX:Index'
    const parts = input.app_target.split(":");
    if (parts.length >= 3) {
      const appName = parts[0].trim();
      const specifierType = parts[1].trim();
      const specifierValue = parts.slice(2).join(":"); // Handle colons in window titles

      // Validate that we have a non-empty app name
      if (!appName) {
        log.warn(
          { app_target: input.app_target },
          "Empty app name detected in app_target, treating as malformed",
        );
        // Try to find the first non-empty part as the app name
        const nonEmptyParts = parts.filter(part => part.trim());
        if (nonEmptyParts.length > 0) {
          args.push("--app", nonEmptyParts[0].trim());
          args.push("--mode", "multi");
        } else {
          // All parts are empty, default to screen mode
          log.warn("All parts of app_target are empty, defaulting to screen mode");
          args.push("--mode", "screen");
        }
      } else {
        args.push("--app", appName);
        args.push("--mode", "window");

        if (specifierType.toUpperCase() === "WINDOW_TITLE") {
          args.push("--window-title", specifierValue);
        } else if (specifierType.toUpperCase() === "WINDOW_INDEX") {
          args.push("--window-index", specifierValue);
        } else {
          log.warn(
            { specifierType },
            "Unknown window specifier type, defaulting to main window",
          );
        }
      }
    } else {
      // Malformed: treat as app name, but validate it's not empty
      const cleanAppTarget = input.app_target.trim();
      if (!cleanAppTarget || cleanAppTarget === ":".repeat(cleanAppTarget.length)) {
        log.warn(
          { app_target: input.app_target },
          "Malformed app_target with only colons or empty, defaulting to screen mode",
        );
        args.push("--mode", "screen");
      } else {
        log.warn(
          { app_target: input.app_target },
          "Malformed window specifier, treating as app name",
        );
        // Remove trailing colons from app name
        const appName = cleanAppTarget.replace(/:+$/, "");
        args.push("--app", appName);
        args.push("--mode", "multi");
      }
    }
  } else {
    // 'AppName': All windows of that app
    args.push("--app", input.app_target.trim());
    args.push("--mode", "multi");
  }

  // Add path if it was provided
  if (effectivePath) {
    args.push("--path", effectivePath);
  }

  // Add format
  args.push("--format", actualFormat);

  // Add capture focus
  args.push("--capture-focus", input.capture_focus || "background");

  return args;
}
