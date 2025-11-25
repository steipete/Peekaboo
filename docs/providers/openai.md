---
summary: 'OpenAI provider architecture and migration status in Peekaboo'
read_when:
  - 'debugging OpenAI model integration or tool calling'
  - 'planning changes to the OpenAI provider layer'
  - 'explaining the Assistants→Chat Completions migration'
---

# OpenAI in Peekaboo

## Status
- Migration from Assistants API to Chat Completions is **complete** (as of 2025-11). Legacy Assistants code was removed; protocol-based message architecture is the sole implementation.
- Streaming, tool calling, and session persistence are wired through the shared model interface used by other providers.

## Key migration outcomes
1. Protocol-based message and tool abstractions for strong typing.
2. Native streaming via `AsyncThrowingStream` with event handling.
3. Type-safe tool system with generic context.
4. Integrated with PeekabooCore services and session resume.
5. Removed feature flags and legacy Assistants artifacts.

## Implementation notes
- Follows the same architecture used for Anthropic/Grok/Ollama: provider-conforming model types with shared error handling.
- Tool results and errors are normalized so agents and CLI renderers stay provider-agnostic.
- When adding new OpenAI models, update the provider registry and regression tests for model capabilities (vision, tools, JSON).

## References and snippets
- Docs/examples for OpenAI live under `examples/docs/` (see `agentCloning.ts`, `chatLoop.ts`, `basicStreaming.ts`, etc.)—useful when cross-checking CLI/MCP behaviors.
- If new event types appear, mirror the Anthropic streaming verification playbook: add golden tests for partial deltas and tool-call payloads.
