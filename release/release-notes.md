## [3.0.0-beta4] - 2026-04-28

### Added
- Root SwiftPM package to expose PeekabooBridge and automation modules for host apps.

### Changed
- Bumped submodule dependencies to tagged releases (AXorcist v0.1.2, Commander v0.2.2, Swiftdansi 0.2.1, Tachikoma v0.2.0, TauTUI v0.1.6).
- Version metadata updated to 3.0.0-beta4 for CLI/macOS app artifacts.

### Fixed
- Test runs now stay hermetic after MCP Swift SDK 0.11 updates by pinning the latest Tachikoma bridge/resource conversions and preventing provider test helpers from consuming live API keys.
- macOS settings now surface Google/Gemini and Grok providers with canonical provider hydration and manual key overrides.
- MCP `list` / `see` text output now surfaces hidden apps, bundle paths, and richer element metadata; thanks @metahacker for [#93](https://github.com/steipete/Peekaboo/pull/93).
- MCP tool descriptions and server-status output now share centralized version/banner metadata; thanks @0xble for [#85](https://github.com/steipete/Peekaboo/pull/85).
- Agent tool responses now handle current MCP resource/resource-link content shapes; thanks @huntharo for [#95](https://github.com/steipete/Peekaboo/pull/95).
- CLI credential writes now honor Peekaboo’s config/profile directory consistently; thanks @0xble for [#82](https://github.com/steipete/Peekaboo/pull/82).
- macOS settings hydration no longer persists config-backed values while loading; thanks @0xble for [#86](https://github.com/steipete/Peekaboo/pull/86).
- CLI agent runtime now prefers local execution by default; thanks @0xble for [#83](https://github.com/steipete/Peekaboo/pull/83).
- Remote `peekaboo see` element detection now uses the command timeout instead of the bridge client's shorter socket default; thanks @0xble for [#89](https://github.com/steipete/Peekaboo/pull/89).
- Screen recording permission checks are more reliable, and MCP Swift SDK compatibility is restored; thanks @romanr for [#94](https://github.com/steipete/Peekaboo/pull/94).
- Coordinate clicks now fail fast when the requested target app is not actually frontmost after focus; thanks @shawny011717 for [#91](https://github.com/steipete/Peekaboo/pull/91).
- Permissions docs now point to the real `peekaboo permissions status|grant` commands; thanks @Undertone0809 for [#68](https://github.com/steipete/Peekaboo/pull/68).

