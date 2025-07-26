# Local-Only Tests for Peekaboo

This directory contains tests that can only be run locally (not on CI) because they require:
- Screen recording permissions
- Accessibility permissions (optional)
- A graphical environment
- User interaction (for permission dialogs)

## Test Host Application

The `TestHost` directory contains a simple SwiftUI application that serves as a controlled environment for testing screenshots and window management. The test host app:

- Displays permission status
- Shows a known window with identifiable content
- Provides various test patterns for screenshot validation
- Logs test interactions

## Running Local Tests

To run the local-only tests:

```bash
cd peekaboo-cli
./run-local-tests.sh
```

Or manually:

```bash
# Enable local tests
export RUN_LOCAL_TESTS=true

# Run all local-only tests
swift test --filter "localOnly"

# Run specific test categories
swift test --filter "screenshot"
swift test --filter "permissions"
swift test --filter "multiWindow"
```

## Test Categories

### Screenshot Validation Tests (`ScreenshotValidationTests.swift`)
- **Image content validation**: Captures windows with known content and validates the output
- **Visual regression testing**: Compares screenshots to detect visual changes
- **Format testing**: Tests PNG and JPG output formats
- **Multi-display support**: Tests capturing from multiple monitors
- **Performance benchmarks**: Measures screenshot capture performance

### Local Integration Tests (`LocalOnlyTests.swift`)
- **Test host window capture**: Captures the test host application window
- **Full screen capture**: Tests screen capture with test host visible
- **Permission dialog testing**: Tests permission request flows
- **Multi-window scenarios**: Tests capturing multiple windows
- **Focus and foreground testing**: Tests window focus behavior

## Adding New Local Tests

When adding new local-only tests:

1. Tag them with `.localOnly` to ensure they don't run on CI
2. Use the test host app for controlled testing scenarios
3. Clean up any created files/windows in test cleanup
4. Document any special requirements

Example:
```swift
@Test("My new local test", .tags(.localOnly, .screenshot))
func myLocalTest() async throws {
    // Your test code here
}
```

## Permissions

The tests will automatically check for required permissions and attempt to trigger permission dialogs if needed. Grant the following permissions when prompted:

1. **Screen Recording**: Required for all screenshot functionality
2. **Accessibility**: Optional, needed for window focus operations

## CI Considerations

These tests are automatically skipped on CI because:
- The `RUN_LOCAL_TESTS` environment variable is not set
- CI environments typically lack screen recording permissions
- There's no graphical environment for window creation

The `.enabled(if:)` trait ensures these tests only run when explicitly enabled.