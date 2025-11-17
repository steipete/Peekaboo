---
summary: 'Reference for Peekaboo configuration precedence, environment variables, and credential handling.'
read_when:
  - 'setting environment variables or editing ~/.peekaboo/config.json'
  - 'debugging why CLI settings are not applied'
---

# Configuration & Environment Variables

## Precedence

Peekaboo resolves settings in this order (highest → lowest):

1. Command-line arguments
2. Environment variables (never copied into files)
3. Credentials file (`~/.peekaboo/credentials`: API keys or OAuth tokens)
4. Configuration file (`~/.peekaboo/config.json`)
5. Built-in defaults

## Available Options

| Setting | Config File | Environment Variable | Description |
|---------|-------------|---------------------|-------------|
| AI Providers | `aiProviders.providers` | `PEEKABOO_AI_PROVIDERS` | Comma-separated list (`openai/gpt-4.1,anthropic/claude,grok/grok-4,ollama/llava:latest`). First healthy provider wins. |
| OpenAI API Key | credentials file | `OPENAI_API_KEY` | Required for OpenAI models. |
| Anthropic API Key | credentials file | `ANTHROPIC_API_KEY` | Required for Claude models (API-key path). |
| Anthropic OAuth | credentials file | `ANTHROPIC_REFRESH_TOKEN`, `ANTHROPIC_ACCESS_TOKEN`, `ANTHROPIC_ACCESS_EXPIRES` | Created by `config login anthropic`; no API key stored. |
| Grok API Key | credentials file | `GROK_API_KEY` / `X_AI_API_KEY` / `XAI_API_KEY` | Required for Grok (xAI). Env alias resolves to Grok. |
| Gemini API Key | credentials file | `GEMINI_API_KEY` | Required for Gemini. |
| Ollama URL | `aiProviders.ollamaBaseUrl` | `PEEKABOO_OLLAMA_BASE_URL` | Base URL for local/remote Ollama (default `http://localhost:11434`). |
| Default Save Path | `defaults.savePath` | `PEEKABOO_DEFAULT_SAVE_PATH` | Directory for screenshots (supports `~`). |
| Log Level | `logging.level` | `PEEKABOO_LOG_LEVEL` | `trace`, `debug`, `info`, `warn`, `error`, `fatal` (default `info`). |
| Log Path | `logging.path` | `PEEKABOO_LOG_FILE` | Custom log destination (default `/tmp/peekaboo-mcp.log` for MCP; CLI uses stderr). |
| CLI Binary Path | - | `PEEKABOO_CLI_PATH` | Override bundled CLI when testing custom builds. |

## API Key Storage

1. **Environment variables** – most secure for automation: `export OPENAI_API_KEY="sk-..."`.
2. **Credentials file** – `peekaboo config set-credential OPENAI_API_KEY sk-...` stores secrets in `~/.peekaboo/credentials` (`chmod 600`).
3. **Config file** – avoid storing keys here unless absolutely necessary. OAuth tokens are never written to `config.json`.

## Provider Variables

- `PEEKABOO_AI_PROVIDERS`: `provider/model` CSV. Example: `openai/gpt-4.1,anthropic/claude-opus-4,grok/grok-4,ollama/llava:latest`.
- `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GROK_API_KEY` | `X_AI_API_KEY` | `XAI_API_KEY`, `GEMINI_API_KEY`: required for their respective providers when using API keys.
- `PEEKABOO_OLLAMA_BASE_URL`: change when your Ollama daemon isn’t on `localhost:11434`.

## Defaults & Paths

- `PEEKABOO_DEFAULT_SAVE_PATH`: screenshot destination (created automatically).
- `PEEKABOO_CLI_PATH`: point Peekaboo at a debug build (`.build/debug/peekaboo`) without copying binaries around.

## Logging & Troubleshooting

- `PEEKABOO_LOG_LEVEL=debug` (or `trace`) surfaces verbose telemetry.
- `PEEKABOO_LOG_FILE=/tmp/peekaboo.log` persists logs for sharing.

## Setting Variables

```bash
# Single command
PEEKABOO_AI_PROVIDERS="ollama/llava:latest" peekaboo image --analyze "Describe this UI" --path img.png

# Session exports
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-ant-..."
export X_AI_API_KEY="xai-..."

# Shell profile
echo 'export OPENAI_API_KEY="sk-..."' >> ~/.zshrc
```

When in doubt, run `peekaboo config show --effective` to see the merged view from every layer.
