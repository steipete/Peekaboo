import AppKit
import Commander
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
        ]
    )
}

// MARK: - List Spaces

@MainActor

struct ListSubcommand: ErrorHandlingCommand, OutputFormattable {
    @Flag(name: .long, help: "Include detailed window information")
    var detailed = false
    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)

        let spaceService = SpaceCommandEnvironment.service
        let spaces = await spaceService.getAllSpaces()

        if self.jsonOutput {
            let data = SpaceListData(
                spaces: spaces.map { space in
                    SpaceData(
                        id: space.id,
                        type: space.type.rawValue,
                        is_active: space.isActive,
                        display_id: space.displayID
                    )
                }
            )
            outputSuccessCodable(data: data, logger: self.logger)
            return
        }

        print("Spaces:")
        var windowsBySpace: [UInt64: [(app: String, window: ServiceWindowInfo)]] = [:]

        if self.detailed {
            let appService = self.services.applications
            let appListResult = try await appService.listApplications()

            for app in appListResult.data.applications where app.windowCount > 0 {
                do {
                    let windowsResult = try await appService.listWindows(for: app.name, timeout: nil)
                    for window in windowsResult.data.windows {
                        let windowSpaces = await spaceService.getSpacesForWindow(windowID: CGWindowID(window.windowID))
                        for space in windowSpaces {
                            windowsBySpace[space.id, default: []].append((app: app.name, window: window))
                        }
                    }
                } catch {
                    continue
                }
            }
        }

        for (index, space) in spaces.enumerated() {
            let marker = space.isActive ? "→" : " "
            let displayInfo = space.displayID.map { " (Display \($0))" } ?? ""
            print("\(marker) Space \(index + 1) [ID: \(space.id), Type: \(space.type.rawValue)\(displayInfo)]")

            if self.detailed {
                if let windows = windowsBySpace[space.id], !windows.isEmpty {
                    for (app, window) in windows {
                        let title = window.title.isEmpty ? "[Untitled]" : window.title
                        let minimized = window.isMinimized ? " [MINIMIZED]" : ""
                        print("    • \(app): \(title)\(minimized)")
                    }
                } else {
                    print("    (No windows)")
                }
            }
        }

        if spaces.isEmpty {
            print("No Spaces found (this may indicate an API issue)")
        }
    }
}

// MARK: - Switch Space

@MainActor

struct SwitchSubcommand: ErrorHandlingCommand, OutputFormattable {
    @Option(name: .long, help: "Space number to switch to (1-based)")
    var to: Int
    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

    /// Validate the requested Space index, switch to it, and report the outcome.
    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)

        do {
            let spaceService = SpaceCommandEnvironment.service
            let spaces = await spaceService.getAllSpaces()

            guard self.to > 0 && self.to <= spaces.count else {
                throw ValidationError("Invalid Space number. Available: 1-\(spaces.count)")
            }

            let targetSpace = spaces[self.to - 1]
            try await spaceService.switchToSpace(targetSpace.id)

            if self.jsonOutput {
                let data = SpaceActionResult(
                    action: "switch",
                    success: true,
                    space_id: targetSpace.id,
                    space_number: self.to
                )
                outputSuccessCodable(data: data, logger: self.logger)
            } else {
                print("✓ Switched to Space \(self.to)")
            }

        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
}

// MARK: - Move Window to Space

@MainActor

struct MoveWindowSubcommand: ApplicationResolvable, ErrorHandlingCommand, OutputFormattable {
    @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
    var app: String?

    @Option(name: .long, help: "Target application by process ID")
    var pid: Int32?

    @Option(name: .long, help: "Target window by title (partial match supported)")
    var windowTitle: String?

    @Option(name: .long, help: "Target window by index (0-based, frontmost is 0)")
    var windowIndex: Int?

    @Option(name: .long, help: "Space number to move window to (1-based)")
    var to: Int?

    @Flag(name: .long, help: "Move window to current Space")
    var toCurrent = false

