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

    struct LaunchSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
        static let configuration = CommandConfiguration(
            commandName: "launch",
            abstract: "Launch an application")

        @Argument(help: "Application name or path")
        var app: String

        @Option(help: "Launch by bundle identifier instead of name")
        var bundleId: String?

        @Flag(help: "Wait for the application to be ready")
        var waitUntilReady = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)
            Logger.shared.verbose("Launching application: \(app)")

            do {
                let launchedApp: NSRunningApplication

                if let bundleId {
                    // Launch by bundle ID
                    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
                        throw NotFoundError.application("Bundle ID: \(bundleId)")
                    }
                    launchedApp = try await launchApplication(at: url, name: bundleId)
                } else {
                    // Try to find app by name
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app) {
                        // It's actually a bundle ID
                        launchedApp = try await launchApplication(at: url, name: app)
                    } else if let url = findApplicationByName(app) {
                        // Found by name
                        launchedApp = try await launchApplication(at: url, name: app)
                    } else if app.contains("/") {
                        // It's a path
                        let url = URL(fileURLWithPath: app)
                        launchedApp = try await launchApplication(at: url, name: app)
                    } else {
                        throw NotFoundError.application(app)
                    }
                }

                // Wait until ready if requested
                if waitUntilReady {
                    try await waitForApplicationReady(launchedApp)
                }

                let data = [
                    "action": "launch",
                    "app_name": launchedApp.localizedName ?? app,
                    "bundle_id": launchedApp.bundleIdentifier ?? "unknown",
                    "pid": launchedApp.processIdentifier,
                    "is_ready": launchedApp.isFinishedLaunching
                ]

                output(data) {
                    print("✓ Launched \(launchedApp.localizedName ?? app) (PID: \(launchedApp.processIdentifier))")
                }

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }

        private func findApplicationByName(_ name: String) -> URL? {
            let workspace = NSWorkspace.shared
            // Check common application directories
            let searchPaths = [
                "/Applications",
                "/System/Applications",
                "~/Applications",
                "/Applications/Utilities"
            ].map { NSString(string: $0).expandingTildeInPath }

            for path in searchPaths {
                let appPath = "\(path)/\(name).app"
                if FileManager.default.fileExists(atPath: appPath) {
                    return URL(fileURLWithPath: appPath)
                }
            }
            return nil
        }

        private func launchApplication(at url: URL, name: String) async throws -> NSRunningApplication {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            do {
                let app = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
                return app
            } catch {
                throw InteractionError.launchFailed("Failed to launch \(name): \(error.localizedDescription)")
            }
        }

        private func waitForApplicationReady(_ app: NSRunningApplication, timeout: TimeInterval = 10) async throws {
            let startTime = Date()
            while !app.isFinishedLaunching {
                if Date().timeIntervalSince(startTime) > timeout {
                    throw InteractionError.timeout("Application did not become ready within \(Int(timeout)) seconds")
                }
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }
    }

    // MARK: - Quit Application

    struct QuitSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable, ApplicationResolvable {
        static let configuration = CommandConfiguration(
            commandName: "quit",
            abstract: "Quit one or more applications")

        @Option(help: "Application to quit")
        var app: String?

        @Flag(help: "Quit all applications")
        var all = false

        @Option(help: "Comma-separated list of apps to exclude when using --all")
        var except: String?

        @Flag(help: "Force quit (doesn't save changes)")
        var force = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            do {
                var quitApps: [(String, NSRunningApplication)] = []

                if all {
                    // Get all apps except system/excluded ones
                    let excluded = Set((except ?? "").split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
                    let systemApps = Set(["Finder", "Dock", "SystemUIServer", "WindowServer"])
                    
                    let runningApps = NSWorkspace.shared.runningApplications
                    for runningApp in runningApps {
                        guard let name = runningApp.localizedName,
                              runningApp.activationPolicy == .regular,
                              !systemApps.contains(name),
                              !excluded.contains(name) else { continue }
                        
                        quitApps.append((name, runningApp))
                    }
                } else if let appName = app {
                    // Find specific app
                    let appInfo = try await resolveApplication(appName)
                    let runningApps = NSWorkspace.shared.runningApplications
                    if let runningApp = runningApps.first(where: { $0.processIdentifier == appInfo.processIdentifier }) {
                        quitApps.append((appInfo.name, runningApp))
                    } else {
                        throw NotFoundError.application(appName)
                    }
                } else {
                    throw ValidationError("Either --app or --all must be specified")
                }

                // Quit the apps
                var results: [[String: Any]] = []
                for (name, runningApp) in quitApps {
                    let success = force ? runningApp.forceTerminate() : runningApp.terminate()
                    results.append([
                        "app_name": name,
                        "pid": runningApp.processIdentifier,
                        "success": success
                    ])
                }

                let data = [
                    "action": "quit",
                    "force": force,
                    "results": results
                ]

                output(data) {
                    for result in results {
                        let name = result["app_name"] as? String ?? "Unknown"
                        let success = result["success"] as? Bool ?? false
                        if success {
                            print("✓ Quit \(name)")
                        } else {
                            print("✗ Failed to quit \(name)")
                        }
                    }
                }

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Hide Application

    struct HideSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable, ApplicationResolvable {
        static let configuration = CommandConfiguration(
            commandName: "hide",
            abstract: "Hide an application")

        @Option(help: "Application to hide")
        var app: String

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            do {
                let appInfo = try await resolveApplication(app)
                
                await MainActor.run {
                    let element = Element(AXUIElementCreateApplication(appInfo.processIdentifier))
                    _ = element.performAction(.init(kAXHideAction))
                }

                let data = [
                    "action": "hide",
                    "app_name": appInfo.name,
                    "bundle_id": appInfo.bundleIdentifier ?? "unknown"
                ]

                output(data) {
                    print("✓ Hidden \(appInfo.name)")
                }

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Unhide Application

    struct UnhideSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable, ApplicationResolvable {
        static let configuration = CommandConfiguration(
            commandName: "unhide",
            abstract: "Show a hidden application")

        @Option(help: "Application to unhide")
        var app: String

        @Flag(help: "Bring to front after unhiding")
        var activate = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            do {
                let appInfo = try await resolveApplication(app)
                
                await MainActor.run {
                    let element = Element(AXUIElementCreateApplication(appInfo.processIdentifier))
                    _ = element.performAction(.init(kAXUnhideAction))
                }

                // Activate if requested
                if activate {
                    let runningApps = NSWorkspace.shared.runningApplications
                    if let runningApp = runningApps.first(where: { $0.processIdentifier == appInfo.processIdentifier }) {
                        runningApp.activate(options: .activateIgnoringOtherApps)
                    }
                }

                let data = [
                    "action": "unhide",
                    "app_name": appInfo.name,
                    "bundle_id": appInfo.bundleIdentifier ?? "unknown",
                    "activated": activate
                ]

                output(data) {
                    print("✓ Shown \(appInfo.name)")
                }

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Switch Application

    struct SwitchSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable, ApplicationResolvable {
        static let configuration = CommandConfiguration(
            commandName: "switch",
            abstract: "Switch to another application")

        @Option(help: "Switch to this application")
        var to: String?

        @Flag(help: "Cycle to next app (Cmd+Tab)")
        var cycle = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            do {
                if cycle {
                    // Simulate Cmd+Tab
                    let source = CGEventSource(stateID: .hidSystemState)
                    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x30, keyDown: true) // Tab
                    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x30, keyDown: false)
                    
                    keyDown?.flags = .maskCommand
                    keyUp?.flags = .maskCommand
                    
                    keyDown?.post(tap: .cghidEventTap)
                    keyUp?.post(tap: .cghidEventTap)
                    
                    let data = ["action": "cycle", "success": true]
                    
                    output(data) {
                        print("✓ Cycled to next application")
                    }
                } else if let targetApp = to {
                    let appInfo = try await resolveApplication(targetApp)
                    
                    // Find and activate the app
                    let runningApps = NSWorkspace.shared.runningApplications
                    guard let runningApp = runningApps.first(where: { $0.processIdentifier == appInfo.processIdentifier }) else {
                        throw NotFoundError.application(targetApp)
                    }
                    
                    let success = runningApp.activate(options: .activateIgnoringOtherApps)
                    
                    let data = [
                        "action": "switch",
                        "app_name": appInfo.name,
                        "bundle_id": appInfo.bundleIdentifier ?? "unknown",
                        "success": success
                    ]
                    
                    output(data) {
                        print("✓ Switched to \(appInfo.name)")
                    }
                } else {
                    throw ValidationError("Either --to or --cycle must be specified")
                }

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - List Applications

    struct ListSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List running applications")

        @Flag(help: "Include hidden apps")
        var includeHidden = false

        @Flag(help: "Include background apps")
        var includeBackground = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            do {
                let apps = try await PeekabooServices.shared.applications.listApplications()
                
                // Filter based on flags
                let filtered = apps.filter { app in
                    if !includeHidden && app.isHidden { return false }
                    if !includeBackground && app.name.isEmpty { return false }
                    return true
                }

                let data = [
                    "count": filtered.count,
                    "apps": filtered.map { app in
                        [
                            "name": app.name,
                            "bundle_id": app.bundleIdentifier ?? "unknown",
                            "pid": app.processIdentifier,
                            "is_active": app.isActive,
                            "is_hidden": app.isHidden
                        ]
                    }
                ]

                output(data) {
                    print("Running Applications (\(filtered.count)):")
                    for app in filtered {
                        let status = app.isActive ? " [active]" : app.isHidden ? " [hidden]" : ""
                        print("  • \(app.name)\(status)")
                        print("    Bundle: \(app.bundleIdentifier ?? "unknown")")
                        print("    PID: \(app.processIdentifier)")
                    }
                }

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }
}