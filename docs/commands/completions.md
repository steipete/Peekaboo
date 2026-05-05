---
summary: 'Install shell-native completions via peekaboo completions'
read_when:
  - 'setting up tab completion for the Peekaboo CLI'
  - 'debugging missing or stale zsh/bash/fish completions'
---

# `peekaboo completions`

`peekaboo completions` prints a shell script that enables tab completion for the
Peekaboo CLI. The command derives its command tree, flags, aliases, and
descriptions from Commander metadata at runtime, so completions stay in sync
with the shipped CLI surface.

## Key options
| Flag | Description |
| --- | --- |
| `[shell]` | Optional shell name or shell path. Accepts `zsh`, `bash`, `fish`, or values like `/bin/zsh`. Defaults to the current `$SHELL`, then falls back to `zsh`. |

## Implementation notes
- The command renders from `CommanderRegistryBuilder.buildDescriptors()` rather than maintaining handwritten completion tables.
- Runtime aliases such as `--json-output` and `--log-level` are included because completion metadata is extracted from the fully normalized Commander signature.
- `peekaboo help` is exposed in completions as a synthetic command tree so users can tab through `peekaboo help <command> ...` just like the real CLI.
- The emitted script is shell-specific, but the command metadata is shared across zsh, bash, and fish via a single completion document.

## Examples
```bash
# Recommended: use the current login shell path directly
eval "$(peekaboo completions $SHELL)"

# Explicit zsh
eval "$(peekaboo completions zsh)"

# Explicit bash
eval "$(peekaboo completions bash)"

# Fish uses source instead of eval
peekaboo completions fish | source
```

## Persistent install

Add one of the following snippets to your shell startup file:

```bash
# ~/.zshrc
eval "$(peekaboo completions $SHELL)"

# ~/.bashrc or ~/.bash_profile
eval "$(peekaboo completions bash)"
```

```fish
# ~/.config/fish/config.fish
peekaboo completions fish | source
```

## Troubleshooting
- Re-run the setup snippet after upgrading Peekaboo so your shell reloads the latest generated script.
- If `$SHELL` points to a wrapper or unsupported shell, pass an explicit value such as `zsh`, `bash`, or `fish`.
- Verify the command resolves in your current session (`command -v peekaboo`) before sourcing the generated script.
- Run `peekaboo completions <shell> > /tmp/peekaboo.<shell>` and inspect the file if your shell reports a syntax error.
