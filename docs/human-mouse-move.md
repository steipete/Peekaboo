---
summary: 'How Peekaboo generates natural-looking cursor motion'
read_when:
  - 'tuning mouse movement heuristics'
  - 'debugging human-style pointer paths'
---

# Human-Style Mouse Movement

Peekaboo's `human` profile makes cursor motion look hand-driven without forcing users to juggle dozens of tuning flags. It builds on three ideas:

1. **Distance-aware pacing** - Short hops complete in ~300 ms while multi-display traversals stretch toward 1.5 s, following a loose Fitts-style curve.
2. **Organic paths** - Each move is simulated with gently changing wind forces, gravity toward the destination, and a single optional overshoot before settling.
3. **Micro-jitter** - Low-amplitude noise keeps the trace from looking perfectly straight, but it is clamped so the pointer never drifts outside the target bounds.

## Using the profile

- **CLI**: add `--profile human` to `peekaboo move ...`. Smooth animation toggles on automatically, and duration/step counts pick sensible defaults per distance. You can still override `--duration` or `--steps` when you need deterministic timings; the profile treats those as hard caps.
- **Agents / MCP**: include `"profile": "human"` in the move tool arguments. Optional `duration` and `steps` fields work the same way as in the CLI-omit them to keep adaptive defaults.

## Defaults at a glance

| Distance | Typical Duration | Typical Steps | Notes |
| --- | --- | --- | --- |
| < 200 px | 280-350 ms | 30-40 | Minimal overshoot; jitter keeps subtle motion. |
| 200-800 px | 400-900 ms | 40-80 | Overshoot only triggers when the hop is long enough to look intentional. |
| > 800 px | 900-1700 ms | 80-120 | Velocity eases into and out of the target to avoid "teleport" endings. |

Additional details:
- Overshoot probability starts near 0 for short hops and tops out around 20 % for long moves. When it fires, the cursor glides slightly past the destination before recentering.
- Jitter amplitude is capped at ~0.35 px per frame so it never visibly shakes; it simply breaks up ruler-straight lines.
- Randomness comes from a seeded generator. When the caller doesn't supply a seed, Peekaboo derives one from wall-clock time, so runs feel unique while tests can still inject deterministic seeds via `MouseMovementProfile.human(HumanMouseProfileConfiguration(randomSeed: ...))`.

## When to prefer other profiles

- Use **`--profile linear`** (or omit `--profile`) for pixel-perfect hops, screenshots that need straight edges, or performance-critical test loops.
- Pair **`--profile human`** with screenshots, menu explorations, or demos where observers expect a believable pointer trace.

For implementation details or to tweak the heuristics, see `GestureService.moveMouse` in `PeekabooAutomation`. Most adjustments boil down to the duration curve, overshoot probability, or jitter amplitude constants described above.***
