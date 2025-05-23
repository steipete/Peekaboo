import { spawn } from 'child_process';
import path from 'path';
// import { fileURLToPath } from 'url'; // No longer needed here
import { Logger } from 'pino';
import fsPromises from 'fs/promises';
import { existsSync } from 'fs';
import { SwiftCliResponse } from '../types/index.js';

let resolvedCliPath: string | null = null;
const INVALID_PATH_SENTINEL = 'PEEKABOO_CLI_PATH_RESOLUTION_FAILED';

function determineSwiftCliPath(packageRootDirForFallback?: string): string {
  const envPath = process.env.CLI_PATH;
  if (envPath) {
    try {
      if (existsSync(envPath)) {
        return envPath;
      }
      // If envPath is set but invalid, fall through to use packageRootDirForFallback
    } catch (err) { /* Fall through if existsSync fails */ }
  }

  if (packageRootDirForFallback) {
    return path.resolve(packageRootDirForFallback, 'peekaboo');
  }
  
  // If neither CLI_PATH is valid nor packageRootDirForFallback is provided,
  // this is a critical failure in path determination.
  return INVALID_PATH_SENTINEL;
}

export function initializeSwiftCliPath(packageRootDir: string): void {
  if (!packageRootDir) {
    // If CLI_PATH is also not set or invalid, this will lead to INVALID_PATH_SENTINEL
    // Allow determineSwiftCliPath to handle this, and the error will be caught by getInitializedSwiftCliPath
  }
  resolvedCliPath = determineSwiftCliPath(packageRootDir);
  // No direct logging here; issues will be caught by getInitializedSwiftCliPath
}

function getInitializedSwiftCliPath(logger: Logger): string { // Logger is now mandatory
  if (!resolvedCliPath || resolvedCliPath === INVALID_PATH_SENTINEL) {
    const errorMessage = `Peekaboo Swift CLI path is not properly initialized or resolution failed. Resolved path: '${resolvedCliPath}'. Ensure CLI_PATH is valid or initializeSwiftCliPath() was called with a correct package root directory at startup.`;
    logger.error(errorMessage); 
    // Throw an error to prevent attempting to use an invalid path
    throw new Error(errorMessage);
  }
  return resolvedCliPath;
}

export async function executeSwiftCli(
  args: string[],
  logger: Logger
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
        code: 'SWIFT_CLI_PATH_INIT_ERROR',
        details: (error as Error).stack
      }
    };
  }
  
  // Always add --json-output flag
  const fullArgs = [...args, '--json-output'];
  
  logger.debug({ command: cliPath, args: fullArgs }, 'Executing Swift CLI');
  
  return new Promise((resolve) => {
    const process = spawn(cliPath, fullArgs);
    
    let stdout = '';
    let stderr = '';
    
    process.stdout.on('data', (data) => {
      stdout += data.toString();
    });
    
    process.stderr.on('data', (data) => {
      const stderrData = data.toString();
      stderr += stderrData;
      // Log stderr immediately as it comes in
      logger.warn({ swift_stderr: stderrData.trim() }, '[SwiftCLI-stderr]');
    });
    
    process.on('close', (exitCode) => {
      logger.debug({ exitCode, stdout: stdout.slice(0, 200) }, 'Swift CLI completed');
      
      if (exitCode !== 0 || !stdout.trim()) {
        logger.error({ exitCode, stdout, stderr }, 'Swift CLI execution failed');
        resolve({
          success: false,
          error: {
            message: `Swift CLI execution failed (exit code: ${exitCode})`,
            code: 'SWIFT_CLI_EXECUTION_ERROR',
            details: stderr || stdout || 'No output received'
          }
        });
        return;
      }
      
      try {
        const response = JSON.parse(stdout) as SwiftCliResponse;
        
        // Log debug messages from Swift CLI
        if (response.debug_logs && Array.isArray(response.debug_logs)) {
          response.debug_logs.forEach((entry) => {
            logger.debug({ backend: 'swift', swift_log: entry });
          });
        }
        
        resolve(response);
      } catch (parseError) {
        logger.error({ parseError, stdout }, 'Failed to parse Swift CLI JSON output');
        resolve({
          success: false,
          error: {
            message: 'Invalid JSON response from Swift CLI',
            code: 'SWIFT_CLI_INVALID_OUTPUT',
            details: stdout.slice(0, 500)
          }
        });
      }
    });
    
    process.on('error', (error) => {
      logger.error({ error }, 'Failed to spawn Swift CLI process');
      resolve({
        success: false,
        error: {
          message: `Failed to execute Swift CLI: ${error.message}`,
          code: 'SWIFT_CLI_SPAWN_ERROR',
          details: error.toString()
        }
      });
    });
  });
}

export async function readImageAsBase64(imagePath: string): Promise<string> {
  const buffer = await fsPromises.readFile(imagePath);
  return buffer.toString('base64');
} 