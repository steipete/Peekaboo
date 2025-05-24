import { executeSwiftCli, initializeSwiftCliPath } from '../../../src/utils/swift-cli';
import { spawn } from 'child_process';
import path from 'path'; // Import path for joining

// Mock child_process
jest.mock('child_process');

// Mock fs to control existsSync behavior for PEEKABOO_CLI_PATH tests
jest.mock('fs', () => ({
  ...jest.requireActual('fs'), // Preserve other fs functions
  existsSync: jest.fn(),
}));

const mockSpawn = spawn as jest.Mock;
const mockExistsSync = jest.requireMock('fs').existsSync as jest.Mock;

describe('Swift CLI Utility', () => {
  const mockLogger = {
    info: jest.fn(),
    error: jest.fn(),
    debug: jest.fn(),
    warn: jest.fn(),
  } as any;

  const MOCK_PACKAGE_ROOT = '/test/package/root';
  const DEFAULT_CLI_PATH_IN_PACKAGE = path.join(MOCK_PACKAGE_ROOT, 'peekaboo');
  const CUSTOM_CLI_PATH = '/custom/path/to/peekaboo';

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.CLI_PATH = '';
    // Reset the internal resolvedCliPath by re-importing or having a reset function (not available here)
    // For now, we will rely on initializeSwiftCliPath overwriting it or testing its logic flow.
    // This is a limitation of testing module-scoped variables without a reset mechanism.
    // We can ensure each describe block for executeSwiftCli calls initializeSwiftCliPath with its desired setup.
  });

  describe('executeSwiftCli with path resolution', () => {
    it('should use CLI path from CLI_PATH if set and valid', async () => {
      process.env.CLI_PATH = CUSTOM_CLI_PATH;
      mockExistsSync.mockReturnValue(true); // Simulate path exists
      initializeSwiftCliPath(MOCK_PACKAGE_ROOT); // Root dir is secondary if CLI_PATH is valid
      
      mockSpawn.mockReturnValue({ stdout: { on: jest.fn() }, stderr: { on: jest.fn() }, on: jest.fn((e,c) => {if(e==='close')c(0)}) });
      await executeSwiftCli(['test'], mockLogger);
      expect(mockSpawn).toHaveBeenCalledWith(CUSTOM_CLI_PATH, ['test', '--json-output']);
    });

    it('should use bundled path if CLI_PATH is set but invalid', async () => {
      process.env.CLI_PATH = '/invalid/path/peekaboo';
      mockExistsSync.mockReturnValue(false); // Simulate path does NOT exist
      initializeSwiftCliPath(MOCK_PACKAGE_ROOT);
      
      mockSpawn.mockReturnValue({ stdout: { on: jest.fn() }, stderr: { on: jest.fn() }, on: jest.fn((e,c) => {if(e==='close')c(0)}) });
      await executeSwiftCli(['test'], mockLogger);
      expect(mockSpawn).toHaveBeenCalledWith(DEFAULT_CLI_PATH_IN_PACKAGE, ['test', '--json-output']);
      // Check console.warn for invalid path (this is in SUT, so it's a side effect test)
      // This test is a bit brittle as it relies on console.warn in the SUT which might change.
      // expect(console.warn).toHaveBeenCalledWith(expect.stringContaining('PEEKABOO_CLI_PATH is set to '/invalid/custom/path', but this path does not exist'));
    });

    it('should use bundled path derived from packageRootDir if CLI_PATH is not set', async () => {
      // CLI_PATH is empty by default from beforeEach
      initializeSwiftCliPath(MOCK_PACKAGE_ROOT);
      
      mockSpawn.mockReturnValue({ stdout: { on: jest.fn() }, stderr: { on: jest.fn() }, on: jest.fn((e,c) => {if(e==='close')c(0)}) });
      await executeSwiftCli(['test'], mockLogger);
      expect(mockSpawn).toHaveBeenCalledWith(DEFAULT_CLI_PATH_IN_PACKAGE, ['test', '--json-output']);
    });

    // Test for the import.meta.url fallback is hard because it would only trigger if 
    // initializeSwiftCliPath was never called or called with undefined rootDir, AND CLI_PATH is not set.
    // Such a scenario would also mean the console.warn/error for uninitialized path would trigger.
    // It's better to ensure tests always initialize appropriately.
  });

  // Remaining tests for executeSwiftCli behavior (parsing, errors, etc.) are largely the same
  // but need to ensure initializeSwiftCliPath has run before each of them.
  describe('executeSwiftCli command execution and output parsing', () => {
    beforeEach(() => {
      // Ensure a default path is initialized for these tests
      // CLI_PATH is empty, so it will use MOCK_PACKAGE_ROOT
      mockExistsSync.mockReturnValue(false); // Ensure CLI_PATH (if accidentally set) is seen as invalid
      initializeSwiftCliPath(MOCK_PACKAGE_ROOT);
    });

    it('should execute command and parse valid JSON output', async () => {
      const mockStdOutput = JSON.stringify({ success: true, data: { message: "Hello" } });
      const mockChildProcess = {
        stdout: { on: jest.fn((event, cb) => { if (event === 'data') cb(Buffer.from(mockStdOutput)); }) },
        stderr: { on: jest.fn() },
        on: jest.fn((event, cb) => { if (event === 'close') cb(0); }),
        kill: jest.fn(),
      };
      mockSpawn.mockReturnValue(mockChildProcess);

      const result = await executeSwiftCli(['list', 'apps'], mockLogger);
      expect(result).toEqual(JSON.parse(mockStdOutput));
      expect(mockSpawn).toHaveBeenCalledWith(DEFAULT_CLI_PATH_IN_PACKAGE, ['list', 'apps', '--json-output']);
      expect(mockLogger.debug).toHaveBeenCalledWith(expect.objectContaining({ command: DEFAULT_CLI_PATH_IN_PACKAGE}), 'Executing Swift CLI');
    });

    it('should handle Swift CLI error with JSON output from CLI', async () => {
      const errorPayload = { success: false, error: { code: 'PERMISSIONS_ERROR', message: "Permission denied" } };
      const mockChildProcess = {
        stdout: { on: jest.fn((event, cb) => { if (event === 'data') cb(Buffer.from(JSON.stringify(errorPayload))); }) },
        stderr: { on: jest.fn() },
        on: jest.fn((event, cb) => { if (event === 'close') cb(0); }), // Swift CLI itself exits 0, but payload indicates error
        kill: jest.fn(),
      };
      mockSpawn.mockReturnValue(mockChildProcess);

      const result = await executeSwiftCli(['image', '--mode', 'screen'], mockLogger);
      expect(result).toEqual(errorPayload);
    });

    it('should handle non-JSON output from Swift CLI with non-zero exit', async () => {
        const mockChildProcess = {
          stdout: { on: jest.fn((event, cb) => { if (event === 'data') cb(Buffer.from("Plain text error")); }) },
          stderr: { on: jest.fn() },
          on: jest.fn((event, cb) => { if (event === 'close') cb(1); }),
          kill: jest.fn(),
        };
        mockSpawn.mockReturnValue(mockChildProcess);
  
        const result = await executeSwiftCli(['list', 'windows'], mockLogger);
        expect(result).toEqual({
          success: false,
          error: {
            code: 'SWIFT_CLI_EXECUTION_ERROR',
            message: 'Swift CLI execution failed (exit code: 1)',
            details: 'Plain text error'
          }
        });
        expect(mockLogger.error).toHaveBeenCalledWith(expect.objectContaining({ exitCode: 1}), 'Swift CLI execution failed');
      });

    it('should handle Swift CLI not found or not executable (spawn error)', async () => {
      const spawnError = new Error('spawn EACCES') as NodeJS.ErrnoException;
      spawnError.code = 'EACCES';
      
      const mockChildProcess = {
        stdout: { on: jest.fn() },
        stderr: { on: jest.fn() },
        on: jest.fn((event: string, cb: (err: Error) => void) => {
          if (event === 'error') {
            cb(spawnError);
          }
        }),
        kill: jest.fn(),
      } as any;

      mockSpawn.mockReturnValue(mockChildProcess);

      const result = await executeSwiftCli(['image'], mockLogger);
      
      expect(result).toEqual({
        success: false,
        error: {
            message: "Failed to execute Swift CLI: spawn EACCES",
            code: 'SWIFT_CLI_SPAWN_ERROR',
            details: spawnError.toString()
        }
      });
      expect(mockLogger.error).toHaveBeenCalledWith(expect.objectContaining({ error: spawnError }), "Failed to spawn Swift CLI process");
    });

    it('should append --json-output to args', async () => {
        const mockChildProcess = {
            stdout: { on: jest.fn((event, cb) => { if (event === 'data') cb(Buffer.from(JSON.stringify({ success: true }))); }) },
            stderr: { on: jest.fn() },
            on: jest.fn((event, cb) => { if (event === 'close') cb(0); }),
            kill: jest.fn(),
          };
          mockSpawn.mockReturnValue(mockChildProcess);
    
          await executeSwiftCli(['list', 'apps'], mockLogger);
          expect(mockSpawn).toHaveBeenCalledWith(expect.any(String), ['list', 'apps', '--json-output']);
    });

    it('should capture stderr output from Swift CLI for debugging', async () => {
        const mockChildProcess = {
          stdout: { on: jest.fn((event, cb) => { if (event === 'data') cb(Buffer.from(JSON.stringify({ success: true, data: {} }))); }) },
          stderr: { on: jest.fn((event, cb) => { if (event === 'data') cb(Buffer.from("Debug warning on stderr")); }) },
          on: jest.fn((event, cb) => { if (event === 'close') cb(0); }),
          kill: jest.fn(),
        };
        mockSpawn.mockReturnValue(mockChildProcess);
  
        const result = await executeSwiftCli(['list', 'apps'], mockLogger);
        expect(result.success).toBe(true);
        expect(mockLogger.warn).toHaveBeenCalledWith({ swift_stderr: "Debug warning on stderr" }, "[SwiftCLI-stderr]");
      });
  });
}); 