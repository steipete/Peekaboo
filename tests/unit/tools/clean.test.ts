import { describe, it, expect, vi, beforeEach } from 'vitest';
import { cleanToolHandler, cleanToolSchema } from "../../../Server/src/tools/clean";
import * as peekabooCliModule from "../../../Server/src/utils/peekaboo-cli";
import { pino } from 'pino';

vi.mock("../../../Server/src/utils/peekaboo-cli");

const mockLogger = pino({ level: "silent" });

describe('cleanToolHandler', () => {
  const mockExecuteSwiftCli = vi.mocked(peekabooCliModule.executeSwiftCli);
  const mockContext = { logger: mockLogger };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('schema validation', () => {
    it('should accept valid all_sessions input', () => {
      const input = { all_sessions: true };
      const result = cleanToolSchema.safeParse(input);
      expect(result.success).toBe(true);
    });

    it('should accept valid older_than input', () => {
      const input = { older_than: 24 };
      const result = cleanToolSchema.safeParse(input);
      expect(result.success).toBe(true);
    });

    it('should accept valid session input', () => {
      const input = { session: "12345" };
      const result = cleanToolSchema.safeParse(input);
      expect(result.success).toBe(true);
    });

    it('should accept dry_run option', () => {
      const input = { all_sessions: true, dry_run: true };
      const result = cleanToolSchema.safeParse(input);
      expect(result.success).toBe(true);
    });

    it('should reject multiple cleanup options', () => {
      const input = { all_sessions: true, older_than: 24 };
      const result = cleanToolSchema.safeParse(input);
      expect(result.success).toBe(false);
      expect(result.error?.issues[0].message).toContain("Specify exactly one of");
    });

    it('should reject no cleanup options', () => {
      const input = {};
      const result = cleanToolSchema.safeParse(input);
      expect(result.success).toBe(false);
    });
  });

  describe('command execution', () => {
    it('should handle all_sessions cleanup', async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          sessions_removed: 3,
          bytes_freed: 1048576,
          session_details: [
            { session_id: "12345", path: "/path/to/session1", size: 524288 },
            { session_id: "12346", path: "/path/to/session2", size: 262144 },
            { session_id: "12347", path: "/path/to/session3", size: 262144 }
          ],
          execution_time: 0.5,
          success: true
        }
      });

      const result = await cleanToolHandler(
        { all_sessions: true },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["clean", "--all-sessions"],
        mockContext.logger
      );

      expect(result.isError).toBe(undefined);
      expect(result.content[0].type).toBe("text");
      const text = result.content[0].text;
      expect(text).toContain("Removed 3 sessions");
      expect(text).toContain("Space freed: 1.0 MB");
      expect(text).toContain("12345");
      expect(text).toContain("Completed in 0.50s");
    });

    it('should handle older_than cleanup', async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          sessions_removed: 2,
          bytes_freed: 2097152,
          session_details: [
            { session_id: "12345", path: "/path/to/old1", size: 1048576 },
            { session_id: "12346", path: "/path/to/old2", size: 1048576 }
          ],
          execution_time: 0.3,
          success: true
        }
      });

      const result = await cleanToolHandler(
        { older_than: 48 },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["clean", "--older-than", "48"],
        mockContext.logger
      );

      expect(result.isError).toBe(undefined);
      const text = result.content[0].text;
      expect(text).toContain("Removed 2 sessions");
      expect(text).toContain("Space freed: 2.0 MB");
    });

    it('should handle specific session cleanup', async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          sessions_removed: 1,
          bytes_freed: 524288,
          session_details: [
            { session_id: "12345", path: "/path/to/session", size: 524288 }
          ],
          execution_time: 0.1,
          success: true
        }
      });

      const result = await cleanToolHandler(
        { session: "12345" },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["clean", "--session", "12345"],
        mockContext.logger
      );

      expect(result.isError).toBe(undefined);
      const text = result.content[0].text;
      expect(text).toContain("Removed 1 session");
      expect(text).toContain("Space freed: 512.0 KB");
    });

    it('should handle dry run mode', async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          sessions_removed: 5,
          bytes_freed: 5242880,
          session_details: [],
          execution_time: 0.2,
          success: true
        }
      });

      const result = await cleanToolHandler(
        { all_sessions: true, dry_run: true },
        mockContext
      );

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        ["clean", "--all-sessions", "--dry-run"],
        mockContext.logger
      );

      expect(result.isError).toBe(undefined);
      const text = result.content[0].text;
      expect(text).toContain("Dry run mode - no files were deleted");
      expect(text).toContain("Would remove 5 sessions");
      expect(text).toContain("Space to be freed: 5.0 MB");
    });

    it('should handle no sessions to clean', async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: true,
        data: {
          sessions_removed: 0,
          bytes_freed: 0,
          session_details: [],
          execution_time: 0.1,
          success: true
        }
      });

      const result = await cleanToolHandler(
        { all_sessions: true },
        mockContext
      );

      expect(result.isError).toBe(undefined);
      const text = result.content[0].text;
      expect(text).toContain("No sessions to clean");
    });

    it('should handle CLI execution errors', async () => {
      mockExecuteSwiftCli.mockResolvedValue({
        success: false,
        error: { message: "Permission denied" }
      });

      const result = await cleanToolHandler(
        { all_sessions: true },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Failed to clean sessions: Permission denied");
    });

    it('should handle unexpected errors', async () => {
      mockExecuteSwiftCli.mockRejectedValue(new Error("Network error"));

      const result = await cleanToolHandler(
        { all_sessions: true },
        mockContext
      );

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Tool execution failed: Network error");
    });

    it('should format bytes correctly', async () => {
      const testCases = [
        { bytes: 512, expected: "512.0 B" },
        { bytes: 1024, expected: "1.0 KB" },
        { bytes: 1536, expected: "1.5 KB" },
        { bytes: 1048576, expected: "1.0 MB" },
        { bytes: 1073741824, expected: "1.0 GB" }
      ];

      for (const testCase of testCases) {
        mockExecuteSwiftCli.mockResolvedValue({
          success: true,
          data: {
            sessions_removed: 1,
            bytes_freed: testCase.bytes,
            session_details: [],
            execution_time: 0.1,
            success: true
          }
        });

        const result = await cleanToolHandler(
          { all_sessions: true },
          mockContext
        );

        const text = result.content[0].text;
        expect(text).toContain(`Space freed: ${testCase.expected}`);
      }
    });
  });
});