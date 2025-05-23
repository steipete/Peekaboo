import OpenAI from 'openai';
import { Logger } from 'pino';
import { AIProvider } from '../types/index.js';

export function parseAIProviders(aiProvidersEnv: string): AIProvider[] {
  if (!aiProvidersEnv || !aiProvidersEnv.trim()) {
    return [];
  }
  
  return aiProvidersEnv
    .split(',')
    .map(p => p.trim())
    .filter(Boolean)
    .map(provider => {
      const [providerName, model] = provider.split('/');
      return {
        provider: providerName?.trim() || '',
        model: model?.trim() || ''
      };
    })
    .filter(p => p.provider && p.model);
}

export async function isProviderAvailable(provider: AIProvider, logger: Logger): Promise<boolean> {
  try {
    switch (provider.provider.toLowerCase()) {
      case 'ollama':
        return await checkOllamaAvailability(logger);
      case 'openai':
        return checkOpenAIAvailability();
      case 'anthropic':
        return checkAnthropicAvailability();
      default:
        logger.warn({ provider: provider.provider }, 'Unknown AI provider');
        return false;
    }
  } catch (error) {
    logger.error({ error, provider: provider.provider }, 'Error checking provider availability');
    return false;
  }
}

async function checkOllamaAvailability(logger: Logger): Promise<boolean> {
  try {
    const baseUrl = process.env.OLLAMA_BASE_URL || 'http://localhost:11434';
    const response = await fetch(`${baseUrl}/api/tags`);
    return response.ok;
  } catch (error) {
    logger.debug({ error }, 'Ollama not available');
    return false;
  }
}

function checkOpenAIAvailability(): boolean {
  return !!process.env.OPENAI_API_KEY;
}

function checkAnthropicAvailability(): boolean {
  return !!process.env.ANTHROPIC_API_KEY;
}

export async function analyzeImageWithProvider(
  provider: AIProvider,
  imagePath: string,
  imageBase64: string,
  question: string,
  logger: Logger
): Promise<string> {
  switch (provider.provider.toLowerCase()) {
    case 'ollama':
      return await analyzeWithOllama(provider.model, imageBase64, question, logger);
    case 'openai':
      return await analyzeWithOpenAI(provider.model, imageBase64, question, logger);
    case 'anthropic':
      throw new Error('Anthropic support not yet implemented');
    default:
      throw new Error(`Unsupported AI provider: ${provider.provider}`);
  }
}

async function analyzeWithOllama(
  model: string,
  imageBase64: string,
  question: string,
  logger: Logger
): Promise<string> {
  const baseUrl = process.env.OLLAMA_BASE_URL || 'http://localhost:11434';
  
  logger.debug({ model, baseUrl }, 'Analyzing image with Ollama');
  
  const response = await fetch(`${baseUrl}/api/generate`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      prompt: question,
      images: [imageBase64],
      stream: false
    })
  });
  
  if (!response.ok) {
    const errorText = await response.text();
    logger.error({ status: response.status, error: errorText }, 'Ollama API error');
    throw new Error(`Ollama API error: ${response.status} - ${errorText}`);
  }
  
  const result = await response.json();
  return result.response || 'No response from Ollama';
}

async function analyzeWithOpenAI(
  model: string,
  imageBase64: string,
  question: string,
  logger: Logger
): Promise<string> {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new Error('OpenAI API key not configured');
  }
  
  logger.debug({ model }, 'Analyzing image with OpenAI');
  
  const openai = new OpenAI({ apiKey });
  
  const response = await openai.chat.completions.create({
    model: model || 'gpt-4o',
    messages: [
      {
        role: 'user',
        content: [
          { type: 'text', text: question },
          {
            type: 'image_url',
            image_url: {
              url: `data:image/jpeg;base64,${imageBase64}`
            }
          }
        ]
      }
    ],
    max_tokens: 1000
  });
  
  return response.choices[0]?.message?.content || 'No response from OpenAI';
}

export function getDefaultModelForProvider(provider: string): string {
  switch (provider.toLowerCase()) {
    case 'ollama':
      return 'llava:latest';
    case 'openai':
      return 'gpt-4o';
    case 'anthropic':
      return 'claude-3-sonnet-20240229';
    default:
      return 'unknown';
  }
} 