# Poltergeist 👻

> The ghost that keeps your Swift projects fresh

Poltergeist is a universal file watcher and automatic build system for Swift projects. It monitors your source files and automatically rebuilds your CLI tools, Mac apps, or any Swift project whenever you save changes. No more manual rebuilding, no more stale binaries, no more wasted time.

## Features

- 🔄 **Automatic Rebuilding** - Detects file changes and rebuilds immediately
- 🎯 **Dual Mode Support** - Works with both Swift Package Manager (CLI) and Xcode projects (Mac apps)
- 🚀 **Auto-Relaunch** - Automatically quits and relaunches Mac apps after successful builds
- 📊 **Build Status Tracking** - JSON-based status files for integration with other tools
- 🔔 **Native Notifications** - macOS notifications with sound for build success/failure
- 🎨 **Smart Error Handling** - Clear error messages and recovery instructions
- ⚡ **High Performance** - Built on Facebook's Watchman for efficient file watching
- 🔧 **Configurable** - JSON configuration with full TypeScript validation
- 📦 **Zero Dependencies** - Only requires Node.js and Watchman

## Installation

### Prerequisites

1. **Node.js** (v18 or later)
   ```bash
   brew install node
   ```

2. **Watchman** (Facebook's file watching service)
   ```bash
   brew install watchman
   ```

### Install Poltergeist

```bash
# Clone or navigate to your project
cd /path/to/your/swift/project

# Install Poltergeist dependencies
cd tools/poltergeist
npm install

# Build TypeScript
npm run build

# Make executable
chmod +x poltergeist
```

## Quick Start

### 1. Initialize Configuration

```bash
./poltergeist init
```

This creates a `poltergeist.config.json` file in your project root. Edit it to match your project:

```json
{
  "cli": {
    "enabled": true,
    "buildCommand": "./scripts/build-swift-debug.sh",
    "outputPath": "./my-cli",
    "statusFile": "/tmp/my-cli-build-status.json",
    "lockFile": "/tmp/my-cli-build.lock",
    "watchPaths": [
      "Sources/**/*.swift",
      "Package.swift"
    ]
  },
  "macApp": {
    "enabled": true,
    "buildCommand": "xcodebuild -workspace MyApp.xcworkspace -scheme MyApp build",
    "bundleId": "com.example.myapp",
    "autoRelaunch": true,
    "watchPaths": [
      "MyApp/**/*.swift",
      "MyApp/**/*.storyboard"
    ]
  }
}
```

### 2. Start Watching

```bash
# Watch all enabled targets
./poltergeist haunt

# Watch only CLI
./poltergeist haunt --cli

# Watch only Mac app
./poltergeist haunt --mac
```

### 3. Check Status

```bash
./poltergeist status
```

## Configuration

### CLI Configuration

| Field | Type | Description |
|-------|------|-------------|
| `enabled` | boolean | Enable/disable CLI watching |
| `buildCommand` | string | Command to build your CLI |
| `outputPath` | string | Path to the built binary |
| `statusFile` | string | Path to build status JSON file |
| `lockFile` | string | Path to build lock file |
| `watchPaths` | string[] | Glob patterns for files to watch |
| `settlingDelay` | number | Milliseconds to wait before building (default: 1000) |
| `maxRetries` | number | Max build retry attempts (default: 3) |
| `backoffMultiplier` | number | Retry delay multiplier (default: 2) |

### Mac App Configuration

| Field | Type | Description |
|-------|------|-------------|
| `enabled` | boolean | Enable/disable Mac app watching |
| `buildCommand` | string | Command to build your app (usually xcodebuild) |
| `bundleId` | string | Bundle identifier for auto-relaunch |
| `autoRelaunch` | boolean | Auto quit/relaunch app after build |
| `statusFile` | string | Path to build status JSON file |
| `lockFile` | string | Path to build lock file |
| `watchPaths` | string[] | Glob patterns for files to watch |

### Global Configuration

```json
{
  "notifications": {
    "enabled": true,
    "successSound": "Glass",
    "failureSound": "Basso"
  },
  "logging": {
    "file": ".poltergeist.log",
    "level": "info"  // debug, info, warn, error
  }
}
```

## Usage Examples

### Basic Swift CLI Project

```json
{
  "cli": {
    "enabled": true,
    "buildCommand": "swift build -c debug",
    "outputPath": ".build/debug/my-tool",
    "watchPaths": ["Sources/**/*.swift", "Package.swift"]
  }
}
```

### Xcode Mac App Project

```json
{
  "macApp": {
    "enabled": true,
    "buildCommand": "xcodebuild -project MyApp.xcodeproj -scheme MyApp -configuration Debug build",
    "bundleId": "com.mycompany.myapp",
    "autoRelaunch": true,
    "watchPaths": ["MyApp/**/*.swift", "MyApp/**/*.xib"]
  }
}
```

### Multi-Target Project

```json
{
  "cli": {
    "enabled": true,
    "buildCommand": "./scripts/build-cli.sh",
    "outputPath": "./bin/cli-tool",
    "watchPaths": ["CLI/**/*.swift", "Shared/**/*.swift"]
  },
  "macApp": {
    "enabled": true,
    "buildCommand": "./scripts/build-app.sh",
    "bundleId": "com.example.app",
    "autoRelaunch": true,
    "watchPaths": ["App/**/*.swift", "Shared/**/*.swift"]
  }
}
```

## Build Status Integration

Poltergeist writes build status to JSON files that other tools can read:

```json
{
  "status": "success",  // "idle", "building", "success", "failed"
  "timestamp": "2025-07-29T19:40:00Z",
  "gitHash": "abc123",
  "errorSummary": "",
  "builder": "poltergeist",
  "buildTime": 12300  // milliseconds
}
```

### Example: Smart CLI Wrapper

```bash
#!/bin/bash
# Wait for Poltergeist to finish building before running

BUILD_STATUS="/tmp/my-cli-build-status.json"
MAX_WAIT=180

# Check if build is in progress
if [ -f "$BUILD_STATUS" ]; then
  STATUS=$(jq -r '.status' "$BUILD_STATUS" 2>/dev/null)
  
  if [ "$STATUS" = "building" ]; then
    echo "⏳ Waiting for build to complete..."
    
    # Wait for build to finish
    WAITED=0
    while [ "$STATUS" = "building" ] && [ $WAITED -lt $MAX_WAIT ]; do
      sleep 1
      STATUS=$(jq -r '.status' "$BUILD_STATUS" 2>/dev/null)
      ((WAITED++))
    done
  fi
  
  if [ "$STATUS" = "failed" ]; then
    echo "❌ Build failed!"
    ERROR=$(jq -r '.errorSummary' "$BUILD_STATUS" 2>/dev/null)
    echo "$ERROR"
    exit 1
  fi
fi

# Run the CLI
exec ./my-cli "$@"
```

## Advanced Features

### Custom Build Scripts

Poltergeist can run any build command. Create wrapper scripts for complex builds:

```bash
#!/bin/bash
# scripts/build-with-env.sh

export MY_BUILD_FLAG=1
export SWIFT_BUILD_FLAGS="-Xswiftc -DDEBUG"

swift build $SWIFT_BUILD_FLAGS
```

### Notification Control

Disable notifications temporarily:
```bash
POLTERGEIST_NOTIFICATIONS=false ./poltergeist haunt
```

### Debug Mode

Enable verbose logging:
```bash
./poltergeist haunt --verbose
```

Or in config:
```json
{
  "logging": {
    "level": "debug"
  }
}
```

## Architecture

Poltergeist is built with TypeScript for maintainability and extensibility:

- **Watchman Integration** - Native Node.js bindings for efficient file watching
- **Modular Design** - Separate concerns for watching, building, and notifications
- **Type Safety** - Full TypeScript with Zod schema validation
- **Async/Await** - Modern async patterns for reliability
- **Process Management** - Proper handling of build processes and cancellation

## Troubleshooting

### Watchman Not Found

```bash
brew install watchman
```

### Permission Denied

```bash
chmod +x poltergeist
chmod +x your-build-script.sh
```

### Build Keeps Failing

1. Check your build command works manually
2. Look at `.poltergeist.log` for detailed errors
3. Ensure all paths in config are correct
4. Try with `--verbose` flag

### Auto-Relaunch Not Working

1. Verify the `bundleId` is correct
2. Check the app is actually installed
3. Ensure the app has proper permissions

## Contributing

Poltergeist is part of the Peekaboo project. To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

## License

MIT License - See LICENSE file in the project root

## Credits

Built with ❤️ for the Swift community by the Peekaboo team.

Powered by:
- [Watchman](https://facebook.github.io/watchman/) - Facebook's file watching service
- [Commander.js](https://github.com/tj/commander.js/) - Node.js command-line interfaces
- [Chalk](https://github.com/chalk/chalk) - Terminal string styling
- [Winston](https://github.com/winstonjs/winston) - Logging library
- [Zod](https://github.com/colinhacks/zod) - TypeScript-first schema validation