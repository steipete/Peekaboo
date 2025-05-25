import { imageToolHandler, buildSwiftCliArgs, ImageToolInput } from '../../../src/tools/image';
import { executeSwiftCli, readImageAsBase64 } from '../../../src/utils/peekaboo-cli';
import { mockSwiftCli } from '../../mocks/peekaboo-cli.mock';
import { pino } from 'pino';
import { SavedFile, ImageCaptureData } from '../../../src/types';

// Mock the Swift CLI utility
jest.mock('../../../src/utils/peekaboo-cli', () => ({
  executeSwiftCli: jest.fn(),
  readImageAsBase64: jest.fn()
}));

const mockExecuteSwiftCli = executeSwiftCli as jest.MockedFunction<typeof executeSwiftCli>;
const mockReadImageAsBase64 = readImageAsBase64 as jest.MockedFunction<typeof readImageAsBase64>;

// Create a mock logger for tests
const mockLogger = pino({ level: 'silent' });
const mockContext = { logger: mockLogger };

describe('Image Tool', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('imageToolHandler', () => {
    it('should capture screen with minimal parameters', async () => {
      const mockResponse = mockSwiftCli.captureImage('screen');
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const result = await imageToolHandler({
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      }, mockContext);

      expect(result.content[0].type).toBe('text');
      expect(result.content[0].text).toContain('Captured');
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(['image', '--mode', 'screen']),
        mockLogger
      );
    });

    it('should capture window with app parameter', async () => {
      const mockResponse = mockSwiftCli.captureImage('window');
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const result = await imageToolHandler({
        app: 'Safari',
        mode: 'window',
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      }, mockContext);

      expect(result.content[0].type).toBe('text');
      expect(result.content[0].text).toContain('Captured');
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(['image', '--app', 'Safari', '--mode', 'window']),
        mockLogger
      );
    });

    it('should handle specific format and options', async () => {
      const mockResponse = mockSwiftCli.captureImage('screen');
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const result = await imageToolHandler({
        format: 'jpg',
        return_data: true,
        capture_focus: 'foreground',
        path: '/tmp/custom'
      }, mockContext);

      expect(result.content[0].type).toBe('text');
      expect(result.content[0].text).toContain('Captured');
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(['image', '--path', '/tmp/custom', '--mode', 'screen', '--format', 'jpg', '--capture-focus', 'foreground']),
        mockLogger
      );
    });

    it('should handle Swift CLI errors', async () => {
      const mockResponse = {
        success: false,
        error: {
          message: 'Permission denied',
          code: 'PERMISSION_DENIED'
        }
      };
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const result = await imageToolHandler({
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      }, mockContext);

      expect(result.content[0].text).toContain('Image capture failed');
      expect(result.isError).toBe(true);
    });

    it('should handle unexpected errors', async () => {
      mockExecuteSwiftCli.mockRejectedValue(new Error('Unexpected error'));

      const result = await imageToolHandler({
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      }, mockContext);

      expect(result.content[0].text).toContain('Unexpected error');
      expect(result.isError).toBe(true);
    });

    it('should return image data when return_data is true and readImageAsBase64 succeeds', async () => {
      const mockSavedFile: SavedFile = { path: '/tmp/test.png', mime_type: 'image/png', item_label: 'Screen 1' };
      const mockCaptureData: ImageCaptureData = { saved_files: [mockSavedFile] };
      const mockCliResponse = { success: true, data: mockCaptureData, messages: ['Captured one file'] };
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);
      mockReadImageAsBase64.mockResolvedValue('base64imagedata');

      const result = await imageToolHandler({
        format: 'png',
        return_data: true,
        capture_focus: 'background'
      }, mockContext);

      expect(result.isError).toBeUndefined(); // Should not be an error response
      expect(result.content).toEqual(expect.arrayContaining([
        expect.objectContaining({ type: 'text', text: expect.stringContaining('Captured 1 image') }),
        expect.objectContaining({ type: 'text', text: 'Messages: Captured one file' }),
        expect.objectContaining({
          type: 'image',
          data: 'base64imagedata',
          mimeType: 'image/png',
          metadata: expect.objectContaining({ source_path: '/tmp/test.png' })
        })
      ]));
      expect(mockReadImageAsBase64).toHaveBeenCalledWith('/tmp/test.png');
      expect(result.saved_files).toEqual([mockSavedFile]);
    });

    it('should include messages from Swift CLI in the output', async () => {
      const mockCliResponse = {
        success: true,
        data: { saved_files: [{ path: '/tmp/msg.png', mime_type: 'image/png' }] },
        messages: ['Test message 1', 'Another message']
      };
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);

      const result = await imageToolHandler({
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      }, mockContext);
      
      expect(result.content).toEqual(expect.arrayContaining([
        expect.objectContaining({ type: 'text', text: expect.stringContaining('Messages: Test message 1; Another message') })
      ]));
    });

    it('should handle error from readImageAsBase64 and still return summary', async () => {
      const mockSavedFile: SavedFile = { path: '/tmp/fail.png', mime_type: 'image/png' };
      const mockCaptureData: ImageCaptureData = { saved_files: [mockSavedFile] };
      const mockCliResponse = { success: true, data: mockCaptureData };
      mockExecuteSwiftCli.mockResolvedValue(mockCliResponse);
      mockReadImageAsBase64.mockRejectedValue(new Error('Read failed'));

      const result = await imageToolHandler({
        format: 'png',
        return_data: true,
        capture_focus: 'background'
      }, mockContext);

      expect(result.isError).toBeUndefined();
      expect(result.content).toEqual(expect.arrayContaining([
        expect.objectContaining({ type: 'text', text: expect.stringContaining('Captured 1 image') }),
        expect.objectContaining({ type: 'text', text: 'Warning: Could not read image data from /tmp/fail.png. Error: Read failed' })
      ]));
      expect(result.saved_files).toEqual([mockSavedFile]);
    });

    it('should handle empty saved_files array', async () => {
      const mockResponse = {
        success: true,
        data: { saved_files: [] }
      };
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const result = await imageToolHandler({
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      }, mockContext);

      expect(result.content[0].text).toBe('Image capture completed but no files were saved.');
      expect(result.saved_files).toEqual([]);
    });

    it('should handle malformed Swift CLI response', async () => {
      const mockResponse = {
        success: true,
        data: null // Invalid data, triggers the new check in imageToolHandler
      };
      mockExecuteSwiftCli.mockResolvedValue(mockResponse as any);

      const result = await imageToolHandler({
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      }, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain('Image capture failed: Invalid response from capture utility (no data).');
      expect(result._meta?.backend_error_code).toBe('INVALID_RESPONSE_NO_DATA');
    });

    it('should handle partial failures when reading multiple images', async () => {
      const mockFiles: SavedFile[] = [
        { path: '/tmp/img1.png', mime_type: 'image/png', item_label: 'Image 1' },
        { path: '/tmp/img2.jpg', mime_type: 'image/jpeg', item_label: 'Image 2' }
      ];
      const mockResponse = {
        success: true,
        data: { saved_files: mockFiles }
      };
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);
      mockReadImageAsBase64
        .mockResolvedValueOnce('base64data1')
        .mockRejectedValueOnce(new Error('Read failed'));

      const result = await imageToolHandler({
        format: 'png',
        return_data: true,
        capture_focus: 'background'
      }, mockContext);

      expect(result.content).toEqual(expect.arrayContaining([
        expect.objectContaining({ type: 'text', text: expect.stringContaining('Captured 2 images')}), // Summary text
        expect.objectContaining({
          type: 'image',
          data: 'base64data1'
        }),
        expect.objectContaining({
          type: 'text',
          text: 'Warning: Could not read image data from /tmp/img2.jpg. Error: Read failed'
        })
      ]));
    });
  });

  describe('buildSwiftCliArgs', () => {
    const defaults = { format: 'png' as const, return_data: false, capture_focus: 'background' as const };

    it('should default to screen mode if no app provided and no mode specified', () => {
      const args = buildSwiftCliArgs({ ...defaults });
      expect(args).toEqual(['image', '--mode', 'screen', '--format', 'png', '--capture-focus', 'background']);
    });

    it('should default to window mode if app is provided and no mode specified', () => {
      const args = buildSwiftCliArgs({ ...defaults, app: 'Safari' });
      expect(args).toEqual(['image', '--app', 'Safari', '--mode', 'window', '--format', 'png', '--capture-focus', 'background']);
    });

    it('should use specified mode: screen', () => {
      const args = buildSwiftCliArgs({ ...defaults, mode: 'screen' });
      expect(args).toEqual(expect.arrayContaining(['--mode', 'screen']));
    });

    it('should use specified mode: window with app', () => {
      const args = buildSwiftCliArgs({ ...defaults, app: 'Terminal', mode: 'window' });
      expect(args).toEqual(expect.arrayContaining(['--app', 'Terminal', '--mode', 'window']));
    });

    it('should use specified mode: multi with app', () => {
      const args = buildSwiftCliArgs({ ...defaults, app: 'Finder', mode: 'multi' });
      expect(args).toEqual(expect.arrayContaining(['--app', 'Finder', '--mode', 'multi']));
    });

    it('should include app', () => {
      const args = buildSwiftCliArgs({ ...defaults, app: 'Notes' });
      expect(args).toEqual(expect.arrayContaining(['--app', 'Notes']));
    });

    it('should include path', () => {
      const args = buildSwiftCliArgs({ ...defaults, path: '/tmp/image.jpg' });
      expect(args).toEqual(expect.arrayContaining(['--path', '/tmp/image.jpg']));
    });

    it('should include window_specifier by title', () => {
      const args = buildSwiftCliArgs({ ...defaults, app: 'Safari', window_specifier: { title: 'Apple' } });
      expect(args).toEqual(expect.arrayContaining(['--window-title', 'Apple']));
    });

    it('should include window_specifier by index', () => {
      const args = buildSwiftCliArgs({ ...defaults, app: 'Safari', window_specifier: { index: 0 } });
      expect(args).toEqual(expect.arrayContaining(['--window-index', '0']));
    });

    it('should include format (default png)', () => {
      const args = buildSwiftCliArgs({ ...defaults });
      expect(args).toEqual(expect.arrayContaining(['--format', 'png']));
    });

    it('should include specified format jpg', () => {
      const args = buildSwiftCliArgs({ ...defaults, format: 'jpg' });
      expect(args).toEqual(expect.arrayContaining(['--format', 'jpg']));
    });

    it('should include capture_focus (default background)', () => {
      const args = buildSwiftCliArgs({ ...defaults });
      expect(args).toEqual(expect.arrayContaining(['--capture-focus', 'background']));
    });

    it('should include specified capture_focus foreground', () => {
      const args = buildSwiftCliArgs({ ...defaults, capture_focus: 'foreground' });
      expect(args).toEqual(expect.arrayContaining(['--capture-focus', 'foreground']));
    });

    it('should handle all options together', () => {
      const input: ImageToolInput = {
        ...defaults, // Ensure all required fields are present
        app: 'Preview',
        path: '/users/test/file.tiff',
        mode: 'window',
        window_specifier: { index: 1 },
        format: 'png', 
        capture_focus: 'foreground'
      };
      const args = buildSwiftCliArgs(input);
      expect(args).toEqual([
        'image',
        '--app', 'Preview',
        '--path', '/users/test/file.tiff',
        '--mode', 'window',
        '--window-index', '1',
        '--format', 'png',
        '--capture-focus', 'foreground'
      ]);
    });
  });

  describe('Edge Cases and Error Handling', () => {
    it('should handle window capture with window_specifier index', async () => {
      const mockResponse = mockSwiftCli.captureImage('window');
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const result = await imageToolHandler({
        app: 'Safari',
        window_specifier: { index: 0 },
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      }, mockContext);

      expect(result.isError).toBeUndefined();
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(['--window-index', '0']),
        mockLogger
      );
    });

    it('should handle all supported image formats', async () => {
      const formats: Array<'png' | 'jpg'> = ['png', 'jpg'];
      
      for (const format of formats) {
        const mockResponse = mockSwiftCli.captureImage('screen');
        mockExecuteSwiftCli.mockResolvedValue(mockResponse);
        
        const result = await imageToolHandler({
          format,
          return_data: false,
          capture_focus: 'background'
        }, mockContext);
        
        expect(result.isError).toBeUndefined();
        expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
          expect.arrayContaining(['--format', format]),
          mockLogger
        );
      }
    });

    it('should handle window capture with window_specifier title', async () => {
      const mockResponse = mockSwiftCli.captureImage('window');
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const result = await imageToolHandler({
        app: 'Safari',
        window_specifier: { title: 'Google' },
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      }, mockContext);

      expect(result.isError).toBeUndefined();
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(['--window-title', 'Google']),
        mockLogger
      );
    });

    it('should handle very long app names', async () => {
      const longAppName = 'A'.repeat(256);
      const mockResponse = mockSwiftCli.captureImage('window');
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const result = await imageToolHandler({
        app: longAppName,
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      }, mockContext);

      expect(result.isError).toBeUndefined();
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(['--app', longAppName]),
        mockLogger
      );
    });

    it('should handle special characters in app names', async () => {
      const specialAppName = 'App with Spaces & Special-Chars (1)';
      const mockResponse = mockSwiftCli.captureImage('window');
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const result = await imageToolHandler({
        app: specialAppName,
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      }, mockContext);

      expect(result.isError).toBeUndefined();
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(['--app', specialAppName]),
        mockLogger
      );
    });

    it('should handle paths with spaces and special characters', async () => {
      const specialPath = '/Users/Test User/Documents/Screen Captures (2024)/';
      const mockResponse = mockSwiftCli.captureImage('screen');
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const result = await imageToolHandler({
        path: specialPath,
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      }, mockContext);

      expect(result.isError).toBeUndefined();
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(['--path', specialPath]),
        mockLogger
      );
    });

    it('should handle multiple saved files', async () => {
      const mockFiles: SavedFile[] = [
        { path: '/tmp/screen1.png', mime_type: 'image/png', item_label: 'Screen 1' },
        { path: '/tmp/screen2.png', mime_type: 'image/png', item_label: 'Screen 2' },
        { path: '/tmp/screen3.png', mime_type: 'image/png', item_label: 'Screen 3' }
      ];
      const mockResponse = {
        success: true,
        data: { saved_files: mockFiles }
      };
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const result = await imageToolHandler({
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      }, mockContext);

      expect(result.content[0].text).toContain('Captured 3 images');
      expect(result.content[0].text).toContain('Screen 1');
      expect(result.content[0].text).toContain('Screen 2');
      expect(result.content[0].text).toContain('Screen 3');
      expect(result.saved_files).toEqual(mockFiles);
    });

    it('should handle return_data with multiple files', async () => {
      const mockFiles: SavedFile[] = [
        { path: '/tmp/img1.png', mime_type: 'image/png', item_label: 'Image 1' },
        { path: '/tmp/img2.jpg', mime_type: 'image/jpeg', item_label: 'Image 2' }
      ];
      const mockResponse = {
        success: true,
        data: { saved_files: mockFiles }
      };
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);
      mockReadImageAsBase64
        .mockResolvedValueOnce('base64data1')
        .mockResolvedValueOnce('base64data2');

      const result = await imageToolHandler({
        format: 'png',
        return_data: true,
        capture_focus: 'background'
      }, mockContext);

      expect(result.content).toEqual(expect.arrayContaining([
        expect.objectContaining({
          type: 'image',
          data: 'base64data1',
          mimeType: 'image/png'
        }),
        expect.objectContaining({
          type: 'image',
          data: 'base64data2',
          mimeType: 'image/jpeg'
        })
      ]));
      expect(mockReadImageAsBase64).toHaveBeenCalledTimes(2);
    });

    it('should handle Swift CLI timeout errors', async () => {
      const mockResponse = {
        success: false,
        error: {
          message: 'Command timed out after 30 seconds',
          code: 'TIMEOUT'
        }
      };
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const result = await imageToolHandler({
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      }, mockContext);

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain('Command timed out');
      expect(result._meta?.backend_error_code).toBe('TIMEOUT');
    });

    it('should handle window_specifier with both title and index', async () => {
      const mockResponse = mockSwiftCli.captureImage('window');
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const args = buildSwiftCliArgs({
        app: 'Safari',
        window_specifier: { title: 'Google', index: 1 },
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      });

      // Should only include the first one (title takes precedence in implementation)
      expect(args).toContain('--window-title');
      expect(args).toContain('Google');
      expect(args).not.toContain('--window-index');
    });

    it('should handle negative window index', async () => {
      const args = buildSwiftCliArgs({
        app: 'Safari',
        window_specifier: { index: -1 },
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      });

      expect(args).toContain('--window-index');
      expect(args).toContain('-1');
    });

    it('should handle very large window index', async () => {
      const largeWindowIndex = 999999;
      const mockResponse = mockSwiftCli.captureImage('window');
      mockExecuteSwiftCli.mockResolvedValue(mockResponse);

      const result = await imageToolHandler({
        app: 'Safari',
        window_specifier: { index: largeWindowIndex },
        format: 'png',
        return_data: false,
        capture_focus: 'background'
      }, mockContext);

      expect(result.isError).toBeUndefined();
      expect(mockExecuteSwiftCli).toHaveBeenCalledWith(
        expect.arrayContaining(['--window-index', largeWindowIndex.toString()]),
        mockLogger
      );
    });
  });
}); 