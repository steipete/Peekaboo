# Poltergeist - Swift CLI Auto-Builder 👻

Poltergeist is a file watcher that automatically rebuilds the Peekaboo Swift CLI whenever source files change. It ensures your CLI binary is always up-to-date without manual intervention.

## Architecture

### Components

1. **poltergeist.sh** - Main control script
   - `npm run poltergeist:haunt` - Start the watcher
   - `npm run poltergeist:rest` - Stop the watcher
   - `npm run poltergeist:status` - Check if running
   - `npm run poltergeist:logs` - View build logs

2. **poltergeist-handler.sh** - Build execution engine
   - Triggered by Watchman when files change
   - Handles build execution with retry logic
   - Manages build status and error recovery
   - Implements exponential backoff for failures

3. **scripts/peekaboo-wait.sh** - Smart wrapper script
   - Checks if binary is fresh before execution
   - Detects build failures via status file
   - Exits with code 42 on build failure
   - Waits for ongoing builds (max 3 minutes)

4. **scripts/poltergeist/poltergeist-signal-recovery.sh** - Recovery signaling
   - Resets Poltergeist's backoff timer
   - Called after manual build fixes

### File Monitoring

Poltergeist watches for changes in:
- `Core/PeekabooCore/**/*.swift`
- `Core/AXorcist/**/*.swift`
- `Apps/CLI/**/*.swift`
- `**/Package.swift`
- `**/Package.resolved`

Excludes: `Version.swift` (auto-generated)

### Status Tracking

Build status is tracked in `/tmp/peekaboo-build-status.json`:
```json
{
    "status": "building|success|failed",
    "timestamp": "2025-01-29T12:00:00Z",
    "git_hash": "abc123",
    "error_summary": "First few lines of error",
    "builder": "poltergeist"
}
```

### Temporary Files

- `/tmp/peekaboo-build-status.json` - Current build status
- `/tmp/peekaboo-build-backoff` - Backoff timer state
- `/tmp/peekaboo-build-recovery` - Recovery signal
- `/tmp/peekaboo-build-cancel` - Build cancellation flag
- `/tmp/peekaboo-swift-build.lock` - Build lock (PID)
- `.poltergeist.log` - Activity log in project root

## Usage Flow

### Normal Operation

1. **Start Poltergeist**: `npm run poltergeist:haunt`
2. **Edit Swift files**: Make your changes
3. **Use wrapper**: `./scripts/peekaboo-wait.sh <command>`
4. **Automatic rebuild**: Poltergeist detects changes and rebuilds
5. **Fresh binary**: Wrapper waits for build and runs your command

### Build Failure Recovery

When a build fails:

1. **Wrapper detects failure**: Exits with code 42
   ```
   ❌ POLTERGEIST BUILD FAILED
   
   Error: [specific error summary]
   
   🔧 TO FIX: Run 'npm run build:swift' to see and fix the compilation errors.
   ```

2. **Manual fix**: Run `npm run build:swift` and fix errors

3. **Signal recovery**: `./scripts/poltergeist/poltergeist-signal-recovery.sh`

4. **Resume normal operation**: Poltergeist resets backoff

### Backoff Strategy

After build failures, Poltergeist backs off:
- 1st failure: Resume on next file change
- 2nd failure: Wait 1 minute
- 3rd failure: Wait 2 minutes
- 4th+ failure: Wait 5 minutes

Recovery signal resets this immediately.

## Best Practices

1. **Always use the wrapper**: `./scripts/peekaboo-wait.sh`
   - Never run `./peekaboo` directly
   - Never manually build unless fixing errors

2. **Check Poltergeist status** once per session:
   ```bash
   npm run poltergeist:status
   ```

3. **Exit code 42** means build failure - fix immediately

4. **Trust the timestamps**: Always verify build timestamp in CLI output:
   ```
   Peekaboo 3.0.0 (main/abc123, built: 2025-01-29T12:00:00+02:00)
   ```

## Troubleshooting

### Poltergeist not detecting changes
- Check if running: `npm run poltergeist:status`
- Restart: `npm run poltergeist:rest && npm run poltergeist:haunt`

### Wrapper timeout after 3 minutes
- Check status: `npm run poltergeist:status`
- View logs: `npm run poltergeist:logs`
- Manual build: `npm run build:swift`

### Swift Package Manager errors
Clean everything and restart:
```bash
npm run poltergeist:stop
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Caches/org.swift.swiftpm
find . -name ".build" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name ".swiftpm" -type d -exec rm -rf {} + 2>/dev/null || true
npm run poltergeist:haunt
```

## Implementation Details

### Build Process
1. Poltergeist uses `./scripts/build-swift-debug.sh` for incremental builds
2. Build output is appended to `.poltergeist.log`
3. Binary is copied to project root as `./peekaboo`
4. Git hash is included in build logs for tracking

### Concurrent Build Handling
- New file changes cancel outdated builds
- Minimum 5 seconds before allowing cancellation
- Process tree cleanup ensures no orphaned builds

### Status File Protocol
- Written atomically to prevent corruption
- 5-minute staleness timeout
- JSON format for easy parsing
- Includes error summaries for quick diagnosis

## For AI Agents

When you see exit code 42:
1. Run `npm run build:swift` immediately
2. Fix compilation errors
3. Run `./scripts/poltergeist/poltergeist-signal-recovery.sh`
4. Continue with your task

Never:
- Check logs first (wastes time)
- Run build commands unless fixing errors
- Use raw binary instead of wrapper
- Worry about Poltergeist internals

Just trust the system - it works! 👻