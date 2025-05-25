import { vi } from 'vitest';
import { pino } from 'pino';
import { analyzeToolHandler, determineProviderAndModel, AnalyzeToolInput } from '../../../src/tools/analyze';
import { readImageAsBase64 } from '../../../src/utils/peekaboo-cli';
import {
  parseAIProviders,
  isProviderAvailable,
  analyzeImageWithProvider,
  getDefaultModelForProvider
} from '../../../src/utils/ai-providers';
import { ToolContext, AIProvider } from '../../../src/types';
import path from 'path'; // Import path for extname

// Mocks
vi.mock('../../../src/utils/peekaboo-cli');
vi.mock('../../../src/utils/ai-providers');

const mockReadImageAsBase64 = readImageAsBase64 as vi.MockedFunction<typeof readImageAsBase64>;
const mockParseAIProviders = parseAIProviders as vi.MockedFunction<typeof parseAIProviders>;
const mockIsProviderAvailable = isProviderAvailable as vi.MockedFunction<typeof isProviderAvailable>;
const mockAnalyzeImageWithProvider = analyzeImageWithProvider as vi.MockedFunction<typeof analyzeImageWithProvider>;
const mockGetDefaultModelForProvider = getDefaultModelForProvider as vi.MockedFunction<typeof getDefaultModelForProvider>;


// Create a mock logger for tests
const mockLogger = pino({ level: 'silent' });
const mockContext: ToolContext = { logger: mockLogger };

const MOCK_IMAGE_BASE64 = 'base64imagedata';

