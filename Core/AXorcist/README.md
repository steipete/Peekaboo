# AXorcist: The power of Swift compels your UI to obey! 🧙‍♂️

<p align="center">
  <img src="assets/logo.png" alt="AXorcist Logo">
</p>

<p align="center">
  <strong>Swift wrapper for macOS Accessibility—chainable, fuzzy-matched queries<br>that read, click, and inspect any UI. The dark arts meet modern Swift!</strong>
</p>

---

**AXorcist** harnesses the supernatural powers of macOS Accessibility APIs to give you mystical control over any application's interface. Whether you're automating workflows, testing applications, or building assistive technologies, AXorcist provides the incantations you need to make UI elements bend to your will.

## Overview

AXorcist enables developers to create sophisticated automation tools, testing frameworks, and accessibility utilities by providing:

- **Type-safe API**: Compile-time safety for accessibility attributes and operations
- **Modern Swift Patterns**: Async/await, structured concurrency, and error handling
- **Comprehensive Command System**: Query, action, observation, and batch operations
- **Element Management**: Efficient UI element discovery and interaction
- **Permission Handling**: Streamlined accessibility permission workflows

---

*This document provides a comprehensive overview of all AXorcist classes and their usage patterns. For interactive API documentation, run `../view-docs.sh` to open the DocC archives.*

## Core Classes Reference

### AXorcist (Main Class)

The central orchestrator for all accessibility operations.

```swift
@MainActor
public class AXorcist {
    static let shared = AXorcist()
    public func runCommand(_ commandEnvelope: AXCommandEnvelope) -> AXResponse
}
```

**Key Features:**
- Singleton pattern for consistent state management
- Command-based architecture for all operations
- MainActor isolation for thread safety
- Comprehensive error handling

**Usage Example:**
```swift
import AXorcist

let axorcist = AXorcist.shared
let command = AXCommandEnvelope(
    commandID: "find-button",
    command: .query(QueryCommand(appName: "Safari", searchCriteria: [.role(.button)]))
)
let response = axorcist.runCommand(command)
```

### Element

Swift wrapper around `AXUIElement` providing modern API patterns.

```swift
public struct Element: Equatable, Hashable {
    public let underlyingElement: AXUIElement
    public var attributes: [String: AnyCodable]?
    public var prefetchedChildren: [Element]?
    public var actions: [String]?
}
```

**Key Features:**
- Type-safe property access with computed properties
- Automatic value conversion between CF and Swift types
- Hierarchy navigation with caching support
- Action execution with error handling
- Batch attribute fetching for performance

**Common Operations:**
```swift
// Create element wrapper
let element = Element(axUIElement)

// Access properties safely
let title = element.title
let role = element.role
let isEnabled = element.isEnabled

// Perform actions
try element.performAction(.press)
try element.setValue("Hello World")

// Navigate hierarchy
let children = element.children()
let parent = element.parent()
```

### AXPermissionHelpers

Modern async/await API for accessibility permissions.

```swift
public struct AXPermissionHelpers {
    static func hasAccessibilityPermissions() -> Bool
    static func requestPermissions() async -> Bool
    static func permissionChanges(interval: TimeInterval = 1.0) -> AsyncStream<Bool>
    static func isSandboxed() -> Bool
}
```

**Key Features:**
- Async/await permission handling
- Real-time permission monitoring with AsyncStream
- Sandbox detection for permission strategy
- Non-blocking permission requests

