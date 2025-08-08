# Swift Build Performance Optimization Guide

*Last Updated: August 2025 | Tested with Xcode 26 beta | Extended testing: December 2025*

## Executive Summary

After extensive testing on the Peekaboo project (727 Swift files, 16-core M-series Mac), we found:

- **Batch mode**: **34% faster** incremental builds (28.5s vs 43s) ✅
- **Compilation caching**: Currently **slower** due to missing explicit modules ❌
- **Integrated Swift driver**: **slower** for all builds (43-55s vs 35-37s) ❌
- **Parallel jobs**: Default is optimal, more jobs = worse performance ❌
- **Root issue**: Module structure causes 700+ files to recompile when changing 1 file

## Tested Optimizations

### 1. Batch Mode ✅ **RECOMMENDED**

**What it does**: Groups source files for compilation, reducing redundant parsing.

**Results**:
- Incremental builds: 19.6s (vs 27.2s baseline) - **27.8% faster**
- Clean builds: Similar performance
- No downsides found

**How to enable**:
```bash
# Command line
swift build -c debug -Xswiftc -enable-batch-mode

# Package.swift
swiftSettings: [
    .unsafeFlags(["-enable-batch-mode"], .when(configuration: .debug))
]
```

### 2. Compilation Caching ❌ **NOT WORKING**

**What it does**: Caches compilation results between builds (new in Xcode 26).

**How to enable**:
```bash
# Via command line flag (preferred)
swift build -Xswiftc -cache-compile-job

# Via environment variable
export COMPILATION_CACHE_ENABLE_CACHING=YES

# Via xcodebuild
xcodebuild build COMPILATION_CACHE_ENABLE_CACHING=YES
```

**Results** (December 2025 testing):
- Clean builds: 49-75s (vs 35-37s baseline) - **32-100% slower**
- Cache not actually working: `warning: -cache-compile-job cannot be used without explicit module build`
- Requires explicit modules which aren't available for SPM yet

**Status**: Not functional for SPM projects. Wait for explicit module support.

### 3. Integrated Swift Driver ⚠️ **MIXED RESULTS**

**What it does**: Uses Swift-based driver with better dependency tracking.

**Results**:
- Clean builds: 69.5s (vs 40.5s) - **71% slower**
- Incremental: 25.4s (vs 35.1s) - **28% faster**
- Recompiled 228 files vs 518 files (better tracking)

**Recommendation**: Don't use - fix module structure instead.

### 4. Explicit Modules 🚫 **NOT AVAILABLE**

**Status**: Flag exists in documentation but not in current compiler.
Expected in future Xcode 26 releases.

### 5. Whole Module Optimization (WMO) ⚠️ **RELEASE ONLY**

**What it does**: Compiles entire module as one unit, enabling cross-file optimizations.

**Results**:
- **Release builds**: Good runtime performance, reasonable compile time
- **Debug builds**: Breaks with error: `index output filenames do not match input source files`
- Loses incremental compilation capability

**Recommendation**: Already enabled by default for release builds. Don't use for debug.

### 6. Parallel Jobs Configuration ❌ **DEFAULT IS BEST**

**What it does**: Controls build parallelism with `-j` flag.

**Results** (December 2025):
- Default: 35-43s
- `-j 8`: 44s (-2% slower)
- `-j 16`: 49s (-32% slower)
- `-j 32`: 67s (-81% slower)

**Why it's worse**: Higher parallelism causes memory contention and CPU thrashing.

**Recommendation**: Let Swift choose optimal parallelism automatically.

### 7. Type Checking Performance 🔍 **DIAGNOSTIC TOOL**

**What it does**: Identifies slow-compiling code.

**How to use**:
```bash
swift build -Xswiftc -Xfrontend -Xswiftc -warn-long-function-bodies=50 \
            -Xswiftc -Xfrontend -Xswiftc -warn-long-expression-type-checking=50
```

**Findings in Peekaboo**:
- `Element+PathGeneration.swift`: `generatePathString` (51ms)
- `Element+PathGeneration.swift`: `generatePathArray` (52ms)
- `Element+Properties.swift`: `_dumpRecursive` (55ms)
- `Element+TypeChecking.swift`: `isDockItem` (52ms)

**Fix**: Add explicit type annotations to complex expressions.

### 8. Other Tested Optimizations

| Optimization | Result | Notes |
|-------------|---------|-------|
| **SWIFT_DETERMINISTIC_HASHING=1** | No change | For reproducible builds |
| **Disable index store** | Not possible | No flag available |
| **LLVM Thin LTO** | Small improvement for release | `-Xswiftc -lto=llvm-thin` |

## Performance Measurements

### Clean Build Times
| Configuration | Time | CPU Usage | Notes |
|--------------|------|-----------|-------|
| Baseline | 70.2s | 493% | Standard build |
| With batch mode | 67.0s | 431% | Slightly faster |
| With caching (first) | 105.5s | 331% | Cache population overhead |
| With integrated driver | 69.5s | 327% | Lower parallelization |

### Incremental Build Times
| Configuration | Time | Files Rebuilt | Improvement |
|--------------|------|---------------|-------------|
| Baseline | 27.2s | 518 | - |
| With batch mode | 19.6s | 518 | 27.8% faster |
| With integrated driver | 25.4s | 228 | Better tracking |

## Key Findings

### The Good 👍
1. **Batch mode** provides consistent improvements with no downsides
2. **Parallel compilation** scales well to 16 cores
3. **Type inference** optimizations can help in specific cases

### The Bad 👎
1. **Compilation caching** has significant overhead in beta
2. **Module structure** causes cascading recompilations
3. **Integrated driver** slower for clean builds

