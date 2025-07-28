# Swift 6 Migration Guide (Reduced)

## Overview

Swift 6 introduces compile-time data race safety. The Swift 6 language mode is opt-in and can be adopted on a per-target basis. This guide focuses on practical migration strategies.

## Key Concepts

### Data Isolation

Swift uses isolation domains to protect mutable state:
1. **Non-isolated** - Default, no access to actor-isolated state
2. **Actor-isolated** - Protected by specific actor instance
3. **Global actor-isolated** - Protected by global actors like `@MainActor`

### Sendable Protocol

Types that can safely cross isolation boundaries must be `Sendable`:
- Value types with all `Sendable` properties are implicitly `Sendable`
- Reference types need explicit conformance with constraints
- Actors and global-actor-isolated types are implicitly `Sendable`

## Migration Strategy

### 1. Enable Complete Checking (Swift 5 Mode)

Start with warnings before switching to Swift 6:

```swift
// Package.swift
.target(
  name: "MyTarget",
  swiftSettings: [
    .enableUpcomingFeature("StrictConcurrency")
  ]
)
```

Or via command line:
```bash
swift build -Xswiftc -strict-concurrency=complete
```

### 2. Address Common Issues

#### Global Variables

```swift
// Problem
var supportedStyleCount = 42

// Solutions:
// 1. Make immutable
let supportedStyleCount = 42

// 2. Add isolation
@MainActor var supportedStyleCount = 42

// 3. Use nonisolated(unsafe) with external synchronization
nonisolated(unsafe) var supportedStyleCount = 42
```

#### Non-Sendable Types

```swift
// Problem
public struct ColorComponents {
    public let red: Float
    public let green: Float
    public let blue: Float
}

// Solution: Add explicit conformance
public struct ColorComponents: Sendable {
    public let red: Float
    public let green: Float
    public let blue: Float
}
```

#### Protocol Conformance Mismatches

```swift
// Problem
protocol Styler {
    func applyStyle()
}

@MainActor
class WindowStyler: Styler {
    func applyStyle() { } // Error: isolation mismatch
}

// Solutions:
// 1. Isolate protocol
@MainActor
protocol Styler {
    func applyStyle()
}

// 2. Make requirement async
protocol Styler {
    func applyStyle() async
}

// 3. Use nonisolated
@MainActor
class WindowStyler: Styler {
    nonisolated func applyStyle() { }
}
```

### 3. Enable Swift 6 Mode

```swift
// swift-tools-version: 6.0

let package = Package(
    name: "MyPackage",
    targets: [
        .target(name: "FullyMigrated"),
        .target(
            name: "NotReady",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
```

## Practical Tips

### Crossing Isolation Boundaries

```swift
// Use sending parameters
func populate(island: Island, with chicken: sending Chicken) async {
    await island.adopt(chicken)
}

// Or use @Sendable closures
func updateStyle(backgroundColorProvider: @Sendable () -> ColorComponents) async {
    await applyBackground(using: backgroundColorProvider)
}
```

### Non-Isolated Init/Deinit

```swift
@MainActor
class WindowStyler {
    nonisolated init(name: String) {
        self.primaryStyleName = name
    }
    
    deinit {
        Task { [store] in
            await store.stopNotifications()
        }
    }
}
```

### Incremental Adoption

Use `@preconcurrency` to suppress warnings temporarily:

```swift
@preconcurrency import UnmigratedModule

@MainActor
class WindowStyler: @preconcurrency Styler {
    func applyStyle() { }
}
```

## Quick Reference

### Compiler Flags
- `-strict-concurrency=complete` - Enable all checks as warnings
- `-swift-version 6` - Enable Swift 6 language mode

### Common Attributes
- `@MainActor` - Isolate to main thread
- `@Sendable` - Mark closure as safe to pass across boundaries
- `sending` - Parameter can safely cross isolation boundaries
- `nonisolated` - Opt out of actor isolation
- `nonisolated(unsafe)` - Disable isolation checking (use carefully)
- `@unchecked Sendable` - Manual thread-safety guarantee

### Migration Checklist
1. ✓ Enable complete checking in Swift 5 mode
2. ✓ Fix global variables (make immutable or add isolation)
3. ✓ Add Sendable conformances to public types
4. ✓ Resolve protocol isolation mismatches
5. ✓ Handle non-isolated init/deinit issues
6. ✓ Switch to Swift 6 language mode

## Key Principles

1. **Express what is true now** - Don't refactor during migration
2. **Start from the outside** - Begin with leaf modules
3. **Use warnings first** - Stay in Swift 5 mode initially
4. **Iterate** - Small changes can have big impacts

Remember: The goal is data race safety, not perfection. Use `@preconcurrency` and `nonisolated(unsafe)` pragmatically during migration, then refactor for better safety later.