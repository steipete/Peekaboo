---
summary: 'Refactor tool results so agents can show rich, human-readable summaries'
read_when:
  - 'planning tool/agent runtime work'
  - 'touching ToolResponse or formatter plumbing'
---

# Tool Result Metadata Refactor Plan

## Current Status
- `ToolEventSummary` struct + helpers live in `ToolEventSummary.swift`; pointer direction math handled in `PointerDirection.swift`.
- Tachikoma MCP adapter now preserves `meta` so summaries flow from tools to CLI/Mac renderers.
- Core UI/system tools (click/drag/move/swipe/scroll/see/shell/sleep/type/hotkey/app/menu/dialog/dock/list/window) populate summaries with human-readable labels instead of internal IDs.
- Permission/Image/Analyze/Space tool paths updated to emit contextual summaries (app name, capture source, question text, etc.).
- MCPAgentTool now emits summaries for session listings and agent runs, completing MCP tool coverage.
- CLI `AgentOutputDelegate` consumes `ToolEventSummary` data, strips legacy `[ok]` glyphs, and falls back to sanitized formatter output only when necessary.
- Mac tool formatter bridge + registry now prioritize `ToolEventSummary` data so timeline rows show the same human-readable summaries as the CLI.
- Added Swift Testing coverage (`ToolEventSummaryTests`, `ToolSummaryEmissionTests`) so shell/sleep summaries and short-description helpers are locked in.
- Streaming pipeline now injects a top-level `summary_text` field into tool completion payloads, giving JSON consumers the same human-readable copy without parsing nested meta blobs.
- Agent output formatters still contain legacy fallbacks; `[ok]` badges remain until we finish Phase 3.

## Next Steps
- Capture CLI/Mac golden transcripts once formatter cleanup lands in CI so we can detect regressions automatically.

## Goals
- Preserve structured context (app name, element label, pointer geometry, shell command, etc.) for every tool call.
- Render concise, human-readable summaries in the CLI/Mac agent views without exposing internal IDs or glyph tokens.
- Eliminate the success `[ok]` badge for normal completions; only show badges/flags on warnings or errors.
- Keep completion tools (`task_completed`, `need_more_information`, `need_info`) flowing through their existing "state" UI without extra summary lines.

## Constraints & Challenges
- `ToolResponse.meta` is currently dropped when converting to `AnyAgentToolValue`; formatters only see whatever plain text the tool returned.
- MCP tools live in `PeekabooAgentRuntime` while the agent runtime/CLI sits elsewhere, so the metadata schema must be shared via Tachikoma types.
- We must not break existing MCP integrations; the new summary data needs a backwards-compatible wire format.

## Phase 1 – Plumbing
1. Introduce a typed `ToolEventSummary` struct (in Tachikoma) with optional fields for app/window, element, coordinates, scroll/move vectors, command strings, durations, etc.
2. Extend `ToolResponse` to carry an optional `summary: ToolEventSummary` (or replace `meta` entirely) and ensure the MCP adapter serializes/deserializes it.
3. Update the agent streaming pipeline (`PeekabooAgentService+Streaming`, `AnyAgentToolValue`, CLI event payloads) so the summary is delivered alongside the existing text result.

## Phase 2 – Tool Implementations
1. Audit every MCP tool (click/type/scroll/see/shell/sleep/window/app/menu/dialog/drag/move/swipe/list/etc.).
2. For each tool, populate `ToolEventSummary` using the context it already has:
   - UI tools: `targetApp`, `windowTitle`, `elementLabel`, `elementRole`, `humanizedPosition`.
   - Pointer tools: `direction`, `distancePx`, `profile`, `durationMs`.
   - Vision tools: `captureApp`, `windowTitle`, `sessionId` (for internal tracing only if we still need it), element counts.
   - System tools: `shellCommand`, `workingDirectory`, `sleepMs`, `reason`.
3. Remove raw element IDs (`elem_153`) and replace them with user-facing labels.

## Phase 3 – Formatting & UX
1. Update `ToolFormatter` (and specialized subclasses) to prefer the new summary fields when generating compact/result summaries.
2. Teach `AgentOutputDelegate` to:
   - Drop the green `[ok]` marker on success.
   - Render geometry in natural language (e.g., `1280×720 anchored top-left on Display 1`).
   - Continue showing badges only for warnings/errors.
3. Verify the Mac UI timeline consumes the same summary strings.

## Phase 4 – Verification
- Add unit tests for representative tools ensuring they emit the expected `ToolEventSummary`.
- Record CLI golden outputs (before/after) to confirm we now print sentences like `Click – Chrome · Button "Sign In with Email"`.
- Dogfood on Grindr/Wingman workflow to ensure the motivation scenarios look correct end-to-end.

## Open Questions
- Should we completely remove `meta`, or keep it for third-party MCP clients that expect arbitrary dictionaries?
- Do we want localized summaries, or is English-only acceptable for now?
- How do we expose the same summaries via API (e.g., JSON streaming) for downstream automation/telemetry?
