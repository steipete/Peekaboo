/// Space (Virtual Desktop) Management Utilities
///
/// This file provides utilities for managing macOS Spaces (virtual desktops) using
/// private CoreGraphics APIs. These APIs enable advanced window management features
/// that are not available through public frameworks.
///
/// ## \(AgentDisplayTokens.Status.warning) Important Warning
///
/// This implementation relies on private CGS (CoreGraphics Services) APIs that:
/// - Are undocumented and unsupported by Apple
/// - May change or break between macOS versions
/// - Could cause crashes if used incorrectly
/// - May require special entitlements in the future
///
/// ## Key Features
///
/// 1. **Space Information**: List all Spaces and their properties
/// 2. **Space Navigation**: Switch between Spaces programmatically
/// 3. **Window Movement**: Move windows between Spaces
/// 4. **Space Detection**: Find which Space contains a window
///
/// ## Requirements (macOS 15 Sequoia+)
///
/// - Screen Recording permission (for CGSCopySpacesForWindows)
/// - Accessibility permission (for window manipulation)
/// - Must be called from main thread
/// - NSApplication must be initialized
///
/// ## Usage Examples
///
/// ```swift
/// let service = SpaceManagementService()
///
/// // List all Spaces
/// let spaces = service.getAllSpaces()
/// for space in spaces {
///     print("Space \(space.id): \(space.type) - Active: \(space.isActive)")
/// }
///
/// // Switch to a Space
/// try await service.switchToSpace(spaceNumber: 2)
///
/// // Move window to current Space
/// try service.moveWindowToCurrentSpace(windowID: 1234)
/// ```
///
/// ## References
///
/// - Based on reverse-engineered CGS APIs
/// - Similar implementations: yabai, Amethyst, Rectangle
/// - No official documentation available

import AppKit
@preconcurrency import CoreFoundation
import Foundation

// MARK: - CGSSpace Private API Declarations

/// Connection identifier for communicating with WindowServer
public typealias CGSConnectionID = UInt32

/// Unique identifier for a Space (virtual desktop)
public typealias CGSSpaceID = UInt64 // size_t in C

/// Managed display identifier
public typealias CGSManagedDisplay = UInt32

/// Window level (z-order)
public typealias CGWindowLevel = Int32

/// Space type enum
public typealias CGSSpaceType = Int

/// Use _CGSDefaultConnection instead of CGSMainConnectionID for better reliability
@_silgen_name("_CGSDefaultConnection")
func _CGSDefaultConnection() -> CGSConnectionID

/// Returns an array of all space IDs matching the given mask
/// The result is a CFArray that may contain space IDs as NSNumbers
@_silgen_name("CGSCopySpaces")
func CGSCopySpaces(_ cid: CGSConnectionID, _ mask: Int) -> CFArray?

/// Given an array of window numbers, returns the IDs of the spaces those windows lie on
/// The windowIDs parameter should be a CFArray of CGWindowID values
@_silgen_name("CGSCopySpacesForWindows")
func CGSCopySpacesForWindows(_ cid: CGSConnectionID, _ mask: Int, _ windowIDs: CFArray) -> CFArray?

/// Gets the type of a space (user, fullscreen, system)
@_silgen_name("CGSSpaceGetType")
func CGSSpaceGetType(_ cid: CGSConnectionID, _ sid: CGSSpaceID) -> CGSSpaceType

/// Gets the ID of the space currently visible to the user
@_silgen_name("CGSGetActiveSpace")
func CGSGetActiveSpace(_ cid: CGSConnectionID) -> CGSSpaceID

/// Creates a new space with the given options dictionary
/// Valid keys are: "type": CFNumberRef, "uuid": CFStringRef
@_silgen_name("CGSSpaceCreate")
func CGSSpaceCreate(_ cid: CGSConnectionID, _ null: UnsafeRawPointer, _ options: CFDictionary) -> CGSSpaceID

/// Removes and destroys the space corresponding to the given space ID
@_silgen_name("CGSSpaceDestroy")
func CGSSpaceDestroy(_ cid: CGSConnectionID, _ sid: CGSSpaceID)

/// Get and set the human-readable name of a space
@_silgen_name("CGSSpaceCopyName")
func CGSSpaceCopyName(_ cid: CGSConnectionID, _ sid: CGSSpaceID) -> CFString

