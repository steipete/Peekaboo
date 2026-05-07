import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation

@MainActor
extension AppCommand {
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
        var app: String?

        @Option(help: "Launch by bundle identifier instead of name")
        var bundleId: String?

        @Flag(help: "Wait for the application to be ready")
        var waitUntilReady = false

        @Flag(help: "Do not bring the app to the foreground after launching")
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

        var outputLogger: Logger {
            self.logger
        }

        var jsonOutput: Bool {
            self.resolvedRuntime.configuration.jsonOutput
        }

        var shouldFocusAfterLaunch: Bool {
            !self.noFocus
        }

        /// Resolve the requested app target, launch it, optionally wait until ready, and emit output.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.prepare(using: runtime)
            do {
                try self.validateInputs()
                let url = try self.resolveApplicationURL()
                let launchedApp = try await self.launchApplication(at: url, name: self.displayName(for: url))
                try await self.waitIfNeeded(for: launchedApp)
                self.activateIfNeeded(launchedApp)
                await self.invalidateFocusSnapshotIfNeeded()
                self.renderLaunchSuccess(app: launchedApp)
            } catch {
                self.handleError(error)
                throw ExitCode(1)
            }
        }

        private mutating func prepare(using runtime: CommandRuntime) {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)
            self.logger.verbose("Launching application: \(self.requestedAppIdentifier)")
        }

        private func validateInputs() throws {
            guard self.app?.isEmpty == false || self.bundleId?.isEmpty == false else {
                throw PeekabooError.invalidInput("Provide an application name/path or --bundle-id")
            }
        }

        private func resolveApplicationURL() throws -> URL {
            try Self.resolver.resolveApplication(appIdentifier: self.requestedAppIdentifier, bundleId: self.bundleId)
        }

        private func displayName(for url: URL) -> String {
            (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? self.requestedAppIdentifier
        }

        private var requestedAppIdentifier: String {
            self.app ?? self.bundleId ?? "unknown"
        }

        private func waitIfNeeded(for app: any RunningApplicationHandle) async throws {
            guard self.waitUntilReady else { return }
            try await self.waitForApplicationReady(app)
        }

        private func activateIfNeeded(_ app: any RunningApplicationHandle) {
            guard self.shouldFocusAfterLaunch else { return }
            if !app.activate(options: []) {
                self.logger
                    .error("Launch succeeded but failed to focus \(app.localizedName ?? self.requestedAppIdentifier)")
            }
        }

        private func invalidateFocusSnapshotIfNeeded() async {
            guard self.shouldFocusAfterLaunch else { return }
            await InteractionObservationInvalidator.invalidateLatestSnapshot(
                using: self.services.snapshots,
                logger: self.logger,
                reason: "app launch focus"
            )
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
                app_name: app.localizedName ?? self.requestedAppIdentifier,
                bundle_id: app.bundleIdentifier ?? "unknown",
                pid: app.processIdentifier,
                is_ready: app.isFinishedLaunching
            )
            AutomationEventLogger.log(
                .app,
                "launch app=\(data.app_name) bundle=\(data.bundle_id) pid=\(data.pid) ready=\(data.is_ready)"
            )

            output(data) {
                print("✓ Launched \(app.localizedName ?? self.requestedAppIdentifier) (PID: \(app.processIdentifier))")
            }
        }

        private func launchApplication(at url: URL, name: String) async throws -> any RunningApplicationHandle {
            if self.openTargets.isEmpty {
                return try await Self.launcher.launchApplication(at: url, activates: self.shouldFocusAfterLaunch)
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
}

extension AppCommand.LaunchSubcommand: AsyncRuntimeCommand, ErrorHandlingCommand, OutputFormattable {}

@MainActor
extension AppCommand.LaunchSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.app = try values.decodeOptionalPositional(0, label: "app")
        self.bundleId = values.singleOption("bundleId")
        self.waitUntilReady = values.flag("waitUntilReady")
        self.noFocus = values.flag("noFocus")
        self.openTargets = values.optionValues("open")
    }
}
