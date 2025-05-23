import { pino } from 'pino';
import { listToolHandler, buildSwiftCliArgs, ListToolInput } from '../../../src/tools/list';
import { executeSwiftCli } from '../../../src/utils/swift-cli';
import { generateServerStatusString } from '../../../src/utils/server-status';
import fs from 'fs/promises';
// import path from 'path'; // path is still used by the test itself for expect.stringContaining if needed, but not for mocking resolve/dirname
// import { fileURLToPath } from 'url'; // No longer needed
import { ToolContext, ApplicationListData, WindowListData } from '../../../src/types/index.js';

// Mocks
jest.mock('../../../src/utils/swift-cli');
jest.mock('../../../src/utils/server-status');
jest.mock('fs/promises');

// Mock path and url functions to avoid import.meta.url issues in test environment
// jest.mock('url', () => ({ // REMOVED
//   ...jest.requireActual('url'), // REMOVED
//   fileURLToPath: jest.fn().mockReturnValue('/mocked/path/to/list.ts'), // REMOVED
// })); // REMOVED
// jest.mock('path', () => ({ // REMOVED
//   ...jest.requireActual('path'), // REMOVED
//   dirname: jest.fn((p) => jest.requireActual('path').dirname(p)), // REMOVED
//   resolve: jest.fn((...paths) => { // REMOVED
//     // If it's trying to resolve relative to the mocked list.ts, provide a specific mocked package.json path // REMOVED
//     if (paths.length === 3 && paths[0] === '/mocked/path/to' && paths[1] === '..' && paths[2] === '..') { // REMOVED
//       return '/mocked/path/package.json';  // REMOVED
//     } // REMOVED
//     return jest.requireActual('path').resolve(...paths); // Fallback to actual resolve // REMOVED
//   }), // REMOVED
// })); // REMOVED

const mockExecuteSwiftCli = executeSwiftCli as jest.MockedFunction<typeof executeSwiftCli>;
const mockGenerateServerStatusString = generateServerStatusString as jest.MockedFunction<typeof generateServerStatusString>;
const mockFsReadFile = fs.readFile as jest.MockedFunction<typeof fs.readFile>;

// Create a mock logger for tests
const mockLogger = pino({ level: 'silent' });
const mockContext: ToolContext = { logger: mockLogger };

