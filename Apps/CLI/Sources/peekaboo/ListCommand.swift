import AppKit
import ArgumentParser
import Foundation
import PeekabooCore

/// List running applications, windows, or check system permissions
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

        SUBCOMMANDS:
          apps          List all running applications with process IDs
          windows       List windows for a specific application  
          permissions   Check permissions required for Peekaboo
          menubar       List all menu bar items (status icons)
        """,
        subcommands: [AppsSubcommand.self, WindowsSubcommand.self, PermissionsSubcommand.self, MenuBarSubcommand.self],
        defaultSubcommand: AppsSubcommand.self)

    func run() async throws {
        // Root command doesn't do anything, subcommands handle everything
    }
}

/// Subcommand for listing all running applications using PeekabooServices.shared.
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

    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            // Check permissions using the service
            guard await PeekabooServices.shared.screenCapture.hasScreenRecordingPermission() else {
                throw CaptureError.screenRecordingPermissionDenied
            }

            // Get applications from the service
            let serviceApps = try await PeekabooServices.shared.applications.listApplications()

            // Convert to CLI model format for compatibility
            let applications = serviceApps.map { app in
                ApplicationInfo(
                    app_name: app.name,
                    bundle_id: app.bundleIdentifier ?? "unknown",
                    pid: app.processIdentifier,
                    is_active: app.isActive,
                    window_count: app.windowCount)
            }

            let data = ApplicationListData(applications: applications)

            if self.jsonOutput {
                outputSuccess(data: data)
            } else {
                self.printApplicationList(applications)
            }

        } catch {
            self.handleError(error)
            throw ExitCode(1)
        }
    }

    private func handleError(_ error: Error) {
        let captureError = mapErrorToCaptureError(error)

        if self.jsonOutput {
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

/// Subcommand for listing windows of a specific application using PeekabooServices.shared.
struct WindowsSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "windows",
        abstract: "List all windows for a specific application",
        discussion: """
        Lists all windows for the specified application using PeekabooCore PeekabooServices.shared.
        Windows are listed in z-order (frontmost first) with optional details.
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
            // Check permissions
            guard await PeekabooServices.shared.screenCapture.hasScreenRecordingPermission() else {
                throw CaptureError.screenRecordingPermissionDenied
            }

            // Find the target application using the service
            let targetApp = try await PeekabooServices.shared.applications.findApplication(identifier: self.app)

            // Parse include details options
            let detailOptions = self.parseIncludeDetails()

            // Get windows for the app using the service
            let serviceWindows = try await PeekabooServices.shared.applications.listWindows(for: self.app)

            // Convert to CLI model format with requested details
            let windows = serviceWindows.enumerated().map { _, window in
                WindowInfo(
                    window_title: window.title,
                    window_id: detailOptions.contains(.ids) ? UInt32(window.windowID) : nil,
                    bounds: detailOptions.contains(.bounds) ? WindowBounds(
                        x: Int(window.bounds.origin.x),
                        y: Int(window.bounds.origin.y),
                        width: Int(window.bounds.size.width),
                        height: Int(window.bounds.size.height)) : nil,
                    is_on_screen: detailOptions.contains(.off_screen) ? !window.isMinimized : nil)
            }

            let targetAppInfo = TargetApplicationInfo(
                app_name: targetApp.name,
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
            throw ExitCode(1)
        }
    }

    private func handleError(_ error: Error) {
        let captureError = mapErrorToCaptureError(error)

        if self.jsonOutput {
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

/// Subcommand for checking system permissions using PeekabooServices.shared.
struct PermissionsSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "permissions",
        abstract: "Check system permissions required for Peekaboo",
        discussion: """
        Checks system permissions using PeekabooCore PeekabooServices.shared.
        Verifies Screen Recording (required) and Accessibility (optional) permissions.
        """)

    @Flag(name: .long, help: "Output results in JSON format for scripting")
    var jsonOutput = false

    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        // Check permissions using the services
        let screenRecording = await PeekabooServices.shared.screenCapture.hasScreenRecordingPermission()
        let accessibility = await PeekabooServices.shared.automation.hasAccessibilityPermission()

        let permissions = PermissionStatus(
            screenRecording: screenRecording,
            accessibility: accessibility)

        let data = PermissionStatusData(permissions: permissions)

        if self.jsonOutput {
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
        case let .ambiguous(identifier, apps):
            let appNames = apps.map { $0.localizedName ?? "Unknown" }.joined(separator: ", ")
            return .ambiguousAppIdentifier(identifier, candidates: appNames)
        case let .ambiguousIdentifier(identifier, candidates):
            return .ambiguousAppIdentifier(identifier, candidates: candidates)
        case .noFrontmostApplication:
            return .noFrontmostApplication
        case let .notInstalled(identifier):
            return .appNotFound(identifier)
        case let .activationFailed(identifier):
            return .unknownError("Failed to activate application: \(identifier)")
        }
    } else {
        return .unknownError(error.localizedDescription)
    }
}

