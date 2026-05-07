import Commander
import CoreGraphics
import Foundation
import PeekabooCore

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
          peekaboo list apps --json                      # Output as JSON

          peekaboo list windows --app Safari             # List Safari windows
          peekaboo list windows --app "Visual Studio Code"
          peekaboo list windows --app Chrome --include-details bounds,ids

          peekaboo list menubar                          # List menu bar items
          peekaboo list menubar --json                   # Output as JSON

          peekaboo list permissions                      # Check permissions

          peekaboo list screens                          # List all displays
          peekaboo list screens --json                   # Output as JSON

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

    struct AppsSubcommand: ErrorHandlingCommand, OutputFormattable, RuntimeOptionsConfigurable {
        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var outputLogger: Logger {
            self.logger
        }

        var jsonOutput: Bool {
            // Tests access jsonOutput while only parsing arguments, so fall back to stored runtime options.
            self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput
        }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try await requireScreenRecordingPermission(services: self.services)
                let output = try await self.services.applications.listApplications()

                if self.jsonOutput {
                    outputSuccessCodable(data: output.data, logger: self.outputLogger)
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

    struct WindowsSubcommand: ErrorHandlingCommand, OutputFormattable, ApplicationResolvablePositional,
    RuntimeOptionsConfigurable {
        @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
        var app: String

        var positionalAppIdentifier: String {
            self.app
        }

        @Option(name: .long, help: "Target application by process ID")
        var pid: Int32?

        @Option(name: .long, help: "Additional details (comma-separated: off_screen,bounds,ids)")
        var includeDetails: String?
        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var outputLogger: Logger {
            self.logger
        }

        var jsonOutput: Bool {
            // PIDWindowsSubcommandTests read jsonOutput immediately after parsing; prefer stored options over a missing
            // runtime.
            self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput
        }

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
                    self.renderJSON(from: output, detailOptions: detailOptions)
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
        ) {
            guard !detailOptions.isEmpty else {
                outputSuccessCodable(data: output.data, logger: self.outputLogger)
                return
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

            let filteredOutput = FilteredWindowListData(
                windows: windows,
                targetApplication: output.data.targetApplication
            )

            outputSuccessCodable(data: filteredOutput, logger: self.outputLogger)
        }
    }

    // MARK: - Permissions

    @MainActor

    struct PermissionsSubcommand: OutputFormattable, RuntimeOptionsConfigurable {
        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var outputLogger: Logger {
            self.logger
        }

        var jsonOutput: Bool {
            self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput
        }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            let permissions = await PermissionHelpers.getCurrentPermissions(services: runtime.services)

            if self.jsonOutput {
                outputSuccessCodable(
                    data: PermissionsStatusPayload(permissions: permissions),
                    logger: self.outputLogger
                )
            } else {
                Swift.print("Peekaboo Permissions:")
                Swift.print("---------------------")
                for permission in permissions {
                    Swift.print("• \(PermissionHelpers.formatPermissionStatus(permission))")
                    if !permission.isGranted {
                        Swift.print("    Grant via: \(permission.grantInstructions)")
                    }
                }
            }
        }
    }

    private struct PermissionsStatusPayload: Codable {
        let permissions: [PermissionHelpers.PermissionInfo]
    }

    // MARK: - Menu Bar

    @MainActor

    struct MenuBarSubcommand: ErrorHandlingCommand, OutputFormattable, RuntimeOptionsConfigurable {
        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var outputLogger: Logger {
            self.logger
        }

        var jsonOutput: Bool {
            self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput
        }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                let items = try await MenuServiceBridge.listMenuBarItems(menu: self.services.menu)
                if self.jsonOutput {
                    MenuBarItemListOutput.outputJSON(items: items, logger: self.outputLogger)
                } else {
                    MenuBarItemListOutput.display(items)
                }
            } catch {
                self.handleError(error)
                throw ExitCode(1)
            }
        }
    }
}

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