@_silgen_name("CGSSpaceSetName")
func CGSSpaceSetName(_ cid: CGSConnectionID, _ sid: CGSSpaceID, _ name: CFString) -> CGError

/// Returns an array of PIDs of applications that have ownership of a given space
@_silgen_name("CGSSpaceCopyOwners")
func CGSSpaceCopyOwners(_ cid: CGSConnectionID, _ sid: CGSSpaceID) -> CFArray

/// Connection-local data in a given space
@_silgen_name("CGSSpaceCopyValues")
func CGSSpaceCopyValues(_ cid: CGSConnectionID, _ space: CGSSpaceID) -> CFDictionary

@_silgen_name("CGSSpaceSetValues")
func CGSSpaceSetValues(_ cid: CGSConnectionID, _ sid: CGSSpaceID, _ values: CFDictionary) -> CGError

/// Changes the active space for a given display
/// Takes a CFString display identifier
@_silgen_name("CGSManagedDisplaySetCurrentSpace")
func CGSManagedDisplaySetCurrentSpace(_ cid: CGSConnectionID, _ display: CFString, _ space: CGSSpaceID)

/// Given an array of space IDs, each space is shown to the user
@_silgen_name("CGSShowSpaces")
func CGSShowSpaces(_ cid: CGSConnectionID, _ spaces: CFArray)

/// Given an array of space IDs, each space is hidden from the user
@_silgen_name("CGSHideSpaces")
func CGSHideSpaces(_ cid: CGSConnectionID, _ spaces: CFArray)

/// Main display identifier constant
@_silgen_name("kCGSPackagesMainDisplayIdentifier")
let kCGSPackagesMainDisplayIdentifier: CFString

/// Given an array of window numbers and an array of space IDs, adds each window to each space
@_silgen_name("CGSAddWindowsToSpaces")
func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windows: CFArray, _ spaces: CFArray)

/// Given an array of window numbers and an array of space IDs, removes each window from each space
@_silgen_name("CGSRemoveWindowsFromSpaces")
func CGSRemoveWindowsFromSpaces(_ cid: CGSConnectionID, _ windows: CFArray, _ spaces: CFArray)

/// Returns information about managed display spaces
@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ cid: CGSConnectionID) -> CFArray

/// Get the level (z-order) of a window
@_silgen_name("CGSGetWindowLevel")
func CGSGetWindowLevel(
    _ cid: CGSConnectionID,
    _ windowID: CGWindowID,
    _ outLevel: UnsafeMutablePointer<CGWindowLevel>) -> CGError

// Space type constants (from CGSSpaceType enum)
private let kCGSSpaceUser = 0 // User-created desktop spaces
private let kCGSSpaceFullscreen = 1 // Fullscreen spaces
private let kCGSSpaceSystem = 2 // System spaces e.g. Dashboard
private let kCGSSpaceTiled = 5 // Tiled spaces (newer macOS)

// Space mask constants (from CGSSpaceMask enum)
private let kCGSSpaceIncludesCurrent = 1 << 0
private let kCGSSpaceIncludesOthers = 1 << 1
private let kCGSSpaceIncludesUser = 1 << 2
private let kCGSSpaceVisible = 1 << 16

private let kCGSCurrentSpaceMask = kCGSSpaceIncludesUser | kCGSSpaceIncludesCurrent
private let kCGSOtherSpacesMask = kCGSSpaceIncludesOthers | kCGSSpaceIncludesCurrent
private let kCGSAllSpacesMask = kCGSSpaceIncludesUser | kCGSSpaceIncludesOthers | kCGSSpaceIncludesCurrent
private let kCGSAllVisibleSpacesMask = kCGSSpaceVisible | kCGSAllSpacesMask

// MARK: - Space Information

public struct SpaceInfo: Sendable {
    public let id: UInt64
    public let type: SpaceType
    public let isActive: Bool
    public let displayID: CGDirectDisplayID?
    public let name: String?
    public let ownerPIDs: [Int]

    public enum SpaceType: String, Sendable {
        case user
        case fullscreen
        case system
        case tiled
        case unknown
    }
}

// MARK: - Space Management Service

