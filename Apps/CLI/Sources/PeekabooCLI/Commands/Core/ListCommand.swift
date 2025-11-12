import AppKit
import Commander
import Foundation
import PeekabooCore

private typealias ScreenOutput = UnifiedToolOutput<ScreenListData>

/// List running applications, windows, or check system permissions.
@MainActor
struct ListCommand: ParsableCommand {
    static let commandDescription = CommandDescription(
        commandName: "list",
        abstract: "List running applications, windows, or check permissions",
        discussion: """
        SYNOPSIS:
          peekaboo list SUBCOMMAND [OPTIONS]

        EXAMPLES:
          peekaboo list                                  # List all applications (default)
          peekaboo list apps                             # List all running applications
          peekaboo list apps --json-output               # Output as JSON

          peekaboo list windows --app Safari             # List Safari windows
          peekaboo list windows --app "Visual Studio Code"
          peekaboo list windows --app Chrome --include-details bounds,ids

          peekaboo list menubar                          # List menu bar items
          peekaboo list menubar --json-output            # Output as JSON

          peekaboo list permissions                      # Check permissions

          peekaboo list screens                          # List all displays
          peekaboo list screens --json-output            # Output as JSON

        SUBCOMMANDS:
          apps          List all running applications with process IDs
          windows       List windows for a specific application
          permissions   Check permissions required for Peekaboo
          menubar       List all menu bar items (status icons)
          screens       List all available displays/monitors
        """,
        subcommands: [
            AppsSubcommand.self,
            WindowsSubcommand.self,
            PermissionsSubcommand.self,
            MenuBarSubcommand.self,
            ScreensSubcommand.self,
        ],
        defaultSubcommand: AppsSubcommand.self
    )

    func run() async throws {
        // Root command doesn’t do anything; subcommands handle the work.
    }
}

extension ListCommand {
    // MARK: - Apps

    @MainActor

    struct AppsSubcommand: ErrorHandlingCommand, OutputFormattable {
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: PeekabooServices { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try await requireScreenRecordingPermission(services: self.services)
                let output = try await self.services.applications.listApplications()

                if self.jsonOutput {
                    try print(output.toJSON())
                } else {
                    print(CLIFormatter.format(output))
                }
            } catch {
                self.handleError(error)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Windows

    @MainActor

    struct WindowsSubcommand: ErrorHandlingCommand, OutputFormattable, ApplicationResolvablePositional {
        @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
        var app: String

        var positionalAppIdentifier: String { self.app }

        @Option(name: .long, help: "Target application by process ID")
        var pid: Int32?

        @Option(name: .long, help: "Additional details (comma-separated: off_screen,bounds,ids)")
        var includeDetails: String?
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: PeekabooServices { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        enum WindowDetailOption: String, ExpressibleFromArgument {
            case ids
            case bounds
            case off_screen

            init?(argument: String) {
                self.init(rawValue: argument.lowercased())
            }
        }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try await requireScreenRecordingPermission(services: self.services)
                let appIdentifier = try self.resolveApplicationIdentifier()
                let output = try await self.services.applications.listWindows(for: appIdentifier, timeout: nil)

                if self.jsonOutput {
                    let detailOptions = self.parseIncludeDetails()
                    let payload = try self.renderJSON(from: output, detailOptions: detailOptions)
                    print(payload)
                } else {
                    print(CLIFormatter.format(output))
                }
            } catch {
                self.handleError(error)
                throw ExitCode(1)
            }
        }

        private func parseIncludeDetails() -> Set<WindowDetailOption> {
            guard let detailsString = includeDetails else { return [] }
            let normalizedTokens = detailsString
                .split(separator: ",")
                .map { token -> String in
                    token
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "-", with: "_")
                        .lowercased()
                }

            let options = normalizedTokens.compactMap { token -> WindowDetailOption? in
                switch token {
                case "offscreen", "off_screen":
                    return .off_screen
                case "bounds":
                    return .bounds
                case "ids":
                    return .ids
                default:
                    return nil
                }
            }

            return Set(options)
        }

