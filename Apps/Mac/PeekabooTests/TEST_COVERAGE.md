# Peekaboo Mac App Test Coverage

This document outlines the comprehensive test suite for the Peekaboo Mac application.

## Test Structure

All tests use the Swift Testing framework (introduced in Xcode 16) with `@Test` and `@Suite` attributes.

## Core Test Files

### ✅ Existing Tests

1. **Agent Tests**
   - `OpenAIAgentTests.swift` - OpenAI API integration tests

2. **Controller Tests**
   - `StatusBarControllerTests.swift` - Menu bar functionality tests

3. **Integration Tests**
   - `EndToEndTests.swift` - Full workflow integration tests

4. **Model Tests**
   - `SessionTests.swift` - Session data model and serialization tests

5. **Service Tests**
   - `AgentServiceTests.swift` - AI agent execution logic tests
   - `PermissionServiceTests.swift` - System permission handling tests
   - `SessionServiceTests.swift` - Session management and persistence tests
   - `SettingsServiceTests.swift` - User preferences and API configuration tests

6. **View Tests**
   - `MainViewTests.swift` - Main UI component logic tests

### 🆕 Newly Added Tests

1. **App Tests**
   - `PeekabooAppTests.swift` - Application initialization and lifecycle tests
     - App component initialization
     - System notification registration
     - State restoration
     - Appearance configuration
     - Lifecycle handlers
     - URL scheme handling
     - Dependency injection verification

2. **Service Tests**
   - `PeekabooToolExecutorTests.swift` - Tool execution bridge tests
     - All tool commands (see, click, type, hotkey, list, window)
     - Error handling and recovery
     - Concurrent execution
     - Performance testing

3. **Feature Tests**
   - `Features/OverlayManagerTests.swift` - Overlay system tests
     - Overlay lifecycle management
     - Application filtering modes
     - Detail level settings
     - Element selection and tracking
     - Mouse tracking
     - Performance with multiple windows
     - Thread safety

4. **Core Tests**
   - `Core/DockIconManagerTests.swift` - Dock icon visibility tests
     - Singleton pattern verification
     - Show/hide dock icon
     - Toggle functionality
     - Persistence of preferences
     - Thread safety

   - `Core/SystemPermissionManagerTests.swift` - System permission tests
     - Permission status checks (Screen Recording, Accessibility)
     - Permission requests
     - Combined permission verification
     - Permission caching
     - Thread safety
     - Feature-specific permission requirements

## Test Organization

Tests are organized by component type:
- `Agent/` - AI and agent-related tests
- `Controllers/` - UI controller tests
- `Core/` - Core system component tests
- `Features/` - Feature-specific tests
- `Integration/` - End-to-end tests
- `Models/` - Data model tests
- `Services/` - Service layer tests
- `Views/` - UI view tests

## Test Tags

All tests are tagged for easy filtering:
- `.unit` - Fast, isolated unit tests
- `.integration` - Tests that interact with external systems
- `.ui` - UI-related tests
- `.services` - Service layer tests
- `.models` - Data model tests
- `.fast` - Quick tests (< 1s)
- `.slow` - Slower tests (> 1s)
- `.networking` - Tests requiring network access
- `.ai` - AI/Agent related tests
- `.permissions` - Tests involving system permissions

## Running Tests

### In Xcode
1. Open `Peekaboo.xcodeproj`
2. Press `Cmd+U` to run all tests
3. Use Test Navigator (`Cmd+6`) for specific tests

### From Command Line
```bash
# Run all tests
swift test

# Run specific tag
swift test --filter .unit
swift test --filter .services

# Skip slow tests
swift test --skip .slow
```

### Using the Test Runner Script
```bash
# Run all tests
./run-tests.sh

# Run only unit tests
./run-tests.sh unit

# Run only fast tests
./run-tests.sh fast
```

## Test Coverage Areas

### ✅ Well Covered
- Session management and persistence
- Model serialization
- Service initialization
- Basic UI component testing
- Tool execution
- Permission handling

### 🔄 Partially Covered
- Status bar interactions (limited by private properties)
- Window management
- Real-time agent streaming

### ⚠️ Areas Needing More Tests
- Speech recognition functionality
- Advanced inspector overlay interactions
- Complex agent workflows
- Error recovery scenarios
- Network failure handling

## Best Practices

1. Use `#expect` for most assertions
2. Use `#require` only for critical preconditions
3. Tag tests appropriately for CI filtering
4. Keep tests fast by mocking external dependencies
5. Test one behavior per test function
6. Use descriptive test names
7. Avoid shared mutable state

## Continuous Integration

Tests are configured to run in CI with:
- Parallel execution enabled
- Network tests skipped in offline environments
- Integration tests run only when dependencies are available

## Future Improvements

1. Add performance benchmarks
2. Implement UI testing with XCUITest for visual components
3. Add stress tests for concurrent operations
4. Create mock services for better isolation
5. Add property-based testing for complex data flows
6. Implement snapshot testing for UI components