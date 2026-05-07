import Commander
import CoreGraphics
import Foundation
import PeekabooCore

protocol SpaceCommandSpaceService: Sendable {
    func getAllSpaces() async -> [SpaceInfo]
    func getSpacesForWindow(windowID: CGWindowID) async -> [SpaceInfo]
    func moveWindowToCurrentSpace(windowID: CGWindowID) async throws
    func moveWindowToSpace(windowID: CGWindowID, spaceID: CGSSpaceID) async throws
    func switchToSpace(_ spaceID: CGSSpaceID) async throws
}

enum SpaceCommandEnvironment {
    @TaskLocal
    private static var override: (any SpaceCommandSpaceService)?

    static var service: any SpaceCommandSpaceService {
        self.override ?? LiveSpaceService.shared
    }

    static func withSpaceService<T>(
        _ service: any SpaceCommandSpaceService,
        perform operation: () async throws -> T
    ) async rethrows -> T {
        try await self.$override.withValue(service) {
            try await operation()
        }
    }

    private final class LiveSpaceService: SpaceCommandSpaceService {
        static let shared = LiveSpaceService()
        @MainActor private static let actor = SpaceManagementActor()

        private init() {}

        func getAllSpaces() async -> [SpaceInfo] {
            await MainActor.run {
                Self.actor.getAllSpaces()
            }
        }

        func getSpacesForWindow(windowID: CGWindowID) async -> [SpaceInfo] {
            await MainActor.run {
                Self.actor.getSpacesForWindow(windowID: windowID)
            }
        }

        func moveWindowToCurrentSpace(windowID: CGWindowID) async throws {
            try await MainActor.run {
                try Self.actor.moveWindowToCurrentSpace(windowID: windowID)
            }
        }

        func moveWindowToSpace(windowID: CGWindowID, spaceID: CGSSpaceID) async throws {
            try await MainActor.run {
                try Self.actor.moveWindowToSpace(windowID: windowID, spaceID: spaceID)
            }
        }

        func switchToSpace(_ spaceID: CGSSpaceID) async throws {
            try await Self.actor.switchToSpace(spaceID)
        }
    }

    @MainActor
    private final class SpaceManagementActor {
        private let inner = SpaceManagementService()

        func getAllSpaces() -> [SpaceInfo] {
            self.inner.getAllSpaces()
        }

        func getSpacesForWindow(windowID: CGWindowID) -> [SpaceInfo] {
            self.inner.getSpacesForWindow(windowID: windowID)
        }

        func moveWindowToCurrentSpace(windowID: CGWindowID) throws {
            try self.inner.moveWindowToCurrentSpace(windowID: windowID)
        }

        func moveWindowToSpace(windowID: CGWindowID, spaceID: CGSSpaceID) throws {
            try self.inner.moveWindowToSpace(windowID: windowID, spaceID: spaceID)
        }

        func switchToSpace(_ spaceID: CGSSpaceID) async throws {
            try await self.inner.switchToSpace(spaceID)
        }
    }
}

/// Manage macOS Spaces (virtual desktops)
@MainActor
struct SpaceCommand: ParsableCommand {
    static let commandDescription = CommandDescription(
        commandName: "space",
        abstract: "Manage macOS Spaces (virtual desktops)",
        discussion: """
        SYNOPSIS:
          peekaboo space SUBCOMMAND [OPTIONS]

        DESCRIPTION:
          Provides Space (virtual desktop) management capabilities including
          listing Spaces, switching between them, and moving windows.

        EXAMPLES:
          # List all Spaces
          peekaboo space list

          # Switch to Space 2
          peekaboo space switch --to 2

          # Move window to Space 3
          peekaboo space move-window --app Safari --to 3

          # Move window to current Space
          peekaboo space move-window --app Terminal --to-current

        SUBCOMMANDS:
          list          List all Spaces and their windows
          switch        Switch to a different Space
          move-window   Move a window to a different Space

        NOTE:
          Space management uses private macOS APIs that may change between
          macOS versions. Some features may not work on all systems.
        """,
        subcommands: [
            ListSubcommand.self,
            SwitchSubcommand.self,
            MoveWindowSubcommand.self,
        ],
        showHelpOnEmptyInvocation: true
    )
}

// MARK: - Response Types

struct SpaceListData: Codable {
    let spaces: [SpaceData]
}

struct SpaceData: Codable {
    let id: UInt64
    let type: String
    let is_active: Bool
    let display_id: CGDirectDisplayID?
}

struct SpaceActionResult: Codable {
    let action: String
    let success: Bool
    let space_id: UInt64
    let space_number: Int
}

struct WindowSpaceActionResult: Codable {
    let action: String
    let success: Bool
    let window_id: CGWindowID
    let window_title: String
    let space_id: UInt64?
    let space_number: Int?
    let moved_to_current: Bool?
    let followed: Bool?
}