        @MainActor
        private func renderJSON(
            from output: UnifiedToolOutput<ServiceWindowListData>,
            detailOptions: Set<WindowDetailOption>
        ) throws -> String {
            guard !detailOptions.isEmpty else {
                return try output.toJSON()
            }

            struct FilteredWindowListData: Codable {
                struct Window: Codable {
                    let index: Int
                    let title: String
                    let isMinimized: Bool
                    let isMainWindow: Bool
                    let windowID: Int?
                    let bounds: CGRect?
                    let offScreen: Bool?
                    let spaceID: UInt64?
                    let spaceName: String?
                }

                let windows: [Window]
                let targetApplication: ServiceApplicationInfo?
            }

            struct FilteredOutput: Codable {
                let data: FilteredWindowListData
                let summary: UnifiedToolOutput<ServiceWindowListData>.Summary
                let metadata: UnifiedToolOutput<ServiceWindowListData>.Metadata
            }

            let windows = output.data.windows.map { window in
                FilteredWindowListData.Window(
                    index: window.index,
                    title: window.title,
                    isMinimized: window.isMinimized,
                    isMainWindow: window.isMainWindow,
                    windowID: detailOptions.contains(.ids) ? window.windowID : nil,
                    bounds: detailOptions.contains(.bounds) ? window.bounds : nil,
                    offScreen: detailOptions.contains(.off_screen) ? window.isOffScreen : nil,
                    spaceID: window.spaceID,
                    spaceName: window.spaceName
                )
            }

            let filteredOutput = FilteredOutput(
                data: FilteredWindowListData(
                    windows: windows,
                    targetApplication: output.data.targetApplication
                ),
                summary: output.summary,
                metadata: output.metadata
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(filteredOutput)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        }
    }

    // MARK: - Permissions

    @MainActor

    struct PermissionsSubcommand: OutputFormattable {
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

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            let permissions = await PermissionHelpers.getCurrentPermissions()

            if self.jsonOutput {
                struct Payload: Codable {
                    let permissions: [PermissionHelpers.PermissionInfo]
                }

                let payload = Payload(permissions: permissions)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(payload)
                if let json = String(data: data, encoding: .utf8) {
                    print(json)
                }
            } else {
                print("Peekaboo Permissions:")
                print("---------------------")
                for permission in permissions {
                    print("• \(PermissionHelpers.formatPermissionStatus(permission))")
                    if !permission.isGranted {
                        print("    Grant via: \(permission.grantInstructions)")
                    }
                }
            }
        }
    }

    // MARK: - Menu Bar

    @MainActor

    struct MenuBarSubcommand: ErrorHandlingCommand, OutputFormattable {
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: PeekabooServices { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                let items = try await MenuServiceBridge.listMenuBarItems(services: self.services)
                if self.jsonOutput {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(items)
                    if let json = String(data: data, encoding: .utf8) {
                        print(json)
                    }
                } else {
                    self.displayMenuBarItems(items)
                }
            } catch {
                self.handleError(error)
                throw ExitCode(1)
            }
        }

        @MainActor
        private func displayMenuBarItems(_ items: [MenuBarItemInfo]) {
            if items.isEmpty {
                print("No menu bar items detected.")
                return
            }

            print("Menu Bar Items (\(items.count)):")
            for (index, item) in items.enumerated() {
                self.displayMenuBarItem(item, index: index)
            }
        }

        @MainActor
        private func displayMenuBarItem(_ item: MenuBarItemInfo, index: Int) {
            let title = item.title ?? "<untitled>"
            print("  [\(index + 1)] \(title)")
            if let description = item.description, !description.isEmpty {
                print("       Description: \(description)")
            }
            if let frame = item.frame {
                let frameOrigin = "\(Int(frame.origin.x)),\(Int(frame.origin.y))"
                let frameSize = "\(Int(frame.width))×\(Int(frame.height))"
                print("       Frame: \(frameOrigin) \(frameSize)")
            }
        }
    }

    // MARK: - Screens

    @MainActor

    struct ScreensSubcommand: ErrorHandlingCommand, OutputFormattable {
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: PeekabooServices { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                let screens = self.services.screens.listScreens()
                let screenListData = self.buildScreenListData(from: screens)
                let output = UnifiedToolOutput(
                    data: screenListData,
                    summary: self.buildScreenSummary(for: screens),
                    metadata: self.buildScreenMetadata()
                )

                if self.jsonOutput {
                    try print(output.toJSON())
                } else {
                    self.displayScreenDetails(screens, count: screens.count)
                }
            } catch {
                self.handleError(error)
                throw ExitCode(1)
            }
        }

        @MainActor
        private func displayScreenDetails(_ screens: [PeekabooCore.ScreenInfo], count: Int) {
            print("Screens (\(count) total):")
            for screen in screens {
                let primaryBadge = screen.isPrimary ? " (Primary)" : ""
                print("\n\(screen.index). \(screen.name)\(primaryBadge)")
                print("   Resolution: \(Int(screen.frame.width))×\(Int(screen.frame.height))")
                print("   Position: \(Int(screen.frame.origin.x)),\(Int(screen.frame.origin.y))")
                let retinaBadge = screen.scaleFactor > 1 ? " (Retina)" : ""
                print("   Scale: \(screen.scaleFactor)x\(retinaBadge)")
                if screen.visibleFrame.size != screen.frame.size {
                    print("   Visible Area: \(Int(screen.visibleFrame.width))×\(Int(screen.visibleFrame.height))")
                }
            }
            print("\n💡 Use 'peekaboo see --screen-index N' to capture a specific screen")
        }

        @MainActor
        private func buildScreenListData(from screens: [PeekabooCore.ScreenInfo]) -> ScreenListData {
            let details = screens.map { screen in
                ScreenListData.ScreenDetails(
                    index: screen.index,
                    name: screen.name,
                    resolution: ScreenListData.Resolution(
                        width: Int(screen.frame.width),
                        height: Int(screen.frame.height)
                    ),
                    position: ScreenListData.Position(
                        x: Int(screen.frame.origin.x),
                        y: Int(screen.frame.origin.y)
                    ),
                    visibleArea: ScreenListData.Resolution(
                        width: Int(screen.visibleFrame.width),
                        height: Int(screen.visibleFrame.height)
                    ),
                    isPrimary: screen.isPrimary,
                    scaleFactor: screen.scaleFactor,
                    displayID: Int(screen.displayID)
                )
            }

            return ScreenListData(
                screens: details,
                primaryIndex: screens.firstIndex { $0.isPrimary }
            )
        }

        private func buildScreenSummary(for screens: [PeekabooCore.ScreenInfo]) -> ScreenOutput.Summary {
            let count = screens.count
            let highlights = screens.enumerated().compactMap { index, screen in
                screen.isPrimary ? ScreenOutput.Summary.Highlight(
                    label: "Primary",
                    value: "\(screen.name) (Index \(index))",
                    kind: ScreenOutput.Summary.Highlight.HighlightKind.primary
                ) : nil
            }
            return ScreenOutput.Summary(
                brief: "Found \(count) screen\(count == 1 ? "" : "s")",
                detail: nil,
                status: ScreenOutput.Summary.Status.success,
                counts: ["screens": count],
                highlights: highlights
            )
        }

        private func buildScreenMetadata() -> ScreenOutput.Metadata {
            ScreenOutput.Metadata(
                duration: 0.0,
                warnings: [],
                hints: ["Use 'peekaboo see --screen-index N' to capture a specific screen"]
            )
        }
    }
}

