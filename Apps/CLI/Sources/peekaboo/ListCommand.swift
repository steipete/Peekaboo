import AppKit
import ArgumentParser
import Foundation

/// Command for listing applications, windows, and checking server status.
///
/// Provides subcommands to inspect running applications, enumerate windows,
/// and verify system permissions required for screenshot operations.
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
          peekaboo list windows --app PID:12345
          peekaboo list windows --app Chrome --include-details bounds,ids

          peekaboo list permissions                      # Check permissions

          # Scripting examples
          peekaboo list apps --json-output | jq '.data.applications[] | select(.is_active)'
          peekaboo list windows --app Safari --json-output | jq '.data.windows[].window_title'

        SUBCOMMANDS:
          apps          List all running applications with process IDs
          windows       List windows for a specific application  
          permissions   Check permissions required for Peekaboo

        OUTPUT FORMAT:
          Default output is human-readable text.
          Use --json-output for machine-readable JSON format.
        """,
        subcommands: [AppsSubcommand.self, WindowsSubcommand.self, PermissionsSubcommand.self],
        defaultSubcommand: AppsSubcommand.self)

    func run() async throws {
        // Root command doesn't do anything, subcommands handle everything
    }
}

/// Subcommand for listing all running applications.
///
/// Displays information about running applications including their process IDs,
/// bundle identifiers, activation status, and window counts.
struct AppsSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apps",
        abstract: "List all running applications with details",
        discussion: """
        SYNOPSIS:
          peekaboo list apps [--json-output]

        DESCRIPTION:
          Lists all running applications with their process IDs, bundle
          identifiers, and window counts. Applications are sorted by name.

        EXAMPLES:
          peekaboo list apps
          peekaboo list apps | grep Safari
          peekaboo list apps | wc -l                     # Count running apps

          # JSON output for scripting
          peekaboo list apps --json-output | jq '.data.applications[] | select(.is_active)'
          peekaboo list apps --json-output | jq -r '.data.applications[].app_name'
          peekaboo list apps --json-output | jq '.data.applications[] | select(.window_count > 3)'

        OUTPUT FIELDS:
          - Application name
          - Bundle identifier (e.g., com.apple.Safari)
          - Process ID (PID)
          - Status (Active/Background)
          - Window count
        """)

    @Flag(name: .long, help: "Output results in JSON format for scripting")
    var jsonOutput = false

    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            try PermissionsChecker.requireScreenRecordingPermission()

            let applications = ApplicationFinder.getAllRunningApplications()
            let data = ApplicationListData(applications: applications)

            if self.jsonOutput {
                outputSuccess(data: data)
            } else {
                self.printApplicationList(applications)
            }

        } catch {
            self.handleError(error)
            throw ExitCode(Int32(1))
        }
    }

    private func handleError(_ error: Error) {
        let captureError: CaptureError = if let err = error as? CaptureError {
            err
        } else if let appError = error as? ApplicationError {
            switch appError {
            case let .notFound(identifier):
                .appNotFound(identifier)
            case let .ambiguous(identifier, _):
                .invalidArgument("Ambiguous application identifier: '\(identifier)'")
            }
        } else {
            .unknownError(error.localizedDescription)
        }

        if self.jsonOutput {
            let code: ErrorCode = switch captureError {
            case .screenRecordingPermissionDenied:
                .PERMISSION_ERROR_SCREEN_RECORDING
            case .accessibilityPermissionDenied:
                .PERMISSION_ERROR_ACCESSIBILITY
            default:
                .INTERNAL_SWIFT_ERROR
            }
            outputError(
                message: captureError.localizedDescription,
                code: code,
                details: "Failed to list applications")
        } else {
            fputs("Error: \(captureError.localizedDescription)\n", stderr)
        }
        // Don't call exit() here - let the caller handle process termination
    }

    func printApplicationList(_ applications: [ApplicationInfo]) {
        let output = self.formatApplicationList(applications)
        print(output)
    }

    func formatApplicationList(_ applications: [ApplicationInfo]) -> String {
        var output = "Running Applications (\(applications.count)):\n\n"

        for (index, app) in applications.enumerated() {
            output += "\(index + 1). \(app.app_name)\n"
            output += "   Bundle ID: \(app.bundle_id)\n"
            output += "   PID: \(app.pid)\n"
            output += "   Status: \(app.is_active ? "Active" : "Background")\n"
            // Only show window count if it's not 1
            if app.window_count != 1 {
                output += "   Windows: \(app.window_count)\n"
            }
            output += "\n"
        }

        return output
    }
}

/// Subcommand for listing windows of a specific application.
///
/// Enumerates all windows belonging to a target application with optional
/// details like bounds, window IDs, and off-screen status.
struct WindowsSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "windows",
        abstract: "List all windows for a specific application",
        discussion: """
        SYNOPSIS:
          peekaboo list windows --app APPLICATION [--include-details DETAILS] [--json-output]

        DESCRIPTION:
          Lists all windows for the specified application. Windows are listed
          in z-order (frontmost first).

        EXAMPLES:
          peekaboo list windows --app Safari
          peekaboo list windows --app "Visual Studio Code"
          peekaboo list windows --app com.apple.Terminal
          peekaboo list windows --app PID:12345

          # Include additional details
          peekaboo list windows --app Chrome --include-details bounds
          peekaboo list windows --app Finder --include-details bounds,ids,off_screen

          # JSON output for scripting
          peekaboo list windows --app Safari --json-output | jq -r '.data.windows[].window_title'
          peekaboo list windows --app Terminal --include-details bounds --json-output | \
            jq '.data.windows[] | select(.bounds.width > 1000)'

        APPLICATION IDENTIFIERS:
          name       Application name (fuzzy matching supported)
          bundle     Bundle identifier (e.g., com.apple.Safari)
          PID:xxxxx  Process ID with PID: prefix

        DETAIL OPTIONS:
          off_screen Include off-screen windows
          bounds     Include window position and size (x, y, width, height)
          ids        Include CGWindowID values for window manipulation
        """)

    @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
    var app: String

    @Option(name: .long, help: "Additional details (comma-separated: off_screen,bounds,ids)")
    var includeDetails: String?

    @Flag(name: .long, help: "Output results in JSON format for scripting")
    var jsonOutput = false

    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            try PermissionsChecker.requireScreenRecordingPermission()

            // Find the target application
            let targetApp = try ApplicationFinder.findApplication(identifier: self.app)

            // Parse include details options
            let detailOptions = self.parseIncludeDetails()

            // Get windows for the app
            let windows = try WindowManager.getWindowsInfoForApp(
                pid: targetApp.processIdentifier,
                includeOffScreen: detailOptions.contains(.off_screen),
                includeBounds: detailOptions.contains(.bounds),
                includeIDs: detailOptions.contains(.ids))

            let targetAppInfo = TargetApplicationInfo(
                app_name: targetApp.localizedName ?? "Unknown",
                bundle_id: targetApp.bundleIdentifier,
                pid: targetApp.processIdentifier)

            let data = WindowListData(
                windows: windows,
                target_application_info: targetAppInfo)

            if self.jsonOutput {
                outputSuccess(data: data)
            } else {
                self.printWindowList(data)
            }

        } catch {
            self.handleError(error)
            throw ExitCode(Int32(1))
        }
    }

    private func handleError(_ error: Error) {
        let captureError: CaptureError = if let err = error as? CaptureError {
            err
        } else if let appError = error as? ApplicationError {
            switch appError {
            case let .notFound(identifier):
                .appNotFound(identifier)
            case let .ambiguous(identifier, _):
                .invalidArgument("Ambiguous application identifier: '\(identifier)'")
            }
        } else {
            .unknownError(error.localizedDescription)
        }

        if self.jsonOutput {
            let code: ErrorCode = switch captureError {
            case .screenRecordingPermissionDenied:
                .PERMISSION_ERROR_SCREEN_RECORDING
            case .accessibilityPermissionDenied:
                .PERMISSION_ERROR_ACCESSIBILITY
            case .appNotFound:
                .APP_NOT_FOUND
            default:
                .INTERNAL_SWIFT_ERROR
            }
            outputError(
                message: captureError.localizedDescription,
                code: code,
                details: "Failed to list windows")
        } else {
            fputs("Error: \(captureError.localizedDescription)\n", stderr)
        }
        // Don't call exit() here - let the caller handle process termination
    }

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

    private func printWindowList(_ data: WindowListData) {
        let app = data.target_application_info
        let windows = data.windows

        print("Windows for \(app.app_name)")
        if let bundleId = app.bundle_id {
            print("Bundle ID: \(bundleId)")
        }
        print("PID: \(app.pid)")
        print("Total Windows: \(windows.count)")
        print()

        if windows.isEmpty {
            print("No windows found.")
            return
        }

        for (index, window) in windows.enumerated() {
            print("\(index + 1). \"\(window.window_title)\"")

            if let windowId = window.window_id {
                print("   Window ID: \(windowId)")
            }

            if let isOnScreen = window.is_on_screen {
                print("   On Screen: \(isOnScreen ? "Yes" : "No")")
            }

            if let bounds = window.bounds {
                print("   Bounds: (\(bounds.x), \(bounds.y)) \(bounds.width)×\(bounds.height)")
            }

            print()
        }
    }
}

/// Subcommand for checking system permissions required for Peekaboo.
///
/// Verifies that required permissions (Screen Recording) and optional
/// permissions (Accessibility) are granted for proper operation.
struct PermissionsSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "permissions",
        abstract: "Check system permissions required for Peekaboo",
        discussion: """
        SYNOPSIS:
          peekaboo list permissions [--json-output]

        DESCRIPTION:
          Checks system permissions required for Peekaboo operations. Use this
          command to troubleshoot permission issues or verify installation.

        EXAMPLES:
          peekaboo list permissions
          peekaboo list permissions --json-output

          # Check specific permission
          peekaboo list permissions --json-output | jq '.data.permissions.screen_recording'

        STATUS CHECKS:
          Screen Recording  Required for all screenshot operations
          Accessibility     Optional, needed for window focus control

        EXIT STATUS:
          0  All required permissions granted
          1  Missing required permissions
        """)

    @Flag(name: .long, help: "Output results in JSON format for scripting")
    var jsonOutput = false

    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        let screenRecording = PermissionsChecker.checkScreenRecordingPermission()
        let accessibility = PermissionsChecker.checkAccessibilityPermission()

        let permissions = ServerPermissions(
            screen_recording: screenRecording,
            accessibility: accessibility)

        let data = ServerStatusData(permissions: permissions)

        if self.jsonOutput {
            outputSuccess(data: data)
        } else {
            print("Server Permissions Status:")
            print("  Screen Recording: \(screenRecording ? "✅ Granted" : "❌ Not granted")")
            print("  Accessibility: \(accessibility ? "✅ Granted" : "❌ Not granted")")
        }
    }
}

/// System permissions status for Peekaboo operations.
///
/// Indicates whether Screen Recording (required) and Accessibility (optional)
/// permissions have been granted.
struct ServerPermissions: Codable {
    let screen_recording: Bool
    let accessibility: Bool
}

/// Container for server status information.
///
/// Wraps permission status data for JSON output.
struct ServerStatusData: Codable {
    let permissions: ServerPermissions
}
