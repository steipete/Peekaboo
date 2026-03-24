---
summary: 'Drive Peekaboo autonomous agent via peekaboo agent'
---

# `peekaboo agent`

`agent` hands a natural-language task to the agent service, which orchestrates the full toolset (see, click, type, menu, etc.).

## Key options

| Flag | Description |
| --- | --- |
| `[task]` | Free-form task description. |
| `--chat` | Force interactive chat loop. |
| `--dry-run` | Emit planned steps without executing. |
| `--max-steps <n>` | Cap tool invocations (default: 100). |
| `--model gpt-5.1|claude-sonnet-4.5|gemini-3-flash` | Override the default model. |
| `--resume` / `--resume-session <id>` | Continue a previous session. |
| `--list-sessions` | Print cached sessions. |
| `--audio` / `--audio-file <path>` | Use microphone or audio file input. |

## Examples

```bash
# Run an automation task
peekaboo agent "Check Slack mentions" --model gpt-5.1 --verbose

# Dry-run without executing tools
peekaboo agent "Install the nightly build" --dry-run

# Resume the last session
peekaboo agent --resume --quiet

# Interactive chat mode
peekaboo agent --chat
```
