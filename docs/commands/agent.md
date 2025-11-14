---
summary: 'Drive Peekaboo’s autonomous agent via peekaboo agent'
read_when:
  - 'testing natural-language automation end-to-end'
  - 'resuming or debugging cached agent sessions'
---

# `peekaboo agent`

`agent` hands a natural-language task to `PeekabooAgentService`, which in turn orchestrates the full toolset (see, click, type, menu, etc.). The command handles session caching, terminal capability detection, progress spinners, and audio capture so you can run the exact same agent loop the macOS app uses.

## Key options
| Flag | Description |
| --- | --- |
| `[task]` | Optional free-form task description. Required unless you pass `--resume`/`--resume-session`. |
| `--dry-run` | Emit the planned steps without actually invoking tools. |
| `--max-steps <n>` | Cap how many tool invocations the agent may issue before aborting. |
| `--model gpt-5.1|claude-sonnet-4.5` | Override the default model (`gpt-5.1-mini`). Input is validated against the allowed list. |
| `--resume` / `--resume-session <id>` | Continue the most recent session or a specific session ID. |
| `--list-sessions` | Print cached sessions (id, task, timestamps, message count) instead of running anything. |
| `--no-cache` | Always create a fresh session even if one is already active. |
| `--quiet` / `--simple` / `--no-color` / `--debug-terminal` | Control output mode; the command auto-detects terminal capabilities when you don’t override it. |
| `--audio` / `--audio-file <path>` / `--realtime` | Use microphone input, pipe audio from disk, or enable OpenAI’s realtime audio mode. |

## Implementation notes
- The command resolves output “modes” (`minimal`, `compact`, `enhanced`, `quiet`, `verbose`) using terminal detection heuristics; `--simple` and `--no-color` force minimal mode, while `--quiet` suppresses progress output entirely.
- Session metadata lives inside `agentService` (PeekabooCore). `--resume` grabs the most recent session, `--list-sessions` prints the cached list, and `--no-cache` disables reuse so each run starts clean.
- All agent executions run under `CommandRuntime.makeDefault()`, so environment variables, credentials, and logging levels match the top-level CLI state.
- When `--dry-run` is set the agent still reasons about the task, but tool invocations are skipped; this is useful for understanding plans without touching the UI.
- Audio flags wire into Tachikoma’s audio stack: `--audio` opens the microphone, `--audio-file` loads a WAV/CAF file, and `--realtime` enables low-latency streaming (OpenAI-only).

## Examples
```bash
# Let the agent sign into Slack using GPT-5.1 with verbose tracing
polter peekaboo -- agent "Check Slack mentions" --model gpt-5.1 --verbose

# Dry-run the same task without executing any tools
polter peekaboo -- agent "Install the nightly build" --dry-run

# Resume the last session and quiet the spinner output
polter peekaboo -- agent --resume --quiet
```
