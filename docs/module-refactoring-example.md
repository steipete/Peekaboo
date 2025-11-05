# Module Refactoring: Practical Example

## Starting Point: Extract PeekabooModels

Here's a concrete example of how to begin the refactoring with the first module extraction.

### Step 1: Create PeekabooModels Package

```bash
mkdir -p Core/PeekabooModels/Sources/PeekabooModels
mkdir -p Core/PeekabooModels/Tests/PeekabooModelsTests
```

### Step 2: Create Package.swift

```swift
// Core/PeekabooModels/Package.swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PeekabooModels",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "PeekabooModels",
            targets: ["PeekabooModels"]),
    ],
    dependencies: [
        // No dependencies! This is the foundation layer
    ],
    targets: [
        .target(
            name: "PeekabooModels",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]),
        .testTarget(
            name: "PeekabooModelsTests",
            dependencies: ["PeekabooModels"]),
    ],
    swiftLanguageModes: [.v6]
)
```

### Step 3: Move Basic Types

Move these files from PeekabooCore to PeekabooModels:

```swift
// Core/PeekabooModels/Sources/PeekabooModels/WindowInfo.swift
import Foundation

public struct WindowInfo: Codable, Sendable {
    public let id: Int
    public let title: String?
    public let app: String
    public let bounds: CGRect
    public let isMinimized: Bool
    
    public init(id: Int, title: String?, app: String, bounds: CGRect, isMinimized: Bool) {
        self.id = id
        self.title = title
        self.app = app
        self.bounds = bounds
        self.isMinimized = isMinimized
    }
}
```

```swift
// Core/PeekabooModels/Sources/PeekabooModels/CaptureTypes.swift
import Foundation

public enum ImageFormat: String, Codable, Sendable {
    case png
    case jpeg
    case tiff
}

public enum CaptureMode: String, Codable, Sendable {
    case screen
    case window
    case area
}

public struct CaptureOptions: Codable, Sendable {
    public let format: ImageFormat
    public let mode: CaptureMode
    public let quality: Float
    
    public init(format: ImageFormat = .png, mode: CaptureMode = .screen, quality: Float = 1.0) {
        self.format = format
        self.mode = mode
        self.quality = quality
    }
}
```

```swift
// Core/PeekabooModels/Sources/PeekabooModels/PeekabooError.swift
import Foundation

public enum PeekabooError: Error, Sendable {
    case permissionDenied(String)
    case windowNotFound(Int)
    case captureFailure(String)
    case invalidInput(String)
    case timeout(TimeInterval)
    
    public var localizedDescription: String {
        switch self {
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        case .windowNotFound(let id):
            return "Window not found: \(id)"
        case .captureFailure(let reason):
            return "Capture failed: \(reason)"
        case .invalidInput(let input):
            return "Invalid input: \(input)"
        case .timeout(let duration):
            return "Operation timed out after \(duration) seconds"
        }
    }
}
```

### Step 4: Update PeekabooCore

```swift
// Core/PeekabooCore/Package.swift
dependencies: [
    .package(path: "../PeekabooModels"),  // Add this
    .package(path: "../AXorcist"),
    // ... other deps
]

targets: [
    .target(
        name: "PeekabooCore",
        dependencies: [
            .product(name: "PeekabooModels", package: "PeekabooModels"),  // Add this
            // ... other deps
        ]
    )
]
```

### Step 5: Temporary Compatibility Layer

```swift
// Core/PeekabooCore/Sources/PeekabooCore/Compatibility.swift
// Temporary re-exports for backward compatibility
// Remove these after all code is migrated

@_exported import PeekabooModels

// This allows existing code to continue working:
// import PeekabooCore still provides access to WindowInfo, etc.
```

### Step 6: Gradual Migration

```swift
// Old code (still works during migration)
import PeekabooCore

func processWindow(_ window: WindowInfo) { }

// New code (preferred)
import PeekabooModels  // Import only what you need

func processWindow(_ window: WindowInfo) { }
```

## Measuring Success

### Before Extraction
```bash
# Change a model file
echo "// test" >> Core/PeekabooCore/Sources/PeekabooCore/Models/WindowInfo.swift
swift build 2>&1 | grep "Compiling" | wc -l
# Result: 700+ files recompile
```

### After Extraction
```bash
# Change a model file
echo "// test" >> Core/PeekabooModels/Sources/PeekabooModels/WindowInfo.swift
swift build 2>&1 | grep "Compiling" | wc -l
# Result: Only files that import PeekabooModels recompile (~50-100)
```

## Common Pitfalls to Avoid

### ❌ Don't: Create Circular Dependencies
```swift
// PeekabooModels/SomeType.swift
import PeekabooCore  // ❌ Models can't depend on Core!
```

### ✅ Do: Keep Dependencies Flowing Downward
```swift
// PeekabooCore/SomeService.swift
import PeekabooModels  // ✅ Core can depend on Models
```

### ❌ Don't: Move Too Much at Once
Moving 50 files in one PR makes review difficult and risky.

### ✅ Do: Move Incrementally
Move 5-10 related files at a time, test, then continue.

### ❌ Don't: Break Public API
```swift
// Removing without deprecation
// public struct WindowInfo  // ❌ Suddenly gone!
```

### ✅ Do: Maintain Compatibility
```swift
// PeekabooCore re-exports during migration
@_exported import PeekabooModels  // ✅ Still available
```

## Next Module: PeekabooProtocols

After PeekabooModels is stable, extract protocols:

```swift
// Core/PeekabooProtocols/Sources/PeekabooProtocols/CaptureService.swift
import PeekabooModels

public protocol CaptureService: Sendable {
    func captureScreen(options: CaptureOptions) async throws -> Data
    func captureWindow(id: Int, options: CaptureOptions) async throws -> Data
}

public protocol WindowService: Sendable {
    func listWindows() async throws -> [WindowInfo]
    func focusWindow(id: Int) async throws
    func minimizeWindow(id: Int) async throws
}
```

## Build Time Improvements

### Expected Timeline
- **Day 1**: Create PeekabooModels, move 10 files
  - Build improvement: 10-15% faster incremental builds
- **Day 2**: Move remaining model files (20 files)
  - Build improvement: 20-30% faster incremental builds
- **Week 1**: Complete PeekabooModels + PeekabooProtocols
  - Build improvement: 40-50% faster incremental builds

### Validation
```bash
# Create a build timing script
#!/bin/bash
echo "Testing incremental build time..."
echo "// Build test $(date)" >> Apps/CLI/Sources/peekaboo/main.swift
time swift build -c debug 2>&1 | tail -1
git checkout Apps/CLI/Sources/peekaboo/main.swift
```

Run this before and after each extraction to measure improvement.

## Module Checklist

Before considering a module extraction complete:

- [ ] Package.swift is minimal (no unnecessary dependencies)
- [ ] All types are properly marked with access control
- [ ] Sendable conformance added where appropriate
- [ ] No circular dependencies exist
- [ ] Tests are passing
- [ ] Build time improved measurably
- [ ] Backward compatibility maintained
- [ ] Documentation updated
- [ ] CI/CD still green
- [ ] Team notified of changes

## Conclusion

Start small, measure everything, and maintain compatibility. The first module extraction (PeekabooModels) should take 1-2 days and immediately improve build times by 20-30%. Each subsequent extraction becomes easier as the pattern is established.