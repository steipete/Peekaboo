# DragCommand Refactoring Documentation

## Overview

This document tracks the progress of refactoring the DragCommand to use PeekabooCore services, following the established V2 command pattern.

## Completed Tasks

### 1. Enhanced UIAutomationServiceProtocol
- ✅ Added `drag` method to the UIAutomationServiceProtocol interface
- ✅ Method signature: `func drag(from: CGPoint, to: CGPoint, duration: Int, steps: Int, modifiers: String?) async throws`
- ✅ Added comprehensive documentation for the new method

### 2. Implemented Drag Functionality in UIAutomationService
- ✅ Added `drag` method implementation in UIAutomationService
- ✅ Added `parseModifierKeys` helper method to parse modifier key strings
- ✅ Added `dragFailed` case to UIAutomationError enum
- ✅ Implemented smooth drag operation with:
  - Mouse down at start point
  - Intermediate drag events through calculated steps
  - Mouse up at end point
  - Support for modifier keys (cmd, shift, option, ctrl)

### 3. Created DragCommandV2
- ✅ Created new DragCommandV2.swift file following the V2 pattern
- ✅ Implemented using PeekabooCore services:
  - Uses `PeekabooServices.shared` for all operations
  - Uses `services.automation.drag()` for drag operations
  - Uses `services.applications` for finding applications
  - Uses `services.automation.waitForElement()` for element resolution
- ✅ Maintained command-line interface compatibility with original DragCommand
- ✅ Added proper error handling with JSON output support
- ✅ Preserved all original functionality:
  - Element-to-element dragging
  - Coordinate-based dragging
  - Drag to application (including Trash)
  - Modifier key support
  - Customizable duration and steps

### 4. Updated PeekabooError
- ✅ Enhanced PeekabooError enum to support DragCommandV2:
  - Changed `windowNotFound` to accept a String parameter
  - Added `applicationNotFound(String)` case
- ✅ Updated error descriptions accordingly

### 5. Registered DragCommandV2
- ✅ Added DragCommandV2 to the main.swift subcommands list

## Tasks Still To Do

### 1. Testing
- [ ] Test DragCommandV2 with various scenarios:
  - [ ] Element-to-element dragging within a session
  - [ ] Coordinate-based dragging
  - [ ] Dragging to applications (Finder, Trash, etc.)
  - [ ] Modifier key combinations
  - [ ] Error cases (invalid elements, missing sessions, etc.)
- [ ] Compare behavior with original DragCommand to ensure parity

### 2. Deprecation Strategy
- [ ] Add deprecation notice to original DragCommand
- [ ] Update command help text to guide users to V2
- [ ] Document migration path in user documentation

### 3. Integration Testing
- [ ] Verify integration with other V2 commands
- [ ] Test session management across commands
- [ ] Ensure error codes are consistent

### 4. Performance Optimization
- [ ] Profile drag operations for performance
- [ ] Optimize step calculations if needed
- [ ] Consider adding adaptive step sizing based on distance

### 5. Documentation
- [ ] Update user documentation for drag-v2 command
- [ ] Add examples to the command help text
- [ ] Document any behavioral differences from v1

## Architecture Notes

### Service Layer Benefits
The refactored version provides several advantages:
1. **Separation of Concerns**: UI automation logic is centralized in UIAutomationService
2. **Reusability**: The drag functionality can be used by other commands or services
3. **Testability**: Services can be mocked for unit testing
4. **Consistency**: Error handling and behavior matches other V2 commands

### Key Differences from Original
1. **Element Resolution**: Uses `waitForElement` with timeout support
2. **Application Finding**: Leverages ApplicationService instead of direct AXorcist calls
3. **Error Types**: Uses service-layer errors (UIAutomationError) internally, mapped to PeekabooError for CLI

### Future Enhancements
1. **Drag Regions**: Support for dragging to select regions (e.g., text selection)
2. **Multi-touch**: Support for multi-finger gestures on trackpad
3. **Animation**: Optional visual feedback during drag operations
4. **Undo Support**: Track drag operations for potential undo functionality

## Migration Guide

For users migrating from `drag` to `drag-v2`:

```bash
# Old command
peekaboo drag --from B1 --to T2

# New command (identical interface)
peekaboo drag-v2 --from B1 --to T2
```

The command interface remains the same, but the underlying implementation now uses PeekabooCore services for better reliability and integration with other Peekaboo features.