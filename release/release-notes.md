## [3.1.1] - 2026-05-11

### Added
- `peekaboo image --path -` now writes a single captured image to stdout for shell pipelines.
- The npm package now allows Intel Macs when shipping the universal CLI binary.

### Fixed
- `peekaboo see --capture-engine cg` now keeps frontmost/window captures on the CoreGraphics path instead of falling through to `SCScreenshotManager`.
