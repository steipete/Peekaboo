---
summary: 'Review Poltergeist Generic Target System - Implementation Summary guidance'
read_when:
  - 'planning work related to poltergeist generic target system - implementation summary'
  - 'debugging or extending features described here'
---

# Poltergeist Generic Target System - Implementation Summary

## Files Created in Poltergeist Repository

### Core Implementation
1. `src/types-new.ts` - New type definitions with generic target system
2. `src/config-new.ts` - Configuration parser with old format detection
3. `src/cli-new.ts` - Updated CLI with --target flag
4. `src/poltergeist-new.ts` - Core watch logic for multiple targets
5. `src/logger-new.ts` - Enhanced logger with target-specific output
6. `src/watchman-new.ts` - Updated Watchman client
7. `src/lock.ts` - File locking mechanism

### Builders
8. `src/builders/base-builder.ts` - Base class for all builders
9. `src/builders/executable-builder.ts` - Builder for CLI tools
10. `src/builders/app-bundle-builder.ts` - Builder for macOS/iOS apps
11. `src/builders/index.ts` - Builder factory

### Testing
12. `test/fixtures/test-config.json` - Example new format config
13. `test/fixtures/old-config.json` - Old format for testing errors
14. `test/config-migration.test.ts` - Basic migration tests

### Documentation
15. `MIGRATION.md` - Detailed migration guide
16. `README-new.md` - Updated README with new examples

### Scripts
17. `scripts/migrate-to-generic-targets.sh` - Automated migration script

## Files Updated in Peekaboo

1. `poltergeist.config.json` - Converted to new format with targets array
2. `README.md` - Updated reference to Poltergeist repository
3. `CLAUDE.md` - Updated reference to Poltergeist repository
4. Removed `docs/poltergeist.md` - Outdated documentation
5. Moved `README-poltergeist.md` to Poltergeist repository

## Key Changes

### Configuration Format
- Old: Separate `cli` and `macApp` sections
- New: Unified `targets` array with flexible types

### CLI Commands
- Old: `--cli` and `--mac` flags
- New: `--target <name>` flag
- Added: `poltergeist list` command

### Benefits
- Support for unlimited targets
- Extensible target types
- Better naming with descriptive target names
- Optimized file watching
- Per-target logging and status

## Next Steps

1. Run migration script in Poltergeist repo
2. Build and test
3. Bump major version (breaking change)
4. Publish to npm
5. Update Peekaboo's package.json to use npm version:
   ```json
   "poltergeist:start": "npx @steipete/poltergeist haunt"
   ```