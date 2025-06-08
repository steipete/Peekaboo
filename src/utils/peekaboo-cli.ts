/// <reference types="node" />

import { spawn } from "child_process";
import path from "path";
// import { fileURLToPath } from 'url'; // No longer needed here
import { Logger } from "pino";
import fsPromises from "fs/promises";
import { existsSync } from "fs";
import { SwiftCliResponse } from "../types/index.js";

let resolvedCliPath: string | null = null;
const INVALID_PATH_SENTINEL = "PEEKABOO_CLI_PATH_RESOLUTION_FAILED";

function determineSwiftCliPath(packageRootDirForFallback?: string): string {
  const envPath = process.env.PEEKABOO_CLI_PATH;
  if (envPath) {
    try {
      if (existsSync(envPath)) {
        return envPath;
      }
      // If envPath is set but invalid, fall through to use packageRootDirForFallback
    } catch (_err) {
      /* Fall through if existsSync fails */
    }
  }

  if (packageRootDirForFallback) {
    return path.resolve(packageRootDirForFallback, "peekaboo");
  }

  // If neither PEEKABOO_CLI_PATH is valid nor packageRootDirForFallback is provided,
  // this is a critical failure in path determination.
  return INVALID_PATH_SENTINEL;
}

export function initializeSwiftCliPath(packageRootDir: string): void {
  if (!packageRootDir) {
    // If PEEKABOO_CLI_PATH is also not set or invalid, this will lead to INVALID_PATH_SENTINEL
    // Allow determineSwiftCliPath to handle this, and the error will be caught by getInitializedSwiftCliPath
  }
  resolvedCliPath = determineSwiftCliPath(packageRootDir);
  // No direct logging here; issues will be caught by getInitializedSwiftCliPath
}

function getInitializedSwiftCliPath(logger: Logger): string {
  // Logger is now mandatory
  if (!resolvedCliPath || resolvedCliPath === INVALID_PATH_SENTINEL) {
    const errorMessage = "Peekaboo Swift CLI path is not properly initialized or resolution failed. " +
      `Resolved path: '${resolvedCliPath}'. Ensure PEEKABOO_CLI_PATH is valid or ` +
      "initializeSwiftCliPath() was called with a correct package root directory at startup.";
    logger.error(errorMessage);
    // Throw an error to prevent attempting to use an invalid path
    throw new Error(errorMessage);
  }
  return resolvedCliPath;
}

function mapExitCodeToErrorMessage(
  exitCode: number,
  stderr: string,
  command: "image" | "list",
  appTarget?: string,
): { message: string; code: string } {
  const defaultMessage = stderr.trim()
    ? "Peekaboo CLI Error: " + stderr.trim()
    : "Swift CLI execution failed (exit code: " + exitCode + ")";

  // Handle exit code 18 specially with command context
  if (exitCode === 18) {
    return {
      message: "The specified application ('" + (appTarget || "unknown") + "') is not running or could not be found.",
      code: "SWIFT_CLI_APP_NOT_FOUND",
    };
  }

  const errorCodeMap: { [key: number]: { message: string; code: string } } = {
    1: { message: "An unknown error occurred in the Swift CLI.", code: "SWIFT_CLI_UNKNOWN_ERROR" },
    7: { message: "The specified application is running but has no capturable windows. Try setting 'capture_focus' to 'foreground' to un-hide application windows.", code: "SWIFT_CLI_NO_WINDOWS_FOUND" },
    10: { message: "No displays available for capture.", code: "SWIFT_CLI_NO_DISPLAYS" },
    11: {
      message: "Screen Recording permission is not granted. Please enable it in System Settings > Privacy & Security > Screen Recording.",
      code: "SWIFT_CLI_NO_SCREEN_RECORDING_PERMISSION",
    },
    12: {
      message: "Accessibility permission is not granted. Please enable it in System Settings > Privacy & Security > Accessibility.",
      code: "SWIFT_CLI_NO_ACCESSIBILITY_PERMISSION",
    },
    13: { message: "Invalid display ID provided for capture.", code: "SWIFT_CLI_INVALID_DISPLAY_ID" },
    14: { message: "The screen capture could not be created.", code: "SWIFT_CLI_CAPTURE_CREATION_FAILED" },
    15: { message: "The specified window was not found.", code: "SWIFT_CLI_WINDOW_NOT_FOUND" },
    16: { message: "Failed to capture the specified window.", code: "SWIFT_CLI_WINDOW_CAPTURE_FAILED" },
    17: {
      message: "Failed to write the capture to a file. This is often a file permissions issue. Please ensure the application has permissions to write to the destination directory.",
      code: "SWIFT_CLI_FILE_WRITE_ERROR",
    },
    19: { message: "The specified window index is invalid.", code: "SWIFT_CLI_INVALID_WINDOW_INDEX" },
    20: { message: "Invalid argument provided to the Swift CLI.", code: "SWIFT_CLI_INVALID_ARGUMENT" },
  };
  return errorCodeMap[exitCode] || { message: defaultMessage, code: "SWIFT_CLI_EXECUTION_ERROR" };
}

