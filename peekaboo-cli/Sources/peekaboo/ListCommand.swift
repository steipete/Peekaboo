import ArgumentParser
import Foundation

#if os(macOS)
import AppKit
#endif

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List running applications or windows",
        subcommands: [AppsSubcommand.self, WindowsSubcommand.self, ServerStatusSubcommand.self],
        defaultSubcommand: AppsSubcommand.self
    )
}

struct AppsSubcommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apps",
        abstract: "List all running applications"
    )

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    func run() {
        Logger.shared.setJsonOutputMode(jsonOutput)

        // Check platform support
        guard PlatformFactory.isPlatformSupported() else {
            handleError(CaptureError.unknownError("Platform not supported"))
            return
        }

        do {
            // Use platform factory to get implementations
            let permissionsManager = PlatformFactory.createPermissionsManager()
            let applicationFinder = PlatformFactory.createApplicationFinder()
            
            // Check permissions
            try permissionsManager.requireScreenCapturePermission()

            let applications = applicationFinder.getRunningApplications(includeBackground: false)
            let data = ApplicationListData(applications: applications)

            if jsonOutput {
                outputSuccess(data: data)
            } else {
                printApplicationList(applications)
            }

        } catch {
            handleError(error)
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

        if jsonOutput {
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
                details: "Failed to list applications"
            )
        } else {
            fputs("Error: \(captureError.localizedDescription)\n", stderr)
        }
        Foundation.exit(captureError.exitCode)
    }

    func printApplicationList(_ applications: [ApplicationInfo]) {
        let output = formatApplicationList(applications)
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

struct WindowsSubcommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "windows",
        abstract: "List windows for a specific application"
    )

    @Option(name: .long, help: "Target application identifier")
    var app: String

    @Option(name: .long, help: "Include additional window details (comma-separated: off_screen,bounds,ids)")
    var includeDetails: String?

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    func run() {
        Logger.shared.setJsonOutputMode(jsonOutput)

        // Check platform support
        guard PlatformFactory.isPlatformSupported() else {
            handleError(CaptureError.unknownError("Platform not supported"))
            return
        }

        do {
            // Use platform factory to get implementations
            let permissionsManager = PlatformFactory.createPermissionsManager()
            let applicationFinder = PlatformFactory.createApplicationFinder()
            let windowManager = PlatformFactory.createWindowManager()
            
            // Check permissions
            try permissionsManager.requireScreenCapturePermission()

            // Find the target application
            let targetApp = try applicationFinder.findApplication(identifier: app)

            // Parse include details options
            let detailOptions = parseIncludeDetails()

            // Get windows for the app - use cross-platform method
            let windowData = try windowManager.getWindowsForApp(
                pid: targetApp.processIdentifier,
                includeOffScreen: detailOptions.contains(.off_screen)
            )
            
            // Convert to the expected format for backward compatibility
            let windows = windowData.map { window in
                WindowInfo(
                    window_title: window.title,
                    window_id: detailOptions.contains(.ids) ? window.windowId : nil,
                    window_index: window.windowIndex,
                    bounds: detailOptions.contains(.bounds) ? WindowBounds(
                        xCoordinate: Int(window.bounds.origin.x),
                        yCoordinate: Int(window.bounds.origin.y),
                        width: Int(window.bounds.size.width),
                        height: Int(window.bounds.size.height)
                    ) : nil,
                    is_on_screen: detailOptions.contains(.off_screen) ? window.isOnScreen : nil,
                    application_name: targetApp.localizedName,
                    process_id: targetApp.processIdentifier
                )
            }

            let data = WindowListData(
                application_name: targetApp.localizedName ?? app,
                process_id: targetApp.processIdentifier,
                windows: windows
            )

            if jsonOutput {
                outputSuccess(data: data)
            } else {
                printWindowList(data)
            }

        } catch {
            handleError(error)
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

        if jsonOutput {
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
                details: "Failed to list windows"
            )
        } else {
            fputs("Error: \(captureError.localizedDescription)\n", stderr)
        }
        Foundation.exit(captureError.exitCode)
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
                print("   Bounds: (\(bounds.xCoordinate), \(bounds.yCoordinate)) \(bounds.width)×\(bounds.height)")
            }

            print()
        }
    }
}

struct ServerStatusSubcommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "server_status",
        abstract: "Check server permissions status"
    )

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    func run() {
        Logger.shared.setJsonOutputMode(jsonOutput)

        let screenRecording = PermissionsChecker.checkScreenRecordingPermission()
        let accessibility = PermissionsChecker.checkAccessibilityPermission()

        let permissions = ServerPermissions(
            screen_recording: screenRecording,
            accessibility: accessibility
        )

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

struct ServerPermissions: Codable {
    let screen_recording: Bool
    let accessibility: Bool
}

struct ServerStatusData: Codable {
    let permissions: ServerPermissions
}
