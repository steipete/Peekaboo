# pblog - Peekaboo Log Viewer

A unified log viewer for all Peekaboo applications and services.

## Quick Start

```bash
# Show recent logs from all Peekaboo subsystems
./scripts/pblog.sh

# Stream logs continuously
./scripts/pblog.sh -f

# Show only errors
./scripts/pblog.sh -e

# Show logs from a specific service
./scripts/pblog.sh -c ElementDetectionService

# Show logs from a specific subsystem
./scripts/pblog.sh --subsystem boo.peekaboo.core
```

## Supported Subsystems

- `boo.peekaboo.core` - Core services (ClickService, ElementDetectionService, etc.)
- `boo.peekaboo.cli` - CLI tool
- `boo.peekaboo.inspector` - Inspector app
- `boo.peekaboo.playground` - Playground test app
- `boo.peekaboo.app` - Main Mac app
- `boo.peekaboo` - Mac app components

## Options

- `-n, --lines NUM` - Number of lines to show (default: 50)
- `-l, --last TIME` - Time range to search (default: 5m)
- `-c, --category CAT` - Filter by category (e.g., ClickService)
- `-s, --search TEXT` - Search for specific text
- `-d, --debug` - Show debug level logs
- `-f, --follow` - Stream logs continuously
- `-e, --errors` - Show only errors
- `--subsystem NAME` - Filter by specific subsystem
- `--json` - Output in JSON format

## Examples

```bash
# Debug element detection issues
./scripts/pblog.sh -c ElementDetectionService -d

# Monitor click operations
./scripts/pblog.sh -c ClickService -f

# Check recent errors
./scripts/pblog.sh -e -l 30m

# Search for specific text
./scripts/pblog.sh -s "Dialog" -n 100

# Monitor Playground app logs
./scripts/pblog.sh --subsystem boo.peekaboo.playground -f
```