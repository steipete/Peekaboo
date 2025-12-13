---
summary: 'Capture annotated UI maps with peekaboo see'
read_when:
  - 'Collecting UI element IDs for automation'
  - 'Troubleshooting click/type targeting'
---

# `peekaboo see`

`peekaboo see` captures the current macOS UI, extracts accessibility metadata, and (optionally) saves annotated screenshots. CLI and agent flows rely on these UI maps to find element IDs (`elem_123`), bounds, labels, and snapshot IDs.

```bash
# Capture frontmost window, print JSON, and save an annotated PNG
polter peekaboo -- see --json-output --annotate --path /tmp/see.png

# Target a specific app or window title
polter peekaboo -- see --app "Google Chrome" --window-title "Login"
```

## When to use

- Before issuing `click`/`type` commands so you have stable element IDs.
- When debugging automation failures—`--json-output` includes raw bounds, labels, and snapshot IDs.
- To snapshot UI regressions (pass `--annotate` + `--path`).

## Key options

| Flag | Description |
| --- | --- |
| `--app`, `--window-title`, `--window-id`, `--pid` | Limit capture to a known app/window/process. |
| `--mode screen` | Capture the entire display instead of a single window. |
| `--annotate` | Overlay element bounds/IDs on the output image. |
| `--path <file>` | Save the screenshot/annotation to disk. |
| `--json-output` | Emit structured metadata (recommended for scripting). |
| `--no-web-focus` | Skip the automatic web-content focus retry (useful if the page reacts badly to synthetic clicks). |

## Automatic web focus fallback (Nov 2025)

Modern browsers sometimes keep keyboard focus in the omnibox, which means embedded login forms (Instagram, Facebook, etc.) never expose their `AXTextField` nodes to accessibility clients. Starting November 2025:

1. `peekaboo see` performs a normal accessibility traversal.
2. If **zero** text fields are detected, the command locates the dominant `AXWebArea` (or equivalent) inside the target window and performs a synthetic `AXPress`.
3. The traversal runs **one more time**. If the web view exposes its inputs after gaining focus, they now appear in the JSON output.

This fallback only runs inside the resolved window (it won’t hop between windows) and logs a debug entry when it fires. If you need to disable it for a specialized flow, run `see` inside a different window or manually focus the desired element first.

## JSON output primer

When `--json-output` is supplied, the CLI prints:

- `snapshot_id` – reference for subsequent `click --snapshot …` and `type --snapshot …`.
- `ui_map` – path to the persisted snapshot file (`~/.peekaboo/snapshots/<id>/snapshot.json`).
- `ui_elements` – flattened list of actionable nodes (buttons, text fields, links, etc.).
- `interactable_count`, `element_count`, `capture_mode`, and performance metadata for debugging.
- Each `ui_elements[n]` entry now mirrors the raw AX metadata we capture—`title`, `label`, **`description`**, `role_description`, `help`, `identifier`, and the keyboard shortcut if one exists. That makes Chrome toolbar icons (which frequently hide their name in `AXDescription`) searchable without relying on coordinates.

Use `jq` or any JSON parser to find elements:

```bash
polter peekaboo -- see --app "Safari" --json-output \
  | jq '.data.ui_elements[] | select(.label | test("Sign in"; "i"))'

# Toolbar buttons that only expose AXDescription:
polter peekaboo -- see --app "Google Chrome" --json-output \
  | jq '.data.ui_elements[] | select((.description // "") | test("Wingman"; "i"))'
```

## Troubleshooting tips

- If the CLI reports **blind typing**, re-run `see` with `--app <Name>` so we can autofocus the app before typing.
- Missing text fields after the fallback usually means the page is shielding its inputs from AX entirely; in that case rely on the Browser MCP DOM or image-based hit tests.
- For repeatable local tests, run `RUN_LOCAL_TESTS=true swift test --filter SeeCommandPlaygroundTests` to exercise the Playground fixtures mentioned in `docs/research/interaction-debugging.md`.

## Smart label placement (`--annotate`)
- The `SmartLabelPlacer` generates external label candidates (above/below/sides/corners) for each element, filters out overlaps/out-of-bounds positions, then scores remaining spots via `AcceleratedTextDetector.scoreRegionForLabelPlacement` to prefer calm regions. Internal placements are a last-resort fallback.
- Edge-aware scoring samples a padded rectangle (6 px halo, clamped to the image) so the chosen region stays clean once text is drawn; above/below placements get slight bonuses to reduce sideways clutter.
- Preferred orientations nudge horizontally tight elements toward vertical labels when scores tie.
- Tests: `Apps/CLI/Tests/CoreCLITests/SmartLabelPlacerTests.swift` (run with `./runner swift test --package-path Apps/CLI --filter SmartLabelPlacerTests`).
- Manual validation: `polter peekaboo -- see --app Playground --annotate --path /tmp/see.png --json-output` then inspect the annotated PNG; if labels cover dense UI, capture the repro and adjust padding/scoring before committing.
