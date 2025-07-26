import AppKit
import ApplicationServices
import ArgumentParser
import AXorcist
import Foundation
import PeekabooCore

/// Control macOS applications
struct AppCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app",
        abstract: "Control applications - launch, quit, hide, show, and switch between apps",
        discussion: """
        EXAMPLES:
          # Launch an application
          peekaboo app launch "Visual Studio Code"
          peekaboo app launch --bundle-id com.microsoft.VSCode --wait-until-ready

          # Quit applications
          peekaboo app quit --app Safari
          peekaboo app quit --all --except "Finder,Terminal"

          # Hide/show applications
          peekaboo app hide --app Slack
          peekaboo app unhide --app Slack

          # Switch between applications
          peekaboo app switch --to Terminal
          peekaboo app switch --cycle  # Cmd+Tab equivalent
        """,
        subcommands: [
            LaunchSubcommand.self,
            QuitSubcommand.self,
            HideSubcommand.self,
            UnhideSubcommand.self,
            SwitchSubcommand.self,
            ListSubcommand.self,
        ])

    // MARK: - Launch Application

    struct LaunchSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "launch",
            abstract: "Launch an application")

        @Argument(help: "Application name or path")
        var app: String

        @Option(help: "Launch by bundle identifier instead of name")
        var bundleId: String?

        @Flag(help: "Wait until the application is ready")
        var waitUntilReady = false

        @Option(help: "Maximum time to wait in milliseconds (default: 10000)")
        var timeout: Int = 10000

        @Flag(help: "Launch in background without activating")
        var background = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            do {
                let identifier = self.bundleId ?? self.app

                // Launch the application using the service
                let appInfo = try await PeekabooServices.shared.applications.launchApplication(identifier: identifier)

                // If not background, activate it
                if !self.background {
                    try await PeekabooServices.shared.applications.activateApplication(identifier: identifier)
                }

                // Wait until ready if requested
                if self.waitUntilReady {
                    let startTime = Date()
                    let timeoutInterval = TimeInterval(timeout) / 1000.0

                    while true {
                        if let runningApp = NSRunningApplication(processIdentifier: appInfo.processIdentifier),
                           runningApp.isFinishedLaunching
                        {
                            break
                        }

                        if Date().timeIntervalSince(startTime) > timeoutInterval {
                            throw AppError.launchTimeout(self.app)
                        }
                        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    }
                }

                // Output result
                if self.jsonOutput {
                    var responseData: [String: Any] = [
                        "action": "launch",
                        "app": appInfo.name,
                        "bundle_id": appInfo.bundleIdentifier ?? "",
                        "pid": appInfo.processIdentifier,
                        "activated": !self.background,
                    ]
                    
                    // Wait a moment for windows to appear
                    try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                    
                    // Check if the app has windows
                    let windows = try? await PeekabooServices.shared.windows.listWindows(
                        target: .application(appInfo.name)
                    )
                    let windowCount = windows?.count ?? 0
                    responseData["window_count"] = windowCount
                    
                    // Add helpful context based on window state
                    if windowCount == 0 {
                        responseData["note"] = "Application launched but has no visible windows. Most document-based apps require creating a new document with 'hotkey' ['cmd', 'n']."
                        responseData["suggestion"] = "Try 'hotkey' with ['cmd', 'n'] to create a new window/document."
                    } else {
                        responseData["note"] = "Application launched successfully with \(windowCount) window(s) visible."
                    }
                    
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable(responseData))
                    outputJSON(response)
                } else {
                    print("✓ Launched \(appInfo.name)")
                    print("  PID: \(appInfo.processIdentifier)")
                }

            } catch let error as ApplicationError {
                handleApplicationServiceError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch let error as AppError {
                handleAppError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Quit Application

    struct QuitSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "quit",
            abstract: "Quit an application")

        @Option(help: "Application to quit")
        var app: String?

        @Flag(help: "Quit all applications")
        var all = false

        @Option(help: "Comma-separated list of apps to exclude when using --all")
        var except: String?

        @Flag(help: "Force quit without saving")
        var force = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            guard self.app != nil || self.all else {
                throw ValidationError("Must specify either --app or --all")
            }

            do {
                var quitResults: [[String: Any]] = []

                if self.all {
                    // Get all running applications using the service
                    let serviceApps = try await PeekabooServices.shared.applications.listApplications()
                    let exceptions = self.except?.split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) } ?? []

                    for appInfo in serviceApps {
                        // Skip system apps and exceptions
                        guard let bundleId = appInfo.bundleIdentifier else { continue }

                        // Always skip Finder and our own app
                        if bundleId == "com.apple.finder" ||
                            appInfo.processIdentifier == ProcessInfo.processInfo.processIdentifier
                        {
                            continue
                        }

                        // Skip exceptions
                        if exceptions.contains(appInfo.name) || exceptions.contains(bundleId) {
                            continue
                        }

                        // Quit the app using the service
                        let success = try await PeekabooServices.shared.applications.quitApplication(
                            identifier: appInfo.name,
                            force: self.force)

                        quitResults.append([
                            "app": appInfo.name,
                            "bundle_id": bundleId,
                            "pid": appInfo.processIdentifier,
                            "success": success,
                        ])
                    }
                } else if let appName = app {
                    // Find and quit specific app using the service
                    do {
                        let appInfo = try await PeekabooServices.shared.applications
                            .findApplication(identifier: appName)
                        let success = try await PeekabooServices.shared.applications.quitApplication(
                            identifier: appName,
                            force: self.force)

                        quitResults.append([
                            "app": appInfo.name,
                            "bundle_id": appInfo.bundleIdentifier ?? "",
                            "pid": appInfo.processIdentifier,
                            "success": success,
                        ])
                    } catch {
                        throw AppError.applicationNotRunning(appName)
                    }
                }

                // Output result
                if self.jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "quit",
                            "force": force,
                            "quit_apps": quitResults,
                        ]))
                    outputJSON(response)
                } else {
                    for result in quitResults {
                        let appName = result["app"] as? String ?? "Unknown"
                        let success = result["success"] as? Bool ?? false
                        if success {
                            print("✓ Quit \(appName)")
                        } else {
                            print("✗ Failed to quit \(appName)")
                        }
                    }
                }

            } catch let error as AppError {
                handleAppError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Hide Application

    struct HideSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "hide",
            abstract: "Hide an application")

        @Option(help: "Application to hide")
        var app: String

        @Flag(help: "Hide all other applications")
        var others = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            do {
                // Find the application using the service
                let appInfo = try await PeekabooServices.shared.applications.findApplication(identifier: self.app)

                if self.others {
                    // Hide other applications using the service
                    try await PeekabooServices.shared.applications.hideOtherApplications(identifier: self.app)
                } else {
                    // Hide this application using the service
                    try await PeekabooServices.shared.applications.hideApplication(identifier: self.app)
                }

                // Output result
                if self.jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": others ? "hide_others" : "hide",
                            "app": appInfo.name,
                        ]))
                    outputJSON(response)
                } else {
                    if self.others {
                        print("✓ Hid all other applications")
                    } else {
                        print("✓ Hid \(appInfo.name)")
                    }
                }

            } catch let error as ApplicationError {
                handleApplicationServiceError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Unhide Application

    struct UnhideSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "unhide",
            abstract: "Show a hidden application")

        @Option(help: "Application to show")
        var app: String?

        @Flag(help: "Show all hidden applications")
        var all = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            guard self.app != nil || self.all else {
                throw ValidationError("Must specify either --app or --all")
            }

            do {
                if self.all {
                    // Show all applications using the service
                    try await PeekabooServices.shared.applications.showAllApplications()

                    // Output result
                    if self.jsonOutput {
                        let response = JSONResponse(
                            success: true,
                            data: AnyCodable([
                                "action": "unhide_all",
                            ]))
                        outputJSON(response)
                    } else {
                        print("✓ Showed all hidden applications")
                    }
                } else if let appName = app {
                    // Find and unhide the application using the service
                    let appInfo = try await PeekabooServices.shared.applications.findApplication(identifier: appName)
                    try await PeekabooServices.shared.applications.unhideApplication(identifier: appName)

                    // Output result
                    if self.jsonOutput {
                        let response = JSONResponse(
                            success: true,
                            data: AnyCodable([
                                "action": "unhide",
                                "app": appInfo.name,
                            ]))
                        outputJSON(response)
                    } else {
                        print("✓ Showed \(appInfo.name)")
                    }
                }

            } catch let error as ApplicationError {
                handleApplicationServiceError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Switch Application

    struct SwitchSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "switch",
            abstract: "Switch to another application")

        @Option(name: .long, help: "Application to switch to")
        var to: String?

        @Flag(help: "Cycle through applications (Cmd+Tab)")
        var cycle = false

        @Flag(help: "Cycle backwards (Cmd+Shift+Tab)")
        var reverse = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            guard self.to != nil || self.cycle else {
                throw ValidationError("Must specify either --to or --cycle")
            }

            do {
                if self.cycle {
                    // Simulate Cmd+Tab or Cmd+Shift+Tab
                    let keyCode: CGKeyCode = 0x30 // Tab
                    let flags: CGEventFlags = self.reverse ? [.maskCommand, .maskShift] : [.maskCommand]

                    let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
                    let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)

                    keyDown?.flags = flags
                    keyUp?.flags = flags

                    keyDown?.post(tap: .cghidEventTap)
                    keyUp?.post(tap: .cghidEventTap)

                    // Output result
                    if self.jsonOutput {
                        let response = JSONResponse(
                            success: true,
                            data: AnyCodable([
                                "action": "cycle",
                                "direction": reverse ? "backward" : "forward",
                            ]))
                        outputJSON(response)
                    } else {
                        print("✓ Cycled to \(self.reverse ? "previous" : "next") application")
                    }
                } else if let appName = to {
                    // Find and activate the application using the service
                    let appInfo = try await PeekabooServices.shared.applications.findApplication(identifier: appName)
                    try await PeekabooServices.shared.applications.activateApplication(identifier: appName)

                    // Output result
                    if self.jsonOutput {
                        let response = JSONResponse(
                            success: true,
                            data: AnyCodable([
                                "action": "switch",
                                "app": appInfo.name,
                                "pid": appInfo.processIdentifier,
                            ]))
                        outputJSON(response)
                    } else {
                        print("✓ Switched to \(appInfo.name)")
                    }
                }

            } catch let error as ApplicationError {
                handleApplicationServiceError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - List Applications

    struct ListSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List running applications using ApplicationService")

        @Flag(help: "Include hidden applications")
        var includeHidden = false

        @Flag(help: "Include background applications")
        var includeBackground = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            do {
                // Get all applications from the service
                var apps = try await PeekabooServices.shared.applications.listApplications()

                // Filter based on flags
                if !self.includeBackground {
                    // Filter out background apps (those without regular activation policy)
                    // Since service already filters prohibited apps, we keep all returned apps
                }

                if !self.includeHidden {
                    apps = apps.filter { !$0.isHidden }
                }

                // Prepare app data for output
                let appData = apps.map { app -> [String: Any] in
                    [
                        "name": app.name,
                        "bundle_id": app.bundleIdentifier ?? "",
                        "pid": app.processIdentifier,
                        "active": app.isActive,
                        "hidden": app.isHidden,
                        "icon": true, // Assume icon exists for compatibility
                    ]
                }

                // Output result
                if self.jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "applications": appData,
                            "count": appData.count,
                        ]))
                    outputJSON(response)
                } else {
                    print("Running applications:")
                    for app in apps {
                        var flags: [String] = []
                        if app.isActive { flags.append("active") }
                        if app.isHidden { flags.append("hidden") }

                        let flagString = flags.isEmpty ? "" : " [\(flags.joined(separator: ", "))]"
                        print("  • \(app.name) (PID: \(app.processIdentifier))\(flagString)")
                    }
                    print("\nTotal: \(apps.count) applications")
                }

            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
                throw ExitCode(1)
            }
        }
    }
}

