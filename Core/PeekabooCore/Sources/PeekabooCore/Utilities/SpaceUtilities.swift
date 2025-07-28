import AppKit
import Foundation

// MARK: - CGSSpace Private API Declarations

public typealias CGSConnectionID = UInt32
public typealias CGSSpaceID = UInt64
public typealias CGSManagedDisplay = UInt32

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSCopySpaces")
func CGSCopySpaces(_ connection: CGSConnectionID, _ mask: Int) -> CFArray?

@_silgen_name("CGSCopySpacesForWindows")
func CGSCopySpacesForWindows(_ connection: CGSConnectionID, _ mask: Int, _ windowNumbers: CFArray) -> CFArray?

@_silgen_name("CGSSpaceGetType")
func CGSSpaceGetType(_ connection: CGSConnectionID, _ space: CGSSpaceID) -> Int

@_silgen_name("CGSGetActiveSpace")
func CGSGetActiveSpace(_ connection: CGSConnectionID) -> CGSSpaceID

@_silgen_name("CGSManagedDisplayGetCurrentSpace")
func CGSManagedDisplayGetCurrentSpace(_ connection: CGSConnectionID, _ display: CGSManagedDisplay) -> CGSSpaceID

@_silgen_name("CGSManagedDisplaySetCurrentSpace")
func CGSManagedDisplaySetCurrentSpace(_ connection: CGSConnectionID, _ display: CGSManagedDisplay, _ space: CGSSpaceID)

@_silgen_name("CGSAddWindowsToSpaces")
func CGSAddWindowsToSpaces(_ connection: CGSConnectionID, _ windows: CFArray, _ spaces: CFArray)

@_silgen_name("CGSRemoveWindowsFromSpaces")
func CGSRemoveWindowsFromSpaces(_ connection: CGSConnectionID, _ windows: CFArray, _ spaces: CFArray)

@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ connection: CGSConnectionID) -> CFArray?

// Space type constants
private let kCGSSpaceUser = 0
private let kCGSSpaceFullscreen = 4
private let kCGSSpaceSystem = 2
private let kCGSSpaceTiled = 5

// Space mask constants
private let kCGSAllSpacesMask = 0xFFFF
private let kCGSCurrentSpaceMask = 0x0001
private let kCGSVisibleSpacesMask = 0x0005

// MARK: - Space Information

public struct SpaceInfo: Sendable {
    public let id: UInt64
    public let type: SpaceType
    public let isActive: Bool
    public let displayID: CGDirectDisplayID?
    
    public enum SpaceType: String, Sendable {
        case user = "user"
        case fullscreen = "fullscreen"
        case system = "system"
        case tiled = "tiled"
        case unknown = "unknown"
    }
}

// MARK: - Space Management Service

@MainActor
public final class SpaceManagementService {
    private var _connection: CGSConnectionID?
    
    private var connection: CGSConnectionID {
        if _connection == nil {
            _connection = CGSMainConnectionID()
        }
        return _connection!
    }
    
    public init() {
        // Defer connection initialization until first use
    }
    
    // MARK: - Space Information
    
    /// Get information about all Spaces
    public func getAllSpaces() -> [SpaceInfo] {
        guard let spacesArray = CGSCopySpaces(connection, kCGSAllSpacesMask) as? [CGSSpaceID] else {
            // Failed to get all Spaces
            return []
        }
        
        let activeSpace = CGSGetActiveSpace(connection)
        
        return spacesArray.compactMap { spaceID in
            let spaceType = CGSSpaceGetType(connection, spaceID)
            let type: SpaceInfo.SpaceType = switch spaceType {
            case kCGSSpaceUser: .user
            case kCGSSpaceFullscreen: .fullscreen
            case kCGSSpaceSystem: .system
            case kCGSSpaceTiled: .tiled
            default: .unknown
            }
            
            // Try to determine which display this Space belongs to
            let displayID = getDisplayForSpace(spaceID)
            
            return SpaceInfo(
                id: spaceID,
                type: type,
                isActive: spaceID == activeSpace,
                displayID: displayID
            )
        }
    }
    