@MainActor
public final class SpaceManagementService {
    private var _connection: CGSConnectionID?
    private let visualizerClient = VisualizationClient.shared

    private var connection: CGSConnectionID {
        if _connection == nil {
            // We're guaranteed to be on main thread due to @MainActor

            // Initialize NSApplication if needed
            _ = NSApplication.shared

            _connection = _CGSDefaultConnection()

            // Verify we got a valid connection
            if _connection == 0 {
                print("WARNING: Failed to get CGS connection")
            }
        }
        return _connection!
    }

    public init() {
        // Defer connection initialization until first use
        Task { @MainActor in
            self.visualizerClient.connect()
        }
    }

    // MARK: - Space Information

    /// Get information about all Spaces
    public func getAllSpaces() -> [SpaceInfo] {
        // Check if we have a valid connection
        guard connection != 0 else {
            print("ERROR: Invalid CGS connection")
            return []
        }

        guard let spacesRef = CGSCopySpaces(connection, kCGSAllSpacesMask) else {
            print("ERROR: CGSCopySpaces returned nil")
            return []
        }

        // Try to interpret the result as an array
        let spacesArray = spacesRef as NSArray
        let activeSpace = CGSGetActiveSpace(connection)

        var spaces: [SpaceInfo] = []

        // Handle both array of IDs and array of dictionaries
        for element in spacesArray {
            var spaceID: CGSSpaceID?

            if let id = element as? Int {
                // Direct space ID
                spaceID = CGSSpaceID(id)
            } else if let dict = element as? [String: Any] {
                // Dictionary with space info - try different keys
                if let id = dict["ManagedSpaceID"] as? Int {
                    spaceID = CGSSpaceID(id)
                } else if let id = dict["id64"] as? Int {
                    spaceID = CGSSpaceID(id)
                } else if let id = dict["id"] as? Int {
                    spaceID = CGSSpaceID(id)
                }
            }

            guard let validSpaceID = spaceID else { continue }

            let spaceType = CGSSpaceGetType(connection, validSpaceID)
            let type: SpaceInfo.SpaceType = switch spaceType {
            case kCGSSpaceUser: .user
            case kCGSSpaceFullscreen: .fullscreen
            case kCGSSpaceSystem: .system
            case kCGSSpaceTiled: .tiled
            default: .unknown
            }

            // Get additional space information
            let spaceName = CGSSpaceCopyName(connection, validSpaceID) as String?
            let ownerPIDsArray = CGSSpaceCopyOwners(connection, validSpaceID) as? [Int] ?? []

            spaces.append(SpaceInfo(
                id: validSpaceID,
                type: type,
                isActive: validSpaceID == activeSpace,
                displayID: nil,
                name: spaceName,
                ownerPIDs: ownerPIDsArray))
        }

        return spaces
    }

    /// Get information about all Spaces organized by display
    public func getAllSpacesByDisplay() -> [CGDirectDisplayID: [SpaceInfo]] {
        // Check if we have a valid connection
        guard connection != 0 else {
            print("ERROR: Invalid CGS connection")
            return [:]
        }

        let managedSpacesRef = CGSCopyManagedDisplaySpaces(connection)

        let managedSpacesArray = managedSpacesRef as NSArray
        let activeSpace = CGSGetActiveSpace(connection)
        var spacesByDisplay: [CGDirectDisplayID: [SpaceInfo]] = [:]

        // Process each display's spaces
        for displayInfo in managedSpacesArray {
            guard let displayDict = displayInfo as? [String: Any] else { continue }

            // Get display identifier
            var displayID: CGDirectDisplayID = 0
            if displayDict["Display Identifier"] is String {
                // Try to map UUID to display ID
                let displays = NSScreen.screens.compactMap { screen -> CGDirectDisplayID? in
                    // Get the display ID from the screen's device description
                    if let screenNumber = screen
                        .deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
                    {
                        return screenNumber.uint32Value
                    }
                    return nil
                }

                // For now, use the first display if we can't match the UUID
                // In a production system, we'd need a proper UUID to display ID mapping
                if !displays.isEmpty {
                    displayID = displays[0]
                }
            }

            // Get spaces for this display
            guard let spaces = displayDict["Spaces"] as? [[String: Any]] else { continue }

            var displaySpaces: [SpaceInfo] = []

            for spaceDict in spaces {
                guard let spaceID = spaceDict["ManagedSpaceID"] as? Int64 else { continue }

                let spaceType = spaceDict["type"] as? Int ?? 0
                let type: SpaceInfo.SpaceType = switch spaceType {
                case kCGSSpaceUser: .user
                case kCGSSpaceFullscreen: .fullscreen
                case kCGSSpaceSystem: .system
                case kCGSSpaceTiled: .tiled
                default: .unknown
                }

                // Get additional space information
                let spaceName = spaceDict["name"] as? String
                let ownerPIDs = spaceDict["ownerPIDs"] as? [Int] ?? []
                let isActive = CGSSpaceID(spaceID) == activeSpace

                let spaceInfo = SpaceInfo(
                    id: CGSSpaceID(spaceID),
                    type: type,
                    isActive: isActive,
                    displayID: displayID,
                    name: spaceName,
                    ownerPIDs: ownerPIDs)

                displaySpaces.append(spaceInfo)
            }

            if displayID != 0, !displaySpaces.isEmpty {
                spacesByDisplay[displayID] = displaySpaces
            }
        }

        return spacesByDisplay
    }

