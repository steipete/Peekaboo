import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

extension WindowCommand {
    // MARK: - Move Command

    @MainActor
    struct MoveSubcommand: ErrorHandlingCommand, OutputFormattable {
        @OptionGroup var windowOptions: WindowIdentificationOptions

        @Option(name: .customShort("x", allowingJoined: false), help: "New X coordinate")
        var x: Int

        @Option(name: .customShort("y", allowingJoined: false), help: "New Y coordinate")
        var y: Int
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

        /// Move the window to the absolute screen coordinates provided by the user.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try self.windowOptions.validate()
                let target = try self.windowOptions.createTarget()
                let appInfo = try await self.windowOptions.resolveApplicationInfoIfNeeded(services: self.services)

                // Get window info
                let windows = try await WindowServiceBridge.listWindows(
                    windows: self.services.windows,
                    target: self.windowOptions.toWindowTarget()
                )
                let windowInfo = self.windowOptions.selectWindow(from: windows)
                let appName = appInfo?.name ?? self.windowOptions.displayName(windowInfo: windowInfo)
                guard windowInfo != nil else {
                    throw PeekabooError.windowNotFound(criteria: "No windows found for \(appName)")
                }

                // Move the window
                let newOrigin = CGPoint(x: x, y: y)
                try await WindowServiceBridge.moveWindow(windows: self.services.windows, target: target, to: newOrigin)
                await invalidateLatestSnapshotAfterWindowMutation(
                    services: self.services,
                    logger: self.logger,
                    reason: "window move"
                )

                // Create result with new bounds
                let updatedInfo = windowInfo.map { info in
                    ServiceWindowInfo(
                        windowID: info.windowID,
                        title: info.title,
                        bounds: CGRect(origin: newOrigin, size: info.bounds.size),
                        isMinimized: info.isMinimized,
                        isMainWindow: info.isMainWindow,
                        windowLevel: info.windowLevel,
                        alpha: info.alpha,
                        index: info.index,
                        isOffScreen: info.isOffScreen
                    )
                }

                let refreshedWindowInfo = await self.windowOptions.refetchWindowInfo(
                    services: self.services,
                    logger: self.logger,
                    context: "window-move"
                )
                let finalWindowInfo = refreshedWindowInfo ?? updatedInfo ?? windowInfo

                logWindowAction(
                    action: "move",
                    appName: appName,
                    windowInfo: finalWindowInfo
                )

                let data = createWindowActionResult(
                    action: "move",
                    success: true,
                    windowInfo: finalWindowInfo,
                    appName: appName
                )

                output(data) {
                    print(
                        "Successfully moved window '\(finalWindowInfo?.title ?? "Untitled")' to (\(self.x), \(self.y))"
                    )
                }

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Resize Command

    @MainActor
    struct ResizeSubcommand: ErrorHandlingCommand, OutputFormattable {
        @OptionGroup var windowOptions: WindowIdentificationOptions

        @Option(name: .customShort("w", allowingJoined: false), help: "New width")
        var width: Int

        @Option(name: .long, help: "New height")
        var height: Int
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

        /// Resize the window to the supplied dimensions, preserving its origin.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try self.windowOptions.validate()
                let target = try self.windowOptions.createTarget()
                let appInfo = try await self.windowOptions.resolveApplicationInfoIfNeeded(services: self.services)

                // Get window info
                let windows = try await WindowServiceBridge.listWindows(
                    windows: self.services.windows,
                    target: self.windowOptions.toWindowTarget()
                )
                let windowInfo = self.windowOptions.selectWindow(from: windows)
                let appName = appInfo?.name ?? self.windowOptions.displayName(windowInfo: windowInfo)
                guard windowInfo != nil else {
                    throw PeekabooError.windowNotFound(criteria: "No windows found for \(appName)")
                }

                // Resize the window
                let newSize = CGSize(width: width, height: height)
                try await WindowServiceBridge.resizeWindow(windows: self.services.windows, target: target, to: newSize)
                await invalidateLatestSnapshotAfterWindowMutation(
                    services: self.services,
                    logger: self.logger,
                    reason: "window resize"
                )

                let refreshedWindowInfo = await self.windowOptions.refetchWindowInfo(
                    services: self.services,
                    logger: self.logger,
                    context: "window-resize"
                )
                let finalWindowInfo = refreshedWindowInfo ?? windowInfo
                logWindowAction(
                    action: "resize",
                    appName: appName,
                    windowInfo: finalWindowInfo
                )

                let data = createWindowActionResult(
                    action: "resize",
                    success: true,
                    windowInfo: finalWindowInfo,
                    appName: appName
                )

                output(data) {
                    let title = finalWindowInfo?.title ?? "Untitled"
                    print("Successfully resized window '\(title)' to \(self.width)x\(self.height)")
                }

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Set Bounds Command

    @MainActor
    struct SetBoundsSubcommand: ErrorHandlingCommand, OutputFormattable {
        @OptionGroup var windowOptions: WindowIdentificationOptions

        @Option(name: .customShort("x", allowingJoined: false), help: "New X coordinate")
        var x: Int

        @Option(name: .customShort("y", allowingJoined: false), help: "New Y coordinate")
        var y: Int

        @Option(name: .customShort("w", allowingJoined: false), help: "New width")
        var width: Int

        @Option(name: .long, help: "New height")
        var height: Int
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

        /// Set both position and size for the window in a single operation, then confirm the new bounds.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try self.windowOptions.validate()
                let target = try self.windowOptions.createTarget()
                let appInfo = try await self.windowOptions.resolveApplicationInfoIfNeeded(services: self.services)

                // Get window info
                let windows = try await WindowServiceBridge.listWindows(
                    windows: self.services.windows,
                    target: self.windowOptions.toWindowTarget()
                )
                let windowInfo = self.windowOptions.selectWindow(from: windows)
                let appName = appInfo?.name ?? self.windowOptions.displayName(windowInfo: windowInfo)
                guard windowInfo != nil else {
                    throw PeekabooError.windowNotFound(criteria: "No windows found for \(appName)")
                }

                // Set bounds
                let newBounds = CGRect(x: x, y: y, width: width, height: height)
                try await WindowServiceBridge.setWindowBounds(
                    windows: self.services.windows,
                    target: target,
                    bounds: newBounds
                )
                await invalidateLatestSnapshotAfterWindowMutation(
                    services: self.services,
                    logger: self.logger,
                    reason: "window set-bounds"
                )

                let refreshedWindowInfo = await self.windowOptions.refetchWindowInfo(
                    services: self.services,
                    logger: self.logger,
                    context: "window-set-bounds"
                )
                let finalWindowInfo = refreshedWindowInfo ?? windowInfo
                logWindowAction(
                    action: "set-bounds",
                    appName: appName,
                    windowInfo: finalWindowInfo
                )

                let data = createWindowActionResult(
                    action: "set-bounds",
                    success: true,
                    windowInfo: finalWindowInfo,
                    appName: appName
                )

                output(data) {
                    let title = finalWindowInfo?.title ?? "Untitled"
                    let boundsDescription = "(\(self.x), \(self.y)) \(self.width)x\(self.height)"
                    print("Successfully set window '\(title)' bounds to \(boundsDescription)")
                }

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }
    }
}
