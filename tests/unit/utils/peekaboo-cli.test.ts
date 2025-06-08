import { describe, it, expect, beforeEach, vi } from "vitest";
import {
  executeSwiftCli,
  initializeSwiftCliPath,
} from "../../../src/utils/peekaboo-cli";
import { spawn } from "child_process";
import path from "path"; // Import path for joining

// Mock child_process
vi.mock("child_process");

// Mock fs to control existsSync behavior
vi.mock("fs", async () => {
  const actualFs = await vi.importActual("fs");
  return {
    ...actualFs,
    existsSync: vi.fn(), // Provide a mock function for existsSync
    // Ensure other fs functions if needed by SUT are also mocked or actual
  };
});

const mockSpawn = spawn as vi.Mock;
// mockExistsSync will be obtained from the mocked 'fs' module within tests

describe("Swift CLI Utility", () => {
  const mockLogger = {
    info: vi.fn(),
    error: vi.fn(),
    debug: vi.fn(),
    warn: vi.fn(),
  } as any;

  const MOCK_PACKAGE_ROOT = "/test/package/root";
  const DEFAULT_CLI_PATH_IN_PACKAGE = path.join(MOCK_PACKAGE_ROOT, "peekaboo");
  const CUSTOM_CLI_PATH = "/custom/path/to/peekaboo";

  let mockedFsExistsSync: vi.Mock; // To store the mock instance

  beforeEach(async () => {
    vi.clearAllMocks();
    process.env.PEEKABOO_CLI_PATH = "";
    const fs = await import("fs"); // Import the mocked fs module here
    mockedFsExistsSync = fs.existsSync as vi.Mock;
  });

  describe("executeSwiftCli with path resolution", () => {
    it("should use CLI path from PEEKABOO_CLI_PATH if set and valid", async () => {
      process.env.PEEKABOO_CLI_PATH = CUSTOM_CLI_PATH;
      mockedFsExistsSync.mockReturnValue(true); // Simulate path exists

      initializeSwiftCliPath(MOCK_PACKAGE_ROOT);

      mockSpawn.mockReturnValue({
        stdout: { on: vi.fn() },
        stderr: { on: vi.fn() },
        on: vi.fn((e, c) => {
          if (e === "close") c(0);
        }),
      });
      await executeSwiftCli(["test"], mockLogger);
      expect(mockSpawn).toHaveBeenCalledWith(CUSTOM_CLI_PATH, [
        "test",
        "--json-output",
      ]);
    });

    it("should use bundled path if PEEKABOO_CLI_PATH is set but invalid", async () => {
      process.env.PEEKABOO_CLI_PATH = "/invalid/path/peekaboo";
      mockedFsExistsSync.mockReturnValue(false); // Simulate path does NOT exist
      initializeSwiftCliPath(MOCK_PACKAGE_ROOT);

      mockSpawn.mockReturnValue({
        stdout: { on: vi.fn() },
        stderr: { on: vi.fn() },
        on: vi.fn((e, c) => {
          if (e === "close") c(0);
        }),
      });
      await executeSwiftCli(["test"], mockLogger);
      expect(mockSpawn).toHaveBeenCalledWith(DEFAULT_CLI_PATH_IN_PACKAGE, [
        "test",
        "--json-output",
      ]);
    });

    it("should use bundled path derived from packageRootDir if PEEKABOO_CLI_PATH is not set", async () => {
      initializeSwiftCliPath(MOCK_PACKAGE_ROOT);
      // No need to mock existsSync here if PEEKABOO_CLI_PATH is empty, as it won't be checked for that path.
      // However, if initializeSwiftCliPath itself uses existsSync, ensure it gets a sensible default or specific mock.
      mockedFsExistsSync.mockReturnValue(true); // Default for bundled path check if any

      mockSpawn.mockReturnValue({
        stdout: { on: vi.fn() },
        stderr: { on: vi.fn() },
        on: vi.fn((e, c) => {
          if (e === "close") c(0);
        }),
      });
      await executeSwiftCli(["test"], mockLogger);
      expect(mockSpawn).toHaveBeenCalledWith(DEFAULT_CLI_PATH_IN_PACKAGE, [
        "test",
        "--json-output",
      ]);
    });
  });

  describe("executeSwiftCli command execution and output parsing", () => {
    beforeEach(async () => {
      const fs = await import("fs"); // Import the mocked fs module here
      mockedFsExistsSync = fs.existsSync as vi.Mock;
      mockedFsExistsSync.mockReturnValue(false); // Ensure PEEKABOO_CLI_PATH (if set) is seen as invalid
      initializeSwiftCliPath(MOCK_PACKAGE_ROOT); // Default to bundled path
    });

    it("should execute command and parse valid JSON output", async () => {
      const mockStdOutput = JSON.stringify({
        success: true,
        data: { message: "Hello" },
      });
      const mockChildProcess = {
        stdout: {
          on: vi.fn((event, cb) => {
            if (event === "data") cb(Buffer.from(mockStdOutput));
          }),
        },
        stderr: { on: vi.fn() },
        on: vi.fn((event, cb) => {
          if (event === "close") cb(0);
        }),
        kill: vi.fn(),
      };
      mockSpawn.mockReturnValue(mockChildProcess);

      const result = await executeSwiftCli(["list", "apps"], mockLogger);
      expect(result).toEqual(JSON.parse(mockStdOutput));
      expect(mockSpawn).toHaveBeenCalledWith(DEFAULT_CLI_PATH_IN_PACKAGE, [
        "list",
        "apps",
        "--json-output",
      ]);
      expect(mockLogger.debug).toHaveBeenCalledWith(
        expect.objectContaining({ command: DEFAULT_CLI_PATH_IN_PACKAGE }),
        "Executing Swift CLI",
      );
    });

    it("should handle Swift CLI error with JSON output from CLI", async () => {
      const errorPayload = {
        success: false,
        error: { code: "PERMISSIONS_ERROR", message: "Permission denied" },
      };
      const mockChildProcess = {
        stdout: {
          on: vi.fn((event, cb) => {
            if (event === "data") cb(Buffer.from(JSON.stringify(errorPayload)));
          }),
        },
        stderr: { on: vi.fn() },
        on: vi.fn((event, cb) => {
          if (event === "close") cb(0);
        }),
        kill: vi.fn(),
      };
      mockSpawn.mockReturnValue(mockChildProcess);

      const result = await executeSwiftCli(
        ["image", "--mode", "screen"],
        mockLogger,
      );
      expect(result).toEqual(errorPayload);
    });

    it("should handle non-JSON output from Swift CLI with non-zero exit", async () => {
      const mockChildProcess = {
        stdout: {
          on: vi.fn((event, cb) => {
            if (event === "data") cb(Buffer.from("Plain text error"));
          }),
        },
        stderr: { on: vi.fn() },
        on: vi.fn((event, cb) => {
          if (event === "close") cb(1);
        }),
        kill: vi.fn(),
      };
      mockSpawn.mockReturnValue(mockChildProcess);

      const result = await executeSwiftCli(["list", "windows"], mockLogger);
      expect(result).toEqual({
        success: false,
        error: {
          code: "SWIFT_CLI_UNKNOWN_ERROR",
          message: "An unknown error occurred in the Swift CLI.",
          details: "Failed to parse JSON response. Raw output: Plain text error",
        },
      });
      expect(mockLogger.error).toHaveBeenCalledWith(
        expect.objectContaining({ exitCode: 1, parseError: expect.any(Error), stdout: "Plain text error" }),
        "Failed to parse Swift CLI JSON output, falling back to exit code mapping",
      );
    });

    it("should handle Swift CLI not found or not executable (spawn error)", async () => {
      const spawnError = new Error("spawn EACCES") as NodeJS.ErrnoException;
      spawnError.code = "EACCES";

      const mockChildProcess = {
        stdout: { on: vi.fn() },
        stderr: { on: vi.fn() },
        on: vi.fn((event: string, cb: (err: Error) => void) => {
          if (event === "error") {
            cb(spawnError);
          }
        }),
        kill: vi.fn(),
      } as any;

      mockSpawn.mockReturnValue(mockChildProcess);

      const result = await executeSwiftCli(["image"], mockLogger);

      expect(result).toEqual({
        success: false,
        error: {
          message: "Failed to execute Swift CLI: spawn EACCES",
          code: "SWIFT_CLI_SPAWN_ERROR",
          details: spawnError.toString(),
        },
      });
      expect(mockLogger.error).toHaveBeenCalledWith(
        expect.objectContaining({ error: spawnError }),
        "Failed to spawn Swift CLI process",
      );
    });

    it("should append --json-output to args", async () => {
      const mockChildProcess = {
        stdout: {
          on: vi.fn((event, cb) => {
            if (event === "data")
              cb(Buffer.from(JSON.stringify({ success: true })));
          }),
        },
        stderr: { on: vi.fn() },
        on: vi.fn((event, cb) => {
          if (event === "close") cb(0);
        }),
        kill: vi.fn(),
      };
      mockSpawn.mockReturnValue(mockChildProcess);

      await executeSwiftCli(["list", "apps"], mockLogger);
      expect(mockSpawn).toHaveBeenCalledWith(expect.any(String), [
        "list",
        "apps",
        "--json-output",
      ]);
    });

    it("should capture stderr output from Swift CLI for debugging", async () => {
      const mockChildProcess = {
        stdout: {
          on: vi.fn((event, cb) => {
            if (event === "data")
              cb(Buffer.from(JSON.stringify({ success: true, data: {} })));
          }),
        },
        stderr: {
          on: vi.fn((event, cb) => {
            if (event === "data") cb(Buffer.from("Debug warning on stderr"));
          }),
        },
        on: vi.fn((event, cb) => {
          if (event === "close") cb(0);
        }),
        kill: vi.fn(),
      };
      mockSpawn.mockReturnValue(mockChildProcess);

      const result = await executeSwiftCli(["list", "apps"], mockLogger);
      expect(result.success).toBe(true);
      expect(mockLogger.warn).toHaveBeenCalledWith(
        { swift_stderr: "Debug warning on stderr" },
        "[SwiftCLI-stderr]",
      );
    });
  });

  describe("executeSwiftCli exit code mapping", () => {
    beforeEach(() => {
      // Ensure the CLI path is initialized for these tests
      initializeSwiftCliPath(MOCK_PACKAGE_ROOT);
    });

    it("should map exit code 11 to screen recording permission error", async () => {
      mockSpawn.mockReturnValue({
        stdout: { on: vi.fn() },
        stderr: { on: vi.fn() },
        on: vi.fn((event, cb) => {
          if (event === "close") cb(11);
        }),
      });

      const result = await executeSwiftCli([], mockLogger);
      expect(result.success).toBe(false);
      expect(result.error?.code).toBe(
        "SWIFT_CLI_NO_SCREEN_RECORDING_PERMISSION",
      );
      expect(result.error?.message).toContain(
        "Screen Recording permission is not granted",
      );
    });

    it("should map exit code 12 to accessibility permission error", async () => {
      mockSpawn.mockReturnValue({
        stdout: { on: vi.fn() },
        stderr: { on: vi.fn() },
        on: vi.fn((event, cb) => {
          if (event === "close") cb(12);
        }),
      });

      const result = await executeSwiftCli([], mockLogger);
      expect(result.success).toBe(false);
      expect(result.error?.code).toBe(
        "SWIFT_CLI_NO_ACCESSIBILITY_PERMISSION",
      );
      expect(result.error?.message).toContain(
        "Accessibility permission is not granted",
      );
    });

    it("should map exit code 18 to app not found error", async () => {
      mockSpawn.mockReturnValue({
        stdout: { on: vi.fn() },
        stderr: { on: vi.fn() },
        on: vi.fn((event, cb) => {
          if (event === "close") cb(18);
        }),
      });

      const result = await executeSwiftCli([], mockLogger);
      expect(result.success).toBe(false);
      expect(result.error?.code).toBe("SWIFT_CLI_APP_NOT_FOUND");
      expect(result.error?.message).toContain(
        "could not be found",
      );
    });

    it("should handle an unknown exit code with a generic message", async () => {
      mockSpawn.mockReturnValue({
        stdout: { on: vi.fn() },
        stderr: { on: vi.fn((event, cb) => {
          if (event === 'data') cb('Some stderr text');
        })},
        on: vi.fn((event, cb) => {
          if (event === "close") cb(99); // Unknown code
        }),
      });

      const result = await executeSwiftCli([], mockLogger);
      expect(result.success).toBe(false);
      expect(result.error?.code).toBe("SWIFT_CLI_EXECUTION_ERROR");
      expect(result.error?.message).toBe("Peekaboo CLI Error: Some stderr text");
    });
  });
});