    /// Get the current active Space
    public func getCurrentSpace() -> SpaceInfo? {
        // Check if we have a valid connection
        guard connection != 0 else {
            print("ERROR: Invalid CGS connection")
            return nil
        }

        let activeSpaceID = CGSGetActiveSpace(connection)
        guard activeSpaceID != 0 else {
            // Failed to get active Space
            return nil
        }

        let spaceType = CGSSpaceGetType(connection, activeSpaceID)
        let type: SpaceInfo.SpaceType = switch spaceType {
        case kCGSSpaceUser: .user
        case kCGSSpaceFullscreen: .fullscreen
        case kCGSSpaceSystem: .system
        case kCGSSpaceTiled: .tiled
        default: .unknown
        }

        // Get additional space information
        let spaceName = CGSSpaceCopyName(connection, activeSpaceID) as String?
        let ownerPIDsArray = CGSSpaceCopyOwners(connection, activeSpaceID) as? [Int] ?? []
        let displayID: CGDirectDisplayID? = nil // Simplified for now

        return SpaceInfo(
            id: activeSpaceID,
            type: type,
            isActive: true,
            displayID: displayID,
            name: spaceName,
            ownerPIDs: ownerPIDsArray)
    }

    /// Get Spaces that contain a specific window
    public func getSpacesForWindow(windowID: CGWindowID) -> [SpaceInfo] {
        // Check if we have a valid connection
        guard connection != 0 else {
            print("ERROR: Invalid CGS connection")
            return []
        }

        let windowArray = [windowID] as CFArray

        guard let spacesRef = CGSCopySpacesForWindows(connection, kCGSAllSpacesMask, windowArray) else {
            // Failed to get Spaces for window
            return []
        }

        // Try to interpret the result as an array
        let spacesArray = spacesRef as NSArray
        let activeSpace = CGSGetActiveSpace(connection)

        var spaces: [SpaceInfo] = []

        // Handle both array of IDs and array of dictionaries
        for element in spacesArray {
            var spaceID: CGSSpaceID?

            if let id = element as? Int {
                // Direct space ID
                spaceID = CGSSpaceID(id)
            } else if let dict = element as? [String: Any] {
                // Dictionary with space info - try different keys
                if let id = dict["ManagedSpaceID"] as? Int {
                    spaceID = CGSSpaceID(id)
                } else if let id = dict["id64"] as? Int {
                    spaceID = CGSSpaceID(id)
                } else if let id = dict["id"] as? Int {
                    spaceID = CGSSpaceID(id)
                }
            }

            guard let validSpaceID = spaceID else { continue }

            let spaceType = CGSSpaceGetType(connection, validSpaceID)
            let type: SpaceInfo.SpaceType = switch spaceType {
            case kCGSSpaceUser: .user
            case kCGSSpaceFullscreen: .fullscreen
            case kCGSSpaceSystem: .system
            case kCGSSpaceTiled: .tiled
            default: .unknown
            }

            // Get additional space information
            let spaceName = CGSSpaceCopyName(connection, validSpaceID) as String?
            let ownerPIDsArray = CGSSpaceCopyOwners(connection, validSpaceID) as? [Int] ?? []

            spaces.append(SpaceInfo(
                id: validSpaceID,
                type: type,
                isActive: validSpaceID == activeSpace,
                displayID: nil,
                name: spaceName,
                ownerPIDs: ownerPIDsArray))
        }

        return spaces
    }

