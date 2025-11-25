---
summary: 'Index of AI provider docs (OpenAI, Anthropic, Grok, Ollama)'
read_when:
  - 'choosing or configuring AI providers for Peekaboo'
  - 'looking for provider-specific plans or status'
---

# Providers index

- **OpenAI** — `openai.md`: architecture, migration status, and guidance for adding models.
- **Anthropic** — `anthropic.md`: plan/status, streaming/tool notes, and Claude CLI examples.
- **Grok** — `grok.md`: Grok 4 implementation guide and checkpoints.
- **Ollama** — `ollama.md`: local model configuration; `ollama-models.md` for model catalog notes.

Use these with `docs/provider.md` for global provider configuration syntax and env var reference.

## Capability quick-compare

| Provider | Tools | Vision | Streaming | Local/offline | Auth |
| --- | --- | --- | --- | --- | --- |
| OpenAI | Yes (function/tool calling) | Yes (gpt-4o/4.1) | Yes | No | API key |
| Anthropic | Yes | Yes (Sonnet/Opus vision) | Yes (SSE) | No | API key or OAuth (Claude Pro/Max) |
| Grok | Yes | Limited | Yes | No | API key |
| Ollama | Yes (via local server) | Model-dependent | Yes | **Yes** (local) | None (local daemon) |

See individual pages for model lists, quirks, and test coverage expectations.
