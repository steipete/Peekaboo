import AppKit
import ApplicationServices
import ArgumentParser
import AXorcist
import Foundation

struct AppCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app",
        abstract: "Manage application lifecycle",
        discussion: """
        Control application launching, quitting, hiding, and switching.

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
            ListSubcommand.self
        ]
    )

    // MARK: - Launch Application

    struct LaunchSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "launch",
            abstract: "Launch an application"
        )

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
            do {
                let workspace = NSWorkspace.shared
                var launched = false
                var launchedApp: NSRunningApplication?

                // Try to launch by bundle ID if provided
                if let bundleId {
                    if let url = workspace.urlForApplication(withBundleIdentifier: bundleId) {
                        let config = NSWorkspace.OpenConfiguration()
                        config.activates = !background

                        launchedApp = try await workspace.openApplication(at: url, configuration: config)
                        launched = true
                    } else {
                        throw AppError.applicationNotFound(bundleId)
                    }
                } else {
                    // Try to find app by name
                    let appName = app.hasSuffix(".app") ? app : "\(app).app"

                    // Check common locations
                    let searchPaths = [
                        "/Applications",
                        "/System/Applications",
                        "/Applications/Utilities",
                        "~/Applications",
                        "/System/Library/CoreServices"
                    ]

                    for path in searchPaths {
                        let expandedPath = NSString(string: path).expandingTildeInPath
                        let appPath = "\(expandedPath)/\(appName)"

                        if FileManager.default.fileExists(atPath: appPath) {
                            let url = URL(fileURLWithPath: appPath)
                            let config = NSWorkspace.OpenConfiguration()
                            config.activates = !background

                            launchedApp = try await workspace.openApplication(at: url, configuration: config)
                            launched = true
                            break
                        }
                    }

                    if !launched {
                        throw AppError.applicationNotFound(app)
                    }
                }

                // Wait until ready if requested
                if waitUntilReady, let runningApp = launchedApp {
                    let startTime = Date()
                    let timeoutInterval = TimeInterval(timeout) / 1000.0

                    while !runningApp.isFinishedLaunching {
                        if Date().timeIntervalSince(startTime) > timeoutInterval {
                            throw AppError.launchTimeout(app)
                        }
                        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    }
                }

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "launch",
                            "app": (launchedApp?.localizedName ?? app) as Any,
                            "bundle_id": (launchedApp?.bundleIdentifier ?? bundleId ?? "") as Any,
                            "pid": (launchedApp?.processIdentifier ?? 0) as Any,
                            "activated": !background
                        ])
                    )
                    outputJSON(response)
                } else {
                    print("✓ Launched \(launchedApp?.localizedName ?? app)")
                    if let pid = launchedApp?.processIdentifier {
                        print("  PID: \(pid)")
                    }
                }

            } catch let error as AppError {
                handleAppError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
            }
        }
    }

    // MARK: - Quit Application

    struct QuitSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "quit",
            abstract: "Quit an application"
        )

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
            guard app != nil || all else {
                throw ValidationError("Must specify either --app or --all")
            }

            do {
                let workspace = NSWorkspace.shared
                var quitApps: [NSRunningApplication] = []

                if all {
                    // Get all running applications
                    let allApps = workspace.runningApplications
                    let exceptions = except?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []

                    quitApps = allApps.filter { app in
                        // Skip system apps and exceptions
                        guard let bundleId = app.bundleIdentifier,
                              let name = app.localizedName else { return false }

                        // Always skip Finder and our own app
                        if bundleId == "com.apple.finder" || app.processIdentifier == ProcessInfo.processInfo
                            .processIdentifier {
                            return false
                        }

                        // Skip exceptions
                        if exceptions.contains(name) || exceptions.contains(bundleId) {
                            return false
                        }

                        // Skip background/system apps
                        return app.activationPolicy == .regular
                    }
                } else if let appName = app {
                    // Find specific app
                    if let (app, _) = try? await findApplication(identifier: appName) {
                        if let pid = app.pid() {
                            quitApps = workspace.runningApplications.filter { $0.processIdentifier == pid }
                        }
                    } else {
                        throw AppError.applicationNotRunning(appName)
                    }
                }

                // Quit the applications
                var quitResults: [[String: Any]] = []

                for app in quitApps {
                    let success = force ? app.forceTerminate() : app.terminate()
                    quitResults.append([
                        "app": app.localizedName ?? "Unknown",
                        "bundle_id": app.bundleIdentifier ?? "",
                        "pid": app.processIdentifier,
                        "success": success
                    ])
                }

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "quit",
                            "force": force,
                            "quit_apps": quitResults
                        ])
                    )
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
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
            }
        }
    }

    // MARK: - Hide Application

    struct HideSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "hide",
            abstract: "Hide an application"
        )

        @Option(help: "Application to hide")
        var app: String

        @Flag(help: "Hide all other applications")
        var others = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        mutating func run() async throws {
            do {
                let (app, _) = try await findApplication(identifier: app)

                if others {
                    // Hide other applications
                    try app.performAction(Attribute<String>("AXHideOthers"))
                } else {
                    // Hide this application
                    try app.performAction(.hide)
                }

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": others ? "hide_others" : "hide",
                            "app": app.title() ?? self.app
                        ])
                    )
                    outputJSON(response)
                } else {
                    if others {
                        print("✓ Hid all other applications")
                    } else {
                        print("✓ Hid \(app.title() ?? self.app)")
                    }
                }

            } catch let error as ApplicationError {
                handleApplicationError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
            }
        }
    }

    // MARK: - Unhide Application

    struct UnhideSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "unhide",
            abstract: "Show a hidden application"
        )

        @Option(help: "Application to show")
        var app: String?

        @Flag(help: "Show all hidden applications")
        var all = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        mutating func run() async throws {
            guard app != nil || all else {
                throw ValidationError("Must specify either --app or --all")
            }

            do {
                if all {
                    // Show all applications
                    let systemWide = Element.systemWide()
                    try systemWide.performAction(Attribute<String>("AXShowAll"))

                    // Output result
                    if jsonOutput {
                        let response = JSONResponse(
                            success: true,
                            data: AnyCodable([
                                "action": "unhide_all"
                            ])
                        )
                        outputJSON(response)
                    } else {
                        print("✓ Showed all hidden applications")
                    }
                } else if let appName = app {
                    let (app, _) = try await findApplication(identifier: appName)
                    try app.performAction(.unhide)

                    // Output result
                    if jsonOutput {
                        let response = JSONResponse(
                            success: true,
                            data: AnyCodable([
                                "action": "unhide",
                                "app": app.title() ?? appName
                            ])
                        )
                        outputJSON(response)
                    } else {
                        print("✓ Showed \(app.title() ?? appName)")
                    }
                }

            } catch let error as ApplicationError {
                handleApplicationError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
            }
        }
    }

    // MARK: - Switch Application

    struct SwitchSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "switch",
            abstract: "Switch to another application"
        )

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
            guard to != nil || cycle else {
                throw ValidationError("Must specify either --to or --cycle")
            }

            do {
                if cycle {
                    // Simulate Cmd+Tab or Cmd+Shift+Tab
                    let keyCode: CGKeyCode = 0x30 // Tab
                    let flags: CGEventFlags = reverse ? [.maskCommand, .maskShift] : [.maskCommand]

                    let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
                    let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)

                    keyDown?.flags = flags
                    keyUp?.flags = flags

                    keyDown?.post(tap: .cghidEventTap)
                    keyUp?.post(tap: .cghidEventTap)

                    // Output result
                    if jsonOutput {
                        let response = JSONResponse(
                            success: true,
                            data: AnyCodable([
                                "action": "cycle",
                                "direction": reverse ? "backward" : "forward"
                            ])
                        )
                        outputJSON(response)
                    } else {
                        print("✓ Cycled to \(reverse ? "previous" : "next") application")
                    }
                } else if let appName = to {
                    let (app, _) = try await findApplication(identifier: appName)

                    // Make the app frontmost
                    if let pid = app.pid() {
                        let workspace = NSWorkspace.shared
                        if let runningApp = workspace.runningApplications
                            .first(where: { $0.processIdentifier == pid }) {
                            runningApp.activate()

                            // Wait for activation
                            let startTime = Date()
                            while !runningApp.isActive && Date().timeIntervalSince(startTime) < 2.0 {
                                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                            }
                        }
                    }

                    // Output result
                    if jsonOutput {
                        let response = JSONResponse(
                            success: true,
                            data: AnyCodable([
                                "action": "switch",
                                "app": app.title() ?? appName as Any,
                                "pid": app.pid() ?? 0 as Any
                            ])
                        )
                        outputJSON(response)
                    } else {
                        print("✓ Switched to \(app.title() ?? appName)")
                    }
                }

            } catch let error as ApplicationError {
                handleApplicationError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
            }
        }
    }

    // MARK: - List Applications

    struct ListSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List running applications"
        )

        @Flag(help: "Include hidden applications")
        var includeHidden = false

        @Flag(help: "Include background applications")
        var includeBackground = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        func run() async throws {
            let workspace = NSWorkspace.shared
            var apps = workspace.runningApplications

            // Filter applications
            if !includeBackground {
                apps = apps.filter { $0.activationPolicy == .regular }
            }

            if !includeHidden {
                apps = apps.filter { !$0.isHidden }
            }

            // Sort by name
            apps.sort { ($0.localizedName ?? "") < ($1.localizedName ?? "") }

            // Prepare app data
            let appData = apps.compactMap { app -> [String: Any]? in
                guard let name = app.localizedName else { return nil }

                return [
                    "name": name,
                    "bundle_id": app.bundleIdentifier ?? "",
                    "pid": app.processIdentifier,
                    "active": app.isActive,
                    "hidden": app.isHidden,
                    "icon": app.icon != nil
                ]
            }

            // Output result
            if jsonOutput {
                let response = JSONResponse(
                    success: true,
                    data: AnyCodable([
                        "applications": appData,
                        "count": appData.count
                    ])
                )
                outputJSON(response)
            } else {
                print("Running applications:")
                for app in appData {
                    let name = app["name"] as? String ?? ""
                    let pid = app["pid"] as? Int32 ?? 0
                    let active = app["active"] as? Bool ?? false
                    let hidden = app["hidden"] as? Bool ?? false

                    var flags: [String] = []
                    if active { flags.append("active") }
                    if hidden { flags.append("hidden") }

                    let flagString = flags.isEmpty ? "" : " [\(flags.joined(separator: ", "))]"
                    print("  • \(name) (PID: \(pid))\(flagString)")
                }
                print("\nTotal: \(appData.count) applications")
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
                code: ErrorCode(rawValue: error.errorCode) ?? .UNKNOWN_ERROR
            )
        )
        outputJSON(response)
    } else {
        print("❌ \(error.localizedDescription)")
    }
}
