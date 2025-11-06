import AppKit
import ArgumentParser
import Foundation
import PeekabooCore

/// List running applications, windows, or check system permissions.
struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
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
            ScreensSubcommand.self
        ],
        defaultSubcommand: AppsSubcommand.self
    )

    func run() async throws {
        // Root command doesn't do anything, subcommands handle everything
    }
}

/// Subcommand for listing all running applications using PeekabooServices.shared.
struct AppsSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "apps",
        abstract: "List all running applications with details",
        discussion: """
        Lists all running applications using the ApplicationService from PeekabooCore.
        Applications are sorted by name and include process IDs, bundle identifiers,
        and activation status.
        """
    )

    @Flag(name: .long, help: "Output results in JSON format for scripting")
    var jsonOutput = false

    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            // Check permissions using the service
            try await requireScreenRecordingPermission()

            // Get applications from the service
            let output = try await PeekabooServices.shared.applications.listApplications()

            if self.jsonOutput {
                // Output full UnifiedToolOutput as JSON
                try print(output.toJSON())
            } else {
                // Use CLIFormatter for human-readable output
                print(CLIFormatter.format(output))
            }

        } catch {
            self.handleError(error)
            throw ExitCode(1)
        }
    }

    // Error handling is provided by ErrorHandlingCommand protocol
}

/// Subcommand for listing windows of a specific application using PeekabooServices.shared.
struct WindowsSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable,
ApplicationResolvablePositional {
    static let configuration = CommandConfiguration(
        commandName: "windows",
        abstract: "List all windows for a specific application",
        discussion: """
        Lists all windows for the specified application using PeekabooCore PeekabooServices.shared.
        Windows are listed in z-order (frontmost first) with optional details.
        """
    )

    @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
    var app: String

    @Option(name: .long, help: "Target application by process ID")
    var pid: Int32?

    @Option(name: .long, help: "Additional details (comma-separated: off_screen,bounds,ids)")
    var includeDetails: String?

    @Flag(name: .long, help: "Output results in JSON format for scripting")
    var jsonOutput = false

    /// Resolve the target application, retrieve its windows, and emit the requested output format.
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            // Check permissions
            try await requireScreenRecordingPermission()

            // Resolve application identifier
            let appIdentifier = try self.resolveApplicationIdentifier()

            // Find the target application using the service
            // Get windows for the app using the service
            let output = try await PeekabooServices.shared.applications.listWindows(for: appIdentifier, timeout: nil)

            if self.jsonOutput {
                let detailOptions = self.includeDetails.map { self.parseIncludeDetails() } ?? []
                let payload = try self.renderJSON(from: output, detailOptions: detailOptions)
                print(payload)
            } else {
                // Use CLIFormatter for human-readable output
                print(CLIFormatter.format(output))
            }

        } catch {
            self.handleError(error)
            throw ExitCode(1)
        }
    }

    // Error handling is provided by ErrorHandlingCommand protocol

    /// Parse the `--include-details` flag into a normalized option set.
    private func parseIncludeDetails() -> Set<WindowDetailOption> {
        guard let detailsString = includeDetails else {
            return []
        }

        let components = detailsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var options: Set<WindowDetailOption> = []

        for component in components {
            if let option = WindowDetailOption(rawValue: component) {
                options.insert(option)
            }
        }

        return options
    }

    /// Produce the JSON payload, redacting heavy fields unless explicitly requested.
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

        let filteredOutput = UnifiedToolOutput(
            data: FilteredWindowListData(
                windows: windows,
                targetApplication: output.data.targetApplication),
            summary: output.summary,
            metadata: output.metadata)

        return try filteredOutput.toJSON()
    }
}

