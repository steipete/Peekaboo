---
summary: 'Checklist for recreating the lost CLI/Visualizer refactor'
read_when:
  - Repo changes vanished after a reset
  - Coordinating manual restoration of CLI runtime refactor
  - Hunting for the Visualizer resiliency patches
---

# Restoration Checklist (Nov 10, 2025)

A `git reset --hard` wiped the in-progress CLI runtime refactor + visualizer hardening. This file records what needs to be re-applied manually so we can recover without guessing. Reapply each section and tick it off in this doc when finished.

## 1. Visualizer Client Hardening
- [x] `VisualizationClient` imports AppKit and checks `NSRunningApplication` to see if Peekaboo.app is running before connecting.
- [x] Connection retries no longer stop after 3 attempts; instead we back off (capped at 30 s) and keep retrying indefinitely, logging the “Peekaboo.app is not running” message only once per outage.
- [x] Every `show*` visual-feedback method re-calls `connect()` when invoked while disconnected.
- [x] `docs/visualization.md` reflects the new reconnect behavior.

## 2. CLI Runtime Pattern (representative commands)
- [x] Dock command + all subcommands use plain structs with `@RuntimeStorage`, service bridges, `nonisolated(unsafe)` configurations, and runtime loggers instead of singletons.
- [x] Menu/MenuBar/System/Interaction commands follow the same shape (`run(using:)` marked `@MainActor`, `outputLogger` derived from the runtime, no `@MainActor struct`).
- [x] `FocusCommandOptions`, `WindowIdentificationOptions`, and helper bridges use `MainActor.assumeIsolated` where needed instead of reaching for shared singletons.

## 3. Shared Helpers & Docs
- [x] `CommandUtilities.requireScreenRecordingPermission` and `selectWindow` are `@MainActor`.
- [x] `docs/refactor.md` logs the new tmux build IDs after each restoration batch.
- [x] `Core/*/Package.swift` files point to `Vendor/swift-argument-parser` so SwiftPM stops warning about duplicate IDs.

Add more sections as we rediscover missing edits. Update the checkboxes (or add short notes) once each item is restored so future contributors know what’s still outstanding.
