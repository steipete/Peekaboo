import { generateServerStatusString } from '../../../src/utils/server-status';

describe('Server Status Utility - generateServerStatusString', () => {
  const testVersion = '1.2.3';

  beforeEach(() => {
    // Clear the environment variable before each test
    delete process.env.AI_PROVIDERS;
  });

  it('should return status with default providers text when AI_PROVIDERS is not set', () => {
    const status = generateServerStatusString(testVersion);
    expect(status).toContain(`Version: ${testVersion}`);
    expect(status).toContain('Configured AI Providers (from AI_PROVIDERS ENV): None Configured. Set AI_PROVIDERS ENV.');
  });

  it('should return status with default providers text when AI_PROVIDERS is an empty string', () => {
    process.env.AI_PROVIDERS = '';
    const status = generateServerStatusString(testVersion);
    expect(status).toContain(`Version: ${testVersion}`);
    expect(status).toContain('Configured AI Providers (from AI_PROVIDERS ENV): None Configured. Set AI_PROVIDERS ENV.');
  });

  it('should return status with default providers text when AI_PROVIDERS is whitespace', () => {
    process.env.AI_PROVIDERS = '   ';
    const status = generateServerStatusString(testVersion);
    expect(status).toContain(`Version: ${testVersion}`);
    expect(status).toContain('Configured AI Providers (from AI_PROVIDERS ENV): None Configured. Set AI_PROVIDERS ENV.');
  });

  it('should list a single provider from AI_PROVIDERS', () => {
    process.env.AI_PROVIDERS = 'ollama/llava';
    const status = generateServerStatusString(testVersion);
    expect(status).toContain(`Version: ${testVersion}`);
    expect(status).toContain('Configured AI Providers (from AI_PROVIDERS ENV): ollama/llava');
  });

  it('should list multiple providers from AI_PROVIDERS, trimmed and joined', () => {
    process.env.AI_PROVIDERS = 'ollama/llava, openai/gpt-4o';
    const status = generateServerStatusString(testVersion);
    expect(status).toContain(`Version: ${testVersion}`);
    expect(status).toContain('Configured AI Providers (from AI_PROVIDERS ENV): ollama/llava, openai/gpt-4o');
  });

  it('should handle extra whitespace and empty segments in AI_PROVIDERS', () => {
    process.env.AI_PROVIDERS = '  ollama/llava  , ,, openai/gpt-4o  ,anthropic/claude ';
    const status = generateServerStatusString(testVersion);
    expect(status).toContain(`Version: ${testVersion}`);
    expect(status).toContain('Configured AI Providers (from AI_PROVIDERS ENV): ollama/llava, openai/gpt-4o, anthropic/claude');
  });

  it('should correctly include the provided version string', () => {
    const customVersion = 'z.y.x';
    const status = generateServerStatusString(customVersion);
    expect(status).toContain(`Version: ${customVersion}`);
  });

  it('should produce a trimmed multi-line string', () => {
    const status = generateServerStatusString('0.0.1');
    expect(status.startsWith('---')).toBe(true);
    expect(status.endsWith('---')).toBe(true);
    expect(status).not.toMatch(/^\s/); // No leading whitespace
    expect(status).not.toMatch(/\s$/); // No trailing whitespace
  });
}); 