/// Subcommand for checking system permissions using PeekabooServices.shared.
struct PermissionsSubcommand: AsyncParsableCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "permissions",
        abstract: "Check system permissions required for Peekaboo",
        discussion: """
        Checks system permissions using PeekabooCore PeekabooServices.shared.

        Permissions checked:
        - Screen Recording: Required for capturing screen content and optimal window listing
        - Accessibility: Required for UI automation (clicking, typing, etc.)

        Note: Screen Recording permission also improves performance for window operations
        by allowing use of faster CGWindowList API with full window information.
        """
    )

    @Flag(name: .long, help: "Output results in JSON format for scripting")
    var jsonOutput = false

    /// Summarize the current permission state and present detailed guidance when anything is missing.
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        // Get permissions using shared helper
        let permissionInfos = await PermissionHelpers.getCurrentPermissions()

        // Extract status for JSON output
        let screenRecording = permissionInfos.first { $0.name == "Screen Recording" }?.isGranted ?? false
        let accessibility = permissionInfos.first { $0.name == "Accessibility" }?.isGranted ?? false

        // Additional check for screen recording using CGWindowList heuristic
        let cgWindowListCheck = self.checkScreenRecordingViaWindowList()

        // Create permission status for JSON
        let permissions = PermissionStatus(
            screenRecording: screenRecording,
            accessibility: accessibility
        )

        let data = PermissionStatusData(permissions: permissions)

        output(data) {
            print("Peekaboo Permissions Status:")

            for permission in permissionInfos {
                print("  \(PermissionHelpers.formatPermissionStatus(permission))")

                // Only show grant instructions if permission is not granted
                if !permission.isGranted {
                    print("    Grant via: \(permission.grantInstructions)")
                }
            }

            // Show additional performance info for screen recording
            if screenRecording {
                if cgWindowListCheck {
                    print("\n  ✅ Optimal performance mode enabled (CGWindowList access confirmed)")
                } else {
                    print("\n  ⚠️  Limited CGWindowList access - window names may not be visible")
                }
                print("     → Screen recording improves window listing performance")
            }
        }
    }

    /// Check screen recording permission using CGWindowList heuristic
    private func checkScreenRecordingViaWindowList() -> Bool {
        // Check screen recording permission using CGWindowList heuristic
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        let ourPID = ProcessInfo.processInfo.processIdentifier

        // Check if we can see window names from other processes
        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID != ourPID,
                  let _ = window[kCGWindowName as String] as? String else {
                continue
            }
            // Found a window name from another process - we have permission
            return true
        }

        return false
    }
}

// MARK: - Helper Functions (error mapping removed - now in CommandUtilities)

/// Subcommand for listing menu bar items
struct MenuBarSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "menubar",
        abstract: "List all menu bar items (status icons)",
        discussion: """
        Lists all menu bar items (status icons) currently visible in the macOS menu bar.
        This includes system items like Wi-Fi, Battery, Time Machine, and third-party
        application status items.
        """
    )

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    /// Collect menu bar extras and print either a JSON payload or detailed textual breakdown.
    mutating func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            // Use the enhanced menu service to get menu bar items
            let menuExtras = try await PeekabooServices.shared.menu.listMenuExtras()

            struct MenuBarListResult: Codable {
                let count: Int
                let items: [MenuBarItem]

                struct MenuBarItem: Codable {
                    let name: String
                    let appName: String
                    let position: Position
                    let visible: Bool

                    struct Position: Codable {
                        let x: Int
                        let y: Int
                    }
                }
            }

            let items = menuExtras.map { extra in
                MenuBarListResult.MenuBarItem(
                    name: extra.title,
                    appName: extra.title,
                    position: MenuBarListResult.MenuBarItem.Position(
                        x: Int(extra.position.x),
                        y: Int(extra.position.y)
                    ),
                    visible: extra.isVisible
                )
            }

            let outputData = MenuBarListResult(count: menuExtras.count, items: items)

            output(outputData) {
                if menuExtras.isEmpty {
                    print("No menu bar items found.")
                    print("Note: Ensure Screen Recording permission is granted.")
                } else {
                    print("Menu Bar Items (\(menuExtras.count) total):")
                    print(String(repeating: "=", count: 50))

                    for (index, extra) in menuExtras.enumerated() {
                        print("\n\(index + 1). \(extra.title)")
                        print("   Position: x=\(Int(extra.position.x)), y=\(Int(extra.position.y))")
                        print("   Visible: \(extra.isVisible ? "Yes" : "No")")
                    }
                }
            }
        } catch {
            self.handleError(error)
            throw ExitCode(1)
        }
    }

    // Error handling is provided by ErrorHandlingCommand protocol
}

