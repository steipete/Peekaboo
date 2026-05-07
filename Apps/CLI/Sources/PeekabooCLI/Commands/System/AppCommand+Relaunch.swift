import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation

@MainActor
extension AppCommand {
    // MARK: - Relaunch Application

    @MainActor
    struct RelaunchSubcommand {
        @MainActor
        static var launcher: any ApplicationLaunching = ApplicationLaunchEnvironment.launcher
        @MainActor
        static var resolver: any ApplicationURLResolving = ApplicationURLResolverEnvironment.resolver

        static let commandDescription = CommandDescription(
            commandName: "relaunch",
            abstract: "Quit and relaunch an application"
        )

        @Argument(help: "Application name, bundle ID, or 'PID:12345' for process ID")
        var app: String

        var positionalAppIdentifier: String {
            self.app
        }

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

        var outputLogger: Logger {
            self.logger
        }

        var jsonOutput: Bool {
            self.resolvedRuntime.configuration.jsonOutput
        }

        /// Quit the target app, wait if requested, relaunch it, and report success metrics.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime

            do {
                // Find the application first
                let appIdentifier = try self.resolveApplicationIdentifier()
                let appInfo = try await resolveApplication(appIdentifier, services: self.services)
                let originalPID = appInfo.processIdentifier
                let processIdentifier = "PID:\(originalPID)"

                // Step 1: Quit the app
                let quitSuccess = try await self.services.applications.quitApplication(
                    identifier: processIdentifier,
                    force: self.force
                )

                if !quitSuccess {
                    throw PeekabooError
                        .commandFailed(
                            "Failed to quit \(appInfo.name) (PID: \(originalPID)). The app may have unsaved changes."
                        )
                }

                // Wait for the app to actually terminate
                try await self.waitUntilTerminated(identifier: processIdentifier, appName: appInfo.name)

                // Step 2: Wait the specified duration
                if self.wait > 0 {
                    try await Task.sleep(nanoseconds: UInt64(self.wait * 1_000_000_000))
                }

                // Step 3: Launch the app
                let appURL = try self.resolveLaunchURL(for: appInfo)
                let launchedApp = try await Self.launcher.launchApplication(at: appURL, activates: true)

                // Wait until ready if requested
                if self.waitUntilReady {
                    try await self.waitUntilReady(launchedApp)
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

        private func waitUntilTerminated(identifier: String, appName: String) async throws {
            var terminateWaitTime = 0.0
            while await self.services.applications.isApplicationRunning(identifier: identifier),
                  terminateWaitTime < 5.0 {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                terminateWaitTime += 0.1
            }

            if await self.services.applications.isApplicationRunning(identifier: identifier) {
                throw PeekabooError.timeout("App \(appName) did not terminate within 5 seconds")
            }
        }

        private func resolveLaunchURL(for appInfo: ServiceApplicationInfo) throws -> URL {
            if let bundleID = appInfo.bundleIdentifier {
                return try Self.resolver.resolveBundleIdentifier(bundleID)
            }
            if let bundlePath = appInfo.bundlePath {
                return URL(fileURLWithPath: bundlePath)
            }
            throw PeekabooError.commandFailed("No bundle ID or path available to relaunch \(appInfo.name)")
        }

        private func waitUntilReady(_ app: any RunningApplicationHandle) async throws {
            var readyWaitTime = 0.0
            while !app.isFinishedLaunching && readyWaitTime < 10.0 {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                readyWaitTime += 0.1
            }
        }
    }
}

extension AppCommand.RelaunchSubcommand: AsyncRuntimeCommand, ErrorHandlingCommand, OutputFormattable,
    ApplicationResolvablePositional,
    ApplicationResolver {}

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
