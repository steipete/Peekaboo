import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

// Logger for window command debugging

/// Manipulate application windows with various actions
@MainActor
struct WindowCommand: ParsableCommand {
    static let commandDescription = CommandDescription(
        commandName: "window",
        abstract: "Manipulate application windows",
        discussion: """
        SYNOPSIS:
          peekaboo window SUBCOMMAND [OPTIONS]

        DESCRIPTION:
          Provides window manipulation capabilities including closing, minimizing,
          maximizing, moving, resizing, and focusing windows.

        EXAMPLES:
          # Close a window
          peekaboo window close --app Safari
          peekaboo window close --app Safari --window-title "GitHub"
          peekaboo window close --window-id 12345

          # Minimize/maximize windows
          peekaboo window minimize --app Finder
          peekaboo window maximize --app Terminal

          # Move and resize windows
          peekaboo window move --app TextEdit --x 100 --y 100
          peekaboo window resize --app Safari --width 1200 --height 800
          peekaboo window set-bounds --app Chrome --x 50 --y 50 --width 1024 --height 768

          # Focus a window
          peekaboo window focus --app "Visual Studio Code"
          peekaboo window focus --app Safari --window-title "Apple"
          peekaboo window focus --window-id 12345

          # List windows (convenience shortcut)
          peekaboo window list --app Safari

        SUBCOMMANDS:
          close         Close a window
          minimize      Minimize a window to the Dock
          maximize      Maximize a window (full screen)
          move          Move a window to a new position
          resize        Resize a window
          set-bounds    Set window position and size in one operation
          focus         Bring a window to the foreground
          list          List windows for an application

        OUTPUT FORMAT:
          Default output is human-readable text.
          Use --json for machine-readable JSON format.
        """,
        subcommands: [
            CloseSubcommand.self,
            MinimizeSubcommand.self,
            MaximizeSubcommand.self,
            MoveSubcommand.self,
            ResizeSubcommand.self,
            SetBoundsSubcommand.self,
            FocusSubcommand.self,
            WindowListSubcommand.self,
        ],
        showHelpOnEmptyInvocation: true
    )
}

// MARK: - Subcommands

extension WindowCommand {
    @MainActor
    struct FocusSubcommand: ErrorHandlingCommand, OutputFormattable {
        @OptionGroup var windowOptions: WindowIdentificationOptions

        @OptionGroup var focusOptions: FocusCommandOptions

        @Option(help: "Snapshot ID to focus the captured window context")
        var snapshot: String?

        @Flag(help: "Verify the window is focused after the action")
        var verify = false
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

        /// Focus the targeted window, handling Space switches or relocation according to the provided options.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.debug("FocusSubcommand.run() called")
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                self.logger.debug("About to validate window options")
                let observation = await InteractionObservationContext.resolve(
                    explicitSnapshot: self.snapshot,
                    fallbackToLatest: false,
                    snapshots: self.services.snapshots
                )
                try self.windowOptions.validate(allowMissingTarget: observation.hasSnapshot)
                try await observation.validateIfExplicit(using: self.services.snapshots)
                self.logger.debug("Window options validated")
                let hasWindowTarget = self.windowOptions.app != nil ||
                    self.windowOptions.pid != nil ||
                    self.windowOptions.windowId != nil
                let target = hasWindowTarget ? self.windowOptions.createTarget() : nil
                if let target {
                    self.logger.debug("Target created: \(target)")
                }
                let appInfo = try await self.windowOptions.resolveApplicationInfoIfNeeded(services: self.services)

                // Get window info before action
                let windowInfo: ServiceWindowInfo?
                let appName: String
                let snapshotContext = try await self.resolveSnapshotContextIfNeeded(observation)
                if hasWindowTarget {
                    let windows = try await WindowServiceBridge.listWindows(
                        windows: self.services.windows,
                        target: self.windowOptions.toWindowTarget()
                    )
                    self.logger.debug("Found \(windows.count) windows")
                    guard !windows.isEmpty else {
                        let displayName = appInfo?.name ?? self.windowOptions.displayName(windowInfo: nil)
                        throw PeekabooError.windowNotFound(criteria: "No windows found for \(displayName)")
                    }
                    windowInfo = self.windowOptions.selectWindow(from: windows)
                    appName = appInfo?.name ?? self.windowOptions.displayName(windowInfo: windowInfo)
                } else if let snapshotContext {
                    windowInfo = await self.refetchWindowInfo(
                        target: snapshotContext.target,
                        context: "window-focus-snapshot"
                    )
                    appName = snapshotContext.appName
                } else {
                    throw ValidationError("Either --app, --pid, --window-id, or --snapshot must be specified")
                }