    /// Get the current active Space
    public func getCurrentSpace() -> SpaceInfo? {
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
        
        let displayID = getDisplayForSpace(activeSpaceID)
        
        return SpaceInfo(
            id: activeSpaceID,
            type: type,
            isActive: true,
            displayID: displayID
        )
    }
    
    /// Get Spaces that contain a specific window
    public func getSpacesForWindow(windowID: CGWindowID) -> [SpaceInfo] {
        let windowArray = [windowID] as CFArray
        
        guard let spacesArray = CGSCopySpacesForWindows(connection, kCGSAllSpacesMask, windowArray) as? [CGSSpaceID] else {
            // Failed to get Spaces for window
            return []
        }
        
        let activeSpace = CGSGetActiveSpace(connection)
        
        return spacesArray.compactMap { spaceID in
            let spaceType = CGSSpaceGetType(connection, spaceID)
            let type: SpaceInfo.SpaceType = switch spaceType {
            case kCGSSpaceUser: .user
            case kCGSSpaceFullscreen: .fullscreen
            case kCGSSpaceSystem: .system
            case kCGSSpaceTiled: .tiled
            default: .unknown
            }
            
            let displayID = getDisplayForSpace(spaceID)
            
            return SpaceInfo(
                id: spaceID,
                type: type,
                isActive: spaceID == activeSpace,
                displayID: displayID
            )
        }
    }
    
    // MARK: - Space Switching
    
    /// Switch to a specific Space
    public func switchToSpace(_ spaceID: CGSSpaceID) async throws {
        // Find which display this Space belongs to
        guard let displayID = getDisplayForSpace(spaceID) else {
            throw SpaceError.spaceNotFound(spaceID)
        }
        
        // Convert CGDirectDisplayID to CGSManagedDisplay (they're typically the same value)
        let managedDisplay = CGSManagedDisplay(displayID)
        
        // Switching to Space
        
        // Switch to the Space
        CGSManagedDisplaySetCurrentSpace(connection, managedDisplay, spaceID)
        
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
    
    // MARK: - Window Movement
    
    /// Move a window to a specific Space
    public func moveWindowToSpace(windowID: CGWindowID, spaceID: CGSSpaceID) throws {
        let windowArray = [windowID] as CFArray
        let spaceArray = [spaceID] as CFArray
        
        // First, get current Spaces for the window
        let currentSpaces = getSpacesForWindow(windowID: windowID)
        
        // Remove from current Spaces
        if !currentSpaces.isEmpty {
            let currentSpaceIDs = currentSpaces.map { $0.id } as CFArray
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
        // Get all displays
        var displayCount: UInt32 = 0
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
        
        CGGetOnlineDisplayList(16, &onlineDisplays, &displayCount)
        
        // Check each display to see if it contains this Space
        for i in 0..<Int(displayCount) {
            let display = onlineDisplays[i]
            let managedDisplay = CGSManagedDisplay(display)
            let displaySpace = CGSManagedDisplayGetCurrentSpace(connection, managedDisplay)
            
            if displaySpace == spaceID {
                return display
            }
        }
        
        // If not the current Space on any display, check managed display Spaces
        // This requires iterating through all Spaces for each display
        guard let managedSpacesArray = CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else {
            return nil
        }
        
        for spaceDict in managedSpacesArray {
            if let currentSpaceID = spaceDict["Current Space"] as? CGSSpaceID,
               currentSpaceID == spaceID,
               let _ = spaceDict["Display Identifier"] as? String {
                // Convert display identifier to CGDirectDisplayID
                // The identifier is typically a UUID string
                for i in 0..<Int(displayCount) {
                    let display = onlineDisplays[i]
                    // Note: This is a simplified approach. In production, you'd need
                    // to properly match the display identifier
                    return display
                }
            }
        }
        
        return nil
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
        case .spaceNotFound(let spaceID):
            return "Space with ID \(spaceID) not found"
        case .windowNotInAnySpace(let windowID):
            return "Window with ID \(windowID) is not in any Space"
        case .failedToGetCurrentSpace:
            return "Failed to get current Space information"
        case .failedToSwitchSpace:
            return "Failed to switch to target Space"
        }
    }
}