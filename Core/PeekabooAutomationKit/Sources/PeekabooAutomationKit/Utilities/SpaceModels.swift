import AppKit
import Foundation

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

    public init(
        id: UInt64,
        type: SpaceType,
        isActive: Bool,
        displayID: CGDirectDisplayID?,
        name: String?,
        ownerPIDs: [Int])
    {
        self.id = id
        self.type = type
        self.isActive = isActive
        self.displayID = displayID
        self.name = name
        self.ownerPIDs = ownerPIDs
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
