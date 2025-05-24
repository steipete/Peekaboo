import path from 'path';
import fs from 'fs/promises';
import os from 'os';
import { Logger } from 'pino'; 

import { 
  imageToolHandler, 
  listToolHandler,
  imageToolSchema,
  listToolSchema
} from '../../src/tools'; // Adjusted import path for schemas
import { initializeSwiftCliPath } from '../../src/utils/peekaboo-cli';
import { Result } from '@modelcontextprotocol/sdk/types.js'; // Corrected SDK import path and type

// Define a more specific type for content items used in Peekaboo
interface PeekabooContentItem {
  type: string;
  text?: string;
  imageUrl?: string;
  data?: any;
}

interface PeekabooWindowItem {
  app_name?: string; // Swift CLI might use app_name
  owningApplication?: string;
  kCGWindowOwnerName?: string; // For flexibility
  window_title?: string; // Swift CLI might use window_title
  windowName?: string;
  windowID?: number; // Made optional to reflect reality
  window_id?: number; // Allow for Swift CLI variant
  windowLevel?: number; // Make optional
  isOnScreen?: boolean; // Make optional
  is_on_screen?: boolean; // Allow for Swift CLI variant
  bounds?: { // Make optional
    X: number;
    Y: number;
    Width: number;
    Height: number;
  };
  window_index?: number; // Added based on log
  // Add any other potential fields observed from Swift CLI output
  [key: string]: any; // Allow other fields to be present
}

// Ensure local TestToolResponse interface is removed or commented out
// interface TestToolResponse {
//   isError?: boolean;
//   content?: Array<{ type: string; text?: string; imageUrl?: string; data?: any }>;
//   application_list?: Array<any>; 
//   saved_files?: Array<{ path: string; data?: string }>;
//   _meta?: { backend_error_code?: string; [key: string]: any };
//   [key: string]: any; 
// }

// Initialize Swift CLI path (assuming 'peekaboo' binary is at project root)
const packageRootDir = path.resolve(__dirname, '..', '..'); // Adjust path from tests/integration to project root
initializeSwiftCliPath(packageRootDir);

const mockLogger: Logger = {
  debug: jest.fn(),
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
  fatal: jest.fn(),
  child: jest.fn().mockReturnThis(),
  flush: jest.fn(),
  level: 'info',
  levels: { values: { info: 30 }, labels: { '30': 'info'} }
} as unknown as Logger; // Still using unknown for simplicity if full mock is too verbose

