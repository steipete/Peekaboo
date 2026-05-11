## [3.1.1] - 2026-05-11

### Added
- `peekaboo image --path -` now writes a single captured image to stdout for shell pipelines.
- The npm package now allows Intel Macs when shipping the universal CLI binary.

### Fixed
- Agent tool schemas now preserve MCP `anyOf`/`oneOf` parameters so Gemini no longer rejects `peekaboo agent` requests with orphan `required` entries. Thanks @bcharleson for #125.
- The macOS app release script now fails if the packaged app is missing its main executable and preserves the AppleEvents entitlement when re-signing.
- `peekaboo see --capture-engine cg` now keeps frontmost/window captures on the CoreGraphics path instead of falling through to `SCScreenshotManager`.