// MARK: - App Errors

enum AppError: LocalizedError {
    case applicationNotFound(String)
    case applicationNotRunning(String)
    case launchTimeout(String)
    case activationFailed(String)

    var errorDescription: String? {
        switch self {
        case let .applicationNotFound(app):
            "Application '\(app)' not found"
        case let .applicationNotRunning(app):
            "Application '\(app)' is not running"
        case let .launchTimeout(app):
            "Application '\(app)' failed to launch within timeout"
        case let .activationFailed(app):
            "Failed to activate application '\(app)'"
        }
    }

    var errorCode: String {
        switch self {
        case .applicationNotFound:
            "APP_NOT_FOUND"
        case .applicationNotRunning:
            "APP_NOT_RUNNING"
        case .launchTimeout:
            "LAUNCH_TIMEOUT"
        case .activationFailed:
            "ACTIVATION_FAILED"
        }
    }
}

// MARK: - Error Handling

private func handleAppError(_ error: AppError, jsonOutput: Bool) {
    if jsonOutput {
        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: error.localizedDescription,
                code: ErrorCode(rawValue: error.errorCode) ?? .UNKNOWN_ERROR))
        outputJSON(response)
    } else {
        fputs("❌ \(error.localizedDescription)\n", stderr)
    }
}

private func handleApplicationServiceError(_ error: ApplicationError, jsonOutput: Bool) {
    let appError: AppError
    switch error {
    case let .notFound(identifier):
        appError = .applicationNotFound(identifier)
    case let .ambiguous(identifier, apps):
        let appNames = apps.map { $0.localizedName ?? "Unknown" }.joined(separator: ", ")
        appError = .applicationNotFound("Multiple apps match '\(identifier)': \(appNames)")
    case let .ambiguousIdentifier(identifier, candidates):
        appError = .applicationNotFound("Multiple apps match '\(identifier)': \(candidates)")
    case .noFrontmostApplication:
        appError = .applicationNotFound("No frontmost application")
    case let .notInstalled(identifier):
        appError = .applicationNotFound(identifier)
    case let .activationFailed(identifier):
        appError = .activationFailed(identifier)
    }

    handleAppError(appError, jsonOutput: jsonOutput)
}
