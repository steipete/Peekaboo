---
summary: "Borrowed improvements from pi-mono to harden and polish the Peekaboo agent"
read_when:
  - "planning agent runtime or CLI refactors"
  - "adding streaming/UI affordances to agent chat"
  - "rethinking session persistence, tool validation, or model selection"
---

# Agent Improvements (pi-mono learnings)
_Status: Archived · Focus: streaming/tool-call UX and queue mode roadmap._

This note captures concrete ideas to port from `pi-mono` (pi-coding-agent, pi-agent, pi-ai, pi-tui) into Peekaboo. Use as a grab-bag when planning the next agent/CLI pass.

## Runtime & UX
- Add a **message queue mode** toggle: one-at-a-time vs all-queued injection before the next turn. Surface the current mode in the chat banner.
- Stream **tool-call argument deltas** and render partial args (e.g., file paths) so users can abort bad calls early.
- Emit a **uniform event stream** (`agent_start/turn_start/message_update/tool_execution_*`) that drives all UIs (CLI/TUI/app) instead of per-surface plumbing.
- Standardize a **default message transformer**: attachments → image or doc text blocks, strip app-only fields before sending to the model.

## Tooling & Safety
- Define tools with **runtime schema validation** (TypeBox/AJV equivalent in Swift) so invalid LLM args return structured errors instead of throwing mid-turn.
- Normalize tool results to a **single envelope**: `role=toolResult`, `toolCallId`, `toolName`, `content`, `isError`, `details`. Keep UI/renderers simple.
- When a tool is missing or fails, return a **synthetic toolResult error message** rather than aborting the whole turn.

## Session & Model Management
- Persist sessions as **JSONL per-working-directory** with headers (cwd, model, thinking level) plus message entries; enable branch/resume without bespoke formats.
- Apply **hierarchical context loading** (global → parents → cwd AGENTS/CLAUDE) directly into the system prompt builder so chat always inherits repo + user guidance.
- Model selection priority: **CLI args > restored session > saved default > first available with key**; expose a **scoped model cycle** list (patterns) for quick switching.

## Transports & Deployability
- Offer dual transports: **direct provider** and **proxy/SSE** that reconstructs partial messages client-side. Optional **baseUrl rewrites** allow browser/CORS use without code forks.

## CLI/TUI Ergonomics
- Borrow TUI features: synchronized output to prevent flicker, bracketed paste markers, slash-command autocomplete, file-path autocomplete, and queued-message badges.
- Show a compact **turn footer** (model, duration, tool-count) after each exchange in chat mode.

## Quick Wins to Pilot First
1) Add queue mode + partial tool-call streaming to the CLI chat loop.
2) Wrap tool execution with schema validation and error-to-toolResult fallback.
3) Unify event emission and wire it to the CLI renderer; keep UI changes minimal at first.

## Progress Log
- 2025-11-21: Streaming loop now dedupes tool-call start events, emits `toolCallUpdated` with trimmed (320-char) args, and caps previews so chat UIs aren’t flooded. Follow-up: propagate richer argument diffs and show inline diffs in the TUI.
- 2025-11-21: CLI TauTUI now renders `toolCallUpdated` as a live refresh line (↻ …) so mid-stream argument changes are visible without restart spam.
- 2025-11-21: Scoped next steps — add argument diffing for updates, ensure line/TTY chat surfaces updates (not just TUI), and gate previews to redact secrets if needed.
- 2025-11-21: Line/TTY chat now prints tool-call updates (↻) with compact summaries, so both chat modes show mid-stream argument changes.
- 2025-11-21: Next: model-queue mode toggle + inline arg diffing; consider token-aware truncation and secret redaction for streamed arg previews.
- 2025-11-21: Added basic secret redaction for streamed tool-call argument previews (keys containing token/secret/key/auth/password plus regex for sk-*/Bearer) before trimming to 320 chars.
- 2025-11-21: Secret redaction happens inside streaming loop; upcoming: add allowlist of safe keys, redact nested arrays of creds, and add tests/goldens once streaming is unit-testable.
- 2025-11-21: CLI line output now shows tool-call update diffs (top-level key changes, capped to 3 entries, values trimmed) so arg changes are visible without dumping full JSON.
- 2025-11-21: TauTUI tool-call updates now include compact diffs (up to 3 key deltas with trimmed values) so both chat surfaces show what changed, not just that something changed.
- 2025-11-21: Next up — decide on queue-mode toggle, add nested redaction coverage, and consider JSONL session logging for chat runs to mirror pi-mono resume/branch.
- 2025-11-21: Skips redundant toolCallUpdated events when args didn’t change (both TUI and line outputs), reducing spam during noisy streaming calls.
- 2025-11-21: Streaming redaction now also covers auth/cookie keys plus session/token regexes; still need allowlist + unit/goldens.
- 2025-11-21: Current gaps — queue-mode toggle still pending; need unit/golden coverage for streaming events and a per-tool allowlist for safe arg fields.
- 2025-11-21: To-do ordering — (1) add queue-mode flag + wiring to agent loop, (2) add redaction tests/goldens, (3) per-tool safe-field allowlist, (4) optional JSONL session log for chat runs.
- 2025-11-21: Added extra secret patterns (cookie/auth/session tokens) to redaction; still need allowlist + tests.
- 2025-11-21: Open action item: implement queue-mode flag (one-at-a-time vs all) in CLI chat + agent loop; wire to TUI badge and line prompt banner.
- 2025-11-21: Added `QueueMode` enum and `queueDrained` event scaffolding in agent runtime; wiring to chat/loop still pending.
- 2025-11-21: Agent service APIs now take a queueMode parameter end-to-end; CLI/UI still need to pass it through and surface state.
- 2025-11-21: CLI now batches queued prompts when queueMode=all (TUI path) and shows mode in chat header; TODO: replicate for line chat + add session/JSONL logging.
- 2025-11-21: CLI now accepts --queue-mode (one-at-a-time/all) and TUI header shows current mode; still need actual queued-message injection through the agent loop.
- 2025-11-21: Remaining queue work — CLI flag/plumbing into Chat (line + TUI), show current mode in prompt/banner, and inject queued prompts when queueMode=all.
