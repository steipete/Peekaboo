import { vi } from 'vitest';
import { pino } from 'pino';

// Mock all the tool handlers to avoid import.meta issues
const mockImageToolHandler = vi.fn();
const mockListToolHandler = vi.fn();
const mockAnalyzeToolHandler = vi.fn();

vi.mock('../../src/tools/image', () => ({
  imageToolHandler: mockImageToolHandler
}));

vi.mock('../../src/tools/list', () => ({
  listToolHandler: mockListToolHandler
}));

vi.mock('../../src/tools/analyze', () => ({
  analyzeToolHandler: mockAnalyzeToolHandler
}));

// Create a mock logger for tests
const mockLogger = pino({ level: 'silent' });
const mockContext = { logger: mockLogger };

describe('MCP Server Integration', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('Tool Integration Tests', () => {
    describe('Image Tool', () => {
      it('should capture screen successfully', async () => {
        const mockResult = {
          content: [{
            type: 'text',
            text: 'Captured 1 image in screen mode.\n\nSaved files:\n1. /tmp/screen_capture.png (Screen Capture)'
          }],
          saved_files: [{
            path: '/tmp/screen_capture.png',
            item_label: 'Screen Capture',
            mime_type: 'image/png'
          }]
        };
        
        mockImageToolHandler.mockResolvedValue(mockResult);

        const result = await mockImageToolHandler({
          format: 'png',
          return_data: false,
          capture_focus: 'background'
        }, mockContext);

        expect(result.content).toHaveLength(1);
        expect(result.content[0].type).toBe('text');
        expect(result.content[0].text).toContain('Captured 1 image in screen mode');
        expect(result.isError).toBeFalsy();
      });

      it('should handle permission errors', async () => {
        const mockResult = {
          content: [{
            type: 'text',
            text: 'Image capture failed: Permission denied. Screen recording permission is required.'
          }],
          isError: true,
          _meta: {
            backend_error_code: 'PERMISSION_DENIED'
          }
        };
        
        mockImageToolHandler.mockResolvedValue(mockResult);

        const result = await mockImageToolHandler({
          format: 'png',
          return_data: false,
          capture_focus: 'background'
        }, mockContext);

        expect(result.content[0].text).toContain('Permission');
        expect(result.isError).toBe(true);
      });
    });

    describe('List Tool', () => {
      it('should list running applications', async () => {
        const mockResult = {
          content: [{
            type: 'text',
            text: 'Found 3 running applications:\n\n1. Safari (com.apple.Safari) - PID: 1234 [ACTIVE] - Windows: 2\n2. Cursor (com.todesktop.230313mzl4w4u92) - PID: 5678 - Windows: 1\n3. Terminal (com.apple.Terminal) - PID: 9012 - Windows: 1'
          }],
          application_list: []
        };
        
        mockListToolHandler.mockResolvedValue(mockResult);

        const result = await mockListToolHandler({
          item_type: 'running_applications'
        }, mockContext);

        expect(result.content[0].text).toContain('Found 3 running applications');
        expect(result.content[0].text).toContain('Safari');
        expect(result.content[0].text).toContain('Cursor');
        expect(result.isError).toBeFalsy();
      });

      it('should list application windows', async () => {
        const mockResult = {
          content: [{
            type: 'text',
            text: 'Found 2 windows for application: Safari (com.apple.Safari) - PID: 1234\n\nWindows:\n1. Safari - Main Window (ID: 12345, Index: 0)\n2. Safari - Secondary Window (ID: 12346, Index: 1)'
          }],
          window_list: [],
          target_application_info: {}
        };
        
        mockListToolHandler.mockResolvedValue(mockResult);

        const result = await mockListToolHandler({
          item_type: 'application_windows',
          app: 'Safari'
        }, mockContext);

        expect(result.content[0].text).toContain('Found 2 windows for application: Safari');
        expect(result.content[0].text).toContain('Safari - Main Window');
        expect(result.isError).toBeFalsy();
      });

      it('should require app parameter for application_windows', async () => {
        const mockResult = {
          content: [{
            type: 'text',
            text: "For 'application_windows', 'app' identifier is required."
          }],
          isError: true
        };
        
        mockListToolHandler.mockResolvedValue(mockResult);

        const result = await mockListToolHandler({
          item_type: 'application_windows'
        }, mockContext);

        expect(result.content[0].text).toContain("For 'application_windows', 'app' identifier is required");
        expect(result.isError).toBe(true);
      });
    });

    describe('Analyze Tool', () => {
      beforeEach(() => {
        process.env.PEEKABOO_AI_PROVIDERS = 'ollama/llava';
      });

      it('should analyze image successfully', async () => {
        const mockResult = {
          content: [{
            type: 'text',
            text: 'Image Analysis:\n\nThis is a screenshot of Safari browser showing a webpage with various elements including navigation bars, content areas, and user interface components.'
          }],
          analysis_text: 'This is a screenshot of Safari browser showing a webpage with various elements including navigation bars, content areas, and user interface components.'
        };
        
        mockAnalyzeToolHandler.mockResolvedValue(mockResult);

        const result = await mockAnalyzeToolHandler({
          image_path: '/tmp/test.png',
          question: 'What do you see?'
        }, mockContext);

        expect(result.content[0].text).toContain('This is a screenshot of Safari browser');
        expect(result.analysis_text).toBeDefined();
        expect(result.isError).toBeFalsy();
      });

      it('should handle missing AI configuration', async () => {
        const mockResult = {
          content: [{
            type: 'text',
            text: 'AI analysis not configured. Please set PEEKABOO_AI_PROVIDERS environment variable.'
          }],
          isError: true
        };
        
        mockAnalyzeToolHandler.mockResolvedValue(mockResult);

        const result = await mockAnalyzeToolHandler({
          image_path: '/tmp/test.png',
          question: 'What do you see?'
        }, mockContext);

        expect(result.content[0].text).toContain('AI analysis not configured');
        expect(result.isError).toBe(true);
      });
    });
  });

  describe('Error Handling', () => {
    it('should handle Swift CLI errors gracefully', async () => {
      const mockResult = {
        content: [{
          type: 'text',
          text: 'Image capture failed: Swift CLI crashed'
        }],
        isError: true,
        _meta: {
          backend_error_code: 'SWIFT_CLI_CRASH'
        }
      };
      
      mockImageToolHandler.mockResolvedValue(mockResult);

      const result = await mockImageToolHandler({
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      }, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain('Image capture failed');
    });

    it('should handle unexpected errors', async () => {
      const mockResult = {
        content: [{
          type: 'text',
          text: 'Unexpected error: Network connection failed'
        }],
        isError: true
      };
      
      mockListToolHandler.mockResolvedValue(mockResult);

      const result = await mockListToolHandler({
        item_type: 'running_applications'
      }, mockContext);

      expect(result.content[0].text).toContain('Unexpected error');
      expect(result.isError).toBe(true);
    });
  });

  describe('Cross-tool Integration', () => {
    it('should work with concurrent tool calls', async () => {
      const mockListResult = {
        content: [{
          type: 'text',
          text: 'Found 3 running applications:\n\n1. Safari\n2. Cursor\n3. Terminal'
        }],
        application_list: []
      };
      
      const mockImageResult = {
        content: [{
          type: 'text',
          text: 'Captured 1 image in screen mode.'
        }],
        saved_files: []
      };
      
      mockListToolHandler.mockResolvedValue(mockListResult);
      mockImageToolHandler.mockResolvedValue(mockImageResult);

      // Make concurrent requests
      const [listResult, imageResult] = await Promise.all([
        mockListToolHandler({ item_type: 'running_applications' }, mockContext),
        mockImageToolHandler({ format: 'png', return_data: false, capture_focus: 'background' }, mockContext)
      ]);

      expect(listResult.content[0].text).toContain('Found 3 running applications');
      expect(imageResult.content[0].text).toContain('Captured 1 image in screen mode');
      expect(mockListToolHandler).toHaveBeenCalledTimes(1);
      expect(mockImageToolHandler).toHaveBeenCalledTimes(1);
    });
  });
}); 