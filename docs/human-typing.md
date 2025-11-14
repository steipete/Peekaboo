---
summary: 'Plan for Peekaboo\'s human-like typing cadence'
read_when:
  - 'designing or tuning TypeCommand/TypeTool timing controls'
  - 'implementing Peekaboo automation that must mimic human keystrokes'
---

# Human Typing Mode Plan

## Goals
- Give `peekaboo type` and the MCP `type` tool a first-class `--wpm` / `wpm` knob so automation can mimic fast but believable humans without guessing raw millisecond delays.
- Ensure every caller (CLI, ProcessService, agents) travels through a shared `TypingCadence` model so future heuristics (thinking pauses, typo injection) slot in without new flags.
- Keep deterministic fallbacks (`--delay`, JSON output) so scripted runs and regression tests stay repeatable when human cadence is disabled.

## Reference Behavior

### Words-per-minute baseline
“Words per minute” is standardized at five characters per word, so base inter-key delay (ms) = `60_000 / (wpm * 5)`. Example: 150 WPM ≈ 80 ms per key before jitter.citeturn0search11

### Realistic jitter curves
Keystroke flight and dwell times follow skewed, log-normal-style distributions rather than uniform noise, so our sampler should pull delays from a log-normal (or log-logistic) curve, then clamp to reasonable bounds. This matches research showing keyboard dynamics contain multiple overlapping log-normal components.citeturn0search5

### Inspiration from existing tools
The `human-keyboard` automation library exposes knobs for WPM, “thinking delay”, space/punctuation multipliers, and optional typo correction—concrete precedents we can mirror (minus the typo bits for now) so our UX feels familiar.citeturn1search7

## Parameter Mapping
| Mode | Approx. WPM | Base delay (ms) before jitter | Notes |
| --- | --- | --- | --- |
| `--wpm 120` (default) | 120 | ~100 | Feels like a fast typist, safe for demos. |
| `--wpm 150` | 150 | ~80 | “Pro” speed; cap jitter so bursts stay under 120 ms. |
| `--wpm 90` | 90 | ~133 | Safer for flows that must look cautious/human. |

Implementation: derive base delay from the formula, then apply ±20 % jitter per character, add +35 % before whitespace/punctuation, and insert a 300–500 ms “thinking pause” every N (default 12) words. Future flags can expose jitter magnitude once core behavior ships.

## Implementation Plan

### CLI & Commander layer
- Add `@Option(name: .customLong("wpm"), help: ...) var wpm: Int?` to `TypeCommand`, treating it as mutually exclusive with `--delay`.
- Validate acceptable range (80–220) and warn when users mix both knobs (“WPM takes precedence over --delay”).
- Emit the chosen cadence inside `TypeCommandResult` so downstream log parsing shows whether human mode was active.

### Shared cadence model
- Introduce `TypingCadence` in PeekabooFoundation: `.fixed(milliseconds: Int)` and `.human(wordsPerMinute: Int)`.
- Extend `TypeActionsRequest`, `AutomationServiceBridge.typeActions`, and `UIAutomationServiceProtocol` to pass the cadence instead of a bare `typingDelay`.
- Mirror the new schema in the MCP `type` tool (`wpm`, optional `delay`), giving precedence rules identical to the CLI.

### TypeService algorithm
- When cadence == `.human`, compute the base delay from WPM, then:
  - Sample per-character wait times via a log-normal generator seeded by `TypingCadenceSampler` so tests can inject deterministic values.
  - Multiply waits by 1.35 for spaces/punctuation and divide by 1.15 for alphanumeric digraphs to create bursts.
  - Every N words, insert a “thinking pause” (configurable default 350 ms) before resuming normal jitter.
- Fall back to the existing fixed-delay loop when cadence == `.fixed` to keep legacy scripts untouched.

### Testing & Observability
- CLI tests: ensure parsing enforces mutual exclusivity, default WPM, and JSON serialization.
- TypeService tests: supply a fake sampler to assert the produced delays stay within ±20 % of the base and honor punctuation multipliers.
- Logging: add a single debug line (“human typing @ 150 WPM, jitter ±20 %”) so diagnosing cadence mismatches is trivial without verbose tracing.

## Future Extensions
- Once stable, consider exposing optional typo/backspace injection and variance sliders, modeled after the knobs that `human-keyboard` surfaces today.citeturn1search7
- Add a `--thinking-pause-ms` override for workflows that need deterministic pauses (e.g., compliance demos) without toggling the entire cadence engine.