                // Check if we found any windows
                guard hasWindowTarget || snapshotContext != nil else { preconditionFailure("validated above") }

                // Use enhanced focus with space support
                if let windowID = windowInfo?.windowID {
                    try await ensureFocused(
                        windowID: CGWindowID(windowID),
                        applicationName: appName,
                        windowTitle: self.windowOptions.windowTitle,
                        options: self.focusOptions.asFocusOptions,
                        services: self.services
                    )
                } else if let snapshotContext {
                    try await ensureFocused(
                        snapshotId: snapshotContext.snapshotId,
                        options: self.focusOptions.asFocusOptions,
                        services: self.services
                    )
                } else if let target {
                    // Fallback to regular focus if no window ID
                    try await WindowServiceBridge.focusWindow(windows: self.services.windows, target: target)
                } else {
                    throw ValidationError("Either --app, --pid, --window-id, or --snapshot must be specified")
                }

                let refreshedWindowInfo: ServiceWindowInfo? = if hasWindowTarget {
                    await self.windowOptions.refetchWindowInfo(
                        services: self.services,
                        logger: self.logger,
                        context: "window-focus"
                    )
                } else if let snapshotContext {
                    await self.refetchWindowInfo(
                        target: snapshotContext.target,
                        context: "window-focus"
                    )
                } else {
                    nil
                }
                let finalWindowInfo = refreshedWindowInfo ?? windowInfo

                if self.verify {
                    try await self.verifyFocus(
                        expectedWindowId: finalWindowInfo?.windowID,
                        expectedTitle: self.windowOptions.windowTitle,
                        expectedApp: appInfo
                    )
                }
                await InteractionObservationInvalidator.invalidateAfterMutationOrLatest(
                    observation,
                    snapshots: self.services.snapshots,
                    logger: self.logger,
                    reason: "window focus"
                )
                logWindowAction(
                    action: "focus",
                    appName: appName,
                    windowInfo: finalWindowInfo
                )

                let data = createWindowActionResult(
                    action: "focus",
                    success: true,
                    windowInfo: finalWindowInfo,
                    appName: appName
                )

