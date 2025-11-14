---
summary: 'Review Module Architecture Refactoring Plan guidance'
read_when:
  - 'planning work related to module architecture refactoring plan'
  - 'debugging or extending features described here'
---

# Module Architecture Refactoring Plan

## Problem Analysis

### Current State
- **727 Swift files** total, with **132 in PeekabooCore** alone
- When `main.swift` changes, **700+ files rebuild** (96% of codebase!)
- PeekabooCore is a **monolithic module** containing everything:
  - Services (Agent, AI, Audio, Capture, Core, System, UI)
  - Models, Utilities, Visualization, MCP integration
  - Tool formatting, registries, and configuration
- **40 imports** of PeekabooCore throughout CLI commands
- Circular dependencies: PeekabooCore → Tachikoma → TachikomaMCP → back to PeekabooCore types

### Root Causes
1. **God Module**: PeekabooCore contains too much unrelated functionality
2. **Transitive Dependencies**: Importing PeekabooCore brings in everything
3. **No Interface Boundaries**: Concrete types used directly instead of protocols
4. **Wide Public API**: Everything is public, no encapsulation
5. **Command Coupling**: CLI commands directly depend on core implementation details

## Proposed Architecture

### Layer 1: Foundation (No Dependencies)
```
PeekabooModels (New)
├── Basic types (Point, Rectangle, etc.)
├── Enums (ImageFormat, CaptureMode, etc.)
├── Errors (PeekabooError hierarchy)
└── DTOs (WindowInfo, AppInfo, etc.)

PeekabooProtocols (New)
├── Service protocols
├── Tool protocols
├── Agent protocols
└── Provider protocols
```

### Layer 2: Core Services (Depends on Layer 1)
```
PeekabooCapture (New)
├── ScreenCaptureService
├── WindowCaptureService
└── ImageProcessing

PeekabooAutomation (New)
├── ClickService
├── TypeService
├── ScrollService
└── HotkeyService

PeekabooSystem (New)
├── AppManagementService
├── WindowManagementService
├── DockService
└── SpaceService

PeekabooVision (New)
├── OCRService
├── ElementDetectionService
└── VisualizationService
```

### Layer 3: Integration (Depends on Layers 1-2)
```
PeekabooAgent (New)
├── AgentService
├── ToolRegistry
└── AgentEventHandling

PeekabooMCP (New)
├── MCPToolRegistry
├── MCPToolAdapter
└── MCPClientManager

PeekabooFormatting (New)
├── ToolFormatters
├── OutputFormatters
└── ResultFormatters
```

### Layer 4: Commands (Depends on Layers 1-3)
```
PeekabooCommands (New)
├── CoreCommands
│   ├── SeeCommand
│   ├── ClickCommand
│   └── TypeCommand
├── SystemCommands
│   ├── AppCommand
│   ├── WindowCommand
│   └── DockCommand
└── AICommands
    ├── AgentCommand
    └── MCPCommand
```

### Layer 5: Application (Top Level)
```
peekaboo (CLI executable)
├── main.swift
├── PeekabooApp.swift
└── Configuration loading
```

## Implementation Strategy

### Phase 1: Extract Models & Protocols (Week 1)
1. **Create PeekabooModels package**
   - Move all structs, enums, and basic types
   - No dependencies on AppKit/Foundation beyond basics
   - ~20 files

2. **Create PeekabooProtocols package**
   - Define service protocols
   - Extract tool protocols
   - ~15 files

3. **Update PeekabooCore to use new packages**
   - Replace internal types with imports
   - Maintain backward compatibility

**Impact**: Reduces rebuild scope by 30-40% immediately

### Phase 2: Service Decomposition (Week 2-3)
1. **Extract PeekabooCapture**
   - Move capture services
   - ~15 files
   - Only depends on Models/Protocols

2. **Extract PeekabooAutomation**
   - Move UI automation services
   - ~20 files
   - Depends on AXorcist, Models/Protocols

3. **Extract PeekabooSystem**
   - Move system management services
   - ~15 files
   - Only depends on Models/Protocols

**Impact**: Reduces rebuild scope by another 30%

### Phase 3: Command Modularization (Week 4)
1. **Create PeekabooCommands package**
   - Move all command implementations
   - Group by functionality
   - ~50 files

2. **Slim down CLI target**
   - Only main.swift and app setup
   - Import PeekabooCommands
   - ~5 files

**Impact**: CLI changes only rebuild commands, not services

