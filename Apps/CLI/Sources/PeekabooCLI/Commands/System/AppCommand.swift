import AppKit
import ApplicationServices
@preconcurrency import ArgumentParser
import AXorcist
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Control macOS applications
struct AppCommand: ParsableCommand {
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

          # Relaunch applications
          peekaboo app relaunch Safari
          peekaboo app relaunch "Visual Studio Code" --wait 3 --wait-until-ready
        """,
        subcommands: [
            LaunchSubcommand.self,
            QuitSubcommand.self,
            RelaunchSubcommand.self,
            HideSubcommand.self,
            UnhideSubcommand.self,
            SwitchSubcommand.self,
            ListSubcommand.self,
        ]
    )

    // MARK: - Launch Application

    struct LaunchSubcommand: AsyncParsableCommand, AsyncRuntimeCommand, ErrorHandlingCommand, OutputFormattable {
        static let configuration = CommandConfiguration(
            commandName: "launch",
            abstract: "Launch an application"
        )

        @Argument(help: "Application name or path")
        var app: String

        @Option(help: "Launch by bundle identifier instead of name")
        var bundleId: String?

        @Flag(help: "Wait for the application to be ready")
        var waitUntilReady = false

        @OptionGroup
        var runtimeOptions: CommandRuntimeOptions

        @RuntimeStorage private var runtime: CommandRuntime?

        private var logger: Logger {
            self.runtime?.logger ?? Logger.shared
        }

        private var services: PeekabooServices {
            self.runtime?.services ?? PeekabooServices.shared
        }

        var outputLogger: Logger { self.logger }

        private var services: PeekabooServices {
            self.runtime?.services ?? PeekabooServices.shared
        }

        var jsonOutput: Bool {
            self.runtimeOptions.jsonOutput
        }

        mutating func run() async throws {
            let runtime = CommandRuntime(options: self.runtimeOptions)
            try await self.run(using: runtime)
        }

        /// Resolve the requested app target, launch it, optionally wait until ready, and emit output.
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            let logger = self.logger
            logger.verbose("Launching application: \(self.app)")

            do {
                let launchedApp: NSRunningApplication

                if let bundleId {
                    // Launch by bundle ID
                    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
                        throw NotFoundError.application("Bundle ID: \(bundleId)")
                    }
                    launchedApp = try await self.launchApplication(at: url, name: bundleId)
                } else {
                    // Try to find app by name
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app) {
                        // It's actually a bundle ID
                        launchedApp = try await self.launchApplication(at: url, name: self.app)
                    } else if let url = findApplicationByName(app) {
                        // Found by name
                        launchedApp = try await self.launchApplication(at: url, name: self.app)
                    } else if self.app.contains("/") {
                        // It's a path
                        let url = URL(fileURLWithPath: app)
                        launchedApp = try await self.launchApplication(at: url, name: self.app)
                    } else {
                        throw NotFoundError.application(self.app)
                    }
                }

                // Wait until ready if requested
                if self.waitUntilReady {
                    try await self.waitForApplicationReady(launchedApp)
                }

                struct LaunchResult: Codable {
                    let action: String
                    let app_name: String
                    let bundle_id: String
                    let pid: Int32
                    let is_ready: Bool
                }

                let data = LaunchResult(
                    action: "launch",
                    app_name: launchedApp.localizedName ?? self.app,
                    bundle_id: launchedApp.bundleIdentifier ?? "unknown",
                    pid: launchedApp.processIdentifier,
                    is_ready: launchedApp.isFinishedLaunching
                )

                output(data) {
                    print("✓ Launched \(launchedApp.localizedName ?? self.app) (PID: \(launchedApp.processIdentifier))")
                }

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }

        private func findApplicationByName(_ name: String) -> URL? {
            _ = NSWorkspace.shared
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
                throw PeekabooError.commandFailed("Failed to launch \(name): \(error.localizedDescription)")
            }
        }

        private func waitForApplicationReady(_ app: NSRunningApplication, timeout: TimeInterval = 10) async throws {
            let startTime = Date()
            while !app.isFinishedLaunching {
                if Date().timeIntervalSince(startTime) > timeout {
                    throw PeekabooError.timeout("Application did not become ready within \(Int(timeout)) seconds")
                }
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }
    }

    // MARK: - Quit Application

    struct QuitSubcommand: AsyncParsableCommand, AsyncRuntimeCommand, ErrorHandlingCommand, OutputFormattable, ApplicationResolvable,
    ApplicationResolver {
        static let configuration = CommandConfiguration(
            commandName: "quit",
            abstract: "Quit one or more applications"
        )

        @Option(help: "Application to quit")
        var app: String?

        @Option(name: .long, help: "Target application by process ID")
        var pid: Int32?

        @Flag(help: "Quit all applications")
        var all = false

        @Option(help: "Comma-separated list of apps to exclude when using --all")
        var except: String?

        @Flag(help: "Force quit (doesn't save changes)")
        var force = false

        @OptionGroup
        var runtimeOptions: CommandRuntimeOptions

        @RuntimeStorage private var runtime: CommandRuntime?

        private var logger: Logger {
            self.runtime?.logger ?? Logger.shared
        }

        var outputLogger: Logger { self.logger }

        var jsonOutput: Bool {
            self.runtimeOptions.jsonOutput
        }

        mutating func run() async throws {
            let runtime = CommandRuntime(options: self.runtimeOptions)
            try await self.run(using: runtime)
        }

        /// Resolve the targeted applications, issue quit or force-quit requests, and report results per app.
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            let logger = self.logger

            do {
                var quitApps: [(String, NSRunningApplication)] = []

                if self.all {
                    // Get all apps except system/excluded ones
                    let excluded = Set((except ?? "").split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespaces) }
                    )
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
                    let appInfo = try await resolveApplication(appName, services: self.services)
                    let runningApps = NSWorkspace.shared.runningApplications
                    if let runningApp = runningApps
                        .first(where: { $0.processIdentifier == appInfo.processIdentifier }) {
                        quitApps.append((appInfo.name, runningApp))
                    } else {
                        throw NotFoundError.application(appName)
                    }
                } else {
                    throw ValidationError("Either --app or --all must be specified")
                }

                // Quit the apps
                struct AppQuitInfo: Codable {
                    let app_name: String
                    let pid: Int32
                    let success: Bool
                }

                var results: [AppQuitInfo] = []
                for (name, runningApp) in quitApps {
                    let success = self.force ? runningApp.forceTerminate() : runningApp.terminate()
                    results.append(AppQuitInfo(
                        app_name: name,
                        pid: runningApp.processIdentifier,
                        success: success
                    ))

                    // Log additional debug info when quit fails
                    if !success && !self.jsonOutput {
                        // Check if app might be in a modal state or have unsaved changes
                        if !self.force {
                            logger
                                .debug(
                                    "Quit failed for \(name) (PID: \(runningApp.processIdentifier)). The app may have unsaved changes or be showing a dialog. Try --force to force quit."
                                )
                        } else {
                            logger
                                .debug(
                                    "Force quit failed for \(name) (PID: \(runningApp.processIdentifier)). The app may be unresponsive or protected."
                                )
                        }
                    }
                }

                struct QuitResult: Codable {
                    let action: String
                    let force: Bool
                    let results: [AppQuitInfo]
                }

                let data = QuitResult(
                    action: "quit",
                    force: force,
                    results: results
                )

                output(data) {
                    for result in results {
                        if result.success {
                            print("✓ Quit \(result.app_name)")
                        } else {
                            print("✗ Failed to quit \(result.app_name) (PID: \(result.pid))")
                            if !self.force {
                                print(
                                    "  💡 Tip: The app may have unsaved changes or be showing a dialog. Try --force to force quit."
                                )
                            }
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

    struct HideSubcommand: AsyncParsableCommand, AsyncRuntimeCommand, ErrorHandlingCommand, OutputFormattable,
    ApplicationResolvablePositional, ApplicationResolver {
        static let configuration = CommandConfiguration(
            commandName: "hide",
            abstract: "Hide an application"
        )

        @Option(help: "Application to hide")
        var app: String

        @Option(name: .long, help: "Target application by process ID")
        var pid: Int32?

        @OptionGroup
        var runtimeOptions: CommandRuntimeOptions

        @RuntimeStorage private var runtime: CommandRuntime?

        private var logger: Logger {
            self.runtime?.logger ?? Logger.shared
        }

        var outputLogger: Logger { self.logger }

        private var services: PeekabooServices {
            self.runtime?.services ?? PeekabooServices.shared
        }

        var jsonOutput: Bool {
            self.runtimeOptions.jsonOutput
        }

        mutating func run() async throws {
            let runtime = CommandRuntime(options: self.runtimeOptions)
            try await self.run(using: runtime)
        }

        /// Hide the specified application and emit confirmation in either text or JSON form.
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime

            do {
                let appIdentifier = try self.resolveApplicationIdentifier()
                    let appInfo = try await resolveApplication(appIdentifier, services: self.services)

                await MainActor.run {
                    let element = Element(AXUIElementCreateApplication(appInfo.processIdentifier))
                    _ = element.hideApplication()
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

    struct UnhideSubcommand: AsyncParsableCommand, AsyncRuntimeCommand, ErrorHandlingCommand, OutputFormattable,
    ApplicationResolvablePositional, ApplicationResolver {
        static let configuration = CommandConfiguration(
            commandName: "unhide",
            abstract: "Show a hidden application"
        )

        @Option(help: "Application to unhide")
        var app: String

        @Option(name: .long, help: "Target application by process ID")
        var pid: Int32?

        @Flag(help: "Bring to front after unhiding")
        var activate = false

        @OptionGroup
        var runtimeOptions: CommandRuntimeOptions

        @RuntimeStorage private var runtime: CommandRuntime?

        private var logger: Logger {
            self.runtime?.logger ?? Logger.shared
        }

        var outputLogger: Logger { self.logger }

        private var services: PeekabooServices {
            self.runtime?.services ?? PeekabooServices.shared
        }

        var jsonOutput: Bool {
            self.runtimeOptions.jsonOutput
        }

        mutating func run() async throws {
            let runtime = CommandRuntime(options: self.runtimeOptions)
            try await self.run(using: runtime)
        }

        /// Unhide the target application and optionally re-activate its main window.
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime

            do {
                let appIdentifier = try self.resolveApplicationIdentifier()
                let appInfo = try await resolveApplication(appIdentifier, services: self.services)

                await MainActor.run {
                    let element = Element(AXUIElementCreateApplication(appInfo.processIdentifier))
                    _ = element.unhideApplication()
                }

                // Activate if requested
                if self.activate {
                    let runningApps = NSWorkspace.shared.runningApplications
                    if let runningApp = runningApps
                        .first(where: { $0.processIdentifier == appInfo.processIdentifier }) {
                        runningApp.activate()
                    }
                }

                struct UnhideResult: Codable {
                    let action: String
                    let app_name: String
                    let bundle_id: String
                    let activated: Bool
                }

                let data = UnhideResult(
                    action: "unhide",
                    app_name: appInfo.name,
                    bundle_id: appInfo.bundleIdentifier ?? "unknown",
                    activated: self.activate
                )

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

    struct SwitchSubcommand: AsyncParsableCommand, AsyncRuntimeCommand, ErrorHandlingCommand, OutputFormattable, ApplicationResolver {
        static let configuration = CommandConfiguration(
            commandName: "switch",
            abstract: "Switch to another application"
        )

        @Option(help: "Switch to this application")
        var to: String?

        @Flag(help: "Cycle to next app (Cmd+Tab)")
        var cycle = false

        @OptionGroup
        var runtimeOptions: CommandRuntimeOptions

        @RuntimeStorage private var runtime: CommandRuntime?

        private var logger: Logger {
            self.runtime?.logger ?? Logger.shared
        }

        var outputLogger: Logger { self.logger }

        private var services: PeekabooServices {
            self.runtime?.services ?? PeekabooServices.shared
        }

        var jsonOutput: Bool {
            self.runtimeOptions.jsonOutput
        }

        mutating func run() async throws {
            let runtime = CommandRuntime(options: self.runtimeOptions)
            try await self.run(using: runtime)
        }

        /// Switch focus either by cycling (Cmd+Tab) or by activating a specific application.
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime

            do {
                if self.cycle {
                    // Simulate Cmd+Tab
                    let source = CGEventSource(stateID: .hidSystemState)
                    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x30, keyDown: true) // Tab
                    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x30, keyDown: false)

                    keyDown?.flags = .maskCommand
                    keyUp?.flags = .maskCommand

                    keyDown?.post(tap: .cghidEventTap)
                    keyUp?.post(tap: .cghidEventTap)

                    struct CycleResult: Codable {
                        let action: String
                        let success: Bool
                    }

                    let data = CycleResult(action: "cycle", success: true)

                    output(data) {
                        print("✓ Cycled to next application")
                    }
                } else if let targetApp = to {
                    let appInfo = try await resolveApplication(targetApp, services: self.services)

                    // Find and activate the app
                    let runningApps = NSWorkspace.shared.runningApplications
                    guard let runningApp = runningApps
                        .first(where: { $0.processIdentifier == appInfo.processIdentifier }) else {
                        throw NotFoundError.application(targetApp)
                    }

                    let success = runningApp.activate()

                    struct SwitchResult: Codable {
                        let action: String
                        let app_name: String
                        let bundle_id: String
                        let success: Bool
                    }

                    let data = SwitchResult(
                        action: "switch",
                        app_name: appInfo.name,
                        bundle_id: appInfo.bundleIdentifier ?? "unknown",
                        success: success
                    )

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

    struct ListSubcommand: AsyncParsableCommand, AsyncRuntimeCommand, ErrorHandlingCommand, OutputFormattable {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List running applications"
        )

        @Flag(help: "Include hidden apps")
        var includeHidden = false

        @Flag(help: "Include background apps")
        var includeBackground = false

        @OptionGroup
        var runtimeOptions: CommandRuntimeOptions

        @RuntimeStorage private var runtime: CommandRuntime?

        private var logger: Logger {
            self.runtime?.logger ?? Logger.shared
        }

        private var services: PeekabooServices {
            self.runtime?.services ?? PeekabooServices.shared
        }

        var outputLogger: Logger { self.logger }

        var jsonOutput: Bool {
            self.runtimeOptions.jsonOutput
        }

        mutating func run() async throws {
            let runtime = CommandRuntime(options: self.runtimeOptions)
            try await self.run(using: runtime)
        }

        /// Enumerate running applications, apply filtering flags, and emit the chosen output representation.
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime

            do {
                let appsOutput = try await self.services.applications.listApplications()

                // Filter based on flags
                let filtered = appsOutput.data.applications.filter { app in
                    if !self.includeHidden && app.isHidden { return false }
                    if !self.includeBackground && app.name.isEmpty { return false }
                    return true
                }

                struct AppInfo: Codable {
                    let name: String
                    let bundle_id: String
                    let pid: Int32
                    let is_active: Bool
                    let is_hidden: Bool
                }

                struct ListResult: Codable {
                    let count: Int
                    let apps: [AppInfo]
                }

                let data = ListResult(
                    count: filtered.count,
                    apps: filtered.map { app in
                        AppInfo(
                            name: app.name,
                            bundle_id: app.bundleIdentifier ?? "unknown",
                            pid: app.processIdentifier,
                            is_active: app.isActive,
                            is_hidden: app.isHidden
                        )
                    }
                )

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

    // MARK: - Relaunch Application

    struct RelaunchSubcommand: AsyncParsableCommand, AsyncRuntimeCommand, ErrorHandlingCommand, OutputFormattable,
    ApplicationResolvablePositional, ApplicationResolver {
        static let configuration = CommandConfiguration(
            commandName: "relaunch",
            abstract: "Quit and relaunch an application"
        )

        @Argument(help: "Application name, bundle ID, or 'PID:12345' for process ID")
        var app: String

        @Option(name: .long, help: "Target application by process ID")
        var pid: Int32?

        @Option(help: "Wait time in seconds between quit and launch (default: 2)")
        var wait: TimeInterval = 2.0

        @Flag(help: "Force quit (doesn't save changes)")
        var force = false

        @Flag(help: "Wait until the app is ready after launch")
        var waitUntilReady = false

        @OptionGroup
        var runtimeOptions: CommandRuntimeOptions

        @RuntimeStorage private var runtime: CommandRuntime?

        private var logger: Logger {
            self.runtime?.logger ?? Logger.shared
        }

        private var services: PeekabooServices {
            self.runtime?.services ?? PeekabooServices.shared
        }

        var outputLogger: Logger { self.logger }

        var jsonOutput: Bool {
            self.runtimeOptions.jsonOutput
        }

        mutating func run() async throws {
            let runtime = CommandRuntime(options: self.runtimeOptions)
            try await self.run(using: runtime)
        }

        /// Quit the target app, wait if requested, relaunch it, and report success metrics.
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime

            do {
                // Find the application first
                let appIdentifier = try self.resolveApplicationIdentifier()
                let appInfo = try await resolveApplication(appIdentifier, services: self.services)
                let originalPID = appInfo.processIdentifier

                // Step 1: Quit the app
                let runningApps = NSWorkspace.shared.runningApplications
                guard let runningApp = runningApps.first(where: { $0.processIdentifier == originalPID }) else {
                    throw NotFoundError.application(self.app)
                }

                let quitSuccess = self.force ? runningApp.forceTerminate() : runningApp.terminate()

                if !quitSuccess {
                    throw PeekabooError
                        .commandFailed(
                            "Failed to quit \(appInfo.name) (PID: \(originalPID)). The app may have unsaved changes."
                        )
                }

                // Wait for the app to actually terminate
                var terminateWaitTime = 0.0
                while runningApp.isTerminated == false && terminateWaitTime < 5.0 {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    terminateWaitTime += 0.1
                }

                if !runningApp.isTerminated {
                    throw PeekabooError.timeout("App \(appInfo.name) did not terminate within 5 seconds")
                }

                // Step 2: Wait the specified duration
                if self.wait > 0 {
                    try await Task.sleep(nanoseconds: UInt64(self.wait * 1_000_000_000))
                }

                // Step 3: Launch the app
                let workspace = NSWorkspace.shared
                let newApp: NSRunningApplication?

                if let bundleId = appInfo.bundleIdentifier {
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = true
                    if let url = workspace.urlForApplication(withBundleIdentifier: bundleId) {
                        newApp = try await workspace.openApplication(at: url, configuration: config)
                    } else {
                        throw NotFoundError.application("Could not find application URL for bundle ID: \(bundleId)")
                    }
                } else if let bundlePath = appInfo.bundlePath {
                    let url = URL(fileURLWithPath: bundlePath)
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = true
                    newApp = try await workspace.openApplication(at: url, configuration: config)
                } else {
                    throw PeekabooError.commandFailed("No bundle ID or path available to relaunch \(appInfo.name)")
                }

                guard let launchedApp = newApp else {
                    throw PeekabooError.commandFailed("Failed to launch application")
                }

                // Wait until ready if requested
                if self.waitUntilReady {
                    var readyWaitTime = 0.0
                    while !launchedApp.isFinishedLaunching && readyWaitTime < 10.0 {
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        readyWaitTime += 0.1
                    }
                }

                struct RelaunchResult: Codable {
                    let action: String
                    let app_name: String
                    let old_pid: Int32
                    let new_pid: Int32
                    let bundle_id: String?
                    let quit_forced: Bool
                    let wait_time: TimeInterval
                    let launch_success: Bool
                }

                let data = RelaunchResult(
                    action: "relaunch",
                    app_name: appInfo.name,
                    old_pid: originalPID,
                    new_pid: launchedApp.processIdentifier,
                    bundle_id: appInfo.bundleIdentifier,
                    quit_forced: self.force,
                    wait_time: self.wait,
                    launch_success: launchedApp.isFinishedLaunching || !self.waitUntilReady
                )

                output(data) {
                    print("✓ Relaunched \(appInfo.name)")
                    print("  Old PID: \(originalPID) → New PID: \(launchedApp.processIdentifier)")
                    if self.waitUntilReady {
                        print("  Status: \(launchedApp.isFinishedLaunching ? "Ready" : "Launching...")")
                    }
                }

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }
}
