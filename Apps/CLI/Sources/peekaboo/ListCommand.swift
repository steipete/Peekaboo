import AppKit
import ArgumentParser
import Foundation
import PeekabooCore

/// Refactored ListCommand using PeekabooCore services
///
/// This version delegates all operations to the service layer while maintaining
/// the same command interface and JSON output compatibility.
struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List running applications, windows, or check permissions (service-based)",
        discussion: """
        This is a refactored version of the list command that uses PeekabooCore services
        instead of direct implementation. It maintains the same interface but delegates
        all operations to the service layer.
        
        SYNOPSIS:
          peekaboo list SUBCOMMAND [OPTIONS]

        EXAMPLES:
          peekaboo list                                  # List all applications (default)
          peekaboo list apps                             # List all running applications
          peekaboo list apps --json-output               # Output as JSON

          peekaboo list windows --app Safari             # List Safari windows
          peekaboo list windows --app "Visual Studio Code"
          peekaboo list windows --app Chrome --include-details bounds,ids

          peekaboo list permissions                      # Check permissions

        SUBCOMMANDS:
          apps          List all running applications with process IDs
          windows       List windows for a specific application  
          permissions   Check permissions required for Peekaboo
        """,
        subcommands: [AppsSubcommand.self, WindowsSubcommand.self, PermissionsSubcommand.self],
        defaultSubcommand: AppsSubcommand.self)

    func run() async throws {
        // Root command doesn't do anything, subcommands handle everything
    }
}

