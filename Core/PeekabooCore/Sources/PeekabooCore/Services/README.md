# Services Layer

The Services layer provides high-level functionality through well-defined interfaces. Each service encapsulates a specific domain of functionality and can be easily mocked for testing.

## Architecture

Services are organized by domain:
- **System** - OS-level operations (apps, processes, files)
- **UI** - User interface automation and interaction
- **Capture** - Screen capture and visual analysis
- **Agent** - AI-powered automation
- **Support** - Cross-cutting concerns (logging, sessions)

## Service Container

The `PeekabooServices` class in `Support/` acts as a dependency injection container:

```swift
let services = PeekabooServices()
let screenshot = try await services.screenCapture.captureScreen()
```

## Domain Overview

### 🖥️ System Services
Low-level system operations:
- **ApplicationService** - Launch apps, list running apps, activate windows
- **ProcessService** - Process management and monitoring
- **FileService** - File operations, screenshot saving

### 🎯 UI Services
User interface automation:
- **UIAutomationService** - Click, type, scroll, keyboard shortcuts
- **UIAutomationServiceEnhanced** - Advanced element detection
- **WindowManagementService** - Window positioning, focus, listing
- **MenuService** - Menu bar interaction
- **DialogService** - Alert and dialog handling
- **DockService** - Dock interaction

### 📸 Capture Services
Visual capture and analysis:
- **ScreenCaptureService** - Screenshots with AI-powered element detection

### 👻 Agent Services
AI-powered automation:
- **PeekabooAgentService** - Natural language task execution
- **Tools/** - Modular tool implementations

### 🔧 Support Services
Infrastructure and utilities:
- **LoggingService** - Centralized, structured logging
- **SessionManager** - Conversation persistence
- **PeekabooServices** - Service container and initialization

## Protocol-Driven Design

Each service has a corresponding protocol in `Core/Protocols/`:

```swift
public protocol ApplicationServiceProtocol {
    func listApplications() async throws -> [ApplicationInfo]
    func launchApplication(name: String) async throws -> String
    func activateApplication(bundleID: String) async throws
}
```

This enables:
- Easy mocking for tests
- Alternative implementations
- Clear API contracts
- Dependency injection

## Adding a New Service

1. Define protocol in `Core/Protocols/YourServiceProtocol.swift`
2. Implement service in appropriate domain folder
3. Add to `PeekabooServices` container
4. Write comprehensive tests
5. Document public API

## Best Practices

### Error Handling
- Use typed `PeekabooError` cases
- Include context in errors
- Provide recovery suggestions

### Async/Await
- All I/O operations should be async
- Use structured concurrency
- Handle cancellation properly

### Logging
- Log significant operations
- Use appropriate log levels
- Include correlation IDs

### Testing
- Write unit tests for business logic
- Use protocol mocks for dependencies
- Test error conditions

## Service Guidelines

1. **Single Responsibility** - Each service should have one clear purpose
2. **Protocol First** - Define the interface before implementation
3. **Stateless** - Services should be stateless when possible
4. **Thread-Safe** - Use actors or synchronization for shared state
5. **Documented** - Every public method needs documentation
