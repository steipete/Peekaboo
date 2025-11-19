---
summary: "Capture engine selector (ScreenCaptureKit vs CGWindowList) and how to control it."
read_when:
  - "changing capture behavior or debugging SC vs CG fallbacks"
  - "adding new commands that trigger screenshots"
---

# Capture Engine Selection

Peekaboo supports two capture backends:
- **modern**: ScreenCaptureKit (SCStream/SCScreenshotManager)
- **classic**: CGWindowListCreateImage (legacy)

## How selection works
- Default: **auto** (modern first, then classic if allowed).
- Environment:
  - `PEEKABOO_CAPTURE_ENGINE=auto|modern|sckit|classic|cg` (preferred)
  - Back-compat: `PEEKABOO_USE_MODERN_CAPTURE=true|false|modern-only|legacy`
- CLI flags (set the env for this invocation):
  - `peekaboo capture --capture-engine auto|modern|sckit|classic|cg`
  - `peekaboo image --capture-engine ...`
  - `peekaboo see --capture-engine ...`

Aliases:
- modern: `modern`, `sckit`, `sc`, `sck`
- classic: `classic`, `cg`, `legacy`
- auto: `auto`

## Current policy (Nov 2025)
- macOS 13/14: auto = try SC, fallback to CG on failure.
- macOS 15+: SC only by default; legacy CG is disabled unless you explicitly set `PEEKABOO_ALLOW_LEGACY_CAPTURE=1` or use `--capture-engine classic|cg`.

## Logging & telemetry
- ScreenCaptureService logs which engine was attempted and when fallback occurs.
- Consider adding env `PEEKABOO_DISABLE_CGWINDOWLIST` if you want to dogfood pure SC.

## When to use which
- Prefer **modern**. Use **classic** only when you hit SC gaps (e.g., certain menu-bar popovers) and are on ≤14, or for explicit regression checks.
- For reproducible SC failures, log them and aim to remove the classic dependency rather than relying on it long-term.
