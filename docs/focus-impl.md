# Peekaboo Focus & Space Management Implementation Plan

## Overview

This document outlines the comprehensive implementation plan for adding intelligent window focusing with Space switching capabilities to Peekaboo. The implementation leverages macOS's stable CGWindowID and CGSSpace private APIs to provide reliable, cross-Space window management.

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [Architecture Overview](#architecture-overview)
3. [Implementation Phases](#implementation-phases)
4. [Detailed Implementation](#detailed-implementation)
5. [Testing Strategy](#testing-strategy)
6. [Documentation Plan](#documentation-plan)

## Core Concepts

### Window Identity

- **CGWindowID**: Stable identifier for window lifetime
- **AXIdentifier**: Optional developer-provided stable ID
- **Window Title**: Human-readable but unstable
- **Window Index**: Position-based, very unstable

### Space Management

- **CGSSpaceID**: Identifier for virtual desktops
- **Space Types**: User, Fullscreen, System
- **Space Switching**: Via CGSManagedDisplaySetCurrentSpace
- **Window Movement**: Via CGSAddWindowsToSpaces/CGSRemoveWindowsFromSpaces

### Focus Hierarchy

1. Application must be frontmost
2. Window must be focused within application
3. Window must be on current Space (or we switch/move)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLI Commands                            │
│  (click, type, menu, scroll, etc.)                             │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Focus Utility Extension                      │
│  ensureWindowFocus() - Smart focus with Space support          │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Window Resolution                           │
│  CGWindowID → AXUIElement → Focus Actions                      │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Space Management                           │
│  CGSSpace APIs for switching and window movement               │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation Phases

### Phase 1: Core Infrastructure (Foundation)

1. **SpaceUtilities.swift** - CGSSpace API declarations
2. **WindowIdentityUtilities.swift** - CGWindowID ↔ AXUIElement conversion
3. **FocusUtilities.swift** - Core focus extension for commands
4. **Enhanced Session Storage** - Add windowID to UIAutomationSession

### Phase 2: Window Focus Command Enhancement

1. **Update FocusSubcommand** - Add Space switching options
2. **Implement Space detection** - Check if window is on different Space
3. **Add movement options** - --move-here flag
4. **Focus verification** - Polling-based verification

### Phase 3: Command Integration

1. **Click Command** - Add --focus parameter
2. **Type Command** - Add --focus parameter
3. **Menu Command** - Add --focus parameter
4. **Other Interactive Commands** - scroll, hotkey, drag, etc.

### Phase 4: Space Command

1. **New SpaceCommand** - Dedicated Space management
2. **List Spaces** - Show all Spaces with details
3. **Switch Space** - Direct Space switching
4. **Move Windows** - Move windows between Spaces

### Phase 5: Documentation & Polish

1. **docs/focus.md** - User-facing documentation
2. **Error messages** - Clear, actionable errors
3. **Performance optimization** - Caching, efficient lookups
4. **Tests** - Comprehensive test coverage

## Detailed Implementation

### 1. SpaceUtilities.swift

```swift
// Location: Core/PeekabooCore/Sources/PeekabooCore/Utilities/SpaceUtilities.swift

import Foundation
import CoreGraphics

// MARK: - Type Definitions

public typealias CGSConnectionID = UInt32
public typealias CGSSpaceID = UInt64
public typealias CGSSpaceSelector = Int
public typealias CGSManagedDisplay = UInt32

// MARK: - Constants

public enum CGSSpaceConstants {
    // Space selectors
    static let kCGSSpaceCurrent: CGSSpaceSelector = 5
    static let kCGSSpaceOther: CGSSpaceSelector = 6
    static let kCGSSpaceAll: CGSSpaceSelector = 7
    
    // Space types
    static let kCGSSpaceUser = 0
    static let kCGSSpaceFullscreen = 1
    static let kCGSSpaceSystem = 2
    static let kCGSSpaceTiled = 3 // Stage Manager
    
    // Display
    static let kCGSPackagesMainDisplayIdentifier: CGSManagedDisplay = 1
}

// MARK: - Private API Declarations (Weak Import)

@_silgen_name("_CGSDefaultConnection")
func _CGSDefaultConnection() -> CGSConnectionID

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSCopySpaces")
func CGSCopySpaces(_ cid: CGSConnectionID, _ selector: CGSSpaceSelector) -> CFArray?

@_silgen_name("CGSGetActiveSpace")
func CGSGetActiveSpace(_ cid: CGSConnectionID) -> CGSSpaceID

@_silgen_name("CGSSpaceGetType")
func CGSSpaceGetType(_ cid: CGSConnectionID, _ space: CGSSpaceID) -> Int

@_silgen_name("CGSSpaceCopyName")
func CGSSpaceCopyName(_ cid: CGSConnectionID, _ space: CGSSpaceID) -> CFString?

@_silgen_name("CGSCopyManagedDisplayForSpace")
func CGSCopyManagedDisplayForSpace(_ cid: CGSConnectionID, _ space: CGSSpaceID) -> CGSManagedDisplay

@_silgen_name("CGSCopySpacesForWindows")
func CGSCopySpacesForWindows(_ cid: CGSConnectionID, _ selector: CGSSpaceSelector, _ windowIDs: CFArray) -> CFArray?

@_silgen_name("CGSAddWindowsToSpaces")
func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windowIDs: CFArray, _ spaceIDs: CFArray)

@_silgen_name("CGSRemoveWindowsFromSpaces")
func CGSRemoveWindowsFromSpaces(_ cid: CGSConnectionID, _ windowIDs: CFArray, _ spaceIDs: CFArray)

@_silgen_name("CGSManagedDisplaySetCurrentSpace")
func CGSManagedDisplaySetCurrentSpace(_ cid: CGSConnectionID, _ display: CGSManagedDisplay, _ space: CGSSpaceID)

@_silgen_name("CGSWillSwitchSpaces")
func CGSWillSwitchSpaces(_ cid: CGSConnectionID, _ space: CGSSpaceID) -> Bool

@_silgen_name("CGSManagedDisplayGetCurrentSpace")
func CGSManagedDisplayGetCurrentSpace(_ cid: CGSConnectionID, _ display: CGSManagedDisplay) -> CGSSpaceID

// MARK: - Space Management Service

public final class SpaceManagementService: Sendable {
    public static let shared = SpaceManagementService()
    private let logger = Logger(subsystem: "PeekabooCore", category: "SpaceManagement")
    
    // Cache for performance
    private let spaceCache = ThreadSafeCache<CGSSpaceID, SpaceInfo>(ttl: 0.1) // 100ms cache
    
    private init() {}
    
    // MARK: - Public API
    
    /// Get the currently active Space
    public func getCurrentSpace() -> CGSSpaceID {
        let cid = _CGSDefaultConnection()
        return CGSGetActiveSpace(cid)
    }
    
    /// Get the Space containing a specific window
    public func getWindowSpace(_ windowID: CGWindowID) async throws -> CGSSpaceID {
        let cid = _CGSDefaultConnection()
        let windowArray = [windowID] as CFArray
        
        guard let spaces = CGSCopySpacesForWindows(cid, CGSSpaceConstants.kCGSSpaceAll, windowArray) as? [CGSSpaceID],
              let space = spaces.first else {
            throw SpaceError.windowNotFound(windowID: windowID)
        }
        
        return space
    }
    
    /// Get all user Spaces (excluding fullscreen, system, etc.)
    public func getUserSpaces() async -> [SpaceInfo] {
        let cid = _CGSDefaultConnection()
        guard let allSpaces = CGSCopySpaces(cid, CGSSpaceConstants.kCGSSpaceAll) as? [CGSSpaceID] else {
            return []
        }
        
        return allSpaces.compactMap { spaceID in
            // Check cache first
            if let cached = spaceCache.get(spaceID) {
                return cached
            }
            
            let type = CGSSpaceGetType(cid, spaceID)
            guard type == CGSSpaceConstants.kCGSSpaceUser else { return nil }
            
            let name = CGSSpaceCopyName(cid, spaceID) as String? ?? "Space \(spaceID)"
            let display = CGSCopyManagedDisplayForSpace(cid, spaceID)
            
            let info = SpaceInfo(
                id: spaceID,
                name: name,
                type: .user,
                displayID: display,
                isCurrent: spaceID == getCurrentSpace()
            )
            
            spaceCache.set(spaceID, info)
            return info
        }
    }
    
    /// Switch to a specific Space
    public func switchToSpace(_ spaceID: CGSSpaceID, waitForSwitch: Bool = true) async throws {
        let cid = _CGSDefaultConnection()
        let currentSpace = getCurrentSpace()
        
        guard currentSpace != spaceID else { return } // Already there
        
        // Get display for target Space
        let display = CGSCopyManagedDisplayForSpace(cid, spaceID)
        
        logger.info("Switching from Space \(currentSpace) to \(spaceID) on display \(display)")
        
        // Perform the switch
        CGSManagedDisplaySetCurrentSpace(cid, display, spaceID)
        
        if waitForSwitch {
            try await waitForSpaceSwitch(targetSpace: spaceID)
        }
    }
    
    /// Move a window to current Space
    public func moveWindowToCurrentSpace(_ windowID: CGWindowID) async throws {
        let cid = _CGSDefaultConnection()
        let currentSpace = getCurrentSpace()
        let windowSpace = try await getWindowSpace(windowID)
        
        guard windowSpace != currentSpace else { return } // Already here
        
        logger.info("Moving window \(windowID) from Space \(windowSpace) to \(currentSpace)")
        
        let windowArray = [windowID] as CFArray
        let currentSpaceArray = [currentSpace] as CFArray
        let windowSpaceArray = [windowSpace] as CFArray
        
        // Add to current Space
        CGSAddWindowsToSpaces(cid, windowArray, currentSpaceArray)
        
        // Sonoma+ fix: small delay to prevent rubber-banding
        try await Task.sleep(nanoseconds: 100_000) // 0.1ms
        
        // Remove from original Space
        CGSRemoveWindowsFromSpaces(cid, windowArray, windowSpaceArray)
    }
    
    /// Move a window to a specific Space
    public func moveWindowToSpace(_ windowID: CGWindowID, targetSpace: CGSSpaceID) async throws {
        let cid = _CGSDefaultConnection()
        let windowSpace = try await getWindowSpace(windowID)
        
        guard windowSpace != targetSpace else { return } // Already there
        
        logger.info("Moving window \(windowID) from Space \(windowSpace) to \(targetSpace)")
        
        let windowArray = [windowID] as CFArray
        let targetSpaceArray = [targetSpace] as CFArray
        let windowSpaceArray = [windowSpace] as CFArray
        
        // Add to target Space
        CGSAddWindowsToSpaces(cid, windowArray, targetSpaceArray)
        
        // Delay for Sonoma+
        try await Task.sleep(nanoseconds: 100_000)
        
        // Remove from original Space
        CGSRemoveWindowsFromSpaces(cid, windowArray, windowSpaceArray)
    }
    
    // MARK: - Private Helpers
    
    private func waitForSpaceSwitch(targetSpace: CGSSpaceID, timeout: TimeInterval = 2.0) async throws {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if getCurrentSpace() == targetSpace {
                // Additional delay for animation completion
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms poll
        }
        
        throw SpaceError.switchTimeout(targetSpace: targetSpace)
    }
}

// MARK: - Supporting Types

public struct SpaceInfo: Sendable {
    public let id: CGSSpaceID
    public let name: String
    public let type: SpaceType
    public let displayID: CGSManagedDisplay
    public let isCurrent: Bool
}

public enum SpaceType: String, Sendable {
    case user = "user"
    case fullscreen = "fullscreen"
    case system = "system"
    case tiled = "tiled" // Stage Manager
}

public enum SpaceError: Error, CustomStringConvertible {
    case windowNotFound(windowID: CGWindowID)
    case spaceNotFound(spaceID: CGSSpaceID)
    case switchTimeout(targetSpace: CGSSpaceID)
    case invalidSpace(spaceID: CGSSpaceID)
    case multipleDisplaysNotSupported
    
    public var description: String {
        switch self {
        case .windowNotFound(let id):
            return "Window \(id) not found in any Space"
        case .spaceNotFound(let id):
            return "Space \(id) not found"
        case .switchTimeout(let space):
            return "Timeout waiting for Space switch to \(space)"
        case .invalidSpace(let id):
            return "Invalid Space ID: \(id)"
        case .multipleDisplaysNotSupported:
            return "Multiple display support not yet implemented"
        }
    }
}
```

### 2. WindowIdentityUtilities.swift

```swift
// Location: Core/PeekabooCore/Sources/PeekabooCore/Utilities/WindowIdentityUtilities.swift

import Foundation
import CoreGraphics
import AXorcist

// MARK: - Private API for CGWindowID ↔ AXUIElement

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ outWindowID: UnsafeMutablePointer<CGWindowID>) -> AXError

// MARK: - Window Identity Service

public final class WindowIdentityService: Sendable {
    public static let shared = WindowIdentityService()
    private let logger = Logger(subsystem: "PeekabooCore", category: "WindowIdentity")
    
    private init() {}
    
    /// Extract CGWindowID from an AXUIElement
    @MainActor
    public func extractWindowID(from element: Element) -> CGWindowID? {
        var windowID: CGWindowID = 0
        let error = _AXUIElementGetWindow(element.underlyingElement, &windowID)
        
        guard error == .success else {
            logger.debug("Failed to extract windowID: \(error)")
            return nil
        }
        
        return windowID
    }
    
    /// Find AXUIElement for a CGWindowID within an application
    @MainActor
    public func findAXWindow(windowID: CGWindowID, in app: Element) async -> Element? {
        // Try to get windows
        guard let windows = app.windows() else {
            logger.debug("No windows found for app")
            return nil
        }
        
        // Search through windows
        for window in windows {
            if let currentID = extractWindowID(from: window),
               currentID == windowID {
                return window
            }
        }
        
        logger.debug("Window \(windowID) not found in app")
        return nil
    }
    
    /// Find window by CGWindowID across all applications
    @MainActor
    public func findWindowByID(_ windowID: CGWindowID) async throws -> (app: Element, window: Element)? {
        // Get window list to find owning app
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        
        // Find window info
        guard let windowInfo = windowList.first(where: { 
            ($0[kCGWindowNumber as String] as? CGWindowID) == windowID 
        }) else {
            return nil
        }
        
        // Get owner PID
        guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t else {
            return nil
        }
        
        // Create AX element for app
        let appElement = Element(AXUIElementCreateApplication(ownerPID))
        
        // Find window in app
        guard let window = await findAXWindow(windowID: windowID, in: appElement) else {
            return nil
        }
        
        return (app: appElement, window: window)
    }
    
    /// Check if a window is still alive
    public func isWindowAlive(_ windowID: CGWindowID) -> Bool {
        let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        return windowList.contains { 
            ($0[kCGWindowNumber as String] as? CGWindowID) == windowID 
        }
    }
}

// MARK: - Window Reference

public struct WindowReference: Sendable {
    public let windowID: CGWindowID
    public let title: String
    public let appName: String
    public let bundleID: String?
    public let pid: pid_t
    
    @MainActor
    public func toAXElement() async -> Element? {
        let appElement = Element(AXUIElementCreateApplication(pid))
        return await WindowIdentityService.shared.findAXWindow(windowID: windowID, in: appElement)
    }
}
```

### 3. FocusUtilities.swift

```swift
// Location: Core/PeekabooCore/Sources/PeekabooCore/Utilities/FocusUtilities.swift

import Foundation
import ArgumentParser
import AXorcist

// MARK: - Focus Extension for Commands

public extension AsyncParsableCommand {
    
    /// Focus behavior options
    enum FocusMode: String, CaseIterable, ExpressibleByArgument {
        case auto = "auto"      // Smart behavior (default)
        case always = "always"  // Force focus
        case never = "never"    // Skip focus
    }
    
    /// Space switching behavior
    enum SpaceSwitchMode: String, CaseIterable, ExpressibleByArgument {
        case auto = "auto"          // Switch if needed (default)
        case always = "always"      // Always switch
        case never = "never"        // Never switch
    }
    
    /// Focus operation result
    struct FocusResult {
        public let focused: Bool
        public let app: String
        public let windowID: CGWindowID?
        public let windowTitle: String?
        public let didSwitchSpace: Bool
        public let movedWindow: Bool
        public let elapsedTime: TimeInterval
        
        public var skipped: Bool { !focused }
        
        public static func skipped(reason: String) -> FocusResult {
            FocusResult(
                focused: false,
                app: "",
                windowID: nil,
                windowTitle: nil,
                didSwitchSpace: false,
                movedWindow: false,
                elapsedTime: 0
            )
        }
    }
    
    /// Focus context with all window information
    struct FocusContext {
        let sessionId: String?
        let windowID: CGWindowID?
        let axIdentifier: String?
        let appIdentifier: String
        let windowTitle: String?
        let windowIndex: Int?
        let bundleID: String?
    }
    
    /// Focus options
    struct FocusOptions {
        var focusMode: FocusMode = .auto
        var spaceSwitchMode: SpaceSwitchMode = .auto
        var moveWindow: Bool = false
        var waitForSpaceSwitch: Bool = true
        var verifyFocus: Bool = true
        var focusTimeout: TimeInterval = 2.0
    }
    
    /// Main focus utility - ensures window has focus before interaction
    func ensureWindowFocus(
        sessionId: String? = nil,
        appIdentifier: String? = nil,
        windowTitle: String? = nil,
        windowIndex: Int? = nil,
        options: FocusOptions = FocusOptions()
    ) async throws -> FocusResult {
        let startTime = Date()
        let logger = Logger.shared
        
        // 1. Build focus context
        let context = try await buildFocusContext(
            sessionId: sessionId,
            appIdentifier: appIdentifier,
            windowTitle: windowTitle,
            windowIndex: windowIndex
        )
        
        // 2. Check if focus is needed
        if !shouldFocus(context, mode: options.focusMode) {
            logger.debug("Focus skipped - not needed for context")
            return .skipped(reason: "Focus not required")
        }
        
        // 3. Find target window
        let window = try await findTargetWindow(context)
        logger.debug("Found target window: \(window.title) (ID: \(window.windowID))")
        
        // 4. Handle Space management
        let spaceResult = try await handleSpaceManagement(
            window: window,
            options: options
        )
        
        // 5. Focus the window
        try await focusWindow(window, options: options)
        
        // 6. Update session if needed
        if let sessionId = sessionId {
            await updateSessionWindowInfo(sessionId, window: window)
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        logger.info("Window focused in \(String(format: "%.2f", elapsedTime))s")
        
        return FocusResult(
            focused: true,
            app: window.appName,
            windowID: window.windowID,
            windowTitle: window.title,
            didSwitchSpace: spaceResult.didSwitch,
            movedWindow: spaceResult.didMove,
            elapsedTime: elapsedTime
        )
    }
    
    // MARK: - Private Helpers
    
    private func buildFocusContext(
        sessionId: String?,
        appIdentifier: String?,
        windowTitle: String?,
        windowIndex: Int?
    ) async throws -> FocusContext {
        var windowID: CGWindowID? = nil
        var axIdentifier: String? = nil
        var app = appIdentifier
        var title = windowTitle
        var bundleID: String? = nil
        
        // Try to get info from session
        if let sessionId = sessionId {
            if let session = await SessionManager.shared.getSession(sessionId: sessionId) {
                windowID = session.windowID.map { CGWindowID($0) }
                axIdentifier = session.windowAXIdentifier
                app = app ?? session.applicationName
                title = title ?? session.windowTitle
                bundleID = session.bundleIdentifier
            }
        }
        
        // Validate we have enough info
        guard let appIdentifier = app else {
            throw FocusError.missingApplicationIdentifier
        }
        
        return FocusContext(
            sessionId: sessionId,
            windowID: windowID,
            axIdentifier: axIdentifier,
            appIdentifier: appIdentifier,
            windowTitle: title,
            windowIndex: windowIndex,
            bundleID: bundleID
        )
    }
    
    private func shouldFocus(_ context: FocusContext, mode: FocusMode) -> Bool {
        switch mode {
        case .always:
            return true
        case .never:
            return false
        case .auto:
            // Skip focus if we don't have specific window info
            return context.windowID != nil || 
                   context.windowTitle != nil || 
                   context.windowIndex != nil
        }
    }
    
    private func findTargetWindow(_ context: FocusContext) async throws -> WindowReference {
        let windowService = PeekabooServices.shared.windows
        let appService = PeekabooServices.shared.applications
        
        // 1. Try windowID first (most reliable)
        if let windowID = context.windowID {
            if WindowIdentityService.shared.isWindowAlive(windowID) {
                // Get window info
                if let (app, window) = await WindowIdentityService.shared.findWindowByID(windowID) {
                    let appInfo = try await appService.findApplication(identifier: context.appIdentifier)
                    return WindowReference(
                        windowID: windowID,
                        title: window.title() ?? "Untitled",
                        appName: appInfo.name,
                        bundleID: appInfo.bundleIdentifier,
                        pid: appInfo.processIdentifier
                    )
                }
            }
            // Window died, fall through to other methods
            Logger.shared.debug("Window \(windowID) no longer exists, trying other methods")
        }
        
        // 2. Try AXIdentifier (developer-provided)
        if let axIdentifier = context.axIdentifier {
            // Implementation would search for window by AX identifier
            // This is app-specific and rarely used
        }
        
        // 3. Get app and search windows
        let appInfo = try await appService.findApplication(identifier: context.appIdentifier)
        let windows = try await appService.listWindows(for: context.appIdentifier)
        
        guard !windows.isEmpty else {
            throw FocusError.noWindowsAvailable(app: context.appIdentifier)
        }
        
        // 4. Find by title or index
        let targetWindow: ServiceWindowInfo
        
        if let title = context.windowTitle {
            guard let window = windows.first(where: { $0.title.contains(title) }) else {
                throw FocusError.windowNotFound(
                    app: context.appIdentifier,
                    criteria: "title: \(title)"
                )
            }
            targetWindow = window
        } else if let index = context.windowIndex {
            guard index < windows.count else {
                throw FocusError.windowNotFound(
                    app: context.appIdentifier,
                    criteria: "index: \(index)"
                )
            }
            targetWindow = windows[index]
        } else {
            // Default to frontmost window
            targetWindow = windows[0]
        }
        
        return WindowReference(
            windowID: CGWindowID(targetWindow.windowID),
            title: targetWindow.title,
            appName: appInfo.name,
            bundleID: appInfo.bundleIdentifier,
            pid: appInfo.processIdentifier
        )
    }
    
    private func handleSpaceManagement(
        window: WindowReference,
        options: FocusOptions
    ) async throws -> (didSwitch: Bool, didMove: Bool) {
        let spaceService = SpaceManagementService.shared
        
        // Get current and window Spaces
        let currentSpace = spaceService.getCurrentSpace()
        let windowSpace = try await spaceService.getWindowSpace(window.windowID)
        
        // Already on same Space?
        if windowSpace == currentSpace && options.spaceSwitchMode != .always {
            return (didSwitch: false, didMove: false)
        }
        
        // Handle window movement
        if options.moveWindow {
            try await spaceService.moveWindowToCurrentSpace(window.windowID)
            return (didSwitch: false, didMove: true)
        }
        
        // Handle Space switching
        if options.spaceSwitchMode != .never {
            try await spaceService.switchToSpace(
                windowSpace,
                waitForSwitch: options.waitForSpaceSwitch
            )
            return (didSwitch: true, didMove: false)
        }
        
        // Can't focus - window is on different Space
        if windowSpace != currentSpace {
            throw FocusError.windowInDifferentSpace(
                windowID: window.windowID,
                currentSpace: currentSpace,
                windowSpace: windowSpace
            )
        }
        
        return (didSwitch: false, didMove: false)
    }
    
    @MainActor
    private func focusWindow(_ window: WindowReference, options: FocusOptions) async throws {
        // Get AX elements
        guard let axWindow = await window.toAXElement() else {
            throw FocusError.windowNotAccessible(windowID: window.windowID)
        }
        
        guard let app = axWindow.parent() else {
            throw FocusError.applicationNotAccessible(app: window.appName)
        }
        
        // 1. Activate application
        if !app.activate() {
            throw FocusError.applicationActivationFailed(app: window.appName)
        }
        
        // 2. Focus window
        if !axWindow.focusWindow() {
            throw FocusError.windowFocusFailed(windowID: window.windowID)
        }
        
        // 3. Verify if requested
        if options.verifyFocus {
            let verified = try await verifyWindowFocus(
                window: axWindow,
                windowID: window.windowID,
                timeout: options.focusTimeout
            )
            
            if !verified {
                throw FocusError.focusVerificationFailed(windowID: window.windowID)
            }
        }
    }
    
    @MainActor
    private func verifyWindowFocus(
        window: Element,
        windowID: CGWindowID,
        timeout: TimeInterval = 2.0
    ) async throws -> Bool {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Check window is focused
            if window.isFocused() == true {
                // Check app is frontmost
                if let app = window.parent(),
                   app.isFrontmost() == true {
                    // Verify it's still the same window
                    if let currentID = WindowIdentityService.shared.extractWindowID(from: window),
                       currentID == windowID {
                        return true
                    }
                }
            }
            
            // Check if window was destroyed
            if !WindowIdentityService.shared.isWindowAlive(windowID) {
                throw FocusError.windowDestroyed(windowID: windowID)
            }
            
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        return false
    }
    
    private func updateSessionWindowInfo(_ sessionId: String, window: WindowReference) async {
        // Update session with latest window info
        if var session = await SessionManager.shared.getSession(sessionId: sessionId) {
            session.windowID = Int(window.windowID)
            session.windowTitle = window.title
            session.applicationName = window.appName
            session.bundleIdentifier = window.bundleID
            session.lastFocusTime = Date()
            
            await SessionManager.shared.updateSession(sessionId: sessionId, data: session)
        }
    }
}

// MARK: - Focus Errors

public enum FocusError: Error, CustomStringConvertible {
    case missingApplicationIdentifier
    case appNotRunning(String)
    case windowNotFound(app: String, criteria: String)
    case windowDestroyed(windowID: CGWindowID)
    case noWindowsAvailable(app: String)
    case windowInDifferentSpace(windowID: CGWindowID, currentSpace: CGSSpaceID, windowSpace: CGSSpaceID)
    case windowNotAccessible(windowID: CGWindowID)
    case applicationNotAccessible(app: String)
    case applicationActivationFailed(app: String)
    case windowFocusFailed(windowID: CGWindowID)
    case focusVerificationFailed(windowID: CGWindowID)
    case focusTimeout(app: String, windowID: CGWindowID?)
    case accessibilityDenied
    case windowMinimized(windowID: CGWindowID)
    
    public var description: String {
        switch self {
        case .missingApplicationIdentifier:
            return "No application identifier provided"
        case .appNotRunning(let app):
            return "Application '\(app)' is not running"
        case .windowNotFound(let app, let criteria):
            return "Window not found in '\(app)' matching: \(criteria)"
        case .windowDestroyed(let id):
            return "Window \(id) was closed or destroyed"
        case .noWindowsAvailable(let app):
            return "No windows available for '\(app)'"
        case .windowInDifferentSpace(let id, let current, let window):
            return "Window \(id) is on Space \(window), current Space is \(current). Use --space-switch or --move-here"
        case .windowNotAccessible(let id):
            return "Cannot access window \(id) via accessibility API"
        case .applicationNotAccessible(let app):
            return "Cannot access application '\(app)' via accessibility API"
        case .applicationActivationFailed(let app):
            return "Failed to activate application '\(app)'"
        case .windowFocusFailed(let id):
            return "Failed to focus window \(id)"
        case .focusVerificationFailed(let id):
            return "Failed to verify focus for window \(id)"
        case .focusTimeout(let app, let id):
            if let id = id {
                return "Timeout waiting for window \(id) in '\(app)' to focus"
            } else {
                return "Timeout waiting for '\(app)' to focus"
            }
        case .accessibilityDenied:
            return "Accessibility permission denied. Grant via System Settings > Privacy & Security > Accessibility"
        case .windowMinimized(let id):
            return "Window \(id) is minimized"
        }
    }
}
```

### 4. Enhanced Session Model

```swift
// Update: Core/PeekabooCore/Sources/PeekabooCore/Core/Models/Session.swift

public struct UIAutomationSession: Codable, Sendable {
    public static let currentVersion = 6 // Increment version
    
    // Existing fields
    public let version: Int
    public var screenshotPath: String?
    public var annotatedPath: String?
    public var uiMap: [String: UIElement]
    public var lastUpdateTime: Date
    public var applicationName: String?
    public var windowTitle: String?
    public var windowBounds: CGRect?
    public var menuBar: MenuBarData?
    
    // NEW: Window identity fields
    public var windowID: Int?  // CGWindowID as Int
    public var windowAXIdentifier: String? // If app provides window.identifier
    public var bundleIdentifier: String? // App bundle ID
    public var lastFocusTime: Date? // When window was last focused
    
    // Computed property for staleness
    public var isWindowInfoStale: Bool {
        guard let lastFocus = lastFocusTime else { return true }
        return Date().timeIntervalSince(lastFocus) > 300 // 5 minutes
    }
    
    // ... rest of implementation
}
```

### 5. Window Focus Command Enhancement

```swift
// Update: Apps/CLI/Sources/peekaboo/Commands/System/WindowCommand.swift

struct FocusSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "focus",
        abstract: "Bring a window to the foreground, switching Spaces if needed",
        discussion: """
        Focuses a window and ensures it's visible and ready for interaction.
        
        By default, if the window is on a different Space, Peekaboo will
        switch to that Space. You can control this behavior with options.
        
        EXAMPLES:
          # Focus window, auto-switch Space if needed
          peekaboo window focus --app Safari
          
          # Never switch Spaces
          peekaboo window focus --app Terminal --space-switch never
          
          # Move window to current Space
          peekaboo window focus --app "VS Code" --move-here
          
          # Focus specific window by title
          peekaboo window focus --app Chrome --window-title "GitHub"
        """)
    
    @OptionGroup var windowOptions: WindowIdentificationOptions
    
    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false
    
    // NEW: Space management options
    @Option(
        name: .long,
        help: "Space switching behavior: auto, always, never"
    )
    var spaceSwitch: SpaceSwitchMode = .auto
    
    @Flag(
        name: .long,
        help: "Move window to current Space instead of switching"
    )
    var moveHere = false
    
    @Flag(
        name: .long,
        help: "Skip focus verification (faster but less reliable)"
    )
    var noVerify = false
    
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)
        
        do {
            try self.windowOptions.validate()
            
            // Build focus options
            let focusOptions = FocusOptions(
                focusMode: .always, // Always focus for explicit command
                spaceSwitchMode: self.moveHere ? .never : self.spaceSwitch,
                moveWindow: self.moveHere,
                verifyFocus: !self.noVerify
            )
            
            // Perform focus with Space management
            let result = try await ensureWindowFocus(
                appIdentifier: self.windowOptions.app,
                windowTitle: self.windowOptions.windowTitle,
                windowIndex: self.windowOptions.windowIndex,
                options: focusOptions
            )
            
            // Get final window info
            let windows = try await PeekabooServices.shared.windows.listWindows(
                target: self.windowOptions.toWindowTarget()
            )
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            
            // Create result
            let data = FocusActionResult(
                action: "focus",
                success: true,
                app_name: result.app,
                window_title: result.windowTitle ?? windowInfo?.title ?? "Untitled",
                window_id: result.windowID.map { Int($0) },
                did_switch_space: result.didSwitchSpace,
                moved_window: result.movedWindow,
                execution_time: result.elapsedTime
            )
            
            output(data) {
                var message = "Successfully focused window '\(data.window_title)' of \(data.app_name)"
                
                if result.didSwitchSpace {
                    message += " (switched Space)"
                } else if result.movedWindow {
                    message += " (moved to current Space)"
                }
                
                print(message)
            }
            
        } catch let error as FocusError {
            handleFocusError(error)
            throw ExitCode(1)
        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
    
    private func handleFocusError(_ error: FocusError) {
        if self.jsonOutput {
            let errorCode: ErrorCode = switch error {
            case .appNotRunning:
                .APP_NOT_FOUND
            case .windowNotFound, .windowDestroyed, .noWindowsAvailable:
                .WINDOW_NOT_FOUND
            case .windowInDifferentSpace:
                .WINDOW_IN_DIFFERENT_SPACE
            case .accessibilityDenied:
                .PERMISSION_DENIED
            default:
                .INTERACTION_FAILED
            }
            
            outputError(
                message: error.description,
                code: errorCode,
                details: "Focus operation failed"
            )
        } else {
            fputs("❌ \(error.description)\n", stderr)
        }
    }
}

// Add new result type
struct FocusActionResult: Codable {
    let action: String
    let success: Bool
    let app_name: String
    let window_title: String
    let window_id: Int?
    let did_switch_space: Bool
    let moved_window: Bool
    let execution_time: TimeInterval
}

// Add new error code
extension ErrorCode {
    static let WINDOW_IN_DIFFERENT_SPACE = ErrorCode(rawValue: "WINDOW_IN_DIFFERENT_SPACE")
}
```

### 6. Command Integration (Click Example)

```swift
// Update: Apps/CLI/Sources/peekaboo/Commands/Interaction/ClickCommand.swift

struct ClickCommand: AsyncParsableCommand {
    // Existing fields...
    
    // NEW: Focus options
    @Option(
        name: .long,
        help: "Focus behavior before clicking: auto, always, never"
    )
    var focus: FocusMode = .auto
    
    @Option(
        name: .long,
        help: "Space switching if window is on different Space: auto, always, never"
    )
    var spaceSwitch: SpaceSwitchMode = .auto
    
    @Flag(
        name: .long,
        help: "Move window to current Space instead of switching"
    )
    var moveWindow = false
    
    func run() async throws {
        // ... existing validation ...
        
        // Focus window if we have session or app context
        if self.session != nil || self.on != nil {
            let focusOptions = FocusOptions(
                focusMode: self.focus,
                spaceSwitchMode: self.moveWindow ? .never : self.spaceSwitch,
                moveWindow: self.moveWindow
            )
            
            _ = try await ensureWindowFocus(
                sessionId: self.session,
                options: focusOptions
            )
        }
        
        // ... rest of click logic ...
    }
}
```

### 7. New Space Command

```swift
// New file: Apps/CLI/Sources/peekaboo/Commands/System/SpaceCommand.swift

import ArgumentParser
import Foundation
import PeekabooCore

struct SpaceCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "space",
        abstract: "Manage macOS Spaces (virtual desktops)",
        discussion: """
        Control macOS Spaces including listing, switching, and moving windows.
        
        EXAMPLES:
          # List all Spaces
          peekaboo space list
          
          # Switch to Space 2
          peekaboo space switch --to 2
          
          # Move Safari to Space 3
          peekaboo space move-window --app Safari --to 3
          
          # Get current Space info
          peekaboo space current
        """,
        subcommands: [
            ListSubcommand.self,
            CurrentSubcommand.self,
            SwitchSubcommand.self,
            MoveWindowSubcommand.self,
            WhereIsSubcommand.self
        ])
    
    // MARK: - List Spaces
    
    struct ListSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all Spaces")
        
        @Flag(name: .long, help: "Include system and fullscreen Spaces")
        var all = false
        
        @Flag(name: .long, help: "Output in JSON format")
        var jsonOutput = false
        
        func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)
            
            do {
                let spaces = await SpaceManagementService.shared.getUserSpaces()
                
                let data = SpaceListData(
                    spaces: spaces.map { space in
                        SpaceData(
                            id: Int(space.id),
                            name: space.name,
                            is_current: space.isCurrent,
                            display_id: Int(space.displayID),
                            type: space.type.rawValue
                        )
                    },
                    current_space_id: Int(SpaceManagementService.shared.getCurrentSpace())
                )
                
                output(data) {
                    print("Spaces:")
                    for space in data.spaces {
                        let current = space.is_current ? " (current)" : ""
                        print("  Space \(space.id): \(space.name)\(current)")
                    }
                }
                
            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }
    
    // MARK: - Current Space
    
    struct CurrentSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
        static let configuration = CommandConfiguration(
            commandName: "current",
            abstract: "Show current Space information")
        
        @Flag(name: .long, help: "Output in JSON format")
        var jsonOutput = false
        
        func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)
            
            do {
                let currentID = SpaceManagementService.shared.getCurrentSpace()
                let spaces = await SpaceManagementService.shared.getUserSpaces()
                
                guard let current = spaces.first(where: { $0.id == currentID }) else {
                    throw SpaceError.spaceNotFound(spaceID: currentID)
                }
                
                let data = SpaceData(
                    id: Int(current.id),
                    name: current.name,
                    is_current: true,
                    display_id: Int(current.displayID),
                    type: current.type.rawValue
                )
                
                output(data) {
                    print("Current Space: \(data.name) (ID: \(data.id))")
                }
                
            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }
    
    // MARK: - Switch Space
    
    struct SwitchSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
        static let configuration = CommandConfiguration(
            commandName: "switch",
            abstract: "Switch to a different Space")
        
        @Option(name: .long, help: "Target Space number (1-based)")
        var to: Int
        
        @Flag(name: .long, help: "Don't wait for switch animation")
        var noWait = false
        
        @Flag(name: .long, help: "Output in JSON format")
        var jsonOutput = false
        
        func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)
            
            do {
                let spaces = await SpaceManagementService.shared.getUserSpaces()
                
                // Convert 1-based to 0-based index
                let index = self.to - 1
                guard index >= 0 && index < spaces.count else {
                    throw ValidationError("Space \(self.to) does not exist. Available: 1-\(spaces.count)")
                }
                
                let targetSpace = spaces[index]
                
                try await SpaceManagementService.shared.switchToSpace(
                    targetSpace.id,
                    waitForSwitch: !self.noWait
                )
                
                let data = SpaceSwitchResult(
                    action: "switch",
                    success: true,
                    from_space_id: Int(SpaceManagementService.shared.getCurrentSpace()),
                    to_space_id: Int(targetSpace.id),
                    space_name: targetSpace.name
                )
                
                output(data) {
                    print("Switched to \(targetSpace.name)")
                }
                
            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }
    
    // MARK: - Move Window
    
    struct MoveWindowSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
        static let configuration = CommandConfiguration(
            commandName: "move-window",
            abstract: "Move a window to a different Space")
        
        @Option(name: .long, help: "Target application")
        var app: String
        
        @Option(name: .long, help: "Window title (partial match)")
        var windowTitle: String?
        
        @Option(name: .long, help: "Target Space number (1-based)")
        var to: Int
        
        @Flag(name: .long, help: "Output in JSON format")
        var jsonOutput = false
        
        func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)
            
            do {
                // Find target window
                let windows = try await PeekabooServices.shared.windows.listWindows(
                    target: .application(self.app)
                )
                
                let targetWindow: ServiceWindowInfo
                if let title = self.windowTitle {
                    guard let window = windows.first(where: { $0.title.contains(title) }) else {
                        throw ValidationError("No window found with title containing '\(title)'")
                    }
                    targetWindow = window
                } else {
                    guard let window = windows.first else {
                        throw ValidationError("No windows found for '\(self.app)'")
                    }
                    targetWindow = window
                }
                
                // Get target Space
                let spaces = await SpaceManagementService.shared.getUserSpaces()
                let index = self.to - 1
                guard index >= 0 && index < spaces.count else {
                    throw ValidationError("Space \(self.to) does not exist")
                }
                
                let targetSpace = spaces[index]
                
                // Move window
                try await SpaceManagementService.shared.moveWindowToSpace(
                    CGWindowID(targetWindow.windowID),
                    targetSpace: targetSpace.id
                )
                
                let data = WindowMoveResult(
                    action: "move_window",
                    success: true,
                    window_title: targetWindow.title,
                    app_name: self.app,
                    to_space_id: Int(targetSpace.id),
                    space_name: targetSpace.name
                )
                
                output(data) {
                    print("Moved '\(targetWindow.title)' to \(targetSpace.name)")
                }
                
            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }
    
    // MARK: - Where Is Window
    
    struct WhereIsSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
        static let configuration = CommandConfiguration(
            commandName: "where-is",
            abstract: "Find which Space contains a window")
        
        @Option(name: .long, help: "Target application")
        var app: String
        
        @Option(name: .long, help: "Window title (partial match)")
        var windowTitle: String?
        
        @Flag(name: .long, help: "Output in JSON format")
        var jsonOutput = false
        
        func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)
            
            do {
                // Find window
                let windows = try await PeekabooServices.shared.windows.listWindows(
                    target: .application(self.app)
                )
                
                let results = try await withThrowingTaskGroup(of: WindowLocationResult.self) { group in
                    for window in windows {
                        if let title = self.windowTitle,
                           !window.title.contains(title) {
                            continue
                        }
                        
                        group.addTask {
                            let spaceID = try await SpaceManagementService.shared.getWindowSpace(
                                CGWindowID(window.windowID)
                            )
                            
                            let spaces = await SpaceManagementService.shared.getUserSpaces()
                            let spaceInfo = spaces.first { $0.id == spaceID }
                            
                            return WindowLocationResult(
                                window_title: window.title,
                                window_id: window.windowID,
                                space_id: Int(spaceID),
                                space_name: spaceInfo?.name ?? "Unknown",
                                is_current_space: spaceID == SpaceManagementService.shared.getCurrentSpace()
                            )
                        }
                    }
                    
                    var results: [WindowLocationResult] = []
                    for try await result in group {
                        results.append(result)
                    }
                    return results
                }
                
                let data = WindowLocationData(
                    app_name: self.app,
                    windows: results
                )
                
                output(data) {
                    print("Windows for \(self.app):")
                    for window in results {
                        let current = window.is_current_space ? " (current)" : ""
                        print("  '\(window.window_title)' - Space \(window.space_id): \(window.space_name)\(current)")
                    }
                }
                
            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }
}

// MARK: - Data Types

struct SpaceData: Codable {
    let id: Int
    let name: String
    let is_current: Bool
    let display_id: Int
    let type: String
}

struct SpaceListData: Codable {
    let spaces: [SpaceData]
    let current_space_id: Int
}

struct SpaceSwitchResult: Codable {
    let action: String
    let success: Bool
    let from_space_id: Int
    let to_space_id: Int
    let space_name: String
}

struct WindowMoveResult: Codable {
    let action: String
    let success: Bool
    let window_title: String
    let app_name: String
    let to_space_id: Int
    let space_name: String
}

struct WindowLocationResult: Codable {
    let window_title: String
    let window_id: Int
    let space_id: Int
    let space_name: String
    let is_current_space: Bool
}

struct WindowLocationData: Codable {
    let app_name: String
    let windows: [WindowLocationResult]
}
```

### 8. Update main.swift

Add SpaceCommand to the subcommands list:

```swift
// In Apps/CLI/Sources/peekaboo/main.swift

static let configuration = CommandConfiguration(
    // ... existing config ...
    subcommands: [
        // ... existing commands ...
        WindowCommand.self,
        SpaceCommand.self,  // NEW
        MenuCommand.self,
        // ... rest of commands ...
    ]
)
```

## Testing Strategy

### Unit Tests

1. **SpaceUtilities Tests**
   - Test Space detection
   - Test Space switching
   - Test window movement
   - Mock CGS functions for testing

2. **WindowIdentity Tests**
   - Test CGWindowID extraction
   - Test window lookup
   - Test lifecycle detection

3. **Focus Utility Tests**
   - Test focus scenarios
   - Test error cases
   - Test Space integration

### Integration Tests

1. **Cross-Space Focus**
   - Create window on Space 2
   - Focus from Space 1
   - Verify Space switch

2. **Window Movement**
   - Move window between Spaces
   - Verify window location
   - Test with multiple windows

3. **Session Persistence**
   - Store windowID in session
   - Close and reopen window
   - Verify fallback to title search

### Manual Testing Checklist

- [ ] Focus window on same Space
- [ ] Focus window on different Space
- [ ] Move window to current Space
- [ ] Focus minimized window
- [ ] Focus full-screen app
- [ ] Handle window closure during focus
- [ ] Test with Stage Manager enabled
- [ ] Test with multiple displays
- [ ] Test all error scenarios

## Documentation Plan

### docs/focus.md

```markdown
# Window Focus and Space Management

Peekaboo provides intelligent window focusing that works across macOS Spaces.

## Quick Start

```bash
# Focus a window (auto-switches Space if needed)
peekaboo window focus --app Safari

# Focus without switching Spaces
peekaboo window focus --app Terminal --space-switch never

# Move window to current Space
peekaboo window focus --app "VS Code" --move-here
```

## How It Works

1. **Window Identity**: Peekaboo uses stable CGWindowID to track windows
2. **Space Detection**: Automatically detects which Space contains a window
3. **Smart Switching**: Switches Spaces only when necessary
4. **Session Memory**: Remembers windows across commands

## Focus Options

### For `window focus` Command

- `--space-switch [auto|always|never]`: Control Space switching
- `--move-here`: Move window to current Space instead of switching
- `--no-verify`: Skip focus verification (faster)

### For Interactive Commands

Commands like `click`, `type`, and `menu` support:
- `--focus [auto|always|never]`: Control focus behavior
- `--space-switch [auto|always|never]`: Control Space switching
- `--move-window`: Move to current Space

## Space Management

### List Spaces
```bash
peekaboo space list
```

### Switch Spaces
```bash
peekaboo space switch --to 2
```

### Move Windows
```bash
peekaboo space move-window --app Safari --to 3
```

### Find Windows
```bash
peekaboo space where-is --app Chrome
```

## Best Practices

1. **Use Sessions**: The `see` command stores window identity
2. **Prefer Switching**: Less disruptive than moving windows
3. **Handle Errors**: Windows can close or move unexpectedly

## Troubleshooting

### "Window in different Space" Error
- Use `--space-switch auto` to allow switching
- Or use `--move-here` to bring window to you

### "Window not found" Error
- Window may have been closed
- Try using window title instead of index

### Permission Errors
- Grant Accessibility permission in System Settings
- Some Space operations require additional permissions
```

## Performance Considerations

1. **CGWindowID Lookup**: O(1) when available
2. **Space Detection**: ~5-10ms per window
3. **Space Switching**: ~200-500ms with animation
4. **Focus Verification**: 50ms polling, 2s timeout
5. **Session Cache**: 100ms TTL for Space info

## Security Considerations

1. **Private API Usage**: Weak-link CGS functions
2. **Graceful Degradation**: Fall back if APIs unavailable
3. **Permission Checks**: Verify accessibility before operations
4. **Sandbox Compatibility**: Document entitlement requirements

## Future Enhancements

1. **Multi-Display Support**: Handle windows on different displays
2. **Stage Manager**: Better integration with Stage Manager
3. **Window Groups**: Focus multiple related windows
4. **Space Templates**: Save and restore Space layouts
5. **Automation Scripts**: Higher-level window management

## Success Metrics

1. **Reliability**: 99%+ successful focus operations
2. **Performance**: <100ms for same-Space focus
3. **User Experience**: Intuitive Space switching
4. **Error Recovery**: Graceful handling of edge cases