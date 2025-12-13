import AppKit
import AXorcist
import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Control macOS applications
@MainActor
struct AppCommand: ParsableCommand {
    static let commandDescription = CommandDescription(
        commandName: "app",
        abstract: "Control applications - launch, quit, relaunch, hide/unhide, switch, and list apps",
        discussion: """
        EXAMPLES:
          # Launch an application
          peekaboo app launch "Visual Studio Code"
          peekaboo app launch --bundle-id com.microsoft.VSCode --wait-until-ready
          peekaboo app launch "Safari" --open https://example.com --open ~/Desktop/notes.txt --no-focus

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
        ],
        showHelpOnEmptyInvocation: true
    )

    // MARK: - Launch Application

    @MainActor
    struct LaunchSubcommand {
        @MainActor
        static var launcher: any ApplicationLaunching = ApplicationLaunchEnvironment.launcher
        @MainActor
        static var resolver: any ApplicationURLResolving = ApplicationURLResolverEnvironment.resolver

        static let commandDescription = CommandDescription(
            commandName: "launch",
            abstract: "Launch an application",
            discussion: """
            Launches the target app, optionally waits for it to finish starting,
            and can hand one or more documents/URLs to the app immediately.

            KEY OPTIONS:
              --bundle-id <id>       Launch by bundle identifier instead of name/path
              --open <path-or-url>   Repeatable; pass documents/URLs to the app right after launch
              --wait-until-ready     Poll until the app reports it is fully launched
              --no-focus             Skip bringing the app to the foreground

            EXAMPLES:
              peekaboo app launch "Safari"
              peekaboo app launch "Safari" --open https://example.com --open https://news.ycombinator.com
              peekaboo app launch "Preview" --open ~/Desktop/report.pdf --no-focus
              peekaboo app launch --bundle-id com.apple.Notes --wait-until-ready
            """
        )

        @Argument(help: "Application name or path")
        var app: String

        var positionalAppIdentifier: String { self.app }

        @Option(help: "Launch by bundle identifier instead of name")
        var bundleId: String?

        @Flag(help: "Wait for the application to be ready")
        var waitUntilReady = false

        @Flag(name: .customLong("no-focus"), help: "Do not bring the app to the foreground after launching")
        var noFocus = false

        @Option(
            name: .customLong("open"),
            help: "Document or URL to open immediately after launch",
            parsing: .upToNextOption
        )
        var openTargets: [String] = []
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        @MainActor private var logger: Logger {
            self.resolvedRuntime.logger
        }

        @MainActor private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        var outputLogger: Logger { self.logger }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }
        var shouldFocusAfterLaunch: Bool { !self.noFocus }

        /// Resolve the requested app target, launch it, optionally wait until ready, and emit output.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.prepare(using: runtime)
            do {
                let url = try self.resolveApplicationURL()
                let launchedApp = try await self.launchApplication(at: url, name: self.displayName(for: url))
                try await self.waitIfNeeded(for: launchedApp)
                self.activateIfNeeded(launchedApp)
                self.renderLaunchSuccess(app: launchedApp)
            } catch {
                self.handleError(error)
                throw ExitCode(1)
            }
        }

        private mutating func prepare(using runtime: CommandRuntime) {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)
            self.logger.verbose("Launching application: \(self.app)")
        }

        private func resolveApplicationURL() throws -> URL {
            try Self.resolver.resolveApplication(appIdentifier: self.app, bundleId: self.bundleId)
        }

        private func displayName(for url: URL) -> String {
            (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? self.app
        }

        private func waitIfNeeded(for app: any RunningApplicationHandle) async throws {
            guard self.waitUntilReady else { return }
            try await self.waitForApplicationReady(app)
        }

        private func activateIfNeeded(_ app: any RunningApplicationHandle) {
            guard self.shouldFocusAfterLaunch else { return }
            if !app.activate(options: []) {
                self.logger.error("Launch succeeded but failed to focus \(app.localizedName ?? self.app)")
            }
        }

        private func renderLaunchSuccess(app: any RunningApplicationHandle) {
            struct LaunchResult: Codable {
                let action: String
                let app_name: String
                let bundle_id: String
                let pid: Int32
                let is_ready: Bool
            }

            let data = LaunchResult(
                action: "launch",
                app_name: app.localizedName ?? self.app,
                bundle_id: app.bundleIdentifier ?? "unknown",
                pid: app.processIdentifier,
                is_ready: app.isFinishedLaunching
            )
            AutomationEventLogger.log(
                .app,
                "launch app=\(data.app_name) bundle=\(data.bundle_id) pid=\(data.pid) ready=\(data.is_ready)"
            )

            output(data) {
                print("✓ Launched \(app.localizedName ?? self.app) (PID: \(app.processIdentifier))")
            }
        }

        private func launchApplication(at url: URL, name: String) async throws -> any RunningApplicationHandle {
            if self.openTargets.isEmpty {
                return try await Self.launcher.launchApplication(at: url, activates: true)
            } else {
                let urls = try self.openTargets.map { try Self.resolveOpenTarget($0) }
                return try await Self.launcher.launchApplication(
                    url,
                    opening: urls,
                    activates: self.shouldFocusAfterLaunch
                )
            }
        }

        private func waitForApplicationReady(
            _ app: any RunningApplicationHandle,
            timeout: TimeInterval = 10
        ) async throws {
            let startTime = Date()
            while !app.isFinishedLaunching {
                if Date().timeIntervalSince(startTime) > timeout {
                    throw PeekabooError.timeout("Application did not become ready within \(Int(timeout)) seconds")
                }
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }

        static func resolveOpenTarget(
            _ value: String,
            cwd: String = FileManager.default.currentDirectoryPath
        ) throws -> URL {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw ValidationError("Open target must not be empty")
            }

            if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
                return url
            }

            let expanded = NSString(string: trimmed).expandingTildeInPath
            let absolutePath: String = if expanded.hasPrefix("/") {
                expanded
            } else {
                NSString(string: cwd)
                    .appendingPathComponent(expanded)
            }

            return URL(fileURLWithPath: absolutePath)
        }
    }

    // MARK: - Quit Application

    @MainActor

    struct QuitSubcommand {
        static let commandDescription = CommandDescription(
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
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        @MainActor private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        var outputLogger: Logger { self.logger }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        /// Resolve the targeted applications, issue quit or force-quit requests, and report results per app.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            let logger = self.logger

            do {
                if self.all {
                    if self.app != nil || self.pid != nil {
                        throw ValidationError("Cannot combine --all with --app or --pid")
                    }
                } else {
                    if let except = self.except,
                       !except.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        throw ValidationError("--except requires --all")
                    }
                    if self.app != nil && self.pid != nil {
                        throw ValidationError("Cannot combine --app with --pid")
                    }
                    if self.app == nil && self.pid == nil {
                        throw ValidationError("Either --app, --pid, or --all must be specified")
                    }
                }

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
                } else if let pid = self.pid {
                    guard let runningApp = NSRunningApplication(processIdentifier: pid),
                          let name = runningApp.localizedName else {
                        throw NotFoundError.application("pid \(pid)")
                    }
                    quitApps.append((name, runningApp))
                } else {
                    throw ValidationError("Either --app, --pid, or --all must be specified")
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
                                    """
                                    Quit failed for \(name) (PID: \(runningApp.processIdentifier)). \
                                    The app may have unsaved changes or be showing a dialog. \
                                    Try --force to force quit.
                                    """
                                )
                        } else {
                            logger
                                .debug(
                                    """
                                    Force quit failed for \(name) (PID: \(runningApp.processIdentifier)). \
                                    The app may be unresponsive or protected.
                                    """
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
                                    "  💡 Tip: The app may have unsaved changes or be showing a dialog. " +
                                        "Try --force to force quit."
                                )
                            }
                        }
                    }
                }
                for result in results {
                    AutomationEventLogger.log(
                        .app,
                        "quit app=\(result.app_name) pid=\(result.pid) success=\(result.success) force=\(self.force)"
                    )
                }

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Hide Application

    @MainActor

    struct HideSubcommand {
        static let commandDescription = CommandDescription(
            commandName: "hide",
            abstract: "Hide an application"
        )

        @Option(help: "Application to hide")
        var app: String

        var positionalAppIdentifier: String { self.app }

        @Option(name: .long, help: "Target application by process ID")
        var pid: Int32?
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var outputLogger: Logger { self.logger }

        @MainActor private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        /// Hide the specified application and emit confirmation in either text or JSON form.
        @MainActor

        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime

            do {
                let appIdentifier = try self.resolveApplicationIdentifier()
                let appInfo = try await resolveApplication(appIdentifier, services: self.services)

                guard let runningApp = NSRunningApplication(processIdentifier: appInfo.processIdentifier) else {
                    throw PeekabooError.appNotFound(appIdentifier)
                }

                await MainActor.run {
                    _ = AXApp(runningApp).element.hideApplication()
                }

                let data = [
                    "action": "hide",
                    "app_name": appInfo.name,
                    "bundle_id": appInfo.bundleIdentifier ?? "unknown"
                ]

                output(data) {
                    print("✓ Hidden \(appInfo.name)")
                }
                AutomationEventLogger.log(
                    .app,
                    "hide app=\(appInfo.name) bundle=\(appInfo.bundleIdentifier ?? "unknown")"
                )

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Unhide Application

    @MainActor

    struct UnhideSubcommand {
        static let commandDescription = CommandDescription(
            commandName: "unhide",
            abstract: "Show a hidden application"
        )

        @Option(help: "Application to unhide")
        var app: String

        var positionalAppIdentifier: String { self.app }

        @Option(name: .long, help: "Target application by process ID")
        var pid: Int32?

        @Flag(help: "Bring to front after unhiding")
        var activate = false
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var outputLogger: Logger { self.logger }

        @MainActor private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        /// Unhide the target application and optionally re-activate its main window.
        @MainActor

        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime

            do {
                let appIdentifier = try self.resolveApplicationIdentifier()
                let appInfo = try await resolveApplication(appIdentifier, services: self.services)

                guard let runningApp = NSRunningApplication(processIdentifier: appInfo.processIdentifier) else {
                    throw PeekabooError.appNotFound(appIdentifier)
                }

                await MainActor.run {
                    _ = AXApp(runningApp).element.unhideApplication()
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
                AutomationEventLogger.log(
                    .app,
                    "unhide app=\(appInfo.name) bundle=\(appInfo.bundleIdentifier ?? "unknown") "
                        + "activated=\(self.activate)"
                )

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Switch Application

    @MainActor

    struct SwitchSubcommand {
        static let commandDescription = CommandDescription(
            commandName: "switch",
            abstract: "Switch to another application"
        )

        @Option(help: "Switch to this application")
        var to: String?

        @Flag(help: "Cycle to next app (Cmd+Tab)")
        var cycle = false
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var outputLogger: Logger { self.logger }

        @MainActor private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        /// Switch focus either by cycling (Cmd+Tab) or by activating a specific application.
        @MainActor

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
                    AutomationEventLogger.log(.app, "switch action=cycle success=true")
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
                    AutomationEventLogger.log(
                        .app,
                        "switch app=\(appInfo.name) bundle=\(appInfo.bundleIdentifier ?? "unknown") success=\(success)"
                    )
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

    @MainActor

    struct ListSubcommand {
        static let commandDescription = CommandDescription(
            commandName: "list",
            abstract: "List running applications"
        )

        @Flag(help: "Include hidden apps")
        var includeHidden = false

        @Flag(help: "Include background apps")
        var includeBackground = false
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        @MainActor private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        var outputLogger: Logger { self.logger }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        /// Enumerate running applications, apply filtering flags, and emit the chosen output representation.
        @MainActor
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
                AutomationEventLogger.log(
                    .app,
                    "list count=\(filtered.count) includeHidden=\(self.includeHidden) "
                        + "includeBackground=\(self.includeBackground)"
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

    @MainActor

    struct RelaunchSubcommand {
        static let commandDescription = CommandDescription(
            commandName: "relaunch",
            abstract: "Quit and relaunch an application"
        )

        @Argument(help: "Application name, bundle ID, or 'PID:12345' for process ID")
        var app: String

        var positionalAppIdentifier: String { self.app }

        @Option(name: .long, help: "Target application by process ID")
        var pid: Int32?

        @Option(help: "Wait time in seconds between quit and launch (default: 2)")
        var wait: TimeInterval = 2.0

        @Flag(help: "Force quit (doesn't save changes)")
        var force = false

        @Flag(help: "Wait until the app is ready after launch")
        var waitUntilReady = false
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        @MainActor private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        var outputLogger: Logger { self.logger }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        /// Quit the target app, wait if requested, relaunch it, and report success metrics.
        @MainActor

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

extension AppCommand.LaunchSubcommand: AsyncRuntimeCommand, ErrorHandlingCommand, OutputFormattable {}
@MainActor
extension AppCommand.LaunchSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.app = try values.decodePositional(0, label: "app")
        self.bundleId = values.singleOption("bundleId")
        self.waitUntilReady = values.flag("waitUntilReady")
        self.noFocus = values.flag("noFocus")
        self.openTargets = values.optionValues("open")
    }
}

extension AppCommand.QuitSubcommand: AsyncRuntimeCommand, ErrorHandlingCommand, OutputFormattable,
    ApplicationResolvable,
    ApplicationResolver {}
@MainActor
extension AppCommand.QuitSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.app = values.singleOption("app")
        self.pid = try values.decodeOption("pid", as: Int32.self)
        self.all = values.flag("all")
        self.except = values.singleOption("except")
        self.force = values.flag("force")
    }
}

extension AppCommand.HideSubcommand: AsyncRuntimeCommand, ErrorHandlingCommand, OutputFormattable,
ApplicationResolvablePositional, ApplicationResolver {}
@MainActor
extension AppCommand.HideSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.app = try values.requireOption("app", as: String.self)
        self.pid = try values.decodeOption("pid", as: Int32.self)
    }
}

extension AppCommand.UnhideSubcommand: AsyncRuntimeCommand, ErrorHandlingCommand, OutputFormattable,
ApplicationResolvablePositional, ApplicationResolver {}
@MainActor
extension AppCommand.UnhideSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.app = try values.requireOption("app", as: String.self)
        self.pid = try values.decodeOption("pid", as: Int32.self)
        self.activate = values.flag("activate")
    }
}

extension AppCommand.SwitchSubcommand: AsyncRuntimeCommand, ErrorHandlingCommand, OutputFormattable,
ApplicationResolver {}
@MainActor
extension AppCommand.SwitchSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.to = values.singleOption("to")
        self.cycle = values.flag("cycle")
    }
}

extension AppCommand.ListSubcommand: AsyncRuntimeCommand, ErrorHandlingCommand, OutputFormattable {}
@MainActor
extension AppCommand.ListSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.includeHidden = values.flag("includeHidden")
        self.includeBackground = values.flag("includeBackground")
    }
}

extension AppCommand.RelaunchSubcommand: AsyncRuntimeCommand, ErrorHandlingCommand, OutputFormattable,
ApplicationResolvablePositional, ApplicationResolver {}
@MainActor
extension AppCommand.RelaunchSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.app = try values.decodePositional(0, label: "app")
        self.pid = try values.decodeOption("pid", as: Int32.self)
        if let wait: TimeInterval = try values.decodeOption("wait", as: TimeInterval.self) {
            self.wait = wait
        }
        self.force = values.flag("force")
        self.waitUntilReady = values.flag("waitUntilReady")
    }
}