**Usage Patterns:**
```swift
// Check current status
let hasPermissions = AXPermissionHelpers.hasAccessibilityPermissions()

// Request permissions asynchronously
let granted = await AXPermissionHelpers.requestPermissions()

// Monitor permission changes
for await hasPermissions in AXPermissionHelpers.permissionChanges() {
    if hasPermissions {
        print("Permissions granted!")
        // Enable accessibility features
    } else {
        print("Permissions revoked!")
        // Disable accessibility features
    }
}
```

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Element Search and Matching](#element-search-and-matching)
- [Available Commands](#available-commands)
- [Actions](#actions)
- [Notifications and Observing](#notifications-and-observing)
- [Command-Line Usage](#command-line-usage)
- [Advanced Examples](#advanced-examples)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)

## Features

- 🔍 **Powerful Search**: Find UI elements using multiple criteria with flexible matching
- 🎯 **Precise Navigation**: Navigate UI hierarchies with path-based locators
- 🎬 **Actions**: Perform clicks, set values, and trigger UI interactions
- 👁️ **Observation**: Monitor UI changes in real-time with notifications
- 🚀 **Batch Operations**: Execute multiple commands efficiently
- 📊 **Rich Attributes**: Access all accessibility attributes and computed properties
- 🔧 **CLI Tool**: Full command-line interface for scripting and automation
- 📝 **Comprehensive Logging**: Debug support with detailed operation logs

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AXorcist.git", from: "1.0.0")
]
```

### Command Line Tool

Build and install the CLI tool:

```bash
swift build -c release
cp .build/release/axorc /usr/local/bin/
```

## Quick Start

### Swift API

```swift
import AXorcist

// Initialize AXorcist
let axorcist = AXorcist()

// Create a query command
let query = QueryCommand(
    appIdentifier: "com.apple.TextEdit",
    locator: AXLocator(criteria: [
        AXCriterion(attribute: "AXRole", value: "AXTextArea")
    ]),
    attributesToReturn: ["AXValue", "AXRole"]
)

// Execute the command
let response = axorcist.runCommand(AXCommandEnvelope(
    commandID: "query-1",
    command: .query(query)
))
```

### Command Line

```bash
# Find all buttons in Safari
echo '{"command": "query", "application": "com.apple.Safari", "locator": {"criteria": [{"attribute": "AXRole", "value": "AXButton"}]}}' | axorc --stdin

# Click the Back button
echo '{"command": "performAction", "application": "Safari", "locator": {"criteria": [{"attribute": "AXTitle", "value": "Back"}]}, "action": "AXPress"}' | axorc --stdin
```

## Element Search and Matching

### Matching Types

AXorcist supports multiple matching strategies:

- **`exact`** - Exact string match (default)
- **`contains`** - Case-insensitive substring match
- **`regex`** - Regular expression match
- **`containsAny`** - Matches if any comma-separated value is contained
- **`prefix`** - String starts with the expected value
- **`suffix`** - String ends with the expected value

### Searchable Attributes

#### Core Attributes
- `role` / `AXRole` - Element's role (e.g., "AXButton", "AXWindow")
- `subrole` / `AXSubrole` - Additional role information
- `identifier` / `id` / `AXIdentifier` - Developer-assigned unique ID
- `title` / `AXTitle` - Element's title
- `value` / `AXValue` - Element's value
- `description` / `AXDescription` - Detailed description
- `help` / `AXHelp` - Tooltip/help text
- `placeholder` / `AXPlaceholderValue` - Placeholder text

#### State Attributes
- `enabled` / `AXEnabled` - Is element enabled?
- `focused` / `AXFocused` - Is element focused?
- `hidden` / `AXHidden` - Is element hidden?
- `busy` / `AXElementBusy` - Is element busy?

#### Special Attributes
- `pid` - Process ID (exact match only)
- `domclasslist` / `AXDOMClassList` - Web element classes
- `domid` / `AXDOMIdentifier` - DOM element ID
- `computedname` / `name` - Computed accessible name

### Search Examples

#### Find button by exact title
```json
{
  "criteria": [
    {"attribute": "role", "value": "AXButton"},
    {"attribute": "title", "value": "Submit"}
  ]
}
```

#### Find text field containing "email"
```json
{
  "criteria": [
    {"attribute": "role", "value": "AXTextField"},
    {"attribute": "title", "value": "email", "match_type": "contains"}
  ]
}
```

#### Find element by multiple classes (web content)
```json
{
  "criteria": [
    {"attribute": "domclasslist", "value": "btn-primary", "match_type": "contains"}
  ]
}
```

#### Using OR logic
```json
{
  "criteria": [
    {"attribute": "title", "value": "Save"},
    {"attribute": "title", "value": "Submit"},
    {"attribute": "title", "value": "OK"}
  ],
  "matchAll": false
}
```

### Path Navigation

Navigate through UI hierarchies with path hints:

```json
{
  "path_from_root": [
    {"attribute": "role", "value": "AXWindow", "depth": 1},
    {"attribute": "identifier", "value": "main-content", "depth": 3},
    {"attribute": "role", "value": "AXButton"}
  ]
}
```

Each path component supports:
- `attribute` - What to match
- `value` - Expected value
- `depth` - Max search depth for this step (default: 3)
- `match_type` - How to match (default: exact)

## Available Commands

### 1. Query
Find elements and retrieve their attributes.

```json
{
  "command": "query",
  "application": "com.apple.TextEdit",
  "locator": {
    "criteria": [{"attribute": "AXRole", "value": "AXTextArea"}]
  },
  "attributes": ["AXValue", "AXRole", "AXTitle"],
  "maxDepthForSearch": 10
}
```

### 2. Perform Action
Execute actions on elements.

```json
{
  "command": "performAction",
  "application": "Safari",
  "locator": {
    "criteria": [{"attribute": "AXTitle", "value": "Back"}]
  },
  "action": "AXPress"
}
```

### 3. Get Focused Element
Retrieve the currently focused element.

```json
{
  "command": "getFocusedElement",
  "application": "focused",
  "attributes": ["AXRole", "AXTitle", "AXValue"]
}
```

### 4. Get Element at Point
Find element at specific screen coordinates.

```json
{
  "command": "getElementAtPoint",
  "xCoordinate": 500,
  "yCoordinate": 300,
  "attributes": ["AXRole", "AXTitle"]
}
```

### 5. Batch Commands
Execute multiple commands in sequence.

```json
{
  "command": "batch",
  "commands": [
    {
      "command": "query",
      "application": "TextEdit",
      "locator": {"criteria": [{"attribute": "AXRole", "value": "AXTextArea"}]}
    },
    {
      "command": "performAction",
      "application": "TextEdit",
      "locator": {"criteria": [{"attribute": "AXRole", "value": "AXTextArea"}]},
      "action": "AXSetValue",
      "actionValue": "Hello, World!"
    }
  ]
}
```

### 6. Observe Notifications
Monitor UI changes in real-time.

```json
{
  "command": "observe",
  "application": "com.apple.TextEdit",
  "notifications": ["AXValueChanged", "AXFocusedUIElementChanged"],
  "includeDetails": true,
  "watchChildren": false
}
```

### 7. Collect All
Recursively collect all elements.

```json
{
  "command": "collectAll",
  "application": "Safari",
  "attributes": ["AXRole", "AXTitle"],
  "maxDepth": 5,
  "filterCriteria": [{"attribute": "AXRole", "value": "AXButton"}]
}
```

## Actions

Available actions to perform on elements:

- **AXPress** - Click/activate an element
- **AXIncrement** - Increment value (sliders, steppers)
- **AXDecrement** - Decrement value
- **AXConfirm** - Confirm action
- **AXCancel** - Cancel action
- **AXShowMenu** - Show context menu
- **AXPick** - Pick/select element
- **AXRaise** - Bring element to front
- **AXSetValue** - Set value (for text fields)

### Setting Text Values

```json
{
  "command": "performAction",
  "application": "TextEdit",
  "locator": {"criteria": [{"attribute": "AXRole", "value": "AXTextArea"}]},
  "action": "AXSetValue",
  "actionValue": "New text content"
}
```

## Notifications and Observing

Monitor UI changes with these notifications:

- **AXFocusedUIElementChanged** - Focus changes
- **AXValueChanged** - Value changes
- **AXUIElementDestroyed** - Element destruction
- **AXWindowCreated** - Window creation
- **AXWindowResized** - Window resizing
- **AXTitleChanged** - Title changes
- **AXSelectedTextChanged** - Text selection changes
- **AXLayoutChanged** - Layout updates

### Observer Example

```json
{
  "command": "observe",
  "application": "TextEdit",
  "notifications": ["AXValueChanged", "AXFocusedUIElementChanged"],
  "locator": {"criteria": [{"attribute": "AXRole", "value": "AXTextArea"}]},
  "includeDetails": true
}
```

## Command-Line Usage

### Basic Usage

```bash
# Run command from file
axorc --file command.json

# Run command from stdin
echo '{"command": "ping"}' | axorc --stdin

# Pretty print output
axorc --file command.json --pretty

# Include debug logging
axorc --file command.json --debug
```

### Advanced CLI Examples

```bash
# Find all enabled buttons
echo '{
  "command": "query",
  "application": "Safari",
  "locator": {
    "criteria": [
      {"attribute": "AXRole", "value": "AXButton"},
      {"attribute": "AXEnabled", "value": "true"}
    ]
  }
}' | axorc --stdin --pretty

# Click button using path navigation
echo '{
  "command": "performAction",
  "application": "com.apple.Safari",
  "locator": {
    "path_from_root": [
      {"attribute": "AXRole", "value": "AXWindow"},
      {"attribute": "AXIdentifier", "value": "toolbar"}
    ],
    "criteria": [{"attribute": "AXTitle", "value": "Back"}]
  },
  "action": "AXPress"
}' | axorc --stdin
```

## Advanced Examples

### Complex Search with Path Navigation

```json
{
  "command": "query",
  "application": "com.apple.Safari",
  "locator": {
    "path_from_root": [
      {"attribute": "AXRole", "value": "AXWindow", "depth": 1},
      {"attribute": "AXRole", "value": "AXWebArea", "depth": 5}
    ],
    "criteria": [
      {"attribute": "AXRole", "value": "AXButton"},
      {"attribute": "AXDOMClassList", "value": "submit-button primary", "match_type": "contains"}
    ]
  },
  "attributes": ["AXTitle", "AXValue", "AXEnabled", "AXPosition", "AXSize"]
}
```

### Automated Form Filling

```json
{
  "command": "batch",
  "commands": [
    {
      "command": "performAction",
      "application": "Safari",
      "locator": {
        "criteria": [
          {"attribute": "AXRole", "value": "AXTextField"},
          {"attribute": "AXPlaceholderValue", "value": "Email", "match_type": "contains"}
        ]
      },
      "action": "AXSetValue",
      "actionValue": "user@example.com"
    },
    {
      "command": "performAction",
      "application": "Safari",
      "locator": {
        "criteria": [
          {"attribute": "AXRole", "value": "AXTextField"},
          {"attribute": "AXPlaceholderValue", "value": "Password", "match_type": "contains"}
        ]
      },
      "action": "AXSetValue",
      "actionValue": "secretpassword"
    },
    {
      "command": "performAction",
      "application": "Safari",
      "locator": {
        "criteria": [
          {"attribute": "AXRole", "value": "AXButton"},
          {"attribute": "AXTitle", "value": "Sign In", "match_type": "contains"}
        ]
      },
      "action": "AXPress"
    }
  ]
}
```

### Monitoring Text Changes

```json
{
  "command": "observe",
  "application": "com.apple.TextEdit",
  "notifications": ["AXValueChanged", "AXSelectedTextChanged"],
  "locator": {
    "criteria": [{"attribute": "AXRole", "value": "AXTextArea"}]
  },
  "includeDetails": true,
  "watchChildren": true
}
```

## Architecture

### Core Components

- **AXorcist** - Main orchestrator class
- **Element** - Wrapper around AXUIElement with convenience methods
- **ElementSearch** - Tree traversal and matching engine
- **AXElementMatcher** - Criteria matching logic
- **PathNavigator** - Hierarchical navigation
- **AXObserverCenter** - Notification management

### Thread Safety

All operations are MainActor-isolated for thread safety when interacting with the Accessibility API.

### Performance Optimizations

- Early termination on first match
- Depth-limited searches
- Efficient tree traversal with visitor pattern
- Caching of frequently accessed attributes

## Troubleshooting

### Permission Issues

Ensure your app has accessibility permissions:

```json
{
  "command": "isProcessTrusted"
}
```

### Finding Elements

Use the debug flag to see detailed search logs:

```bash
axorc --file command.json --debug
```

### Common Issues

1. **Element not found**: Try broader criteria or increase search depth
2. **Action failed**: Ensure element is enabled and supports the action
3. **Observer not working**: Check notification names and app identifier

### Debug Mode

Enable debug logging in commands:

```json
{
  "command": "query",
  "debugLogging": true,
  ...
}
```

## License

[Add your license information here]

## Contributing

[Add contribution guidelines here]