# Peekaboo Test Suite

## Overview

The Peekaboo test suite is designed to be **fully portable and runnable on any operating system** without requiring:
- macOS
- Screen recording permissions
- The Swift CLI binary
- Any specific system configuration

## Test Structure

```
tests/
├── unit/           # Unit tests for individual components
│   ├── tools/      # Tests for each tool (image, list, analyze)
│   └── utils/      # Tests for utility functions
├── integration/    # Integration tests for tool interactions
└── mocks/          # Mock implementations
```

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

```bash
# Run all tests
npm test

# Run with coverage
npm run test:coverage

# Run in watch mode
npm run test:watch

# Run specific test file
npm test -- tests/unit/tools/image.test.ts
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