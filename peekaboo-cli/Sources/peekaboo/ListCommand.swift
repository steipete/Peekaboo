import ArgumentParser
import Foundation

#if os(macOS)
import AppKit
#endif

struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List running applications or windows",
        subcommands: [AppsSubcommand.self, WindowsSubcommand.self, ServerStatusSubcommand.self],
        defaultSubcommand: AppsSubcommand.self
    )

    func run() async throws {
        // Root command doesn't do anything, subcommands handle everything
    }
}

struct AppsSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apps",
        abstract: "List all running applications"
    )

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    func run() async throws {
        Logger.shared.setJsonOutputMode(jsonOutput)

        // Check platform support
        guard PlatformFactory.isSupported else {
            let error = CaptureError.platformNotSupported(PlatformFactory.currentPlatform)
            handleError(error)
            throw ExitCode(Int32(1))
        }
        
        let capabilities = PlatformFactory.capabilities
        guard capabilities.applicationFinding else {
            let error = CaptureError.featureNotSupported("Application listing", PlatformFactory.currentPlatform)
            handleError(error)
            throw ExitCode(Int32(1))
        }

        do {
            // Check permissions using platform-specific checker
            let permissionsChecker = PlatformFactory.createPermissionsChecker()
            let hasPermission = await permissionsChecker.hasScreenRecordingPermission()
            
            if !hasPermission {
                let instructions = permissionsChecker.getPermissionInstructions()
                Logger.shared.error("Screen recording permission required. \(instructions)")
                let error = CaptureError.screenRecordingPermissionDenied
                handleError(error)
                throw ExitCode(Int32(1))
            }

            let applicationFinder = PlatformFactory.createApplicationFinder()
            let applications = try await applicationFinder.getRunningApplications()
            
            // Convert to the expected format
            let appInfos = applications.map { app in
                ApplicationInfo(
                    app_name: app.name,
                    bundle_id: app.bundleIdentifier ?? "",
                    pid: Int32(app.processId ?? 0),
                    is_active: app.isRunning,
                    window_count: 0 // This would need to be calculated separately
                )
            }
            
            let data = ApplicationListData(applications: appInfos)

            if jsonOutput {
                outputSuccess(data: data)
            } else {
                printApplicationList(appInfos)
            }

        } catch {
            handleError(error)
            throw ExitCode(Int32(1))
        }
    }

    private func handleError(_ error: Error) {
        let captureError: CaptureError = if let err = error as? CaptureError {
            err
        } else {
            CaptureError.unknownError(error.localizedDescription)
        }

        ImageErrorHandler.handleError(captureError, jsonOutput: jsonOutput)
    }

    private func printApplicationList(_ applications: [ApplicationInfo]) {
        print("Running Applications:")
        print("====================")

        for app in applications {
            let activeStatus = app.is_active ? "●" : "○"
            let bundleInfo = app.bundle_id.isEmpty ? "" : " (\(app.bundle_id))"
            print("\(activeStatus) \(app.app_name)\(bundleInfo) [PID: \(app.pid)]")
        }

        print("\nTotal: \(applications.count) applications")
        print("● = Active, ○ = Background")
    }
}

