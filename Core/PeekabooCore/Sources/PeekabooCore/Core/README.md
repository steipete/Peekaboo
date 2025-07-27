# Core Types and Utilities

This directory contains the fundamental types, models, and utilities that form the foundation of PeekabooCore.

## Structure

### 📁 Errors/
Comprehensive error handling system with recovery strategies.

- **PeekabooError.swift** - Central error enumeration covering all error cases
- **ErrorTypes.swift** - Additional error type definitions
- **ErrorFormatting.swift** - Human-readable error formatting
- **ErrorRecovery.swift** - Suggested recovery actions for errors
- **ErrorMigration.swift** - Legacy error type migration
- **StandardizedErrors.swift** - Error standardization utilities

#### Error Philosophy
- Every error should have a clear description
- Include recovery suggestions when possible
- Preserve context (file paths, app names, etc.)
- Support error chaining for debugging

### 📁 Models/
Domain models representing core concepts in Peekaboo.

- **Application.swift** - `ApplicationInfo`, `RunningApplication`
- **Capture.swift** - `CaptureResult`, `DetectedElements`, screen capture data
- **Session.swift** - `SessionInfo`, conversation and automation sessions
- **Window.swift** - `WindowInfo`, `FocusedElementInfo`, UI element data

#### Model Design Principles
- Immutable value types where possible
- Codable for persistence
- Clear, descriptive property names
- Comprehensive documentation

### 📁 Utilities/
Shared utilities and helpers used across the codebase.

- **CorrelationID.swift** - Request tracking for debugging async operations
- **Extensions/** - Swift standard library extensions (future)

## Usage Examples

### Error Handling
```swift
// Creating errors with context
throw PeekabooError.windowNotFound(criteria: "Safari main window")

// Error recovery
catch let error as PeekabooError {
    let recovery = ErrorRecovery.suggestion(for: error)
    print("Error: \(error.localizedDescription)")
    print("Try: \(recovery)")
}
```

### Working with Models
```swift
// Application info
let appInfo = ApplicationInfo(
    name: "Safari",
    bundleIdentifier: "com.apple.Safari",
    processIdentifier: 12345,
    isActive: true
)

// Capture result
let capture = CaptureResult(
    imagePath: "/tmp/screenshot.png",
    width: 1920,
    height: 1080,
    displayID: 1
)
```

### Correlation Tracking
```swift
// Track related operations
let correlationID = CorrelationID.generate()
logger.info("Starting operation", correlationID: correlationID)
// ... perform operations ...
logger.info("Operation complete", correlationID: correlationID)
```

## Adding New Types

When adding new core types:

1. **Errors**: Add to `PeekabooError` enum with descriptive case
2. **Models**: Create in Models/ with Codable conformance
3. **Utilities**: Add to Utilities/ with comprehensive tests

## Design Guidelines

- **Clarity**: Names should clearly express intent
- **Safety**: Use Swift's type system for compile-time safety
- **Performance**: Consider copy costs for large structures
- **Testability**: Design with testing in mind
- **Documentation**: Every public API needs documentation