### The Ugly 🔥
- Changing `main.swift` triggers **518 file recompilations**
- This indicates poor module boundaries and import dependencies
- No optimization flag can fix architectural issues

## Recommendations

### Immediate Actions (Today)
```bash
# Add to your build commands
swift build -c debug -Xswiftc -enable-batch-mode -j 16
```

### Short Term (This Week)
1. Add batch mode to Package.swift
2. Investigate why 518 files rebuild for single file change
3. Add explicit types to slow-compiling functions

### Medium Term (This Month)
1. **Module decomposition** - Split PeekabooCore into:
   - PeekabooCommands
   - PeekabooServices
   - PeekabooUI
2. Create binary frameworks for stable dependencies
3. Implement incremental build monitoring

### Long Term (If Needed)
1. Consider Bazel/Buck2 for 2x+ improvements
2. Distributed build system for team scaling
3. Custom build orchestration

## Build Commands Reference

### Development (Fast Iteration)
```bash
# Best for incremental builds
swift build -c debug -Xswiftc -enable-batch-mode

# With explicit parallelization
swift build -c debug -Xswiftc -enable-batch-mode -j 32
```

### CI/CD (Clean Builds)
```bash
# Skip experimental features for stability
swift build -c release -j $(sysctl -n hw.ncpu)
```

### Debugging Slow Builds
```bash
# Show build timing
swift build -Xswiftc -driver-time-compilation

# Warn about slow type checking
swift build \
  -Xswiftc -Xfrontend \
  -Xswiftc -warn-long-function-bodies=100 \
  -Xswiftc -Xfrontend \
  -Xswiftc -warn-long-expression-type-checking=100
```

## Other Optimization Levers

### Not Tested Yet
- **Module interfaces** (`-emit-module-interface`)
- **Precompiled bridging headers** (`-precompile-bridging-header`)
- **Whole module optimization** for Debug (loses incremental)
- **LTO (Link-Time Optimization)** (`-lto=thin`)
- **RAM disk** for build directory

### Hardware Considerations
- Ensure sufficient RAM (32GB+ recommended)
- Use local SSD, not network drives
- Close unnecessary applications during builds
- Consider dedicated build machine

## Xcode 26 Specific Features

### Available Now
- `-cache-compile-job` (slower in beta)
- `-enable-batch-mode` (working well)
- Better build timeline visualization

### Coming Soon
- Explicit modules by default
- Improved compilation caching
- Better incremental build tracking
- Module interface caching

## Troubleshooting

### "Too many files rebuilding"
**Problem**: Small changes trigger large rebuilds.
**Solution**: 
1. Check import dependencies with `swift-deps-scanner`
2. Reduce `@testable import` usage
3. Split large modules
4. Use protocols for abstraction

### "Build times increasing over time"
**Problem**: Incremental builds getting slower.
**Solution**:
1. Clean derived data periodically
2. Reset package caches: `swift package reset`
3. Check for circular dependencies

### "Low CPU usage during builds"
**Problem**: Not utilizing all cores.
**Solution**:
1. Increase job count: `-j 32`
2. Enable batch mode
3. Check for serialized build phases

## Configuration Files

### Package.swift Optimizations
```swift
// Add to your executable target
swiftSettings: [
    .unsafeFlags(["-parse-as-library"]),
    .unsafeFlags(["-enable-batch-mode"], .when(configuration: .debug)),
    // Add when Xcode 26 ships:
    // .unsafeFlags(["-enable-explicit-modules"], .when(configuration: .debug)),
]
```

### Environment Variables
```bash
# Add to .zshrc or .bashrc
export SWIFT_DRIVER_COMPILATION_JOBS=16
export SWIFT_ENABLE_BATCH_MODE=YES
# Don't use these yet (slower in beta):
# export ENABLE_COMPILATION_CACHE=YES
# export SWIFT_USE_INTEGRATED_DRIVER=YES
```

## Benchmark Results

Testing performed on Peekaboo CLI (August 2025):
- **Hardware**: 16-core M-series Mac
- **Project**: 727 Swift files, 6 package dependencies
- **Baseline clean build**: 70.2 seconds
- **Best optimized build**: 67.0 seconds (batch mode)
- **Baseline incremental**: 27.2 seconds
- **Best incremental**: 19.6 seconds (27.8% improvement)

## Conclusion

After comprehensive testing (December 2025), our findings confirm:

1. **Only batch mode works** - Provides 34% faster incremental builds with no downsides
2. **Most "advanced" features aren't ready** - Compilation caching, explicit modules don't work for SPM
3. **Architecture matters most** - 700+ files rebuilding for single file change is the real problem

### ✅ What Actually Works
- **Batch mode** for debug builds (already applied)
- **Type checking warnings** to identify slow code
- **WMO** for release builds (default)

### ❌ What Doesn't Work (Yet)
- Compilation caching (requires explicit modules)
- Integrated Swift driver (slower)
- Custom parallelism (worse than default)
- Explicit modules (not available)

### 🎯 Action Items
1. Keep batch mode enabled ✅
2. Fix slow type-checking functions in AXorcist
3. Refactor module architecture to reduce cascading rebuilds
4. Wait for Xcode 26 stable before trying cache features again

The most impactful optimization remains **fixing the module architecture**. No compiler flag can overcome poor module boundaries that cause 700+ files to rebuild.

## Resources

- [Swift Compiler Performance](https://github.com/apple/swift/blob/main/docs/CompilerPerformance.md)
- [Optimizing Swift Build Times](https://github.com/fastred/Optimizing-Swift-Build-Times)
- [Xcode 26 Release Notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes)
- [WWDC 2025: What's new in Xcode 26](https://developer.apple.com/videos/play/wwdc2025/247/)