describe('Swift CLI Integration Tests', () => {
  describe('listToolHandler', () => {
    it('should return server_status correctly', async () => {
      const args = listToolSchema.parse({ item_type: 'server_status' });
      const response: Result = await listToolHandler(args, { logger: mockLogger }); 

      expect(response.isError).not.toBe(true);
      expect(response.content).toBeDefined();
      // Ensure content is an array and has at least one item before accessing it
      if (response.content && Array.isArray(response.content) && response.content.length > 0) {
        const firstContentItem = response.content[0] as PeekabooContentItem;
        expect(firstContentItem.type).toBe('text');
        expect(firstContentItem.text).toContain('Peekaboo MCP Server Status');
      } else {
        fail('Response content was not in the expected format for server_status');
      }
    });

    it('should call Swift CLI for running_applications and return a structured response', async () => {
      const args = listToolSchema.parse({ item_type: 'running_applications' });
      const response: Result = await listToolHandler(args, { logger: mockLogger }); 

      if (response.isError) {
        console.error('listToolHandler running_applications error:', JSON.stringify(response));
      }
      expect(response.isError).not.toBe(true);

      if (!response.isError) {
        expect(response).toHaveProperty('application_list');
        expect((response as any).application_list).toBeInstanceOf(Array); 
        // Optionally, check if at least one app is returned if any are expected to be running
        if ((response as any).application_list.length === 0) {
            console.warn('listToolHandler for running_applications returned an empty list.');
        }
      }
    }, 15000);

    it('should list windows for a known application (Finder) without details by default', async () => {
      const args = listToolSchema.parse({ 
        item_type: 'application_windows', 
        app: 'Finder'
        // No include_window_details passed
      });
      const response: Result = await listToolHandler(args, { logger: mockLogger });

      if (response.isError) {
        console.error('listToolHandler Finder windows error response:', JSON.stringify(response));
      }
      expect(response.isError).not.toBe(true);

      if (!response.isError) {
        expect(response).toHaveProperty('window_list');
        expect(response).toHaveProperty('target_application_info');
        
        const targetAppInfo = (response as any).target_application_info;
        expect(targetAppInfo).toBeDefined();
        expect(targetAppInfo.app_name).toBe('Finder'); 

        const windowList = (response as any).window_list as PeekabooWindowItem[];
        expect(windowList).toBeInstanceOf(Array);
        
        if (windowList.length > 0) {
          const firstWindow = windowList[0];
          // console.log('First window object from Finder (no details requested):', JSON.stringify(firstWindow, null, 2));
          expect(firstWindow).toHaveProperty('window_title'); // Expect basic info
          expect(firstWindow).toHaveProperty('window_index'); // Expect basic info
          // Should NOT have detailed info unless requested
          expect(firstWindow.windowID).toBeUndefined();
          expect(firstWindow.window_id).toBeUndefined();
          expect(firstWindow.bounds).toBeUndefined();
        } else {
          console.warn('listToolHandler for Finder windows returned an empty list. This might be normal.');
        }
      }
    }, 15000);

    it('should return an error when listing windows for a non-existent application', async () => {
      const nonExistentApp = 'DefinitelyNotAnApp123ABC';
      const args = listToolSchema.parse({ 
        item_type: 'application_windows', 
        app: nonExistentApp 
      });
      const response: Result = await listToolHandler(args, { logger: mockLogger });

      expect(response.isError).toBe(true);
      if (response.content && Array.isArray(response.content) && response.content.length > 0) {
        const firstContentItem = response.content[0] as PeekabooContentItem;
        // Expect the generic failure message from the handler when Swift CLI fails
        expect(firstContentItem.text?.toLowerCase()).toMatch(/list operation failed: swift cli execution failed/i);
      }
    }, 15000);
  });

  describe('imageToolHandler', () => {
    let tempImagePath: string;

    beforeEach(() => {
      tempImagePath = path.join(os.tmpdir(), `peekaboo-test-image-${Date.now()}.png`);
    });

    afterEach(async () => {
      try {
        await fs.unlink(tempImagePath);
      } catch (error) {
        // Ignore
      }
    });

    it('should attempt to capture screen and save to a file', async () => {
      const args = imageToolSchema.parse({
        mode: 'screen',
        path: tempImagePath,
        format: 'png',
        return_data: false,
      });
      const response: Result = await imageToolHandler(args, { logger: mockLogger }); 

      if (response.isError) {
        let errorText = '';
        if (response.content && Array.isArray(response.content) && response.content.length > 0) {
          const firstContentItem = response.content[0] as PeekabooContentItem;
          errorText = firstContentItem.text?.toLowerCase() ?? '';
        }
        const metaErrorCode = (response._meta as any)?.backend_error_code; 
        // console.log('Image tool error response:', JSON.stringify(response)); 

        expect(
          errorText.includes('permission') ||
          errorText.includes('denied') ||
          metaErrorCode === 'PERMISSION_DENIED_SCREEN_RECORDING' ||
          errorText.includes('capture failed')
        ).toBeTruthy();

        await expect(fs.access(tempImagePath)).rejects.toThrow();
      } else {
        expect(response.isError).toBeUndefined(); 
        expect(response).toHaveProperty('saved_files');
        const successResponse = response as Result & { saved_files?: { path: string }[] }; 
        expect(successResponse.saved_files).toBeInstanceOf(Array);
        if (successResponse.saved_files && successResponse.saved_files.length > 0) {
          expect(successResponse.saved_files[0]?.path).toBe(tempImagePath);
        }
        await expect(fs.access(tempImagePath)).resolves.toBeUndefined();
      }
    }, 20000);
  });
}); 