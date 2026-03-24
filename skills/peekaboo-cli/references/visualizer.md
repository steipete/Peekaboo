---
summary: 'Exercise Peekaboo visual feedback animations'
---

# `peekaboo visualizer`

Runs a smoke sequence that fires visualizer events to verify Peekaboo's overlay renderer.

## What it does

- Connects to the visualizer host (typically `Peekaboo.app`)
- Emits events: screenshot flash, capture HUD, click ripple, typing overlay, scroll indicator, swipe path, hotkey HUD, etc.

## Usage

```bash
peekaboo visualizer
peekaboo visualizer --json-output
```

## Notes

- This is primarily a manual visual check.
- If nothing appears, verify `Peekaboo.app` is running and permissions are granted.