### Phase 4: Tool & Agent Extraction (Week 5)
1. **Extract PeekabooAgent**
   - Move agent services
   - Tool registry and execution
   - ~20 files

2. **Extract PeekabooMCP**
   - Move MCP integration
   - Keep separate from core tools
   - ~10 files

**Impact**: AI changes don't trigger core rebuilds

## Dependency Rules

### Strict Layering
```
Layer 5 (App) → Layer 4 (Commands) → Layer 3 (Integration) → Layer 2 (Services) → Layer 1 (Foundation)
```

### Module Rules
1. **No circular dependencies** - Lower layers cannot import higher layers
2. **Protocol boundaries** - Services expose protocols, not concrete types
3. **Minimal public API** - Only expose what's necessary
4. **No transitive exports** - Don't re-export dependencies
5. **Dependency injection** - Pass dependencies explicitly

## Migration Path

### Step 1: Non-Breaking Extraction
```swift
// In PeekabooCore/Package.swift
dependencies: [
    .package(path: "../PeekabooModels"),
    .package(path: "../PeekabooProtocols"),
]

// Re-export for compatibility
@_exported import PeekabooModels
@_exported import PeekabooProtocols
```

### Step 2: Gradual Migration
```swift
// Old way (still works)
import PeekabooCore

// New way (preferred)
import PeekabooModels
import PeekabooCapture
```

### Step 3: Remove Re-exports
After all code is migrated, remove `@_exported` statements

## Build Performance Expectations

### Before Refactoring
- Change to main.swift → 700+ files rebuild
- Change to a service → 500+ files rebuild
- Incremental build: 43 seconds

### After Phase 1
- Change to main.swift → ~400 files rebuild
- Change to a service → ~300 files rebuild
- Incremental build: ~25 seconds

### After Full Refactoring
- Change to main.swift → ~50 files rebuild
- Change to a service → ~20 files rebuild
- Incremental build: ~5-10 seconds

## Success Metrics

1. **Rebuild Scope**: No more than 10% of files rebuild for typical changes
2. **Build Time**: Incremental builds under 10 seconds
3. **Module Size**: No module larger than 30 files
4. **Import Count**: Average file imports < 5 modules
5. **Compilation Parallelism**: Modules can build in parallel

## Testing Strategy

### Continuous Validation
```bash
# Measure rebuild scope
echo "// test" >> main.swift
swift build -Xswiftc -driver-show-incremental 2>&1 | grep "Compiling" | wc -l
```

### Module Independence Test
Each module should build independently:
```bash
cd PeekabooModels && swift build
cd PeekabooCapture && swift build
```

## Common Patterns

### Service Definition
```swift
// In PeekabooProtocols
public protocol CaptureService {
    func captureScreen() async throws -> CaptureResult
}

// In PeekabooCapture
public struct DefaultCaptureService: CaptureService {
    public func captureScreen() async throws -> CaptureResult {
        // Implementation
    }
}

// In CLI
let captureService: CaptureService = DefaultCaptureService()
```

### Command Pattern
```swift
// In PeekabooCommands
public struct SeeCommand: AsyncParsableCommand {
    @Inject var captureService: CaptureService
    
    public func run() async throws {
        let result = try await captureService.captureScreen()
    }
}
```

## Risk Mitigation

1. **Maintain backward compatibility** during migration
2. **Test each phase** thoroughly before proceeding
3. **Monitor build times** after each change
4. **Keep PR sizes small** - one module at a time
5. **Document module boundaries** clearly

## Timeline

- **Week 1**: Extract Models & Protocols
- **Week 2-3**: Service Decomposition
- **Week 4**: Command Modularization
- **Week 5**: Tool & Agent Extraction
- **Week 6**: Cleanup and optimization

Total: 6 weeks for full refactoring

## Next Steps

1. Create new package directories:
```bash
mkdir -p Core/PeekabooModels
mkdir -p Core/PeekabooProtocols
mkdir -p Core/PeekabooCapture
```

2. Start with PeekabooModels extraction
3. Set up CI to track build times
4. Create module dependency diagram
5. Begin incremental migration

## Conclusion

This refactoring will transform Peekaboo from a monolithic structure to a modular, scalable architecture. The key is **incremental migration** with backward compatibility, allowing the team to maintain velocity while improving build times by **80-90%**.

The investment of 6 weeks will pay dividends in:
- Developer productivity (5-10s vs 43s builds)
- Code maintainability (clear module boundaries)
- Team scalability (parallel development)
- Testing efficiency (isolated module tests)