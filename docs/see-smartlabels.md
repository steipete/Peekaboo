---
summary: 'Label placement strategy for `peekaboo see --annotate`'
read_when:
  - 'touching the SeeCommand annotation pipeline'
  - 'debugging smart label placement or cluttered overlays'
---

# Smart Label Placement (SeeCommand)

Peekaboo’s `see --annotate` flow renders element IDs and connector lines on top of the captured window. The `SmartLabelPlacer` helper makes sure those overlays land in calm areas of the UI instead of covering meaningful content. This document explains the placement algorithm, the recent padding tweak, and the testing steps to keep the behavior stable.

## How It Works

1. **Candidate generation:** For each detected element we derive a set of external positions (above, below, sides, corners). Buttons/links get extra corner candidates. Internal placements act as a last resort.
2. **Constraint filtering:** Candidates that spill outside the image, overlap other elements, or collide with already-placed labels are dropped. When everything fails we retry with relaxed bounds, and finally fall back to internal placement.
3. **Edge-aware scoring:** Each surviving candidate is scored by `AcceleratedTextDetector.scoreRegionForLabelPlacement`. A higher score means fewer edges/text, i.e., a calmer background for the label.
4. **Padding region:** Beginning November 17, 2025 we expand the sampled rectangle by 6 px on all sides before scoring and clamp to the image bounds. Sampling the halo around the label keeps us from picking regions that become cluttered once the text is drawn.
5. **Preferred orientations:** Above/below placements get small score multipliers so horizontally constrained elements favor vertical labels when all else is equal.

## Tests

- **Unit tests:** `Apps/CLI/Tests/CoreCLITests/SmartLabelPlacerTests.swift` injects a recording text detector to verify that the expanded/clamped scoring rectangles match expectations. Run via:

  ```bash
  ./runner swift test --package-path Apps/CLI --filter SmartLabelPlacerTests
  ```

- **Manual validation:** Capture Playground (or another deterministic app) and inspect the annotated PNGs to ensure labels sit over quiet regions:

  ```bash
  polter peekaboo -- see --app Playground --annotate --path .artifacts/playground-tools/$(date +%Y%m%d-%H%M%S)-see.png --json-output
  open .artifacts/playground-tools/<timestamp>-see_annotated.png
  ```

  Look for labels landing in the middle of complex controls or text blocks; if you find any, add their bounding boxes to a regression doc and adjust the padding/scoring heuristics accordingly.

## When to Update

- You change `SmartLabelPlacer` (spacing, scoring, candidate order, text detection logic).
- You touch `AcceleratedTextDetector` in ways that might affect edge density thresholds.
- You see `see --annotate` regressions (labels overlapping key UI, line crossings, etc.) and need to record the repro/mitigation.
- You add new annotation features (e.g., accessibility hints, new label types) that rely on or augment this placement logic.
