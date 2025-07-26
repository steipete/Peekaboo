# Peekaboo GUI Tests

This test suite uses Swift Testing (introduced in Xcode 16) to test the Peekaboo menu bar application.

## Running Tests

### In Xcode
1. Open `Peekaboo.xcodeproj`
2. Press `Cmd+U` to run all tests
3. Or use the Test Navigator (`Cmd+6`) to run specific tests

### From Command Line
```bash
# Run all tests
swift test

# Run tests with specific tags
swift test --filter .unit
swift test --filter .services
swift test --skip .slow

# Run tests in parallel (default)
swift test

# Run tests serially
swift test --parallel=off
```

## Test Organization

Tests are organized by component:

### Services (`Services/`)
- `SessionServiceTests` - Session management and persistence
- `SettingsServiceTests` - User preferences and API configuration
- `PermissionServiceTests` - System permission handling
- `AgentServiceTests` - AI agent execution logic

### Models (`Models/`)
- `SessionTests` - Session data model and serialization

### Views (`Views/`)
- `MainViewTests` - Main UI component logic

### Agent (`Agent/`)
- `OpenAIAgentTests` - OpenAI API integration
- `PeekabooToolExecutorTests` - CLI tool execution

### Controllers (`Controllers/`)
- `StatusBarControllerTests` - Menu bar functionality

## Test Tags

Tests are tagged for easy filtering:

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

## Writing New Tests

Follow these patterns when adding tests:

```swift
import Testing
@testable import Peekaboo

@Suite("Component Tests", .tags(.unit, .fast))
struct ComponentTests {
    // Setup in init() if needed
    init() {
        // Setup code
    }
    
    @Test("Descriptive test name")
    func testFeature() {
        // Arrange
        let sut = Component()
        
        // Act
        let result = sut.performAction()
        
        // Assert
        #expect(result == expectedValue)
    }
    
    @Test("Parameterized test", arguments: [
        (input: 1, expected: 2),
        (input: 2, expected: 4),
        (input: 3, expected: 6)
    ])
    func testWithParameters(input: Int, expected: Int) {
        #expect(input * 2 == expected)
    }
}
```

## Best Practices

1. **Use `#expect` for most assertions** - Only use `#require` for critical preconditions
2. **Tag tests appropriately** - This helps with test filtering and CI configuration
3. **Keep tests fast** - Mock external dependencies when possible
4. **Test one thing** - Each test should verify a single behavior
5. **Use descriptive names** - Test names should explain what they verify
6. **Avoid shared state** - Each test gets a fresh instance of the test suite

## Continuous Integration

Tests are configured to run in CI with:
- Parallel execution enabled
- Network tests skipped in offline environments
- Integration tests run only when dependencies are available