struct WindowsSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "windows",
        abstract: "List windows for a specific application"
    )

    @Option(name: .long, help: "Target application identifier")
    var app: String

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    @Option(name: .long, help: "Window details to include")
    var details: [WindowDetailOption] = []

    func run() async throws {
        Logger.shared.setJsonOutputMode(jsonOutput)

        // Check platform support
        guard PlatformFactory.isSupported else {
            let error = CaptureError.platformNotSupported(PlatformFactory.currentPlatform)
            handleError(error)
            throw ExitCode(Int32(1))
        }
        
        let capabilities = PlatformFactory.capabilities
        guard capabilities.windowManagement else {
            let error = CaptureError.featureNotSupported("Window management", PlatformFactory.currentPlatform)
            handleError(error)
            throw ExitCode(Int32(1))
        }

        do {
            // Check permissions
            let permissionsChecker = PlatformFactory.createPermissionsChecker()
            let hasAccessibility = await permissionsChecker.hasAccessibilityPermission()
            
            if !hasAccessibility {
                let instructions = permissionsChecker.getPermissionInstructions()
                Logger.shared.error("Accessibility permission required. \(instructions)")
                let error = CaptureError.accessibilityPermissionDenied
                handleError(error)
                throw ExitCode(Int32(1))
            }

            // Find the application
            let applicationFinder = PlatformFactory.createApplicationFinder()
            let apps = try await applicationFinder.findApplications(matching: app)
            
            guard !apps.isEmpty else {
                throw CaptureError.appNotFound(app)
            }
            
            let targetApp = apps.first!
            
            // Get windows for the application
            let windowManager = PlatformFactory.createWindowManager()
            let windows = try await windowManager.getWindows(for: targetApp.id)

            // Convert to the expected format
            let windowInfos = windows.enumerated().map { index, window in
                WindowInfo(
                    window_title: window.title,
                    window_id: UInt32(window.id) ?? nil,
                    window_index: index,
                    bounds: details.contains(.bounds) ? WindowBounds(
                        x_coordinate: Int(window.bounds.minX),
                        y_coordinate: Int(window.bounds.minY),
                        width: Int(window.bounds.width),
                        height: Int(window.bounds.height)
                    ) : nil,
                    is_on_screen: details.contains(.off_screen) ? window.isVisible : nil
                )
            }

            let targetAppInfo = TargetApplicationInfo(
                app_name: targetApp.name,
                bundle_id: targetApp.bundleIdentifier,
                pid: Int32(targetApp.processId ?? 0)
            )

            let data = WindowListData(
                windows: windowInfos,
                target_application_info: targetAppInfo
            )

            if jsonOutput {
                outputSuccess(data: data)
            } else {
                printWindowList(data)
            }

        } catch {
            handleError(error)
            throw ExitCode(Int32(1))
        }
    }

    private func handleError(_ error: Error) {
        let captureError: CaptureError = if let err = error as? CaptureError {
            err
        } else {
            CaptureError.unknownError(error.localizedDescription)
        }

        ImageErrorHandler.handleError(captureError, jsonOutput: jsonOutput)
    }

    private func printWindowList(_ data: WindowListData) {
        let appInfo = data.target_application_info
        print("Windows for \(appInfo.app_name) [PID: \(appInfo.pid)]:")
        print("=" + String(repeating: "=", count: appInfo.app_name.count + 20))

        if data.windows.isEmpty {
            print("No windows found.")
            return
        }

        for (index, window) in data.windows.enumerated() {
            print("[\(index)] \(window.window_title)")

            if let bounds = window.bounds {
                print("    Position: (\(bounds.x_coordinate), \(bounds.y_coordinate))")
                print("    Size: \(bounds.width) × \(bounds.height)")
            }

            if let windowId = window.window_id {
                print("    Window ID: \(windowId)")
            }

            if let isOnScreen = window.is_on_screen {
                print("    On Screen: \(isOnScreen ? "Yes" : "No")")
            }

            if index < data.windows.count - 1 {
                print()
            }
        }

        print("\nTotal: \(data.windows.count) windows")
    }
}

struct ServerStatusSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "server-status",
        abstract: "Show platform and capability status"
    )

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    func run() async throws {
        Logger.shared.setJsonOutputMode(jsonOutput)

        let capabilities = PlatformFactory.capabilities
        let permissionsChecker = PlatformFactory.createPermissionsChecker()
        
        let screenRecordingPermission = await permissionsChecker.hasScreenRecordingPermission()
        let accessibilityPermission = await permissionsChecker.hasAccessibilityPermission()

        if jsonOutput {
            let status = [
                "platform": PlatformFactory.currentPlatform,
                "supported": PlatformFactory.isSupported,
                "capabilities": [
                    "screen_capture": capabilities.screenCapture,
                    "window_management": capabilities.windowManagement,
                    "application_finding": capabilities.applicationFinding,
                    "permissions": capabilities.permissions
                ],
                "permissions": [
                    "screen_recording": screenRecordingPermission,
                    "accessibility": accessibilityPermission
                ]
            ] as [String: Any]
            
            let jsonData = try JSONSerialization.data(withJSONObject: status, options: .prettyPrinted)
            print(String(data: jsonData, encoding: .utf8) ?? "{}")
        } else {
            print("🌍 Platform: \(PlatformFactory.currentPlatform)")
            print("✅ Supported: \(PlatformFactory.isSupported ? "Yes" : "No")")
            print()
            print("📋 Capabilities:")
            print("   Screen Capture: \(capabilities.screenCapture ? "✅" : "❌")")
            print("   Window Management: \(capabilities.windowManagement ? "✅" : "❌")")
            print("   Application Finding: \(capabilities.applicationFinding ? "✅" : "❌")")
            print("   Permissions: \(capabilities.permissions ? "✅" : "❌")")
            print()
            print("🔐 Permissions:")
            print("   Screen Recording: \(screenRecordingPermission ? "✅ Granted" : "❌ Required")")
            print("   Accessibility: \(accessibilityPermission ? "✅ Granted" : "❌ Required")")
            
            if !screenRecordingPermission || !accessibilityPermission {
                print()
                print("ℹ️  Permission Instructions:")
                print(permissionsChecker.getPermissionInstructions())
            }
        }
    }
}