export async function executeSwiftCli(
  args: string[],
  logger: Logger,
): Promise<SwiftCliResponse> {
  let cliPath: string;
  try {
    cliPath = getInitializedSwiftCliPath(logger);
  } catch (error) {
    // Error already logged by getInitializedSwiftCliPath
    return {
      success: false,
      error: {
        message: (error as Error).message,
        code: "SWIFT_CLI_PATH_INIT_ERROR",
        details: (error as Error).stack,
      },
    };
  }

  // Always add --json-output flag
  const fullArgs = [...args, "--json-output"];

  logger.debug({ command: cliPath, args: fullArgs }, "Executing Swift CLI");

  return new Promise((resolve) => {
    const process = spawn(cliPath, fullArgs);

    let stdout = "";
    let stderr = "";

    process.stdout.on("data", (data: Buffer | string) => {
      stdout += data.toString();
    });

    process.stderr.on("data", (data: Buffer | string) => {
      const stderrData = data.toString();
      stderr += stderrData;
      // Log stderr immediately as it comes in
      logger.warn({ swift_stderr: stderrData.trim() }, "[SwiftCLI-stderr]");
    });

    process.on("close", (exitCode: number | null) => {
      logger.debug(
        { exitCode, stdout: stdout.slice(0, 200) },
        "Swift CLI completed",
      );

      // Always try to parse JSON first, even on non-zero exit codes
      if (!stdout.trim()) {
        logger.error(
          { exitCode, stdout, stderr },
          "Swift CLI execution failed with no output",
        );

        // Determine command and app target from args for fallback error message
        const command = args[0] as "image" | "list";
        let appTarget: string | undefined;

        // Find app target in args
        const appIndex = args.indexOf("--app");
        if (appIndex !== -1 && appIndex < args.length - 1) {
          appTarget = args[appIndex + 1];
        }

        const { message, code } = mapExitCodeToErrorMessage(exitCode || 1, stderr, command, appTarget);
        const errorDetails = stderr.trim() || "No output received";

        resolve({
          success: false,
          error: {
            message,
            code,
            details: errorDetails,
          },
        });
        return;
      }

      try {
        // Handle multiple JSON objects by taking the first valid one
        let jsonResponse: SwiftCliResponse;
        const trimmedOutput = stdout.trim();

        // Try to parse as single JSON first
        try {
          jsonResponse = JSON.parse(trimmedOutput);
        } catch (firstParseError) {
          // If that fails, try to extract the first complete JSON object
          // This handles cases where Swift CLI outputs multiple JSON objects
          const lines = trimmedOutput.split("\n");
          let braceCount = 0;
          let firstJsonEnd = -1;

          for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            for (let j = 0; j < line.length; j++) {
              if (line[j] === "{") {
                braceCount++;
              } else if (line[j] === "}") {
                braceCount--;
              }

              if (braceCount === 0 && line[j] === "}") {
                firstJsonEnd = i;
                break;
              }
            }
            if (firstJsonEnd !== -1) {
              break;
            }
          }

          if (firstJsonEnd !== -1) {
            const firstJsonLines = lines.slice(0, firstJsonEnd + 1);
            const firstJsonStr = firstJsonLines.join("\n");
            jsonResponse = JSON.parse(firstJsonStr);
            logger.debug("Extracted first JSON object from multi-object output");
          } else {
            throw firstParseError; // Re-throw original error if extraction fails
          }
        }

        const response = jsonResponse;

        // Log debug messages from Swift CLI
        if (response.debug_logs && Array.isArray(response.debug_logs)) {
          response.debug_logs.forEach((entry) => {
            logger.debug({ backend: "swift", swift_log: entry });
          });
        }

        resolve(response);
      } catch (parseError) {
        logger.error(
          { parseError, stdout, exitCode },
          "Failed to parse Swift CLI JSON output, falling back to exit code mapping",
        );

        // Determine command and app target from args for fallback error message
        const command = args[0] as "image" | "list";
        let appTarget: string | undefined;

        // Find app target in args
        const appIndex = args.indexOf("--app");
        if (appIndex !== -1 && appIndex < args.length - 1) {
          appTarget = args[appIndex + 1];
        }

        const { message, code } = mapExitCodeToErrorMessage(exitCode || 1, stderr, command, appTarget);

        resolve({
          success: false,
          error: {
            message,
            code,
            details: `Failed to parse JSON response. Raw output: ${stdout.slice(0, 500)}`,
          },
        });
      }
    });

    process.on("error", (error: Error) => {
      logger.error({ error }, "Failed to spawn Swift CLI process");
      resolve({
        success: false,
        error: {
          message: `Failed to execute Swift CLI: ${error.message}`,
          code: "SWIFT_CLI_SPAWN_ERROR",
          details: error.toString(),
        },
      });
    });
  });
}

export async function readImageAsBase64(imagePath: string): Promise<string> {
  const buffer = await fsPromises.readFile(imagePath);
  return buffer.toString("base64");
}

// Simple execution function for basic commands without logger dependency
export async function execPeekaboo(
  args: string[],
  packageRootDir: string,
  options: { expectSuccess?: boolean } = {},
): Promise<{ success: boolean; data?: string; error?: string }> {
  const cliPath = process.env.PEEKABOO_CLI_PATH || path.resolve(packageRootDir, "peekaboo");

  return new Promise((resolve) => {
    const process = spawn(cliPath, args);
    let stdout = "";
    let stderr = "";

    process.stdout.on("data", (data) => {
      stdout += data.toString();
    });

    process.stderr.on("data", (data) => {
      stderr += data.toString();
    });

    process.on("close", (code) => {
      const success = code === 0;
      if (options.expectSuccess !== false && !success) {
        resolve({ success: false, error: stderr || stdout });
      } else {
        resolve({ success, data: stdout, error: stderr });
      }
    });

    process.on("error", (err) => {
      resolve({ success: false, error: err.message });
    });
  });
}