    // MARK: - Space Switching

    /// Switch to a specific Space
    public func switchToSpace(_ spaceID: CGSSpaceID) async throws {
        let currentSpace = CGSGetActiveSpace(connection)
        let direction: SpaceDirection = spaceID > currentSpace ? .right : .left

        // Show space switch visualization
        _ = await self.visualizerClient.showSpaceSwitch(from: Int(currentSpace), to: Int(spaceID), direction: direction)

        // Use kCGSPackagesMainDisplayIdentifier for the main display
        CGSManagedDisplaySetCurrentSpace(connection, kCGSPackagesMainDisplayIdentifier, spaceID)

        // Give the system time to perform the switch
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
    }

    /// Switch to the Space containing a specific window
    public func switchToWindowSpace(windowID: CGWindowID) async throws {
        let spaces = getSpacesForWindow(windowID: windowID)

        guard let targetSpace = spaces.first else {
            throw SpaceError.windowNotInAnySpace(windowID)
        }

        // If already on the correct Space, no need to switch
        if targetSpace.isActive {
            // Window is already on active Space
            return
        }

        try await switchToSpace(targetSpace.id)
    }

    // MARK: - Window Information

    /// Get the window level (z-order) for a window
    public func getWindowLevel(windowID: CGWindowID) -> Int32? {
        // Check if we have a valid connection
        guard connection != 0 else {
            print("ERROR: Invalid CGS connection")
            return nil
        }

        // Get the window level
        var level: CGWindowLevel = 0
        let error = CGSGetWindowLevel(connection, windowID, &level)

        // Check for error
        if error != .success {
            return nil
        }

        return level
    }

    // MARK: - Window Movement

    /// Move a window to a specific Space
    public func moveWindowToSpace(windowID: CGWindowID, spaceID: CGSSpaceID) throws {
        let windowArray = [windowID] as CFArray
        let spaceArray = [spaceID] as CFArray

        // First, get current Spaces for the window
        let currentSpaces = getSpacesForWindow(windowID: windowID)

        // Remove from current Spaces
        if !currentSpaces.isEmpty {
            let currentSpaceIDs = currentSpaces.map(\.id) as CFArray
            CGSRemoveWindowsFromSpaces(connection, windowArray, currentSpaceIDs)
        }

        // Add to target Space
        CGSAddWindowsToSpaces(connection, windowArray, spaceArray)

        // Moved window to Space
    }

    /// Move a window to the current Space
    public func moveWindowToCurrentSpace(windowID: CGWindowID) throws {
        guard let currentSpace = getCurrentSpace() else {
            throw SpaceError.failedToGetCurrentSpace
        }

        try moveWindowToSpace(windowID: windowID, spaceID: currentSpace.id)
    }

    // MARK: - Private Helpers

    private func getDisplayForSpace(_ spaceID: CGSSpaceID) -> CGDirectDisplayID? {
        // Simplified implementation that avoids the problematic CGSManagedDisplayGetCurrentSpace
        // For now, just return the main display ID
        CGMainDisplayID()
    }
}

// MARK: - NSScreen Extension

extension NSScreen {
    /// Get the display ID for this screen
    var displayID: CGDirectDisplayID {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }
}

// MARK: - Space Errors

public enum SpaceError: LocalizedError {
    case spaceNotFound(CGSSpaceID)
    case windowNotInAnySpace(CGWindowID)
    case failedToGetCurrentSpace
    case failedToSwitchSpace

    public var errorDescription: String? {
        switch self {
        case let .spaceNotFound(spaceID):
            "Space with ID \(spaceID) not found"
        case let .windowNotInAnySpace(windowID):
            "Window with ID \(windowID) is not in any Space"
        case .failedToGetCurrentSpace:
            "Failed to get current Space information"
        case .failedToSwitchSpace:
            "Failed to switch to target Space"
        }
    }
}
