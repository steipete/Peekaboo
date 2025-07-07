# CLI to PeekabooCore Migration Status

This document tracks the progress of migrating CLI functionality to PeekabooCore services.

## Overview

The goal is to move all business logic from the CLI into PeekabooCore services, allowing:
- Direct use by the Mac app without spawning CLI processes
- Better code reuse and testing
- Cleaner separation of concerns

## Migration Pattern

Each CLI command follows this migration pattern:

1. Create a service protocol in `PeekabooCore/Services/Protocols/`
2. Implement the service in `PeekabooCore/Services/Implementations/`
3. Create a V2 version of the command that uses the service
4. Register the V2 command in `main.swift`
5. Eventually replace the original command with the V2 version

## Migration Status

### ✅ Completed

1. **ImageCommand → ImageCommandV2**
   - Service: `ScreenCaptureService` (fully implemented)
   - Status: Complete example demonstrating the pattern
   - Features: All capture modes, permission checking

2. **ListCommand → ListCommandV2**
   - Service: `ApplicationService` (fully implemented)
   - Status: Complete with all subcommands
   - Features: List apps, windows, permissions

3. **WindowCommand → WindowCommandV2**
   - Service: `WindowManagementService` (fully implemented)
   - Status: Complete with all window operations
   - Features: Close, minimize, maximize, move, resize, focus

4. **MenuCommand → MenuCommandV2**
   - Service: `MenuService` (fully implemented)
   - Status: Complete with all menu operations
   - Features: List menus, click items, menu extras

5. **ClickCommand → ClickCommandV2**
   - Service: `UIAutomationService` (partially implemented)
   - Status: Complete basic functionality
   - Features: Click coordinates/elements, wait for elements

### 🚧 In Progress

1. **SessionManager**
   - Current: Stub implementation
   - Needed: Full implementation migrating from CLI's SessionCache
   - Used by: SeeCommand, ClickCommand, and others

2. **UIAutomationService**
   - Current: Basic click and wait implemented
   - Needed: Element detection, more sophisticated targeting
   - Used by: ClickCommand, TypeCommand, ScrollCommand, etc.

### 📋 To Do

High Priority (Core Functionality):
1. **TypeCommand** → Needs full UIAutomationService
2. **ScrollCommand** → Needs UIAutomationService enhancements
3. **HotkeyCommand** → Needs UIAutomationService enhancements
4. **SeeCommand** → Needs element detection in UIAutomationService
5. **DragCommand** → Needs UIAutomationService drag support
6. **SwipeCommand** → Needs UIAutomationService swipe support

Medium Priority (App Control):
1. **AppCommand** → Can use existing ApplicationService
2. **DockCommand** → Needs DockService
3. **RunCommand** → Needs ProcessService
4. **DialogCommand** → Needs DialogService

Low Priority (Utilities):
1. **CleanCommand** → Needs FileService
2. **SleepCommand** → Simple, can stay in CLI
3. **PermissionsCommand** → Already covered by ListCommand
4. **ConfigCommand** → Configuration management

Special Cases:
1. **AnalyzeCommand** → Already integrated into ImageCommand
2. **AgentCommand** → Complex, may stay CLI-only
3. **SimpleAgentCommand** → Complex, may stay CLI-only

## AXorcist Enhancements Made

As part of this migration, we've enhanced AXorcist with:
1. `maximizeWindow()` method in Element+WindowOperations
2. `Element+UIAutomation` extension with:
   - Click operations
   - Type/keystroke operations
   - Scroll operations
   - Hotkey operations
   - Element state checking

## Next Steps

1. **Implement SessionManager fully**
   - Move logic from CLI's SessionCache
   - Add proper element tracking and expiration
   - Support for element references across commands

2. **Complete UIAutomationService**
   - Add element detection (from SeeCommand)
   - Add drag/drop support
   - Add more sophisticated wait conditions
   - Add screenshot annotation support

3. **Create ProcessService**
   - For RunCommand functionality
   - Process launching and management
   - Output capture

4. **Update Mac App**
   - Replace ProcessRunner calls with direct service usage
   - Remove dependency on CLI binary
   - Improve performance by eliminating IPC overhead

## Testing Strategy

1. Each V2 command should have tests that verify:
   - Same output format as original
   - All options work correctly
   - Error handling matches original

2. Service tests should verify:
   - Core functionality works
   - Error cases handled properly
   - Thread safety (if applicable)

## Benefits Achieved

1. **Code Reuse**: Services can be used by CLI, Mac app, and Inspector
2. **Better Testing**: Services can be unit tested without UI
3. **Performance**: Mac app no longer needs to spawn CLI processes
4. **Maintainability**: Clear separation of concerns
5. **Type Safety**: Shared models between components