    @Flag(name: .long, help: "Switch to the target Space after moving")
    var follow = false
    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)

        do {
            let appIdentifier = try self.resolveApplicationIdentifier()

            guard self.to != nil || self.toCurrent else {
                throw ValidationError("Must specify either --to or --to-current")
            }
            guard !(self.to != nil && self.toCurrent) else {
                throw ValidationError("Cannot specify both --to and --to-current")
            }

            var windowOptions = WindowIdentificationOptions()
            windowOptions.app = appIdentifier
            windowOptions.windowTitle = self.windowTitle
            windowOptions.windowIndex = self.windowIndex

            let target = try windowOptions.toWindowTarget()
            let windows = try await self.services.windows.listWindows(target: target)
            guard let windowInfo = windowOptions.selectWindow(from: windows) else {
                throw NotFoundError.window(app: appIdentifier)
            }

            let windowID = CGWindowID(windowInfo.windowID)
            let spaceService = SpaceCommandEnvironment.service

            if self.toCurrent {
                try await spaceService.moveWindowToCurrentSpace(windowID: windowID)
                if self.jsonOutput {
                    let data = WindowSpaceActionResult(
                        action: "move-window",
                        success: true,
                        window_id: windowID,
                        window_title: windowInfo.title,
                        space_id: nil,
                        space_number: nil,
                        moved_to_current: true,
                        followed: nil
                    )
                    outputSuccessCodable(data: data, logger: self.logger)
                } else {
                    print("✓ Moved window '\(windowInfo.title)' to current Space")
                }
                return
            }

            guard let spaceNum = self.to else {
                preconditionFailure("Expected either --to or --to-current validation")
            }

            let spaces = await spaceService.getAllSpaces()
            guard spaceNum > 0 && spaceNum <= spaces.count else {
                throw ValidationError("Invalid Space number. Available: 1-\(spaces.count)")
            }

            let targetSpace = spaces[spaceNum - 1]
            try await spaceService.moveWindowToSpace(windowID: windowID, spaceID: targetSpace.id)
            if self.follow {
                try await spaceService.switchToSpace(targetSpace.id)
            }

            if self.jsonOutput {
                let data = WindowSpaceActionResult(
                    action: "move-window",
                    success: true,
                    window_id: windowID,
                    window_title: windowInfo.title,
                    space_id: targetSpace.id,
                    space_number: spaceNum,
                    moved_to_current: false,
                    followed: self.follow
                )
                outputSuccessCodable(data: data, logger: self.logger)
            } else {
                var message = "✓ Moved window '\(windowInfo.title)' to Space \(spaceNum)"
                if self.follow { message += " (and switched to it)" }
                print(message)
            }
        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
}

@MainActor
extension ListSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "list",
                abstract: "List all Spaces and their windows"
            )
        }
    }
}

extension ListSubcommand: AsyncRuntimeCommand {}
@MainActor
extension ListSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.detailed = values.flag("detailed")
    }
}

@MainActor
extension SwitchSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "switch",
                abstract: "Switch to a different Space"
            )
        }
    }
}

extension SwitchSubcommand: AsyncRuntimeCommand {}
@MainActor
extension SwitchSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.to = try values.requireOption("to", as: Int.self)
    }
}

@MainActor
extension MoveWindowSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "move-window",
                abstract: "Move a window to a different Space"
            )
        }
    }
}

extension MoveWindowSubcommand: AsyncRuntimeCommand {}
@MainActor
extension MoveWindowSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.app = values.singleOption("app")
        self.pid = try values.decodeOption("pid", as: Int32.self)
        self.windowTitle = values.singleOption("windowTitle")
        self.windowIndex = try values.decodeOption("windowIndex", as: Int.self)
        self.to = try values.decodeOption("to", as: Int.self)
        self.toCurrent = values.flag("toCurrent")
        self.follow = values.flag("follow")
    }
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
