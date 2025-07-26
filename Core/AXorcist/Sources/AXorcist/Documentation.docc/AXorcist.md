# ``AXorcist``

A powerful Swift framework for macOS accessibility automation.

## Overview

AXorcist provides a comprehensive interface for interacting with macOS accessibility APIs. It enables automated testing, UI automation, and accessibility tooling with a modern Swift API.

### Key Features

- **Element Discovery**: Find UI elements using various search criteria
- **Action Execution**: Perform clicks, key presses, and other actions
- **Attribute Access**: Read and modify accessibility attributes
- **Batch Operations**: Execute multiple commands efficiently
- **Permission Management**: Handle accessibility permissions gracefully

### Getting Started

First, ensure your app has accessibility permissions:

```swift
import AXorcist

let hasPermissions = await AXPermissionHelpers.requestPermissions()
if hasPermissions {
    let axorcist = AXorcist.shared
    // Begin accessibility operations
}
```

## Topics

### Essentials

- ``AXorcist``
- ``AXPermissionHelpers``
- ``AXCommandEnvelope``
- ``AXResponse``

### Commands

- ``AXCommand``
- ``AXQueryCommand``
- ``AXActionCommand``
- ``AXGetAttributesCommand``

### Elements

- ``Element``
- ``ElementSearch``
- ``SearchCriteria``

### Utilities

- ``GlobalAXLogger``
- ``AXLogEntry``
- ``ProcessUtils``

### Error Handling

- ``AccessibilityError``
- ``AXError``