/// Subcommand for listing all running applications using services.
struct AppsSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apps",
        abstract: "List all running applications with details",
        discussion: """
        Lists all running applications using the ApplicationService from PeekabooCore.
        Applications are sorted by name and include process IDs, bundle identifiers,
        and activation status.
        """)

    @Flag(name: .long, help: "Output results in JSON format for scripting")
    var jsonOutput = false

    private let services = PeekabooServices.shared

    func run() async throws {
        Logger.shared.setJsonOutputMode(jsonOutput)

        do {
            // Check permissions using the service
            guard await services.screenCapture.hasScreenRecordingPermission() else {
                throw CaptureError.screenRecordingPermissionDenied
            }

            // Get applications from the service
            let serviceApps = try await services.applications.listApplications()
            
            // Convert to CLI model format for compatibility
            let applications = serviceApps.map { app in
                ApplicationInfo(
                    app_name: app.name,
                    bundle_id: app.bundleIdentifier ?? "unknown",
                    pid: app.processIdentifier,
                    is_active: app.isActive,
                    window_count: app.windowCount
                )
            }

            let data = ApplicationListData(applications: applications)

            if jsonOutput {
                outputSuccess(data: data)
            } else {
                printApplicationList(applications)
            }

        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }

    private func handleError(_ error: Error) {
        let captureError = mapErrorToCaptureError(error)

        if jsonOutput {
            let code = mapCaptureErrorToCode(captureError)
            outputError(
                message: captureError.localizedDescription,
                code: code,
                details: "Failed to list applications")
        } else {
            fputs("Error: \(captureError.localizedDescription)\n", stderr)
        }
    }

    private func printApplicationList(_ applications: [ApplicationInfo]) {
        let output = formatApplicationList(applications)
        print(output)
    }

    private func formatApplicationList(_ applications: [ApplicationInfo]) -> String {
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

/// Subcommand for listing windows of a specific application using services.
struct WindowsSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "windows",
        abstract: "List all windows for a specific application",
        discussion: """
        Lists all windows for the specified application using PeekabooCore services.
        Windows are listed in z-order (frontmost first) with optional details.
        """)

    @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
    var app: String

    @Option(name: .long, help: "Additional details (comma-separated: off_screen,bounds,ids)")
    var includeDetails: String?

    @Flag(name: .long, help: "Output results in JSON format for scripting")
    var jsonOutput = false

    private let services = PeekabooServices.shared

    func run() async throws {
        Logger.shared.setJsonOutputMode(jsonOutput)

        do {
            // Check permissions
            guard await services.screenCapture.hasScreenRecordingPermission() else {
                throw CaptureError.screenRecordingPermissionDenied
            }

            // Find the target application using the service
            let targetApp = try await services.applications.findApplication(identifier: app)

            // Parse include details options
            let detailOptions = parseIncludeDetails()

            // Get windows for the app using the service
            let serviceWindows = try await services.applications.listWindows(for: app)
            
            // Convert to CLI model format with requested details
            let windows = serviceWindows.enumerated().map { index, window in
                WindowInfo(
                    window_title: window.title,
                    window_id: detailOptions.contains(.ids) ? UInt32(window.windowID) : nil,
                    bounds: detailOptions.contains(.bounds) ? WindowBounds(
                        x: Int(window.bounds.origin.x),
                        y: Int(window.bounds.origin.y),
                        width: Int(window.bounds.size.width),
                        height: Int(window.bounds.size.height)
                    ) : nil,
                    is_on_screen: detailOptions.contains(.off_screen) ? !window.isMinimized : nil
                )
            }

            let targetAppInfo = TargetApplicationInfo(
                app_name: targetApp.name,
                bundle_id: targetApp.bundleIdentifier,
                pid: targetApp.processIdentifier)

            let data = WindowListData(
                windows: windows,
                target_application_info: targetAppInfo)

            if jsonOutput {
                outputSuccess(data: data)
            } else {
                printWindowList(data)
            }

        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }

    private func handleError(_ error: Error) {
        let captureError = mapErrorToCaptureError(error)

        if jsonOutput {
            let code = mapCaptureErrorToCode(captureError)
            outputError(
                message: captureError.localizedDescription,
                code: code,
                details: "Failed to list windows")
        } else {
            fputs("Error: \(captureError.localizedDescription)\n", stderr)
        }
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

/// Subcommand for checking system permissions using services.
struct PermissionsSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "permissions",
        abstract: "Check system permissions required for Peekaboo",
        discussion: """
        Checks system permissions using PeekabooCore services.
        Verifies Screen Recording (required) and Accessibility (optional) permissions.
        """)

    @Flag(name: .long, help: "Output results in JSON format for scripting")
    var jsonOutput = false

    private let services = PeekabooServices.shared

    func run() async throws {
        Logger.shared.setJsonOutputMode(jsonOutput)

        // Check permissions using the services
        let screenRecording = await services.screenCapture.hasScreenRecordingPermission()
        let accessibility = await services.automation.hasAccessibilityPermission()

        let permissions = ServerPermissions(
            screen_recording: screenRecording,
            accessibility: accessibility)

        let data = ServerStatusData(permissions: permissions)

        if jsonOutput {
            outputSuccess(data: data)
        } else {
            print("Server Permissions Status:")
            print("  Screen Recording: \(screenRecording ? "✅ Granted" : "❌ Not granted")")
            print("  Accessibility: \(accessibility ? "✅ Granted" : "❌ Not granted")")
        }
    }
}

// MARK: - Helper Functions

/// Maps various errors to CaptureError for consistent handling
private func mapErrorToCaptureError(_ error: Error) -> CaptureError {
    if let captureError = error as? CaptureError {
        return captureError
    } else if let appError = error as? ApplicationError {
        switch appError {
        case let .notFound(identifier):
            return .appNotFound(identifier)
        case let .ambiguousIdentifier(identifier, _):
            return .invalidArgument("Ambiguous application identifier: '\(identifier)'")
        case .noFrontmostApplication:
            return .invalidArgument("No frontmost application")
        case let .notInstalled(identifier):
            return .appNotFound("Application not installed: \(identifier)")
        case let .activationFailed(identifier):
            return .invalidArgument("Failed to activate application: \(identifier)")
        }
    } else if let screenError = error as? ScreenCaptureError {
        switch screenError {
        case .noScreenRecordingPermission:
            return .screenRecordingPermissionDenied
        case .noAccessibilityPermission:
            return .accessibilityPermissionDenied
        case .captureFailure(let reason):
            return .captureFailed(reason)
        case .invalidDisplayIndex:
            return .invalidArgument("Invalid display index")
        case .noWindows:
            return .windowNotFound("No windows found")
        }
    } else {
        return .unknownError(error.localizedDescription)
    }
}

/// Maps CaptureError to ErrorCode for JSON output
private func mapCaptureErrorToCode(_ error: CaptureError) -> ErrorCode {
    switch error {
    case .screenRecordingPermissionDenied:
        return .PERMISSION_ERROR_SCREEN_RECORDING
    case .accessibilityPermissionDenied:
        return .PERMISSION_ERROR_ACCESSIBILITY
    case .appNotFound:
        return .APP_NOT_FOUND
    default:
        return .INTERNAL_SWIFT_ERROR
    }
}