/// Subcommand for listing all available screens/displays
struct ScreensSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "screens",
        abstract: "List all available displays/monitors with details",
        discussion: """
        Lists all connected displays including their resolution, position, and other properties.
        Useful for discovering screen indices for the 'see --screen-index' command and
        debugging multi-monitor setups.

        The screen index shown can be used with commands like:
          peekaboo see --screen-index 0    # Capture primary screen
          peekaboo see --screen-index 1    # Capture secondary screen
        """
    )

    @Flag(name: .long, help: "Output results in JSON format for scripting")
    var jsonOutput = false

    @MainActor
    /// Enumerate the connected displays and present a normalized data set (plus highlights for the primary screen).
    mutating func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            // Get screens from the service
            let screens = PeekabooServices.shared.screens.listScreens()
            let primaryIndex = screens.firstIndex { $0.isPrimary }

            // Create output data
            let screenListData = ScreenListData(
                screens: screens.map { screen in
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
                },
                primaryIndex: primaryIndex
            )

            let output = UnifiedToolOutput(
                data: screenListData,
                summary: UnifiedToolOutput<ScreenListData>.Summary(
                    brief: "Found \(screens.count) screen\(screens.count == 1 ? "" : "s")",
                    detail: nil,
                    status: .success,
                    counts: ["screens": screens.count],
                    highlights: screens.enumerated().compactMap { index, screen in
                        screen.isPrimary ? UnifiedToolOutput<ScreenListData>.Summary.Highlight(
                            label: "Primary",
                            value: "\(screen.name) (Index \(index))",
                            kind: .primary
                        ) : nil
                    }
                ),
                metadata: UnifiedToolOutput<ScreenListData>.Metadata(
                    duration: 0.0,
                    warnings: [],
                    hints: ["Use 'peekaboo see --screen-index N' to capture a specific screen"]
                )
            )

            if self.jsonOutput {
                try print(output.toJSON())
            } else {
                // Human-readable output
                print("Screens (\(screens.count) total):")

                for screen in screens {
                    print("\n\(screen.index). \(screen.name)\(screen.isPrimary ? " (Primary)" : "")")
                    print("   Resolution: \(Int(screen.frame.width))×\(Int(screen.frame.height))")
                    print("   Position: \(Int(screen.frame.origin.x)),\(Int(screen.frame.origin.y))")
                    print("   Scale: \(screen.scaleFactor)x\(screen.scaleFactor > 1 ? " (Retina)" : "")")

                    // Show visible area if different from full resolution
                    if screen.visibleFrame.size != screen.frame.size {
                        print("   Visible Area: \(Int(screen.visibleFrame.width))×\(Int(screen.visibleFrame.height))")
                    }
                }

                print("\n💡 Use 'peekaboo see --screen-index N' to capture a specific screen")
            }
        } catch {
            self.handleError(error)
            throw ExitCode(1)
        }
    }
}

// MARK: - Screen List Data Model

struct ScreenListData: Codable {
    let screens: [ScreenDetails]
    let primaryIndex: Int?

    struct ScreenDetails: Codable {
        let index: Int
        let name: String
        let resolution: Resolution
        let position: Position
        let visibleArea: Resolution
        let isPrimary: Bool
        let scaleFactor: CGFloat
        let displayID: Int
    }

    struct Resolution: Codable {
        let width: Int
        let height: Int
    }

    struct Position: Codable {
        let x: Int
        let y: Int
    }
}
