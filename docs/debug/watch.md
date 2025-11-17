---
summary: 'Hands-on protocol for exercising the `peekaboo watch` tool and HUD'
read_when:
  - 'verifying watch captures or HUD regressions'
  - 'debugging annotated frame overlays or motion boxes'
---

# `watch` Debug Protocol

Use this checklist whenever you touch `Peekaboo WatchCaptureSession`, the CLI command, or the new watch visualizer HUD. The steps assume you are on the primary Peekaboo development Mac (screen recording + Accessibility already granted).

## 1. Prep the session

1. Run `pnpm run docs:list` (already required per guardrails) so the docs index stays warm.
2. Ensure Poltergeist is building fresh binaries:  
   ```bash
   npm run poltergeist:haunt
   polter peekaboo --version
   ```
3. Launch the Playground app and load the `Watch HUD` scene so you have predictable motion targets (see `docs/playground-testing.md`).

## 2. Capture inside tmux

Long captures must run inside tmux via the guardrail runner:

```bash
./runner tmux new-session -d -s watch-smoke -- \
  polter peekaboo watch \
    --mode screen \
    --duration 20 \
    --active-fps 10 \
    --threshold 0.8 \
    --heartbeat-sec 4 \
    --highlight-changes

bin/sleep 5
./runner tmux capture-pane -p -t watch-smoke
```

While the capture runs, move the Playground window across displays and resize it so the adaptive cadence switches between idle/active. Remember to stop the tmux session afterwards:

```bash
./runner tmux kill-session -t watch-smoke
```

## 3. Validate artifacts

1. Inspect the output directory printed by the CLI. Confirm `metadata.json`, `contact.png`, and at least one `keep-000X.png` exist.
2. Open one of the kept frames and confirm the red motion boxes hug the region you actually disturbed. The converter now flips AX coordinates, so misalignment usually signals stale metadata.
3. Check `metadata.json` for `warnings` (frame caps, size caps, diff downgrades). Address regressions immediately.

## 4. Check the HUD & visualizer

1. Run `polter peekaboo visualizer` once per build. This fires every visual effect (documented in `docs/visualizer.md`) so you catch regressions early.
2. Trigger `watch` again and watch for the HUD:
   - The timeline should light up on every heartbeat/motion tick.
   - The HUD can be disabled under **Settings → Visual Feedback → Watch Capture**; make sure the toggle works.
   - The screen should **not** flash white anymore—if you see the screenshot flash, confirm `CaptureVisualizerMode.watchCapture` is being passed through.

## 5. Log findings

Capture any new issues in `docs/debug/visualizer-issues.md` (add VIS-XXX rows) and include tmux transcripts + repro steps. If the bug is specific to the watch pipeline, link back to this document so future agents follow the same protocol.
