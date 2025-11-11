---
summary: 'Poltergeist usage tips for Peekaboo'
read_when:
  - Tuning local rebuild performance
  - Disabling specific Poltergeist targets
  - Debugging CLI vs. mac app rebuilds
---

# Poltergeist Tips & Recommendations

## Target Enable/Disable Switches
- Each entry in `poltergeist.config.json` has an `"enabled"` flag. Set `"enabled": false` to stop Poltergeist from rebuilding that target (e.g., disable `peekaboo-mac` during CLI-heavy work).
- Re-enable the target when you need mac builds again—no script changes required.

## Sequential Build Queue
- `buildScheduling.parallelization` is now forced to `1`, so Poltergeist never runs CLI and mac builds in parallel. The intelligent queue still scores targets by focus, but it now drains one build at a time, guaranteeing the CLI artifacts are fresh before the mac target even starts.
- Keep `prioritization.enabled` true so the queue understands which target should run next; if you disable it, the fallback code will reintroduce parallel `Promise.all` builds.

```jsonc
"buildScheduling": {
  "parallelization": 1,
  "prioritization": {
    "enabled": true
  }
}
```

## Back-off For Idle Targets
- The mac target carries a higher `settlingDelay` (4 s vs. the CLI’s 1 s). That extra pause acts as a back-off window: intermittent edits in shared Core files rebuild the CLI immediately but let the mac pipeline idle unless you keep touching UI sources.
- If you start focusing on the app again, drop the delay back down or set the CLI’s `settlingDelay` higher temporarily—the knob lives directly on each target entry.

## Rebuild Triggers & Watch Paths
- Both CLI and mac targets currently watch `Core/PeekabooCore/**/*.swift` and `Core/AXorcist/**/*.swift`, so *any* core edit triggers *both* builders.
- Action items:
  - Tighten the mac target's `watchPaths` to files it really needs, or split Core globs (e.g., `Core/PeekabooCore/CLI/**` vs. `Core/PeekabooCore/App/**`).
  - Consider a dedicated target for shared libraries if you need separate rebuild policies.

## Launch Behavior
- `polter peekaboo …` only waits for the CLI target to finish. The mac target may still rebuild in the background because of overlapping watch paths, but launches won't block on it.

## Caching
- Poltergeist shells into `./scripts/build-swift-debug.sh` and `./scripts/build-mac-debug.sh`. As long as those scripts keep `.build` / `DerivedData` intact, incremental builds remain cached—no cache nuking happens unless a script explicitly does it.

## Best Practices
1. **Disable unused targets** when focusing on CLI work to avoid mac rebuilds.
2. **Batch edits** so Poltergeist rebuilds once instead of after each micro-change.
3. **Run Peekaboo.app in tmux** rather than rebuilding it just to relaunch.
4. **Profile watch paths** before expanding them—every new glob increases rebuild frequency.