// MARK: - Screen List Data Model

struct ScreenListData {
    let screens: [ScreenDetails]
    let primaryIndex: Int?

    struct ScreenDetails {
        let index: Int
        let name: String
        let resolution: Resolution
        let position: Position
        let visibleArea: Resolution
        let isPrimary: Bool
        let scaleFactor: CGFloat
        let displayID: Int
    }

    struct Resolution {
        let width: Int
        let height: Int
    }

    struct Position {
        let x: Int
        let y: Int
    }
}

nonisolated extension ScreenListData: Sendable, Codable {}
nonisolated extension ScreenListData.ScreenDetails: Sendable, Codable {}
nonisolated extension ScreenListData.Resolution: Sendable, Codable {}
nonisolated extension ScreenListData.Position: Sendable, Codable {}

// MARK: - Subcommand Conformances

@MainActor
extension ListCommand.AppsSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "apps",
                abstract: "List all running applications with details",
                discussion: """
                Lists all running applications using the ApplicationService from PeekabooCore.
                Applications are sorted by name and include process IDs, bundle identifiers,
                and activation status.
                """
            )
        }
    }
}

extension ListCommand.AppsSubcommand: AsyncRuntimeCommand {}

@MainActor
extension ListCommand.AppsSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        // Apps subcommand has no parameters today; binding satisfied to keep parity.
        _ = values
    }
}

@MainActor
extension ListCommand.WindowsSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "windows",
                abstract: "List all windows for a specific application",
                discussion: """
                Lists all windows for the specified application using PeekabooServices.
                Windows are listed in z-order (frontmost first) with optional details.
                """
            )
        }
    }
}

extension ListCommand.WindowsSubcommand: AsyncRuntimeCommand {}

@MainActor
extension ListCommand.WindowsSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        guard let resolvedApp = values.singleOption("app") else {
            throw CommanderBindingError.missingArgument(label: "app")
        }
        self.app = resolvedApp
        self.pid = try values.decodeOption("pid", as: Int32.self)
        self.includeDetails = values.singleOption("includeDetails")
    }
}

@MainActor
extension ListCommand.PermissionsSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "permissions",
                abstract: "Check permissions required for Peekaboo"
            )
        }
    }
}

extension ListCommand.PermissionsSubcommand: AsyncRuntimeCommand {}

@MainActor
extension ListCommand.MenuBarSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "menubar",
                abstract: "List all menu bar items (status icons)"
            )
        }
    }
}

extension ListCommand.MenuBarSubcommand: AsyncRuntimeCommand {}

@MainActor
extension ListCommand.MenuBarSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        _ = values
    }
}

@MainActor
extension ListCommand.ScreensSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "screens",
                abstract: "List all displays/monitors"
            )
        }
    }
}

extension ListCommand.ScreensSubcommand: AsyncRuntimeCommand {}

@MainActor
extension ListCommand.ScreensSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        _ = values
    }
}
