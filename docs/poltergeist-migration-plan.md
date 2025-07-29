# Poltergeist Migration Plan - Generic Target System

## Current State

Poltergeist currently has two hardcoded target types:
- `cli` - For command-line executables
- `macApp` - For macOS applications

## Proposed Generic Target System

### New Configuration Structure

Instead of hardcoded target types, use a generic `targets` array:

```json
{
  "targets": [
    {
      "name": "peekaboo-cli",
      "type": "executable",
      "enabled": true,
      "buildCommand": "./scripts/build-swift-debug.sh",
      "outputPath": "./peekaboo",
      "statusFile": "/tmp/peekaboo-cli-build-status.json",
      "lockFile": "/tmp/peekaboo-cli-build.lock",
      "watchPaths": [
        "Core/PeekabooCore/**/*.swift",
        "Core/AXorcist/**/*.swift", 
        "Apps/CLI/**/*.swift"
      ],
      "settlingDelay": 1000
    },
    {
      "name": "peekaboo-app",
      "type": "app-bundle",
      "platform": "macos",
      "enabled": true,
      "buildCommand": "./scripts/build-mac-debug.sh",
      "bundleId": "boo.peekaboo",
      "statusFile": "/tmp/peekaboo-mac-build-status.json",
      "lockFile": "/tmp/peekaboo-mac-build.lock",
      "autoRelaunch": true,
      "watchPaths": [
        "Apps/Mac/Peekaboo/**/*.swift",
        "Apps/Mac/Peekaboo/**/*.storyboard",
        "Apps/Mac/Peekaboo/**/*.xib",
        "Core/PeekabooCore/**/*.swift",
        "Core/AXorcist/**/*.swift"
      ]
    }
  ],
  "notifications": {
    "enabled": true,
    "successSound": "Glass",
    "failureSound": "Basso"
  },
  "logging": {
    "file": ".poltergeist.log",
    "level": "info"
  }
}
```

### Target Types

1. **executable** - Command-line tools, scripts, binaries
   - Required: `outputPath`
   - Optional: `installPath`, `permissions`

2. **app-bundle** - Application bundles (macOS, iOS, etc.)
   - Required: `bundleId` or `outputPath`
   - Optional: `platform`, `autoRelaunch`, `launchArgs`

3. **library** - Static/dynamic libraries
   - Required: `outputPath`
   - Optional: `headers`, `linkFlags`

4. **framework** - Framework bundles
   - Required: `outputPath`, `bundleId`
   - Optional: `headers`, `resources`

5. **test** - Test targets
   - Required: `testCommand`
   - Optional: `coverage`, `parallel`

6. **docker** - Docker images
   - Required: `dockerfile`, `imageName`
   - Optional: `registry`, `tags`

7. **custom** - User-defined targets
   - Only required field is `buildCommand`

### Benefits

1. **Extensibility**: Easy to add new target types without changing core code
2. **Flexibility**: Each target can have its own configuration
3. **Multi-platform**: Can support iOS, watchOS, tvOS, visionOS, Linux, etc.
4. **Multi-language**: Not limited to Swift (could watch TypeScript, Rust, etc.)
5. **Better naming**: Targets have descriptive names instead of generic "cli" or "macApp"

### Migration Path

1. **Phase 1: Backward Compatibility**
   - Support both old (`cli`, `macApp`) and new (`targets`) formats
   - Auto-convert old format to new format internally
   - Deprecation warnings for old format

2. **Phase 2: Migration Tools**
   - Add `poltergeist migrate` command to update config files
   - Update documentation and examples

3. **Phase 3: Remove Legacy Support**
   - After sufficient migration period, remove old format support

### CLI Changes

Current:
```bash
poltergeist haunt --cli
poltergeist haunt --mac
```

New:
```bash
poltergeist haunt --target peekaboo-cli
poltergeist haunt --target peekaboo-app
poltergeist haunt  # Watch all enabled targets
```

### Implementation Notes

1. **Type Validation**: Use Zod schemas for each target type
2. **Plugin System**: Allow custom target types via plugins
3. **Shared Watchers**: Optimize file watching for overlapping paths
4. **Status Aggregation**: Single status command shows all targets

### Example Use Cases

**iOS App + Tests**:
```json
{
  "targets": [
    {
      "name": "MyApp-iOS",
      "type": "app-bundle",
      "platform": "ios",
      "buildCommand": "xcodebuild -scheme MyApp-iOS",
      "bundleId": "com.example.myapp"
    },
    {
      "name": "MyApp-Tests",
      "type": "test",
      "testCommand": "xcodebuild test -scheme MyAppTests",
      "coverage": true
    }
  ]
}
```

**Multi-Platform Library**:
```json
{
  "targets": [
    {
      "name": "MyLib-macOS",
      "type": "library",
      "buildCommand": "swift build --platform macos",
      "outputPath": ".build/macos/libMyLib.dylib"
    },
    {
      "name": "MyLib-Linux",
      "type": "library", 
      "buildCommand": "swift build --platform linux",
      "outputPath": ".build/linux/libMyLib.so"
    }
  ]
}
```

**Full-Stack Project**:
```json
{
  "targets": [
    {
      "name": "backend",
      "type": "executable",
      "buildCommand": "swift build -c release",
      "outputPath": ".build/release/Server"
    },
    {
      "name": "frontend",
      "type": "custom",
      "buildCommand": "npm run build",
      "watchPaths": ["src/**/*.{ts,tsx,css}"]
    },
    {
      "name": "docker",
      "type": "docker",
      "dockerfile": "Dockerfile",
      "imageName": "myapp:latest",
      "buildCommand": "docker build -t myapp:latest ."
    }
  ]
}
```

## Conclusion

This generic target system makes Poltergeist truly universal - it can watch and build any type of project, not just Swift CLIs and Mac apps. The migration can be done gradually with full backward compatibility.