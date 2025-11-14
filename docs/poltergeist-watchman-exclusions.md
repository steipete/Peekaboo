---
summary: 'Review Poltergeist Watchman Exclusion System guidance'
read_when:
  - 'planning work related to poltergeist watchman exclusion system'
  - 'debugging or extending features described here'
---

# Poltergeist Watchman Exclusion System

## Overview

Poltergeist now includes an automatic Watchman configuration system that excludes common build directories and cache files to prevent performance issues and excessive file system events. This system provides both default exclusions and user-configurable custom exclusions.

## Features

### Default Exclusions (70+ patterns)

The system automatically excludes common problematic directories:

**Build Directories:**
- `.build`, `build`, `dist`, `out`, `output`, `target`, `bin`, `obj`

**Dependencies:**
- `node_modules`, `vendor`, `Pods`, `Carthage`

**IDE/Editor:**
- `.vscode`, `.idea`, `.cursor`, `.vs`
- `*.xcworkspace/xcuserdata`, `*.xcodeproj/xcuserdata`

**Version Control:**
- `.git`, `.svn`, `.hg`, `.bzr`

**macOS/Xcode Specific:**
- `DerivedData`, `*.dSYM`, `*.framework`, `*.app`

**Cache Directories:**
- `.cache`, `.sass-cache`, `.parcel-cache`, `.next`, `.nuxt`
- `__pycache__`, `.pytest_cache`, `.mypy_cache`, `.ruff_cache`

**And many more...** (see full list in `WatchmanConfigManager.PROJECT_TYPE_EXCLUSIONS` and `UNIVERSAL_EXCLUSIONS`)

### User Configuration

Configure exclusions in your `poltergeist.config.json`:

```json
{
  "targets": [...],
  "watchman": {
    "useDefaultExclusions": true,
    "excludeDirs": [
      "coverage",
      "*.log", 
      "tmp_screenshots",
      "test_output",
      "custom_build_dir"
    ]
  }
}
```

### Configuration Options

- **`useDefaultExclusions`** (boolean, default: `true`): Enable/disable default exclusions
- **`excludeDirs`** (string[], default: `[]`): Additional custom directories to exclude

## How It Works

### 1. Automatic .watchmanconfig Generation

Poltergeist automatically creates and maintains a `.watchmanconfig` file in your project root:

```json
{
  "ignore_dirs": [
    ".build",
    "build", 
    "node_modules",
    "DerivedData",
    // ... all configured exclusions
  ],
  "ignore_vcs": [".git", ".svn", ".hg", ".bzr"]
}
```

### 2. Subscription-Level Exclusions

Beyond the `.watchmanconfig`, Poltergeist also applies exclusions at the subscription level for additional performance:

```javascript
// Example subscription with exclusions
const subscription = {
  expression: [
    'allof',
    ['match', 'Apps/CLI/**/*.swift', 'wholename'],
    ['not', ['match', '**/.build/**', 'wholename']],
    ['not', ['match', '**/DerivedData/**', 'wholename']],
    ['not', ['match', '**/node_modules/**', 'wholename']],
    // ... more exclusions
  ]
}
```

### 3. Smart Updates

The system intelligently updates the `.watchmanconfig` file when:
- Poltergeist starts and detects configuration changes
- New exclusions are added to the configuration
- Default exclusions are enabled/disabled

## Benefits

### Performance Improvements

- **Reduced Watchman CPU usage**: Fewer files to monitor
- **Faster startup**: Less initial filesystem crawling
- **Fewer "UserDropped" events**: Prevents Watchman recrawling cycles
- **Lower memory usage**: Smaller file tree in memory

### Stability Improvements

- **Prevents build loops**: Excludes generated files that could trigger rebuilds
- **Avoids temporary files**: Excludes IDE and OS temporary files
- **Reduces false positives**: Filters out non-source file changes

## Usage Examples

### Basic Usage (Default exclusions only)

```json
{
  "watchman": {
    "useDefaultExclusions": true
  }
}
```

### Custom Exclusions Only

```json
{
  "watchman": {
    "useDefaultExclusions": false,
    "excludeDirs": [
      ".git",
      "node_modules", 
      "my_custom_cache"
    ]
  }
}
```