describe('Analyze Tool', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // Reset environment variables
    delete process.env.PEEKABOO_AI_PROVIDERS;
    mockReadImageAsBase64.mockResolvedValue(MOCK_IMAGE_BASE64); // Default mock for successful read
  });

  describe('determineProviderAndModel', () => {
    const configured: AIProvider[] = [
      { provider: 'ollama', model: 'llava:server' },
      { provider: 'openai', model: 'gpt-4o:server' },
    ];

    it('should use auto: first available configured provider if no input config', async () => {
      mockIsProviderAvailable.mockResolvedValueOnce(false).mockResolvedValueOnce(true);
      mockGetDefaultModelForProvider.mockReturnValue('default-model');

      const result = await determineProviderAndModel(undefined, configured, mockLogger);
      expect(result).toEqual({ provider: 'openai', model: 'gpt-4o:server' });
      expect(mockIsProviderAvailable).toHaveBeenCalledTimes(2);
      expect(mockIsProviderAvailable).toHaveBeenNthCalledWith(1, configured[0], mockLogger);
      expect(mockIsProviderAvailable).toHaveBeenNthCalledWith(2, configured[1], mockLogger);
      expect(mockGetDefaultModelForProvider).not.toHaveBeenCalled(); // Model was in configuredProviders
    });

    it('should use auto: first available and use default model if configured has no model', async () => {
      const configuredNoModel: AIProvider[] = [{ provider: 'ollama', model: '' }];
      mockIsProviderAvailable.mockResolvedValueOnce(true);
      mockGetDefaultModelForProvider.mockReturnValueOnce('llava:default');

      const result = await determineProviderAndModel(undefined, configuredNoModel, mockLogger);
      expect(result).toEqual({ provider: 'ollama', model: 'llava:default' });
      expect(mockGetDefaultModelForProvider).toHaveBeenCalledWith('ollama');
    });

    it('should use auto: input model overrides configured provider model', async () => {
      mockIsProviderAvailable.mockResolvedValueOnce(true);
      const result = await determineProviderAndModel(
        { type: 'auto', model: 'custom-llava' }, 
        configured, 
        mockLogger
      );
      expect(result).toEqual({ provider: 'ollama', model: 'custom-llava' });
    });

    it('should use specific provider if available', async () => {
      mockIsProviderAvailable.mockResolvedValue(true);
      const result = await determineProviderAndModel(
        { type: 'openai', model: 'gpt-custom' },
        configured,
        mockLogger
      );
      expect(result).toEqual({ provider: 'openai', model: 'gpt-custom' });
      expect(mockIsProviderAvailable).toHaveBeenCalledWith(configured[1], mockLogger);
    });

    it('should use specific provider with its configured model if no input model', async () => {
      mockIsProviderAvailable.mockResolvedValue(true);
      const result = await determineProviderAndModel(
        { type: 'openai' },
        configured,
        mockLogger
      );
      expect(result).toEqual({ provider: 'openai', model: 'gpt-4o:server' });
    });
    
    it('should use specific provider with default model if no input model and no configured model', async () => {
      const configuredNoModel: AIProvider[] = [{ provider: 'openai', model: ''}];
      mockIsProviderAvailable.mockResolvedValue(true);
      mockGetDefaultModelForProvider.mockReturnValueOnce('gpt-default');
      const result = await determineProviderAndModel(
        { type: 'openai' },
        configuredNoModel,
        mockLogger
      );
      expect(result).toEqual({ provider: 'openai', model: 'gpt-default' });
      expect(mockGetDefaultModelForProvider).toHaveBeenCalledWith('openai');
    });

    it('should throw if specific provider is not in server config', async () => {
      const serverConfigWithoutOpenAI: AIProvider[] = [
        { provider: 'ollama', model: 'llava:server' }
      ];
      await expect(determineProviderAndModel(
        { type: 'openai' }, // Type is valid enum, but openai is not in serverConfigWithoutOpenAI
        serverConfigWithoutOpenAI,
        mockLogger
      )).rejects.toThrow("Provider 'openai' is not enabled in server's PEEKABOO_AI_PROVIDERS configuration.");
    });

    it('should throw if specific provider is configured but not available', async () => {
      mockIsProviderAvailable.mockResolvedValue(false);
      await expect(determineProviderAndModel(
        { type: 'ollama' },
        configured,
        mockLogger
      )).rejects.toThrow("Provider 'ollama' is configured but not currently available.");
    });

    it('should return null provider if auto and no providers are available', async () => {
      mockIsProviderAvailable.mockResolvedValue(false);
      const result = await determineProviderAndModel(undefined, configured, mockLogger);
      expect(result).toEqual({ provider: null, model: '' });
      expect(mockIsProviderAvailable).toHaveBeenCalledTimes(configured.length);
    });
  });

  describe('analyzeToolHandler', () => {
    const validInput: AnalyzeToolInput = {
      image_path: '/path/to/image.png',
      question: 'What is this?'
    };

    it('should analyze image successfully with auto provider selection', async () => {
      process.env.PEEKABOO_AI_PROVIDERS = 'ollama/llava,openai/gpt-4o';
      const parsedProviders: AIProvider[] = [{ provider: 'ollama', model: 'llava' }, { provider: 'openai', model: 'gpt-4o' }];
      mockParseAIProviders.mockReturnValue(parsedProviders);
      mockIsProviderAvailable.mockResolvedValueOnce(false).mockResolvedValueOnce(true); // openai is available
      mockAnalyzeImageWithProvider.mockResolvedValue('AI says: It is an apple.');

      const result = await analyzeToolHandler(validInput, mockContext);

      expect(mockReadImageAsBase64).toHaveBeenCalledWith(validInput.image_path);
      expect(mockParseAIProviders).toHaveBeenCalledWith(process.env.PEEKABOO_AI_PROVIDERS);
      expect(mockIsProviderAvailable).toHaveBeenCalledWith(parsedProviders[1], mockLogger); 
      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        { provider: 'openai', model: 'gpt-4o' }, // Determined provider/model
        validInput.image_path,
        MOCK_IMAGE_BASE64,
        validInput.question,
        mockLogger
      );
      expect(result.content[0].text).toBe('AI says: It is an apple.');
      expect(result.analysis_text).toBe('AI says: It is an apple.');
      expect((result as any).model_used).toBe('openai/gpt-4o');
      expect(result.isError).toBeUndefined();
    });

    it('should use specific provider and model if provided and available', async () => {
      process.env.PEEKABOO_AI_PROVIDERS = 'openai/gpt-4-turbo';
      const parsedProviders: AIProvider[] = [{ provider: 'openai', model: 'gpt-4-turbo' }];
      mockParseAIProviders.mockReturnValue(parsedProviders);
      mockIsProviderAvailable.mockResolvedValue(true); 
      mockAnalyzeImageWithProvider.mockResolvedValue('GPT-Turbo says hi.');

      const inputWithProvider: AnalyzeToolInput = {
        ...validInput,
        provider_config: { type: 'openai', model: 'gpt-custom-model' }
      };
      const result = await analyzeToolHandler(inputWithProvider, mockContext);

      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        { provider: 'openai', model: 'gpt-custom-model' },
        validInput.image_path,
        MOCK_IMAGE_BASE64,
        validInput.question,
        mockLogger
      );
      expect(result.content[0].text).toBe('GPT-Turbo says hi.');
      expect((result as any).model_used).toBe('openai/gpt-custom-model');
      expect(result.isError).toBeUndefined();
    });

    it('should return error for unsupported image format', async () => {
      const result = await analyzeToolHandler({ ...validInput, image_path: '/path/image.gif' }, mockContext) as any;
      expect(result.content[0].text).toContain('Unsupported image format: .gif');
      expect(result.isError).toBe(true);
    });

    it('should return error if PEEKABOO_AI_PROVIDERS env is not set', async () => {
      const result = await analyzeToolHandler(validInput, mockContext) as any;
      expect(result.content[0].text).toContain('AI analysis not configured on this server');
      expect(result.isError).toBe(true);
    });

    it('should return error if PEEKABOO_AI_PROVIDERS env has no valid providers', async () => {
      process.env.PEEKABOO_AI_PROVIDERS = 'invalid/';
      mockParseAIProviders.mockReturnValue([]);
      const result = await analyzeToolHandler(validInput, mockContext) as any;
      expect(result.content[0].text).toContain('No valid AI providers found');
      expect(result.isError).toBe(true);
    });

    it('should return error if no configured providers are operational (auto mode)', async () => {
      process.env.PEEKABOO_AI_PROVIDERS = 'ollama/llava';
      mockParseAIProviders.mockReturnValue([{ provider: 'ollama', model: 'llava' }]);
      mockIsProviderAvailable.mockResolvedValue(false); // All configured are unavailable
      const result = await analyzeToolHandler(validInput, mockContext) as any;
      expect(result.content[0].text).toContain('No configured AI providers are currently operational');
      expect(result.isError).toBe(true);
    });

    it('should return error if specific provider in config is not enabled on server', async () => {
      process.env.PEEKABOO_AI_PROVIDERS = 'ollama/llava'; // Server only has ollama
      mockParseAIProviders.mockReturnValue([{ provider: 'ollama', model: 'llava' }]);
      // User requests openai
      const inputWithProvider: AnalyzeToolInput = { ...validInput, provider_config: { type: 'openai' } };
      const result = await analyzeToolHandler(inputWithProvider, mockContext) as any;
      // This error is now caught by determineProviderAndModel and then re-thrown, so analyzeToolHandler catches it
      expect(result.content[0].text).toContain("Provider 'openai' is not enabled in server's PEEKABOO_AI_PROVIDERS configuration");
      expect(result.isError).toBe(true);
    });

     it('should return error if specific provider is configured but not available', async () => {
      process.env.PEEKABOO_AI_PROVIDERS = 'ollama/llava';
      mockParseAIProviders.mockReturnValue([{ provider: 'ollama', model: 'llava' }]);
      mockIsProviderAvailable.mockResolvedValue(false); // ollama is configured but not available
      const inputWithProvider: AnalyzeToolInput = { ...validInput, provider_config: { type: 'ollama' } };
      const result = await analyzeToolHandler(inputWithProvider, mockContext) as any;
      expect(result.content[0].text).toContain("Provider 'ollama' is configured but not currently available");
      expect(result.isError).toBe(true);
    });

    it('should return error if readImageAsBase64 fails', async () => {
      process.env.PEEKABOO_AI_PROVIDERS = 'ollama/llava';
      mockParseAIProviders.mockReturnValue([{ provider: 'ollama', model: 'llava' }]);
      mockIsProviderAvailable.mockResolvedValue(true);
      mockReadImageAsBase64.mockRejectedValue(new Error('Cannot access file'));
      const result = await analyzeToolHandler(validInput, mockContext) as any;
      expect(result.content[0].text).toContain('Failed to read image file: Cannot access file');
      expect(result.isError).toBe(true);
    });

    it('should return error if analyzeImageWithProvider fails', async () => {
      process.env.PEEKABOO_AI_PROVIDERS = 'ollama/llava';
      mockParseAIProviders.mockReturnValue([{ provider: 'ollama', model: 'llava' }]);
      mockIsProviderAvailable.mockResolvedValue(true);
      mockAnalyzeImageWithProvider.mockRejectedValue(new Error('AI exploded'));
      const result = await analyzeToolHandler(validInput, mockContext) as any;
      expect(result.content[0].text).toContain('AI analysis failed: AI exploded');
      expect(result.isError).toBe(true);
      expect(result._meta.backend_error_code).toBe('AI_PROVIDER_ERROR');
    });

    it('should handle unexpected errors gracefully', async () => {
      process.env.PEEKABOO_AI_PROVIDERS = 'ollama/llava';
      mockParseAIProviders.mockImplementation(() => { throw new Error('Unexpected parse error'); }); // Force an error
      const result = await analyzeToolHandler(validInput, mockContext) as any;
      expect(result.content[0].text).toContain('Unexpected error: Unexpected parse error');
      expect(result.isError).toBe(true);
    });

    it('should handle very long file paths', async () => {
      process.env.PEEKABOO_AI_PROVIDERS = 'ollama/llava';
      mockParseAIProviders.mockReturnValue([{ provider: 'ollama', model: 'llava' }]);
      mockIsProviderAvailable.mockResolvedValue(true);
      mockAnalyzeImageWithProvider.mockResolvedValue('Analysis complete');
      
      const longPath = '/very/long/path/that/goes/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/and/on/image.png';
      const result = await analyzeToolHandler({ ...validInput, image_path: longPath }, mockContext);
      
      expect(mockReadImageAsBase64).toHaveBeenCalledWith(longPath);
      expect(result.isError).toBeUndefined();
    });

    it('should handle special characters in file paths', async () => {
      process.env.PEEKABOO_AI_PROVIDERS = 'ollama/llava';
      mockParseAIProviders.mockReturnValue([{ provider: 'ollama', model: 'llava' }]);
      mockIsProviderAvailable.mockResolvedValue(true);
      mockAnalyzeImageWithProvider.mockResolvedValue('Analysis complete');
      
      const specialPath = '/path/with spaces/and-special_chars/image (1).png';
      const result = await analyzeToolHandler({ ...validInput, image_path: specialPath }, mockContext);
      
      expect(mockReadImageAsBase64).toHaveBeenCalledWith(specialPath);
      expect(result.isError).toBeUndefined();
    });

    it('should handle empty question gracefully', async () => {
      process.env.PEEKABOO_AI_PROVIDERS = 'ollama/llava';
      mockParseAIProviders.mockReturnValue([{ provider: 'ollama', model: 'llava' }]);
      mockIsProviderAvailable.mockResolvedValue(true);
      mockAnalyzeImageWithProvider.mockResolvedValue('General image description');
      
      const result = await analyzeToolHandler({ 
        image_path: validInput.image_path,
        question: ''
      }, mockContext);
      
      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        expect.any(Object),
        validInput.image_path,
        MOCK_IMAGE_BASE64,
        '',
        mockLogger
      );
      expect(result.isError).toBeUndefined();
    });

    it('should handle very long questions', async () => {
      process.env.PEEKABOO_AI_PROVIDERS = 'ollama/llava';
      mockParseAIProviders.mockReturnValue([{ provider: 'ollama', model: 'llava' }]);
      mockIsProviderAvailable.mockResolvedValue(true);
      mockAnalyzeImageWithProvider.mockResolvedValue('Long answer');
      
      const longQuestion = 'What '.repeat(1000) + 'is in this image?';
      const result = await analyzeToolHandler({ 
        ...validInput,
        question: longQuestion
      }, mockContext);
      
      expect(mockAnalyzeImageWithProvider).toHaveBeenCalledWith(
        expect.any(Object),
        validInput.image_path,
        MOCK_IMAGE_BASE64,
        longQuestion,
        mockLogger
      );
      expect(result.isError).toBeUndefined();
    });

    it('should handle mixed case file extensions', async () => {
      const upperCasePath = '/path/to/image.PNG';
      const mixedCasePath = '/path/to/image.JpG';
      
      const result1 = await analyzeToolHandler({ ...validInput, image_path: upperCasePath }, mockContext);
      const result2 = await analyzeToolHandler({ ...validInput, image_path: mixedCasePath }, mockContext);
      
      // Should not return unsupported format error for valid extensions with different cases
      expect(result1.content[0].text).not.toContain('Unsupported image format');
      expect(result2.content[0].text).not.toContain('Unsupported image format');
    });

    it('should handle null or undefined in error messages', async () => {
      process.env.PEEKABOO_AI_PROVIDERS = 'ollama/llava';
      mockParseAIProviders.mockReturnValue([{ provider: 'ollama', model: 'llava' }]);
      mockIsProviderAvailable.mockResolvedValue(true);
      mockAnalyzeImageWithProvider.mockRejectedValue(null);
      
      const result = await analyzeToolHandler(validInput, mockContext) as any;
      expect(result.content[0].text).toContain('AI analysis failed');
      expect(result.isError).toBe(true);
    });

    it('should handle provider returning empty string', async () => {
      process.env.PEEKABOO_AI_PROVIDERS = 'ollama/llava';
      mockParseAIProviders.mockReturnValue([{ provider: 'ollama', model: 'llava' }]);
      mockIsProviderAvailable.mockResolvedValue(true);
      mockAnalyzeImageWithProvider.mockResolvedValue('');
      
      const result = await analyzeToolHandler(validInput, mockContext);
      expect(result.content[0].text).toBe('');
      expect(result.analysis_text).toBe('');
      expect(result.isError).toBeUndefined();
    });

    it('should handle multiple providers where all fail', async () => {
      process.env.PEEKABOO_AI_PROVIDERS = 'ollama/llava,openai/gpt-4o,anthropic/claude-3';
      mockParseAIProviders.mockReturnValue([
        { provider: 'ollama', model: 'llava' },
        { provider: 'openai', model: 'gpt-4o' },
        { provider: 'anthropic', model: 'claude-3' }
      ]);
      mockIsProviderAvailable.mockResolvedValue(false); // All unavailable
      
      const result = await analyzeToolHandler(validInput, mockContext) as any;
      expect(result.content[0].text).toContain('No configured AI providers are currently operational');
      expect(mockIsProviderAvailable).toHaveBeenCalledTimes(3);
    });

    it('should validate file extension case-insensitively', async () => {
      const validExtensions = ['.PNG', '.Png', '.pNg', '.JPEG', '.Jpg', '.JPG', '.WebP', '.WEBP'];
      const invalidExtensions = ['.tiff', '.TIFF', '.Bmp', '.gif'];
      
      // Valid extensions should pass
      for (const ext of validExtensions) {
        const result = await analyzeToolHandler({ 
          ...validInput, 
          image_path: `/path/to/image${ext}` 
        }, mockContext);
        
        // Should proceed to check AI_PROVIDERS (not return unsupported format)
        expect(result.content[0].text).not.toContain('Unsupported image format');
      }
      
      // Invalid extensions should fail
      for (const ext of invalidExtensions) {
        const result = await analyzeToolHandler({ 
          ...validInput, 
          image_path: `/path/to/image${ext}` 
        }, mockContext);
        
        expect(result.content[0].text).toContain('Unsupported image format');
        expect(result.isError).toBe(true);
      }
    });

  });
}); 