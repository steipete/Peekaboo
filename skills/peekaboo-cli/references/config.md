---
summary: 'Manage Peekaboo configuration and AI providers via peekaboo config'
---

# `peekaboo config`

`peekaboo config` manages `~/.peekaboo/`: the JSONC config file, credentials, and custom AI providers.

## Subcommands

| Subcommand | Purpose |
| --- | --- |
| `init` | Create a default `config.json` and show provider readiness. |
| `show` | Print raw or merged "effective" view. Use `--effective`. |
| `edit` | Opens the config in `$EDITOR`. |
| `validate` | Parses the config and surfaces errors. |
| `add` | Store a provider credential and validate it. |
| `login` | Run an OAuth flow for supported providers. |
| `add-provider` | Append or replace a custom AI provider entry. |
| `list-providers` | Dump built-in + custom providers. |
| `test-provider` | Test credentials/base URL for a provider. |
| `remove-provider` | Delete a custom provider entry. |
| `models` | Enumerate every model Peekaboo knows about. |

## Examples

```bash
# Create config and show merged view
peekaboo config init --force
peekaboo config show --effective

# Add and validate API keys
peekaboo config add openai sk-live-...
peekaboo config add anthropic sk-ant-...

# Add a custom provider
peekaboo config add-provider openrouter \
  --type openai \
  --name "OpenRouter" \
  --base-url https://openrouter.ai/api/v1 \
  --api-key "{env:OPENROUTER_API_KEY}"

# Test a provider
peekaboo config test-provider --provider-id openrouter
```
