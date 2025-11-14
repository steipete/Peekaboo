---
summary: 'Review Peekaboo Error Handling Guide guidance'
read_when:
  - 'planning work related to peekaboo error handling guide'
  - 'debugging or extending features described here'
---

# Peekaboo Error Handling Guide

This guide describes the unified error handling system in PeekabooCore, designed to provide consistent, user-friendly error messages across all services.

## Overview

The error handling system consists of three main components:

1. **Standardized Errors** - Consistent error types and codes
2. **Error Formatting** - Unified presentation for CLI, JSON, and logs
3. **Error Recovery** - Automatic retry and graceful degradation

## Error Types

### Standard Error Codes

All errors in Peekaboo use standardized error codes for consistency:

```swift
// Permission errors
case screenRecordingPermissionDenied = "PERMISSION_DENIED_SCREEN_RECORDING"
case accessibilityPermissionDenied = "PERMISSION_DENIED_ACCESSIBILITY"

// Not found errors
case applicationNotFound = "APP_NOT_FOUND"
case windowNotFound = "WINDOW_NOT_FOUND"
case elementNotFound = "ELEMENT_NOT_FOUND"

// Operation errors
case captureFailed = "CAPTURE_FAILED"
case interactionFailed = "INTERACTION_FAILED"
case timeout = "TIMEOUT"
```

### Error Categories

Errors are grouped into categories:
- **Permission**: Access control issues
- **Not Found**: Missing resources
- **Operation**: Execution failures
- **Validation**: Input errors
- **System**: Infrastructure issues
- **AI**: AI provider problems

## Using the Error System

### Creating Errors

Use the predefined error types for consistency:

```swift
// Permission errors
throw PermissionError.screenRecording()
throw PermissionError.accessibility()

// Not found errors
throw NotFoundError.application("Safari")
throw NotFoundError.window(app: "Finder", index: 2)
throw NotFoundError.element("Submit button")

// Operation errors
throw OperationError.captureFailed(reason: "Display disconnected")
throw OperationError.timeout(operation: "screenshot", duration: 30)

// Validation errors
throw ValidationError.invalidInput(field: "coordinates", reason: "Outside screen bounds")
throw ValidationError.ambiguousAppIdentifier("Safari", matches: ["Safari", "Safari Technology Preview"])
```

### Formatting Errors

Use `ErrorFormatter` for consistent presentation:

```swift
// For CLI output
let message = ErrorFormatter.formatForCLI(error, verbose: true)

// For JSON responses
let json = ErrorFormatter.formatForJSON(error)

// For logging
let logMessage = ErrorFormatter.formatForLog(error)

// For multiple errors
let summary = ErrorFormatter.formatMultipleErrors(errors)
```

## Error Recovery

### Retry Policies

Configure automatic retry behavior:

```swift
// Use standard retry policy (3 attempts, exponential backoff)
let result = try await RetryHandler.withRetry {
    try await captureScreen()
}

// Custom retry policy
let policy = RetryPolicy(
    maxAttempts: 5,
    initialDelay: 0.1,
    delayMultiplier: 2.0,
    retryableErrors: [.timeout, .captureFailed]
)

let result = try await RetryHandler.withRetry(policy: policy) {
    try await performOperation()
}
```

### Recovery Suggestions

Errors include recovery suggestions:

```swift
let error = PermissionError.screenRecording()
if let suggestion = error.recoverySuggestion {
    print("Suggestion: \(suggestion)")
    // Output: "Grant Screen Recording permission in System Settings"
}
```

### Graceful Degradation

Handle partial failures:

```swift
let options = DegradationOptions(
    allowPartialResults: true,
    fallbackToDefaults: true,
    skipNonCritical: true
)

// Operations can return degraded results
let result = DegradedResult(
    value: partialData,
    errors: [minorError],
    warnings: ["Some features unavailable"],
    isPartial: true
)
```

## Service Integration

### Example: ScreenCaptureService

```swift
public func captureScreen(displayIndex: Int? = nil) async throws -> CaptureResult {
    // Check permissions
    guard hasScreenRecordingPermission() else {
        throw PermissionError.screenRecording()
    }
    
    // Validate input
    if let index = displayIndex, index < 0 || index >= screenCount {
        throw ValidationError.invalidInput(
            field: "displayIndex",
            reason: "Must be between 0 and \(screenCount - 1)"
        )
    }
    
    // Perform capture with retry
    return try await RetryHandler.withRetry(policy: .standard) {
        guard let image = performCapture() else {
            throw OperationError.captureFailed(
                reason: "Unable to capture display"
            )
        }
        return CaptureResult(image: image)
    }
}
```

## CLI Integration

### Error Output

The CLI automatically formats errors based on output mode:

```bash
# Normal mode - user-friendly message
$ peekaboo capture
Error: Screen Recording permission is required. Please grant permission in System Settings > Privacy & Security > Screen Recording.

Suggestion: Grant Screen Recording permission in System Settings

# Verbose mode - includes context
$ peekaboo capture --verbose
Error: Screen Recording permission is required...

Suggestion: Grant Screen Recording permission in System Settings

Context:
  permission: screen_recording

# JSON mode - structured output
$ peekaboo capture --json-output
{
  "success": false,
  "error": {
    "error_code": "PERMISSION_DENIED_SCREEN_RECORDING",
    "message": "Screen Recording permission is required...",
    "recovery_suggestion": "Grant Screen Recording permission in System Settings",
    "context": {
      "permission": "screen_recording"
    }
  }
}
```

## Best Practices

### 1. Use Standardized Errors
Always use the predefined error types instead of creating custom errors:

```swift
// ✅ Good
throw NotFoundError.application("TextEdit")

// ❌ Avoid
throw NSError(domain: "PeekabooError", code: 404, userInfo: nil)
```

### 2. Provide Context
Include relevant context in errors:

```swift
throw ValidationError.invalidCoordinates(x: 5000, y: 3000)
// Error includes the invalid coordinates in context
```

### 3. Use Appropriate Retry Policies
Choose retry policies based on operation type:

```swift
// Network operations - aggressive retry
RetryPolicy.aggressive

// User interactions - conservative retry
RetryPolicy.conservative

// Critical operations - no retry
RetryPolicy.noRetry
```

### 4. Handle Degraded Results
Design services to continue with partial data when appropriate:

```swift
// Allow partial window list if some windows fail
let windows = await collectWindows(options: .lenient)
if windows.isPartial {
    logger.warning("Some windows could not be accessed")
}
```

## Migration Guide

To migrate existing error handling:

1. Replace custom errors with standardized types
2. Update error formatting to use `ErrorFormatter`
3. Add retry logic where appropriate
4. Implement recovery suggestions

Example migration:

```swift
// Before
throw NSError(domain: "Peekaboo", code: 1, userInfo: [
    NSLocalizedDescriptionKey: "App not found"
])

// After
throw NotFoundError.application(appName)
```

## Testing Errors

Test error handling comprehensively:

```swift
@Test
func testPermissionError() async throws {
    let error = PermissionError.screenRecording()
    
    #expect(error.code == .screenRecordingPermissionDenied)
    #expect(error.userMessage.contains("Screen Recording"))
    #expect(error.recoverySuggestion \!= nil)
    
    let json = ErrorFormatter.formatForJSON(error)
    #expect(json["error_code"] as? String == "PERMISSION_DENIED_SCREEN_RECORDING")
}
```

## Future Enhancements

Planned improvements:
- Localization support for error messages
- Error analytics and reporting
- Advanced recovery strategies
- Error aggregation for batch operations
EOF < /dev/null