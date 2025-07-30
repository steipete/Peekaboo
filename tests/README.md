# Peekaboo Test Suite

## Overview

The Peekaboo test suite is organized into two categories:

1. **Safe Tests (Default)** - Read-only operations that don't modify the system
2. **Full Tests (Opt-in)** - Interactive operations that can change system state

Tests are designed to be **portable and mockable** when possible, with real system interactions reserved for full test mode.

## Test Structure

```
tests/
├── unit/           # Unit tests for individual components
│   ├── tools/      # Tests for each tool (image, list, analyze)
│   └── utils/      # Tests for utility functions
├── integration/    # Integration tests for tool interactions
└── mocks/          # Mock implementations
```

## Test Categories

### Safe Tests (Default)

These tests only perform read operations and don't interact with the system:

**Tools tested in safe mode:**
- `list` - List apps, windows, permissions (read-only)
- `permissions` - Check system permissions (read-only)
- `analyze` - Analyze existing images (no capture)
- `sleep` - Just waits, no system interaction
- Various validation and edge case tests

### Full Tests (Opt-in Required)

These tests perform system interactions and modifications:

**Interactive Tools [full]:**
- `agent` - Can perform arbitrary system actions
- `click` - Clicks on UI elements
- `type` - Types text into applications
- `scroll` - Scrolls content
- `hotkey` - Presses keyboard shortcuts
- `swipe` - Performs swipe gestures
- `drag` - Drags elements
- `move` - Moves mouse cursor

**Application Control [full]:**
- `app` - Launch, quit, hide, show applications
- `window` - Move, resize, close windows
- `menu` - Click menu items
- `dock` - Interact with dock
- `dialog` - Interact with system dialogs
- `space` - Switch between spaces

**Other Interactive [full]:**
- `run` - Executes automation scripts
- `clean` - Modifies filesystem
- `image` - When actually capturing screens
- `see` - When capturing live screens

## Key Design Decisions

### All Tests Use Mocks

Every test in this suite uses mocked implementations of the Swift CLI. This means:

1. **Cross-platform compatibility** - Tests run on Linux, Windows, and macOS
2. **No permissions required** - No screen recording or system permissions needed
3. **Fast execution** - No actual screen captures or file I/O
4. **Deterministic results** - Tests always produce the same output
5. **CI/CD friendly** - Can run in any continuous integration environment

### What We Test

- **Business Logic** - Tool parameter validation, response formatting
- **Error Handling** - All error scenarios including permissions, timeouts, invalid inputs
- **Integration** - How tools work together and with the MCP protocol
- **Type Safety** - TypeScript types and Zod schema validation
- **Edge Cases** - Long file paths, special characters, concurrent execution

### What We Don't Test

- Actual Swift CLI binary execution
- Real screen capture functionality
- macOS-specific permissions
- Binary file permissions/existence

## Running Tests

### Safe Tests (Default)

```bash
# Run safe tests only (default)
npm test
npm run test:safe

# Run with coverage (safe mode)
npm run test:coverage

# Run in watch mode (safe mode)
npm run test:watch

# Run unit tests only (safe mode)
npm run test:unit
```

### Full Tests (Interactive)

**⚠️ Warning:** Full tests may open applications, click buttons, type text, and perform other system interactions on your Mac.

```bash
# Run all tests including interactive ones
npm run test:full

# Run with coverage (full mode)
npm run test:coverage:full

# Run in watch mode (full mode)
npm run test:watch:full

# Run unit tests only (full mode)
npm run test:unit:full

# Run full integration tests
npm run test:integration:full
```

### Running Specific Tests

```bash
# Run specific test file
npm test -- tests/unit/tools/image.test.ts

# Run tests matching a pattern
npm test -- --grep "list tool"
```

### Test Output

When running safe tests, you'll see:

```
Running Peekaboo tests in SAFE mode
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ 45 safe tests passed
⚠ 23 full tests skipped (interactive/system-modifying)

To run full test suite including interactive tests:
  npm run test:full
```

### Environment Variable

You can also control test mode using the `PEEKABOO_TEST_MODE` environment variable:

```bash
# Run safe tests
PEEKABOO_TEST_MODE=safe npm test

# Run full tests
PEEKABOO_TEST_MODE=full npm test
```

## Coverage Goals

We aim for high test coverage while acknowledging that some code paths (actual Swift CLI execution) cannot be tested in this portable test suite:

- Overall coverage target: >85%
- Critical business logic: >95%
- Error handling paths: 100%

## Future Considerations

For true end-to-end testing that exercises the real Swift CLI, consider creating a separate `e2e` test suite that:

1. Only runs on macOS with proper permissions
2. Is excluded from regular CI runs
3. Tests actual screen capture functionality
4. Validates Swift CLI binary behavior

Example structure:
```
tests/
├── e2e/                    # End-to-end tests (macOS only)
│   ├── real-capture.test.ts
│   └── permissions.test.ts
```

These tests would be run manually or in specialized macOS CI environments.