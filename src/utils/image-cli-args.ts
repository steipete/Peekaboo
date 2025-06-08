import { ImageInput } from "../types/index.js";
import { Logger } from "pino";

export function buildSwiftCliArgs(
  input: ImageInput,
  logger?: Logger,
  effectivePath?: string | undefined,
  swiftFormat?: string,
): string[] {
  const args = ["image"];

  // Use provided values or derive from input
  const actualPath = effectivePath !== undefined ? effectivePath : input.path;
  const actualFormat = swiftFormat || (input.format === "data" ? "png" : input.format) || "png";

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
  } else if (input.app_target === "frontmost") {
    // 'frontmost': All windows of the frontmost app
    log.warn(
      "'frontmost' target requires determining current frontmost app, defaulting to screen mode",
    );
    args.push("--mode", "screen");
  } else if (input.app_target.includes(":")) {
    // 'AppName:WINDOW_TITLE:Title' or 'AppName:WINDOW_INDEX:Index'
    const parts = input.app_target.split(":");
    if (parts.length >= 3) {
      const appName = parts[0];
      const specifierType = parts[1];
      const specifierValue = parts.slice(2).join(":"); // Handle colons in window titles

      args.push("--app", appName);
      args.push("--mode", "window");

      if (specifierType === "WINDOW_TITLE") {
        args.push("--window-title", specifierValue);
      } else if (specifierType === "WINDOW_INDEX") {
        args.push("--window-index", specifierValue);
      } else {
        log.warn(
          { specifierType },
          "Unknown window specifier type, defaulting to main window",
        );
      }
    } else {
      // Malformed: treat as app name
      log.warn(
        { app_target: input.app_target },
        "Malformed window specifier, treating as app name",
      );
      args.push("--app", input.app_target);
      args.push("--mode", "multi");
    }
  } else {
    // 'AppName': All windows of that app
    args.push("--app", input.app_target);
    args.push("--mode", "multi");
  }

  // Add path if provided. This is crucial for temporary files.
  if (actualPath) {
    args.push("--path", actualPath);
  } else if (process.env.PEEKABOO_DEFAULT_SAVE_PATH && !input.question) {
    args.push("--path", process.env.PEEKABOO_DEFAULT_SAVE_PATH);
  }

  // Add format
  args.push("--format", actualFormat);

  // Add capture focus
  args.push("--capture-focus", input.capture_focus || "background");

  return args;
}