/// Maps CaptureError to ErrorCode for JSON output
private func mapCaptureErrorToCode(_ error: CaptureError) -> ErrorCode {
    switch error {
    case .screenRecordingPermissionDenied, .permissionDeniedScreenRecording:
        .PERMISSION_ERROR_SCREEN_RECORDING
    case .accessibilityPermissionDenied:
        .PERMISSION_ERROR_ACCESSIBILITY
    case .appNotFound:
        .APP_NOT_FOUND
    case .ambiguousAppIdentifier:
        .AMBIGUOUS_APP_IDENTIFIER
    case .windowNotFound, .noWindowsFound, .windowTitleNotFound:
        .WINDOW_NOT_FOUND
    case .fileWriteError, .fileIOError:
        .FILE_IO_ERROR
    case .invalidArgument:
        .INVALID_ARGUMENT
    case .captureCreationFailed, .windowCaptureFailed, .captureFailure, .captureFailed, .imageConversionFailed:
        .CAPTURE_FAILED
    case .noFrontmostApplication:
        .APP_NOT_FOUND
    case .invalidDisplayID, .invalidDisplayIndex, .invalidCaptureArea, .invalidWindowIndex, .invalidWindowIndexOld:
        .INVALID_ARGUMENT
    case .noDisplaysAvailable, .noDisplaysFound:
        .CAPTURE_FAILED
    case .unknownError:
        .UNKNOWN_ERROR
    }
}

/// Subcommand for listing menu bar items
struct MenuBarSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "menubar",
        abstract: "List all menu bar items (status icons)",
        discussion: """
        Lists all menu bar items (status icons) currently visible in the macOS menu bar.
        This includes system items like Wi-Fi, Battery, Time Machine, and third-party
        application status items.
        """)
    
    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false
    
    mutating func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)
        
        do {
            // Use the enhanced menu service to get menu bar items
            let menuExtras = try await PeekabooServices.shared.menu.listMenuExtras()
            
            if jsonOutput {
                let jsonItems = menuExtras.map { extra in
                    [
                        "name": extra.title,
                        "app_name": extra.title,
                        "position": [
                            "x": Int(extra.position.x),
                            "y": Int(extra.position.y)
                        ],
                        "visible": extra.isVisible
                    ] as [String: Any]
                }
                
                let output = JSONResponse(
                    success: true,
                    data: AnyCodable([
                        "count": menuExtras.count,
                        "items": jsonItems
                    ])
                )
                outputJSON(output)
            } else {
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
    
    private func handleError(_ error: Error) {
        if self.jsonOutput {
            outputError(
                message: error.localizedDescription,
                code: .UNKNOWN_ERROR,
                details: "Failed to list menu bar items")
        } else {
            fputs("Error: \(error.localizedDescription)\n", stderr)
        }
    }
}
