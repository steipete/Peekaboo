## 4.9.1 - 2026-10-10

**Highlights:** Stop idle `peekaboo mcp` servers from burning CPU whenever other applications launch or quit, accept renamed or symlinked CLI executables, refuse to overwrite configuration files that cannot be read, and keep capture output intact at the retention limit.

- Stop an idle `peekaboo mcp` (and other window-tracking hosts) from burning CPU whenever unrelated applications launch or quit: AXorcist now indexes workspace applications by identity and stops re-reading resolved PIDs, cutting the cost from ~0.68 s to ~0.02 s of CPU per launch and quit on a Mac with ~600 running applications. Thanks @coygeek for the detailed report! #1005.
- Accept renamed or symlinked CLI executables when routing commands, normalizing agent tasks, and classifying JSON result envelopes.
- Refuse configuration mutations (custom provider add/remove, configuration updates) when an existing config file cannot be read, instead of overwriting it with defaults or cached data. Thanks @rudycelekli! #1007.
- Retain capture-action child stdout/stderr when the 64 KiB retention limit splits a trailing UTF-8 scalar, instead of discarding the whole valid prefix and recording an empty stream receipt. Thanks @rudycelekli! #1006.
- Accept signed global coordinates for foreground MCP move and drag within existing magnitude bounds, preserving target guards and before-delivery validation. Thanks @rudycelekli! #963.
- Update AXorcist to 0.2.2 so SwiftPM consumers of Peekaboo's library products get the idle-observer CPU fix, plus `collectAll` request-timeout handling, complete observation subscriptions, and fast observer-removal failure reporting.
- Update the shared Swift Log lock to 1.16.1 and Swift Configuration to 1.2.2 for corrected multiplexed log metadata and empty configuration values, preserving the supported Swift and macOS baselines.
- Preserve documentation source text through syntax highlighting, parse CRLF metadata, render unfinished EOF fences, retain link entities/query parameters, and assign unique heading targets. Thanks @rudycelekli! #931, #939, #940, #969, #971.
- Link the npm version page from the published GitHub release body, keeping scoped package paths literal and requiring the registry package name to match the local package before rendering.
- Publish the Sparkle minimum macOS version as the item element Sparkle reads, migrating existing feed entries whose enclosure attribute Sparkle ignored.
