import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation

extension WindowCommand {
    @MainActor
    struct CloseSubcommand: ErrorHandlingCommand, OutputFormattable {
        @OptionGroup var windowOptions: WindowIdentificationOptions
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var outputLogger: Logger {
            self.logger
        }

        var jsonOutput: Bool {
            self.resolvedRuntime.configuration.jsonOutput
        }

        /// Resolve the target window, close it, and surface the outcome in JSON or text form.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try self.windowOptions.validate()
                let target = self.windowOptions.createTarget()
                let appInfo = try await self.windowOptions.resolveApplicationInfoIfNeeded(services: self.services)

                // Get window info before action
                let windows = try await WindowServiceBridge.listWindows(
                    windows: self.services.windows,
                    target: self.windowOptions.toWindowTarget()
                )
                let windowInfo = self.windowOptions.selectWindow(from: windows)
                let appName = appInfo?.name ?? self.windowOptions.displayName(windowInfo: windowInfo)
                guard windowInfo != nil else {
                    throw PeekabooError.windowNotFound(criteria: "No windows found for \(appName)")
                }

                // Perform the action
                try await WindowServiceBridge.closeWindow(windows: self.services.windows, target: target)
                await invalidateLatestSnapshotAfterWindowMutation(
                    services: self.services,
                    logger: self.logger,
                    reason: "window close"
                )

                logWindowAction(
                    action: "close",
                    appName: appName,
                    windowInfo: windowInfo
                )

                let data = createWindowActionResult(
                    action: "close",
                    success: true,
                    windowInfo: windowInfo,
                    appName: appName
                )

                output(data) {
                    print("Successfully closed window '\(windowInfo?.title ?? "Untitled")' of \(appName)")
                }

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }

    @MainActor
    struct MinimizeSubcommand: ErrorHandlingCommand, OutputFormattable {
        @OptionGroup var windowOptions: WindowIdentificationOptions
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var outputLogger: Logger {
            self.logger
        }

        var jsonOutput: Bool {
            self.resolvedRuntime.configuration.jsonOutput
        }

        /// Resolve the target window, minimize it to the Dock, and report the action.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try self.windowOptions.validate()
                let target = self.windowOptions.createTarget()
                let appInfo = try await self.windowOptions.resolveApplicationInfoIfNeeded(services: self.services)

                // Get window info before action
                let windows = try await WindowServiceBridge.listWindows(
                    windows: self.services.windows,
                    target: self.windowOptions.toWindowTarget()
                )
                let windowInfo = self.windowOptions.selectWindow(from: windows)
                let appName = appInfo?.name ?? self.windowOptions.displayName(windowInfo: windowInfo)
                guard windowInfo != nil else {
                    throw PeekabooError.windowNotFound(criteria: "No windows found for \(appName)")
                }

                // Perform the action
                try await WindowServiceBridge.minimizeWindow(windows: self.services.windows, target: target)
                await invalidateLatestSnapshotAfterWindowMutation(
                    services: self.services,
                    logger: self.logger,
                    reason: "window minimize"
                )
                logWindowAction(
                    action: "minimize",
                    appName: appName,
                    windowInfo: windowInfo
                )

                let data = createWindowActionResult(
                    action: "minimize",
                    success: true,
                    windowInfo: windowInfo,
                    appName: appName
                )

                output(data) {
                    print("Successfully minimized window '\(windowInfo?.title ?? "Untitled")' of \(appName)")
                }

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }

    @MainActor
    struct MaximizeSubcommand: ErrorHandlingCommand, OutputFormattable {
        @OptionGroup var windowOptions: WindowIdentificationOptions
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var outputLogger: Logger {
            self.logger
        }

        var jsonOutput: Bool {
            self.resolvedRuntime.configuration.jsonOutput
        }

        /// Expand the resolved window to fill the available screen real estate and share the updated frame.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try self.windowOptions.validate()
                let target = self.windowOptions.createTarget()
                let appInfo = try await self.windowOptions.resolveApplicationInfoIfNeeded(services: self.services)

                // Get window info before action
                let windows = try await WindowServiceBridge.listWindows(
                    windows: self.services.windows,
                    target: self.windowOptions.toWindowTarget()
                )
                let windowInfo = self.windowOptions.selectWindow(from: windows)
                let appName = appInfo?.name ?? self.windowOptions.displayName(windowInfo: windowInfo)
                guard windowInfo != nil else {
                    throw PeekabooError.windowNotFound(criteria: "No windows found for \(appName)")
                }

                // Perform the action
                try await WindowServiceBridge.maximizeWindow(windows: self.services.windows, target: target)
                await invalidateLatestSnapshotAfterWindowMutation(
                    services: self.services,
                    logger: self.logger,
                    reason: "window maximize"
                )
                logWindowAction(
                    action: "maximize",
                    appName: appName,
                    windowInfo: windowInfo
                )

                let data = createWindowActionResult(
                    action: "maximize",
                    success: true,
                    windowInfo: windowInfo,
                    appName: appName
                )

                output(data) {
                    print("Successfully maximized window '\(windowInfo?.title ?? "Untitled")' of \(appName)")
                }

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }
}
