---
summary: 'Manage Peekaboo configuration and AI providers via peekaboo config'
read_when:
  - 'editing ~/.peekaboo/config.json or credentials safely'
  - 'adding/testing custom AI providers and API keys'
---

# `peekaboo config`

`peekaboo config` owns everything under `~/.peekaboo/`: the JSONC config file, the credential store, and the list of custom AI providers. Each subcommand runs on the main actor so it can call the same `ConfigurationManager` used by the CLI at startup, which means the output always reflects what the runtime will actually load.

## Subcommands
| Subcommand | Purpose | Key flags |
| --- | --- | --- |
| `init` | Create a default `config.json` (respects `--force`). | `--force` overwrites an existing file. |
| `show` | Print either the raw file or the fully merged “effective” view (config + env + credentials). | `--effective` switches to the merged view; JSON mode emits a sorted object. |
| `edit` | Opens the config in `$EDITOR` (or the `--editor` you pass) and validates the result after you quit. | `--editor` overrides the detected editor. |
| `validate` | Parses the config without writing anything and surfaces syntax/errors. | None. |
| `set-credential` | Writes secrets (e.g., `OPENAI_API_KEY`) into `~/.peekaboo/credentials`. | Positional `<key> <value>` pair. |
| `add-provider` | Append or replace a custom AI provider entry. | `--type openai|anthropic`, `--name`, `--base-url`, `--api-key`, `--headers key:value,…`, `--description`, `--force`. |
| `list-providers` | Dump built-in + custom providers plus whether they’re enabled. | `--json-output` follows the same schema that the runtime loads. |
| `test-provider` | Fires a quick `/models` request (or Anthropic equivalent) against the provider definition to make sure credentials/base URL are valid. | `--provider-id <id>` (required), `--timeout-ms`, `--model`. |
| `remove-provider` | Delete a custom provider entry. | `--provider-id <id>` and optional `--force` to skip confirmation. |
| `models` | Enumerate every model Peekaboo knows about (native, providers, or the specific server you pass). | `--provider-id`, `--include-disabled`. |

## Implementation notes
- Configuration files are JSON-with-comments: the loader strips `//` / `/* */` comments and interpolates `${VAR}` placeholders before merging with credentials and environment variables (same logic the CLI uses on startup).
- `set-credential` writes through `ConfigurationManager.shared.setCredential`, so it uses macOS file permissions + atomic temp-file renames; partial writes won’t corrupt the store even if the process crashes.
- Provider management commands share the same validation helpers: IDs must match `^[A-Za-z0-9-_]+$`, and provider types are limited to `.openai` or `.anthropic`. Headers passed via `--headers KEY:VALUE,…` are parsed into a `[String:String]` dictionary before being serialized back to disk.
- `test-provider` and `models` invoke the actual HTTP client stack (respecting proxy, TLS, and custom headers) rather than mocking responses, which is why they run on the main actor and surface real latencies.
- All subcommands are `RuntimeOptionsConfigurable`, so global `--json-output` or `--verbose` flags work uniformly (handy when you script config changes).

## Examples
```bash
# Create a clean config + show the merged view
polter peekaboo -- config init --force
polter peekaboo -- config show --effective

# Register OpenRouter as a provider and immediately test it
polter peekaboo -- config add-provider openrouter \
  --type openai \
  --name "OpenRouter" \
  --base-url https://openrouter.ai/api/v1 \
  --api-key "{env:OPENROUTER_API_KEY}" --force
polter peekaboo -- config test-provider --provider-id openrouter

# Store a new Anthropic key securely
polter peekaboo -- config set-credential ANTHROPIC_API_KEY sk-live-...
```