                output(data) {
                    var message = "Successfully focused window '\(finalWindowInfo?.title ?? "Untitled")' of \(appName)"
                    if self.focusOptions.bringToCurrentSpace {
                        message += " (moved to current Space)"
                    }
                    print(message)
                }

            } catch {
                handleError(error)
                throw ExitCode(1)
            }
        }

        private func resolveSnapshotContextIfNeeded(
            _ observation: InteractionObservationContext
        ) async throws -> (snapshotId: String, target: WindowTarget, appName: String)? {
            guard let snapshotId = observation.snapshotId else {
                return nil
            }
            guard let snapshot = try await self.services.snapshots.getUIAutomationSnapshot(snapshotId: snapshotId),
                  let target = windowTarget(from: snapshot)
            else {
                throw PeekabooError.snapshotNotFound(
                    """
                    Snapshot '\(snapshotId)' has no window context. \
                    Run 'peekaboo see' again against a window or provide --app/--pid/--window-id.
                    """
                )
            }
            return (snapshotId, target, windowDisplayName(from: snapshot, snapshotId: snapshotId))
        }

        private func refetchWindowInfo(target: WindowTarget, context: StaticString) async -> ServiceWindowInfo? {
            do {
                let refreshedWindows = try await WindowServiceBridge.listWindows(
                    windows: self.services.windows,
                    target: target
                )
                return refreshedWindows.first
            } catch {
                self.logger.warn("Failed to refetch window info (\(context)): \(error.localizedDescription)")
                return nil
            }
        }

        private func verifyFocus(
            expectedWindowId: Int?,
            expectedTitle: String?,
            expectedApp: ServiceApplicationInfo?
        ) async throws {
            let deadline = Date().addingTimeInterval(1.5)
            while Date() < deadline {
                if let expectedApp {
                    let frontmost = try await self.services.applications.getFrontmostApplication()
                    if let expectedBundle = expectedApp.bundleIdentifier,
                       let frontBundle = frontmost.bundleIdentifier,
                       expectedBundle != frontBundle {
                        try await Task.sleep(nanoseconds: 120_000_000)
                        continue
                    }

                    if frontmost.name.compare(expectedApp.name, options: .caseInsensitive) != .orderedSame,
                       expectedApp.bundleIdentifier == nil {
                        try await Task.sleep(nanoseconds: 120_000_000)
                        continue
                    }
                }

                if let expectedWindowId,
                   let focused = try await self.services.windows.getFocusedWindow(),
                   focused.windowID != expectedWindowId {
                    try await Task.sleep(nanoseconds: 120_000_000)
                    continue
                }

                if expectedWindowId == nil,
                   let expectedTitle,
                   let focused = try await self.services.windows.getFocusedWindow(),
                   !focused.title.localizedCaseInsensitiveContains(expectedTitle) {
                    try await Task.sleep(nanoseconds: 120_000_000)
                    continue
                }

                return
            }

            throw PeekabooError.operationError(message: "Window focus verification failed")
        }
    }

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
                let target = self.windowOptions.createTarget()
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
                        index: info.index
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
                let target = self.windowOptions.createTarget()
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
                let target = self.windowOptions.createTarget()
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

    // MARK: - List Command

    @MainActor
    struct WindowListSubcommand: ErrorHandlingCommand, OutputFormattable, ApplicationResolvable {
        @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
        var app: String?

        @Option(name: .long, help: "Target application by process ID")
        var pid: Int32?
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

        @Flag(name: .long, help: "Group windows by Space (virtual desktop)")
        var groupBySpace = false

        /// List windows for the target application and optionally organize them by Space.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                let appIdentifier = try self.resolveApplicationIdentifier()
                // First find the application to get its info
                let appInfo = try await self.services.applications.findApplication(identifier: appIdentifier)

                let target = WindowTarget.application(appIdentifier)
                let rawWindows = try await WindowServiceBridge.listWindows(
                    windows: self.services.windows,
                    target: target
                )
                let windows = ObservationTargetResolver.filteredWindows(from: rawWindows, mode: .list)

                // Convert ServiceWindowInfo to WindowInfo for consistency
                let windowInfos = windows.map { window in
                    WindowInfo(
                        window_title: window.title,
                        window_id: UInt32(window.windowID),
                        window_index: window.index,
                        bounds: WindowBounds(
                            x: Int(window.bounds.origin.x),
                            y: Int(window.bounds.origin.y),
                            width: Int(window.bounds.size.width),
                            height: Int(window.bounds.size.height)
                        ),
                        is_on_screen: window.isOnScreen
                    )
                }

                // Use PeekabooCore's WindowListData
                let data = WindowListData(
                    windows: windowInfos,
                    target_application_info: TargetApplicationInfo(
                        app_name: appInfo.name,
                        bundle_id: appInfo.bundleIdentifier,
                        pid: appInfo.processIdentifier
                    )
                )

                output(data) {
                    print("\(data.target_application_info.app_name) has \(data.windows.count) window(s):")

                    if self.groupBySpace {
                        // Group windows by space
                        var windowsBySpace: [UInt64?: [(window: ServiceWindowInfo, index: Int)]] = [:]

                        for window in windows {
                            let spaceID = window.spaceID
                            windowsBySpace[spaceID, default: []].append((window, window.index))
                        }

                        // Sort spaces by ID (nil first for windows not on any space)
                        let sortedSpaces = windowsBySpace.keys.sorted { a, b in
                            switch (a, b) {
                            case (nil, nil): false
                            case (nil, _): true
                            case (_, nil): false
                            case let (a?, b?): a < b
                            }
                        }

                        // Print grouped windows
                        for spaceID in sortedSpaces {
                            if let spaceID {
                                let spaceName = windowsBySpace[spaceID]?.first?.window.spaceName ?? "Space \(spaceID)"
                                print("\n  Space: \(spaceName) [ID: \(spaceID)]")
                            } else {
                                print("\n  No Space:")
                            }

                            for (window, index) in windowsBySpace[spaceID] ?? [] {
                                let status = window.isMinimized ? " [minimized]" : ""
                                print("    [\(index)] \"\(window.title)\"\(status)")
                                let origin = window.bounds.origin
                                print("         Position: (\(Int(origin.x)), \(Int(origin.y)))")
                                print(
                                    "         Size: \(Int(window.bounds.size.width))x\(Int(window.bounds.size.height))"
                                )
                            }
                        }
                    } else {
                        // Original flat list
                        for window in data.windows {
                            let index = window.window_index ?? 0
                            let status = (window.is_on_screen == false) ? " [minimized]" : ""
                            print("  [\(index)] \"\(window.window_title)\"\(status)")
                            if let bounds = window.bounds {
                                print("       Position: (\(bounds.x), \(bounds.y))")
                                print("       Size: \(bounds.width)x\(bounds.height)")
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
}
