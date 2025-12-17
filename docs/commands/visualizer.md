---
summary: 'Exercise Peekaboo visual feedback animations via peekaboo visualizer'
read_when:
  - 'verifying Peekaboo.app overlay rendering'
  - 'debugging visualizer transport/animations'
---

# `peekaboo visualizer`

Runs a lightweight smoke sequence that fires a representative set of visualizer events so you can verify Peekaboo’s overlay renderer is working end-to-end.

## What it does
- Connects to the visualizer host (typically `Peekaboo.app`)
- Emits events such as screenshot flash, capture HUD, click ripple, typing overlay, scroll indicator, swipe path, hotkey HUD, window/app/menu/dialog overlays, and a sample element-detection overlay

## Usage
```bash
polter peekaboo -- visualizer
```

## Notes
- This is a manual visual check: success means the command exits 0 and you can see the overlay sequence render.
- If nothing appears, verify:
  - `Peekaboo.app` is running and reachable
  - permissions are granted (`peekaboo permissions status`)
  - your screen isn’t being captured by another app that blocks overlays

