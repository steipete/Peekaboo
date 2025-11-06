# Custom AI Provider Configuration

This document explains how to configure custom AI providers in Peekaboo, enabling access to OpenAI-compatible and Anthropic-compatible endpoints beyond the built-in providers.

## Overview

Peekaboo supports custom AI providers through configuration-based setup. This allows you to:

- Use OpenRouter to access 300+ models through a unified API
- Connect to specialized providers like Groq, Together AI, Perplexity
- Set up self-hosted AI endpoints
- Override built-in providers with custom endpoints
- Configure multiple endpoints with different models

## Built-in vs Custom Providers

### Built-in Providers
- **OpenAI**: GPT-5 family, GPT-4.1, GPT-4o, o4-mini
- **Anthropic**: Claude 4, Claude 3.5, Claude 3.7 series  
- **Grok (xAI)**: Grok 4, Grok 2 series
- **Ollama**: Local models with tool support

### Custom Providers
- **OpenRouter**: Unified access to 300+ models
- **Groq**: Ultra-fast inference with LPU technology
- **Together AI**: High-performance open-source models
- **Perplexity**: AI-powered search with citations
- **Self-hosted**: Your own AI endpoints

## Configuration

### Provider Schema

Custom providers are configured in `~/.peekaboo/config.json`:

```json
{
  "customProviders": {
    "openrouter": {
      "name": "OpenRouter",
      "description": "Access to 300+ models via unified API",
      "type": "openai",
      "options": {
        "baseURL": "https://openrouter.ai/api/v1",
        "apiKey": "{env:OPENROUTER_API_KEY}",
        "headers": {
          "HTTP-Referer": "https://peekaboo.app",
          "X-Title": "Peekaboo"
        }
      },
      "models": {
        "anthropic/claude-3.5-sonnet": {
          "name": "Claude 3.5 Sonnet (OpenRouter)",
          "maxTokens": 8192,
          "supportsTools": true,
          "supportsVision": true
        },
        "openai/gpt-4": {
          "name": "GPT-4 (OpenRouter)",
          "maxTokens": 8192,
          "supportsTools": true
        }
      },
      "enabled": true
    }
  }
}
```

### Provider Types

- **`openai`**: OpenAI-compatible endpoints (Chat Completions API)
- **`anthropic`**: Anthropic-compatible endpoints (Messages API)

### Environment Variables

API keys are referenced using `{env:VARIABLE_NAME}` syntax and stored securely in `~/.peekaboo/credentials`:

```bash
# Set API key
peekaboo config set-credential OPENROUTER_API_KEY or-...
peekaboo config set-credential GROQ_API_KEY gsk-...
```

## CLI Management

### Add Provider

```bash
peekaboo config add-provider \
  --id openrouter \
  --name "OpenRouter" \
  --type openai \
  --url "https://openrouter.ai/api/v1" \
  --api-key OPENROUTER_API_KEY \
  --discover-models
```

### List Providers

```bash
# Custom providers only
peekaboo config list-providers

# Include built-in providers
peekaboo config list-providers --include-built-in
```

### Test Connection

```bash
peekaboo config test-provider openrouter
```

### List Models

```bash
# Show configured models
peekaboo config models-provider openrouter

# Refresh from API
peekaboo config models-provider openrouter --refresh
```

### Remove Provider

```bash
peekaboo config remove-provider openrouter
```

## Usage with Agent

Once configured, use custom providers with the agent command:

```bash
# Use OpenRouter's Claude 3.5 Sonnet
peekaboo agent "take a screenshot" --model openrouter/anthropic/claude-3.5-sonnet

# Use Groq's Llama 3
peekaboo agent "click the button" --model groq/llama3-70b-8192

# Built-in providers work unchanged
peekaboo agent "analyze image" --model anthropic/claude-opus-4
```

## Popular Provider Examples

### OpenRouter

```bash
peekaboo config add-provider \
  --id openrouter \
  --name "OpenRouter" \
  --type openai \
  --url "https://openrouter.ai/api/v1" \
  --api-key OPENROUTER_API_KEY

peekaboo config set-credential OPENROUTER_API_KEY or-your-key-here
```

### Groq

