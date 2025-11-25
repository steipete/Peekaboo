---
summary: 'Anthropic provider plan, status, and usage examples for Peekaboo'
read_when:
  - 'planning or extending Anthropic/Claude support'
  - 'debugging Anthropic provider behavior or SDK wiring'
  - 'needing CLI examples for Claude models'
---

# Anthropic in Peekaboo

## Overview
Peekaboo ships a native Swift integration for Anthropic Claude models so agents and CLI commands can use Claude alongside OpenAI or local providers. The goal is parity with our OpenAI architecture while avoiding external SDK dependencies.

## SDK options (evaluated)
- Community Swift SDKs (AnthropicSwiftSDK, SwiftAnthropic): featureful but add external deps and may lag API updates.
- Official TypeScript SDK: always current but would require a Node bridge and add overhead.
- **Chosen**: custom Swift implementation to match Peekaboo’s protocol-based model layer and keep dependencies lean.

## Implementation status (verification)
- Core types (`AnthropicTypes`, request/response/content blocks, tool definitions, error types) and `AnthropicModel` conform to the shared `ModelInterface`.
- Streaming is fully implemented with SSE parsing for all Claude events (`message_start`, `content_block_*`, `message_delta/stop`) and tool streaming.
- Tool/function calling maps Peekaboo tool schemas to Anthropic `input_schema`, supports `tool_use`, and converts results back to Peekaboo tool envelopes.
- Endpoint and headers: `POST https://api.anthropic.com/v1/messages` with `x-api-key` and `anthropic-version: 2023-06-01`.

## Usage examples
```bash
# Use Claude 3 Opus for complex tasks
peekaboo agent "Analyze the UI structure of Safari" --model claude-3-opus-20240229

# Balanced performance with Claude 3.5 Sonnet
peekaboo agent "Click the Submit button" --model claude-3-5-sonnet-latest

# Fast responses with Claude 3 Haiku
peekaboo agent "What windows are currently open?" --model claude-3-haiku-20240307

# Configure Anthropic as default
export ANTHROPIC_API_KEY=sk-ant-...
export PEEKABOO_AI_PROVIDERS="anthropic/claude-3-opus-latest,openai/gpt-4.1"
peekaboo agent "Help me organize my desktop"
```

## Next steps / maintenance
- Keep parity with Anthropic model/version names as they ship.
- Add regression tests for tool streaming and error mapping when new event types appear.
- Re-run the verification checklist when upgrading the API version header.