### Combined Approach (Recommended)

```json
{
  "watchman": {
    "useDefaultExclusions": true,
    "excludeDirs": [
      "project_specific_cache",
      "generated_docs",
      "*.tmp"
    ]
  }
}
```

## Migration

### Existing Projects

If you have an existing `.watchmanconfig` file:

1. **Backup your existing config**: `cp .watchmanconfig .watchmanconfig.backup`
2. **Poltergeist will merge settings**: Your custom settings will be preserved
3. **Review generated config**: Check `.watchmanconfig` after first run
4. **Adjust as needed**: Add any missing exclusions to `poltergeist.config.json`

### No Configuration Required

If you don't specify any `watchman` configuration, Poltergeist will:
- Use all default exclusions (`useDefaultExclusions: true`)
- Create a comprehensive `.watchmanconfig` automatically
- Apply exclusions to all file watching subscriptions

## Debugging

### Exclusion Summary Logging

Poltergeist logs exclusion information on startup:

```
👻 Watchman Exclusion Summary:
  • Default exclusions: enabled (70 patterns)
  • Custom exclusions: 4 patterns  
  • Total exclusions: 74 patterns
✅ Updated .watchmanconfig with 74 exclusions
```

### Debug Logging

Enable debug logging to see detailed exclusion processing:

```json
{
  "logging": {
    "level": "debug"
  }
}
```

Debug logs will show:
- Pattern fixing and normalization
- Exclusion expression creation
- `.watchmanconfig` updates
- Subscription creation with exclusions

## Troubleshooting

### Common Issues

**Problem**: Poltergeist still detecting changes in excluded directories
**Solution**: Check that the directory pattern matches exactly. Use glob patterns like `**/dirname/**` for recursive exclusion.

**Problem**: Build still slow despite exclusions
**Solution**: 
1. Check Watchman logs: `watchman --log-level=2 watch-project .`
2. Verify exclusions with: `cat .watchmanconfig`
3. Add more specific exclusions to your config

**Problem**: Missing file changes after adding exclusions
**Solution**: Ensure you haven't excluded legitimate source directories. Review your `excludeDirs` configuration.

### Manual Watchman Reset

If Watchman gets into a bad state:

```bash
# Stop Poltergeist
npm run poltergeist:stop

# Reset Watchman
watchman watch-del /path/to/your/project
watchman watch-project /path/to/your/project

# Restart Poltergeist  
npm run poltergeist:haunt
```

## Implementation Details

### Key Classes

- **`WatchmanConfigManager`**: Manages `.watchmanconfig` generation and exclusion lists
- **`WatchmanClient`**: Enhanced to accept dynamic exclusion expressions
- **`Poltergeist`**: Integrates config manager and applies exclusions to subscriptions

### File Structure

```
poltergeist/
├── src/
│   ├── watchman-config.ts    # Exclusion management with project detection
│   ├── watchman.ts           # Enhanced: Dynamic exclusions
│   ├── poltergeist.ts        # Enhanced: Config integration
│   ├── config-migration.ts   # Configuration migration system
│   └── types.ts              # Enhanced: Config types
```

### Configuration Schema

```typescript
interface PoltergeistConfig {
  version: string;
  projectType: ProjectType; // 'swift' | 'node' | 'rust' | 'python' | 'mixed'
  targets: Target[];
  watchman: WatchmanConfig;
  performance?: PerformanceConfig;
  notifications?: NotificationConfig;
  logging?: LoggingConfig;
}

interface WatchmanConfig {
  useDefaultExclusions: boolean;
  excludeDirs: string[];
  projectType: ProjectType;
  maxFileEvents: number;
  recrawlThreshold: number;
  settlingDelay: number;
  rules?: ExclusionRule[];
}
```

## Advanced Features

- **Project Type Detection**: Automatically detects Swift, Node.js, Rust, Python, or mixed projects
- **Performance Profiles**: Conservative, balanced, or aggressive exclusion strategies
- **Pattern Validation**: Strict validation with helpful error messages
- **Configuration Migration**: Automatic migration from legacy configurations
- **Template Configs**: Predefined configurations for different project types
- **Smart Optimization**: Intelligent exclusion suggestions based on project analysis