```bash
peekaboo config add-provider \
  --id groq \
  --name "Groq" \
  --type openai \
  --url "https://api.groq.com/openai/v1" \
  --api-key GROQ_API_KEY

peekaboo config set-credential GROQ_API_KEY gsk-your-key-here
```

### Together AI

```bash
peekaboo config add-provider \
  --id together \
  --name "Together AI" \
  --type openai \
  --url "https://api.together.xyz/v1" \
  --api-key TOGETHER_API_KEY

peekaboo config set-credential TOGETHER_API_KEY your-key-here
```

### Self-hosted

```bash
peekaboo config add-provider \
  --id myserver \
  --name "My AI Server" \
  --type openai \
  --url "https://ai.company.com/v1" \
  --api-key MY_API_KEY

peekaboo config set-credential MY_API_KEY your-key-here
```

## Provider Configuration Options

### Headers

Custom headers for API requests:

```json
"headers": {
  "HTTP-Referer": "https://peekaboo.app",
  "X-Title": "Peekaboo",
  "Authorization": "Bearer custom-token"
}
```

### Model Definitions

Define available models with capabilities:

```json
"models": {
  "model-id": {
    "name": "Display Name",
    "maxTokens": 8192,
    "supportsTools": true,
    "supportsVision": false,
    "parameters": {
      "temperature": "0.7",
      "top_p": "0.9"
    }
  }
}
```

### Provider Options

```json
"options": {
  "baseURL": "https://api.provider.com/v1",
  "apiKey": "{env:API_KEY}",
  "timeout": 30,
  "retryAttempts": 3,
  "headers": {},
  "defaultParameters": {}
}
```

## Mac App Integration

The Mac app settings provide a GUI for managing custom providers:

1. **Settings → AI Providers**
2. **Add Custom Provider** button
3. Provider configuration form with connection testing
4. Model discovery and selection
5. Enable/disable providers

## Troubleshooting

### Connection Issues

```bash
# Test provider connection
peekaboo config test-provider openrouter

# Check configuration
peekaboo config show --effective

# Validate config syntax
peekaboo config validate
```

### Authentication Errors

- Verify API key is set: `peekaboo config show --effective`
- Check credentials file permissions: `ls -la ~/.peekaboo/credentials`
- Test API key with provider's documentation

### Model Not Found

- List available models: `peekaboo config models-provider openrouter`
- Refresh model list: `peekaboo config models-provider openrouter --refresh`
- Check provider documentation for model names

## Security Considerations

- API keys are stored separately in `~/.peekaboo/credentials` (chmod 600)
- Never commit API keys to configuration files
- Use environment variable references: `{env:API_KEY}`
- Rotate API keys regularly
- Use least-privilege API keys when available

## Advanced Usage

### Model Selection Priority

```bash
# Provider string format: provider-id/model-path
peekaboo agent "task" --model openrouter/anthropic/claude-3.5-sonnet
peekaboo agent "task" --model groq/llama3-70b-8192
peekaboo agent "task" --model myserver/custom-model
```

### Fallback Configuration

Configure multiple providers for redundancy:

```json
"aiProviders": {
  "providers": "openrouter/anthropic/claude-3.5-sonnet,anthropic/claude-opus-4,openai/gpt-4.1"
}
```

### Cost Optimization

Use OpenRouter's smart routing for cost optimization:

```json
"openrouter": {
  "options": {
    "headers": {
      "X-Title": "Peekaboo Cost-Optimized"
    }
  }
}
```

## File Locations

- **Configuration**: `~/.peekaboo/config.json`
- **Credentials**: `~/.peekaboo/credentials`
- **Logs**: `~/.peekaboo/logs/peekaboo.log`

## API Compatibility

### OpenAI-Compatible Providers

Support standard OpenAI Chat Completions API:
- Request/response format matches OpenAI
- Tool calling support varies by provider
- Vision capabilities vary by model

### Anthropic-Compatible Providers

Support Anthropic Messages API:
- Different request/response format
- System prompts handled separately
- Native tool calling support

For implementation details, see:
- `Core/PeekabooCore/Sources/PeekabooCore/Configuration/`
- `Core/PeekabooCore/Sources/PeekabooCore/AI/`
