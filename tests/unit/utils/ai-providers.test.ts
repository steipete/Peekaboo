import {
  parseAIProviders,
  isProviderAvailable,
  analyzeImageWithProvider,
  getDefaultModelForProvider,
} from '../../../src/utils/ai-providers';
import { AIProvider } from '../../../src/types'; 
import OpenAI from 'openai';

const mockLogger = {
  info: jest.fn(),
  error: jest.fn(),
  debug: jest.fn(),
  warn: jest.fn(),
} as any;

global.fetch = jest.fn();

// Centralized mock for OpenAI().chat.completions.create
const mockChatCompletionsCreate = jest.fn();

jest.mock('openai', () => {
  // This is the mock constructor for OpenAI
  return jest.fn().mockImplementation(() => {
    return {
      chat: {
        completions: {
          create: mockChatCompletionsCreate, // All instances use this mock
        },
      },
    };
  });
});
// No need for `let mockOpenAICreate` outside, use mockChatCompletionsCreate directly.

describe('AI Providers Utility', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    delete process.env.PEEKABOO_OLLAMA_BASE_URL;
    delete process.env.OPENAI_API_KEY;
    delete process.env.ANTHROPIC_API_KEY;
    (global.fetch as jest.Mock).mockReset();
    mockChatCompletionsCreate.mockReset(); // Reset the shared mock function
  });

  describe('parseAIProviders', () => {
    it('should return empty array for empty or whitespace string', () => {
      expect(parseAIProviders('')).toEqual([]);
      expect(parseAIProviders('   ')).toEqual([]);
    });

    it('should parse a single provider string', () => {
      expect(parseAIProviders('ollama/llava')).toEqual([{ provider: 'ollama', model: 'llava' }]);
    });

    it('should parse multiple comma-separated providers', () => {
      const expected: AIProvider[] = [
        { provider: 'ollama', model: 'llava' },
        { provider: 'openai', model: 'gpt-4o' },
      ];
      expect(parseAIProviders('ollama/llava, openai/gpt-4o')).toEqual(expected);
    });

    it('should handle extra whitespace', () => {
      expect(parseAIProviders('  ollama/llava ,  openai/gpt-4o  ')).toEqual([
        { provider: 'ollama', model: 'llava' },
        { provider: 'openai', model: 'gpt-4o' },
      ]);
    });

    it('should filter out entries without a model or provider name', () => {
      expect(parseAIProviders('ollama/, /gpt-4o, openai/llama3, incomplete')).toEqual([
         { provider: 'openai', model: 'llama3'}
        ]);
    });
     it('should filter out entries with only provider or only model or no slash or empty parts', () => {
        expect(parseAIProviders('ollama/')).toEqual([]);
        expect(parseAIProviders('/gpt-4o')).toEqual([]);
        expect(parseAIProviders('ollama')).toEqual([]); 
        expect(parseAIProviders('ollama/,,openai/gpt4')).toEqual([{provider: 'openai', model: 'gpt4'}]);
      });
  });

  describe('isProviderAvailable', () => {
    it('should return true for available Ollama (fetch ok)', async () => {
      (global.fetch as jest.Mock).mockResolvedValue({ ok: true });
      const result = await isProviderAvailable({ provider: 'ollama', model: 'llava' }, mockLogger);
      expect(result).toBe(true);
      expect(global.fetch).toHaveBeenCalledWith('http://localhost:11434/api/tags');
    });

    it('should use PEEKABOO_OLLAMA_BASE_URL for Ollama check', async () => {
        process.env.PEEKABOO_OLLAMA_BASE_URL = 'http://custom-ollama:11434';
        (global.fetch as jest.Mock).mockResolvedValue({ ok: true });
        await isProviderAvailable({ provider: 'ollama', model: 'llava' }, mockLogger);
        expect(global.fetch).toHaveBeenCalledWith('http://custom-ollama:11434/api/tags');
      });

    it('should return false for unavailable Ollama (fetch fails)', async () => {
      (global.fetch as jest.Mock).mockRejectedValue(new Error('Network Error'));
      const result = await isProviderAvailable({ provider: 'ollama', model: 'llava' }, mockLogger);
      expect(result).toBe(false);
      expect(mockLogger.debug).toHaveBeenCalledWith({ error: new Error('Network Error') }, 'Ollama not available');
    });
    
    it('should return false for unavailable Ollama (response not ok)', async () => {
        (global.fetch as jest.Mock).mockResolvedValue({ ok: false });
        const result = await isProviderAvailable({ provider: 'ollama', model: 'llava' }, mockLogger);
        expect(result).toBe(false);
      });

    it('should return true for available OpenAI (API key set)', async () => {
      process.env.OPENAI_API_KEY = 'test-key';
      const result = await isProviderAvailable({ provider: 'openai', model: 'gpt-4o' }, mockLogger);
      expect(result).toBe(true);
    });

    it('should return false for unavailable OpenAI (API key not set)', async () => {
      const result = await isProviderAvailable({ provider: 'openai', model: 'gpt-4o' }, mockLogger);
      expect(result).toBe(false);
    });

    it('should return true for available Anthropic (API key set)', async () => {
      process.env.ANTHROPIC_API_KEY = 'test-key';
      const result = await isProviderAvailable({ provider: 'anthropic', model: 'claude-3' }, mockLogger);
      expect(result).toBe(true);
    });

    it('should return false for unavailable Anthropic (API key not set)', async () => {
      const result = await isProviderAvailable({ provider: 'anthropic', model: 'claude-3' }, mockLogger);
      expect(result).toBe(false);
    });

    it('should return false and log warning for unknown provider', async () => {
      const result = await isProviderAvailable({ provider: 'unknown', model: 'test' }, mockLogger);
      expect(result).toBe(false);
      expect(mockLogger.warn).toHaveBeenCalledWith({ provider: 'unknown' }, 'Unknown AI provider');
    });

     it('should handle errors during ollama availability check gracefully (fetch throws)', async () => {
        const fetchError = new Error("Unexpected fetch error");
        (global.fetch as jest.Mock).mockImplementationOnce(() => { 
          // Ensure this mock is specific to the ollama check path that uses fetch
          if ((global.fetch as jest.Mock).mock.calls.some(call => call[0].includes('/api/tags'))) {
            throw fetchError; 
          }
          // Fallback for other fetches if any, though not expected in this test path
          return Promise.resolve({ ok: true, json: async () => ({}) }); 
        });
        const result = await isProviderAvailable({ provider: 'ollama', model: 'llava' }, mockLogger);
        expect(result).toBe(false);
        expect(mockLogger.debug).toHaveBeenCalledWith({ error: fetchError }, 'Ollama not available');
        expect(mockLogger.error).not.toHaveBeenCalledWith(
            expect.objectContaining({ error: fetchError, provider: 'ollama' }), 
            'Error checking provider availability'
        );
    });
  });

  describe('analyzeImageWithProvider', () => {
    const imageBase64 = 'test-base64-image';
    const question = 'What is this?';

    it('should call analyzeWithOllama for ollama provider', async () => {
      (global.fetch as jest.Mock).mockResolvedValueOnce({ 
        ok: true, 
        json: async () => ({ response: 'Ollama says hello' }) 
      });
      const result = await analyzeImageWithProvider({ provider: 'ollama', model: 'llava' }, 'path/img.png', imageBase64, question, mockLogger);
      expect(result).toBe('Ollama says hello');
      expect(global.fetch).toHaveBeenCalledWith('http://localhost:11434/api/generate', expect.any(Object));
      expect(JSON.parse((global.fetch as jest.Mock).mock.calls[0][1].body)).toEqual(
        expect.objectContaining({ model: 'llava', prompt: question, images: [imageBase64] })
      );
    });
    
    it('should throw Ollama API error if response not ok', async () => {
        (global.fetch as jest.Mock).mockResolvedValueOnce({ 
          ok: false, 
          status: 500,
          text: async () => "Internal Server Error"
        });
        await expect(
            analyzeImageWithProvider({ provider: 'ollama', model: 'llava' }, 'path/img.png', imageBase64, question, mockLogger)
        ).rejects.toThrow('Ollama API error: 500 - Internal Server Error');
    });


    it('should call analyzeWithOpenAI for openai provider', async () => {
      process.env.OPENAI_API_KEY = 'test-key';
      mockChatCompletionsCreate.mockResolvedValueOnce({ choices: [{ message: { content: 'OpenAI says hello' } }] });
      
      const result = await analyzeImageWithProvider({ provider: 'openai', model: 'gpt-4o' }, 'path/img.png', imageBase64, question, mockLogger);
      expect(result).toBe('OpenAI says hello');
      expect(mockChatCompletionsCreate).toHaveBeenCalledWith(expect.objectContaining({
        model: 'gpt-4o',
        messages: expect.arrayContaining([
          expect.objectContaining({
            role: 'user',
            content: expect.arrayContaining([
              { type: 'text', text: question },
              { type: 'image_url', image_url: { url: `data:image/jpeg;base64,${imageBase64}` } }
            ])
          })
        ])
      }));
    });

    it('should throw error if OpenAI API key is missing for openai provider', async () => {
        await expect(
          analyzeImageWithProvider({ provider: 'openai', model: 'gpt-4o' }, 'path/img.png', imageBase64, question, mockLogger)
        ).rejects.toThrow('OpenAI API key not configured');
    });
    
    it('should return default message if OpenAI provides no response content', async () => {
        process.env.OPENAI_API_KEY = 'test-key';
        mockChatCompletionsCreate.mockResolvedValueOnce({ choices: [{ message: { content: null } }] });

        const result = await analyzeImageWithProvider({ provider: 'openai', model: 'gpt-4o' }, 'path/img.png', imageBase64, question, mockLogger);
        expect(result).toBe('No response from OpenAI');
    });
    
    it('should return default message if Ollama provides no response content', async () => {
        (global.fetch as jest.Mock).mockResolvedValueOnce({ 
          ok: true, 
          json: async () => ({ response: null }) 
        });
        const result = await analyzeImageWithProvider({ provider: 'ollama', model: 'llava' }, 'path/img.png', imageBase64, question, mockLogger);
        expect(result).toBe('No response from Ollama');
      });

    it('should throw error for anthropic provider (not implemented)', async () => {
      await expect(
        analyzeImageWithProvider({ provider: 'anthropic', model: 'claude-3' }, 'path/img.png', imageBase64, question, mockLogger)
      ).rejects.toThrow('Anthropic support not yet implemented');
    });

    it('should throw error for unsupported provider', async () => {
      await expect(
        analyzeImageWithProvider({ provider: 'unknown', model: 'test' }, 'path/img.png', imageBase64, question, mockLogger)
      ).rejects.toThrow('Unsupported AI provider: unknown');
    });
  });

  describe('getDefaultModelForProvider', () => {
    it('should return correct default for ollama', () => {
      expect(getDefaultModelForProvider('ollama')).toBe('llava:latest');
      expect(getDefaultModelForProvider('Ollama')).toBe('llava:latest');
    });

    it('should return correct default for openai', () => {
      expect(getDefaultModelForProvider('openai')).toBe('gpt-4o');
    });

    it('should return correct default for anthropic', () => {
      expect(getDefaultModelForProvider('anthropic')).toBe('claude-3-sonnet-20240229');
    });

    it('should return "unknown" for an unknown provider', () => {
      expect(getDefaultModelForProvider('unknown-provider')).toBe('unknown');
    });
  });
}); 