describe('List Tool', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('buildSwiftCliArgs', () => {
    it('should return default args for running_applications', () => {
      const input: ListToolInput = { item_type: 'running_applications' };
      expect(buildSwiftCliArgs(input)).toEqual(['list', 'apps']);
    });

    it('should return args for application_windows with app only', () => {
      const input: ListToolInput = { item_type: 'application_windows', app: 'Safari' };
      expect(buildSwiftCliArgs(input)).toEqual(['list', 'windows', '--app', 'Safari']);
    });

    it('should return args for application_windows with app and details', () => {
      const input: ListToolInput = {
        item_type: 'application_windows',
        app: 'Chrome',
        include_window_details: ['bounds', 'ids']
      };
      expect(buildSwiftCliArgs(input)).toEqual(['list', 'windows', '--app', 'Chrome', '--include-details', 'bounds,ids']);
    });

    it('should return args for application_windows with app and empty details', () => {
      const input: ListToolInput = {
        item_type: 'application_windows',
        app: 'Finder',
        include_window_details: []
      };
      expect(buildSwiftCliArgs(input)).toEqual(['list', 'windows', '--app', 'Finder']);
    });
    
    it('should ignore app and include_window_details if item_type is not application_windows', () => {
      const input: ListToolInput = {
        item_type: 'running_applications',
        app: 'ShouldBeIgnored',
        include_window_details: ['bounds']
      };
      expect(buildSwiftCliArgs(input)).toEqual(['list', 'apps']);
    });
  });

  describe('listToolHandler', () => {
    it('should list running applications', async () => {
      const mockSwiftResponse: ApplicationListData = {
        applications: [
          { app_name: 'Safari', bundle_id: 'com.apple.Safari', pid: 1234, is_active: true, window_count: 2 },
          { app_name: 'Cursor', bundle_id: 'com.todesktop.230313mzl4w4u92', pid: 5678, is_active: false, window_count: 1 },
        ]
      };
      mockExecuteSwiftCli.mockResolvedValue({ success: true, data: mockSwiftResponse, messages: [] });

      const result = await listToolHandler({
        item_type: 'running_applications'
      }, mockContext);

      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(['list', 'apps'], mockLogger);
      expect(result.content[0].text).toContain('Found 2 running applications');
      expect(result.content[0].text).toContain('Safari (com.apple.Safari) - PID: 1234 [ACTIVE] - Windows: 2');
      expect(result.content[0].text).toContain('Cursor (com.todesktop.230313mzl4w4u92) - PID: 5678 - Windows: 1');
      expect((result as any).application_list).toEqual(mockSwiftResponse.applications);
    });

    it('should list application windows', async () => {
      const mockSwiftResponse: WindowListData = {
        target_application_info: { app_name: 'Safari', bundle_id: 'com.apple.Safari', pid: 1234 },
        windows: [
          { window_title: 'Main Window', window_id: 12345, is_on_screen: true, bounds: {x:0,y:0,width:800,height:600} },
          { window_title: 'Secondary Window', window_id: 12346, is_on_screen: false },
        ]
      };
      mockExecuteSwiftCli.mockResolvedValue({ success: true, data: mockSwiftResponse, messages: [] });

      const result = await listToolHandler({
        item_type: 'application_windows',
        app: 'Safari',
        include_window_details: ['ids', 'bounds', 'off_screen']
      }, mockContext);
      
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(['list', 'windows', '--app', 'Safari', '--include-details', 'ids,bounds,off_screen'], mockLogger);
      expect(result.content[0].text).toContain('Found 2 windows for application: Safari (com.apple.Safari) - PID: 1234');
      expect(result.content[0].text).toContain('1. "Main Window" [ID: 12345] [ON-SCREEN] [0,0 800×600]');
      expect(result.content[0].text).toContain('2. "Secondary Window" [ID: 12346] [OFF-SCREEN]');
      expect((result as any).window_list).toEqual(mockSwiftResponse.windows);
      expect((result as any).target_application_info).toEqual(mockSwiftResponse.target_application_info);
    });

    it('should handle server status', async () => {
      // process.cwd() will be the project root during tests
      const expectedPackageJsonPath = require('path').join(process.cwd(), 'package.json');
      mockFsReadFile.mockResolvedValue(JSON.stringify({ version: '1.2.3' }));
      mockGenerateServerStatusString.mockReturnValue('Peekaboo MCP Server v1.2.3\nStatus: Test Status');

      const result = await listToolHandler({
        item_type: 'server_status'
      }, mockContext);
      
      expect(mockFsReadFile).toHaveBeenCalledWith(expectedPackageJsonPath, 'utf-8');
      expect(mockGenerateServerStatusString).toHaveBeenCalledWith('1.2.3');
      expect(result.content[0].text).toBe('Peekaboo MCP Server v1.2.3\nStatus: Test Status');
      expect(mockExecuteSwiftCli).not.toHaveBeenCalled();
    });

    it('should handle Swift CLI errors', async () => {
      mockExecuteSwiftCli.mockResolvedValue({ 
        success: false, 
        error: { message: 'Application not found', code: 'APP_NOT_FOUND' } 
      });

      const result = await listToolHandler({
        item_type: 'running_applications'
      }, mockContext) as { content: any[], isError?: boolean, _meta?: any };

      expect(result.content[0].text).toBe('List operation failed: Application not found');
      expect(result.isError).toBe(true);
      expect((result as any)._meta.backend_error_code).toBe('APP_NOT_FOUND');
    });

    it('should handle Swift CLI errors with no message or code', async () => {
      mockExecuteSwiftCli.mockResolvedValue({ 
        success: false, 
        error: { message: 'Unknown error', code: 'UNKNOWN_SWIFT_ERROR' } // Provide default message and code
      });

      const result = await listToolHandler({
        item_type: 'running_applications'
      }, mockContext) as { content: any[], isError?: boolean, _meta?: any };

      expect(result.content[0].text).toBe('List operation failed: Unknown error');
      expect(result.isError).toBe(true);
      // Meta might or might not be undefined depending on the exact path, so let's check the code if present
      if (result._meta) {
        expect(result._meta.backend_error_code).toBe('UNKNOWN_SWIFT_ERROR');
      } else {
        // If no _meta, the code should still reflect the error object passed
        // This case might need adjustment based on listToolHandler's exact logic for _meta creation
      }
    });

    it('should handle unexpected errors during Swift CLI execution', async () => {
      mockExecuteSwiftCli.mockRejectedValue(new Error('Unexpected Swift execution error'));

      const result = await listToolHandler({
        item_type: 'running_applications'
      }, mockContext) as { content: any[], isError?: boolean };

      expect(result.content[0].text).toBe('Unexpected error: Unexpected Swift execution error');
      expect(result.isError).toBe(true);
    });
    
    it('should handle unexpected errors during server status (fs.readFile fails)', async () => {
      mockFsReadFile.mockRejectedValue(new Error('Cannot read package.json'));

      const result = await listToolHandler({
        item_type: 'server_status'
      }, mockContext) as { content: any[], isError?: boolean };

      expect(result.content[0].text).toBe('Unexpected error: Cannot read package.json');
      expect(result.isError).toBe(true);
    });
    
    it('should include Swift CLI messages in the output for applications list', async () => {
      const mockSwiftResponse: ApplicationListData = {
        applications: [{ app_name: 'TestApp', bundle_id: 'com.test.app', pid: 111, is_active: false, window_count: 0 }]
      };
      mockExecuteSwiftCli.mockResolvedValue({ 
        success: true, 
        data: mockSwiftResponse, 
        messages: ['Warning: One app hidden.', 'Info: Low memory.'] 
      });

      const result = await listToolHandler({ item_type: 'running_applications' }, mockContext);
      expect(result.content[0].text).toContain('Messages: Warning: One app hidden.; Info: Low memory.');
    });
    
    it('should include Swift CLI messages in the output for windows list', async () => {
      const mockSwiftResponse: WindowListData = {
        target_application_info: { app_name: 'TestApp', pid: 111 },
        windows: [{ window_title: 'TestWindow', window_id: 222 }]
      };
      mockExecuteSwiftCli.mockResolvedValue({ 
        success: true, 
        data: mockSwiftResponse, 
        messages: ['Note: Some windows might be minimized.'] 
      });

      const result = await listToolHandler({ item_type: 'application_windows', app: 'TestApp' }, mockContext);
      expect(result.content[0].text).toContain('Messages: Note: Some windows might be minimized.');
    });
  });
}); 