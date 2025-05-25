import { SwiftCliResponse, ApplicationListData, WindowListData, ImageCaptureData } from '../../src/types/index';
import { vi } from 'vitest';

// Mock Swift CLI responses for testing
export const mockSwiftCli = {
  // Mock successful application list response
  listApplications(): SwiftCliResponse {
    return {
      success: true,
      data: {
        applications: [
          {
            app_name: 'Safari',
            bundle_id: 'com.apple.Safari',
            pid: 1234,
            is_active: true,
            window_count: 2
          },
          {
            app_name: 'Cursor',
            bundle_id: 'com.todesktop.230313mzl4w4u92',
            pid: 5678,
            is_active: false,
            window_count: 1
          },
          {
            app_name: 'Terminal',
            bundle_id: 'com.apple.Terminal',
            pid: 9012,
            is_active: false,
            window_count: 3
          }
        ]
      } as ApplicationListData,
      messages: []
    };
  },

  // Mock successful window list response
  listWindows(appName: string): SwiftCliResponse {
    return {
      success: true,
      data: {
        target_application_info: {
          app_name: appName,
          bundle_id: `com.apple.${appName}`,
          pid: 1234
        },
        windows: [
          {
            window_title: `${appName} - Main Window`,
            window_id: 1,
            window_index: 0,
            bounds: { x: 100, y: 100, width: 800, height: 600 },
            is_on_screen: true
          },
          {
            window_title: `${appName} - Secondary Window`,
            window_id: 2,
            window_index: 1,
            bounds: { x: 200, y: 200, width: 600, height: 400 },
            is_on_screen: true
          }
        ]
      } as WindowListData,
      messages: []
    };
  },

  // Mock successful image capture response
  captureImage(mode: string, options?: { app?: string; path?: string; format?: string }): SwiftCliResponse {
    const appName = options?.app;
    const format = options?.format || 'png';
    const defaultFileName = appName ? `${appName.toLowerCase()}_window.${format}` : `screen_capture.${format}`;
    const actualPath = options?.path || `/tmp/${defaultFileName}`;

    return {
      success: true,
      data: {
        saved_files: [
          {
            path: actualPath,
            item_label: appName ? `${appName} Window` : 'Screen Capture',
            window_title: appName ? `${appName} - Main Window` : undefined,
            window_id: appName ? 1 : undefined,
            mime_type: `image/${format === 'jpg' ? 'jpeg' : format}`
          }
        ]
      } as ImageCaptureData,
      messages: []
    };
  },

  // Mock error responses
  permissionDenied(): SwiftCliResponse {
    return {
      success: false,
      error: {
        message: 'Permission denied. Screen recording permission required.',
        code: 'PERMISSION_DENIED'
      }
    };
  },

  appNotFound(appName: string): SwiftCliResponse {
    return {
      success: false,
      error: {
        message: `Application '${appName}' not found or not running.`,
        code: 'APP_NOT_FOUND'
      }
    };
  },

  // Mock server status response
  serverStatus(): SwiftCliResponse {
    return {
      success: true,
      data: {
        server_version: '1.1.1',
        swift_cli_version: '1.0.0',
        status: 'running'
      },
      messages: []
    };
  }
};

// Mock child_process.spawn for Swift CLI execution
export const mockChildProcess = {
  spawn: vi.fn().mockImplementation(() => ({
    stdout: {
      on: vi.fn((event, callback) => {
        if (event === 'data') {
          callback(Buffer.from(JSON.stringify(mockSwiftCli.listApplications())));
        }
      })
    },
    stderr: {
      on: vi.fn()
    },
    on: vi.fn((event, callback) => {
      if (event === 'close') {
        callback(0);
      }
    })
  }))
}; 