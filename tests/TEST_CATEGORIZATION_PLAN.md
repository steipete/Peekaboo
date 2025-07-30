# Test Categorization Plan: Safe vs Full Test Suites

## Overview

This plan outlines how to separate Peekaboo tests into two distinct categories:
1. **Safe Tests** - Read-only operations that don't modify the system
2. **Full Tests** - Interactive operations that can change system state

## Goals

- Run safe tests by default to avoid unintended system modifications
- Require explicit opt-in for full test suite
- Maintain test coverage while respecting developer's working environment
- Clear documentation and error messages when tests are skipped

## Test Categories

### Safe Tests (Default)

These tests only perform read operations and don't interact with the system:

**Tools:**
- `list` - List apps, windows, permissions (read-only)
- `permissions` - Check system permissions (read-only)
- `analyze` - Analyze existing images (no capture)
- `sleep` - Just waits, no system interaction

**Partial tools (safe operations only):**
- `image` - Only when mocked or using test fixtures
- `see` - Only when mocked or analyzing test images

### Full Tests (Opt-in Required)

These tests perform system interactions and modifications:

**Interactive Tools:**
- `agent` - Can perform arbitrary system actions
- `click` - Clicks on UI elements
- `type` - Types text into applications
- `scroll` - Scrolls content
- `hotkey` - Presses keyboard shortcuts
- `swipe` - Performs swipe gestures
- `drag` - Drags elements
- `move` - Moves mouse cursor

**Application Control:**
- `app` - Launch, quit, hide, show applications
- `window` - Move, resize, close windows
- `menu` - Click menu items
- `dock` - Interact with dock
- `dialog` - Interact with system dialogs
- `space` - Switch between spaces

**Other Interactive:**
- `run` - Executes automation scripts
- `clean` - Modifies filesystem
- `image` - When actually capturing screens
- `see` - When capturing live screens

## Implementation Strategy

### 1. Environment Variable Control

Use `PEEKABOO_TEST_MODE` environment variable:
- `safe` (default) - Only run safe tests
- `full` - Run all tests including interactive ones

### 2. Test Tagging with Vitest

```typescript
// Safe test
describe('list tool [safe]', () => {
  it('should list running applications', () => {
    // Test implementation
  });
});

// Full test
describe.skipIf(process.env.PEEKABOO_TEST_MODE !== 'full')('agent tool [full]', () => {
  it('should execute automation tasks', () => {
    // Test implementation
  });
});
```

### 3. Custom Test Runner Scripts

Update package.json scripts:

```json
{
  "scripts": {
    "test": "PEEKABOO_TEST_MODE=safe vitest run",
    "test:safe": "PEEKABOO_TEST_MODE=safe vitest run",
    "test:full": "PEEKABOO_TEST_MODE=full vitest run",
    "test:full:watch": "PEEKABOO_TEST_MODE=full vitest watch"
  }
}
```

### 4. Test Organization

Maintain current structure but add clear categorization:

```
tests/
├── unit/
│   ├── tools/
│   │   ├── safe/           # Safe tool tests
│   │   │   ├── list.test.ts
│   │   │   ├── permissions.test.ts
│   │   │   └── analyze.test.ts
│   │   └── full/           # Full tool tests
│   │       ├── agent.test.ts
│   │       ├── click.test.ts
│   │       └── app.test.ts
│   └── utils/              # Utility tests (usually safe)
└── integration/
    ├── safe/               # Safe integration tests
    └── full/               # Full integration tests
```

### 5. Clear Messaging

When running safe tests and full tests are skipped:

```
Running Peekaboo tests in SAFE mode
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ 45 safe tests passed
⚠ 23 full tests skipped (interactive/system-modifying)

To run full test suite including interactive tests:
  npm run test:full
  
Warning: Full tests may open applications, click buttons,
and perform other system interactions on your Mac.
```

## Migration Steps

1. **Add test categorization helper** (vitest.setup.ts)
2. **Tag existing tests** with [safe] or [full] markers
3. **Update test runner configuration**
4. **Add documentation** to README
5. **Update CI/CD** to run appropriate test suites

## Special Considerations

### Agent Tests
- **Always marked as [full]** - Agent can do anything
- Add comment: `// Disabled by default - may interact with system`
- Consider creating mock agent tests for safe mode

### Integration Tests
- Most integration tests should be [full]
- Create separate mock-based integration tests for [safe]

### Swift Tests
- Apply same categorization to Swift tests
- Use test tags/categories if available

## Benefits

1. **Developer Safety** - No surprise system interactions
2. **Faster Default Tests** - Safe tests run quickly
3. **Explicit Opt-in** - Clear when running interactive tests
4. **CI/CD Friendly** - Can run safe tests in any environment
5. **Better Test Organization** - Clear separation of concerns