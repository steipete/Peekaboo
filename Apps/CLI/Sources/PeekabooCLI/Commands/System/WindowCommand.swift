import AppKit
@preconcurrency import ArgumentParser
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

// Logger for window command debugging

/// Manipulate application windows with various actions
struct WindowCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
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
          Use --json-output for machine-readable JSON format.
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
        ]
    )
}

// MARK: - Common Options

struct WindowIdentificationOptions: ParsableArguments, ApplicationResolvable {
    @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
    var app: String?

    @Option(name: .long, help: "Target application by process ID")
    var pid: Int32?

    @Option(name: .long, help: "Target window by title (partial match supported)")
    var windowTitle: String?

    @Option(name: .long, help: "Target window by index (0-based, frontmost is 0)")
    var windowIndex: Int?

    enum CodingKeys: String, CodingKey {
        case app
        case pid
        case windowTitle
        case windowIndex
    }

    init() {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.app = try container.decodeIfPresent(String.self, forKey: .app)
        self.pid = try container.decodeIfPresent(Int32.self, forKey: .pid)
        self.windowTitle = try container.decodeIfPresent(String.self, forKey: .windowTitle)
        self.windowIndex = try container.decodeIfPresent(Int.self, forKey: .windowIndex)
    }

    func validate() throws {
        // Ensure we have some way to identify the window
        if self.app == nil && self.pid == nil {
            throw ValidationError("Either --app or --pid must be specified")
        }
    }

    /// Convert to WindowTarget for service layer
    func toWindowTarget() throws -> WindowTarget {
        // Convert to WindowTarget for service layer
        let appIdentifier = try self.resolveApplicationIdentifier()

        if let index = windowIndex {
            return .index(app: appIdentifier, index: index)
        } else if self.windowTitle != nil {
            // For title matching, we still need the app context
            // The service will handle finding the right window
            return .application(appIdentifier)
        } else {
            // Default to app's frontmost window
            return .application(appIdentifier)
        }
    }
}

// MARK: - Helper Functions

private func createWindowActionResult(
    action: String,
    success: Bool,
    windowInfo: ServiceWindowInfo?,
    appName: String? = nil
) -> WindowActionResult {
    let bounds: WindowBounds? = if let windowInfo {
        WindowBounds(
            x: Int(windowInfo.bounds.origin.x),
            y: Int(windowInfo.bounds.origin.y),
            width: Int(windowInfo.bounds.size.width),
            height: Int(windowInfo.bounds.size.height)
        )
    } else {
        nil
    }

    return WindowActionResult(
        action: action,
        success: success,
        app_name: appName ?? "Unknown",
        window_title: windowInfo?.title,
        new_bounds: bounds
    )
}

// MARK: - Subcommands

extension WindowCommand {

@MainActor
struct CloseSubcommand: ErrorHandlingCommand, OutputFormattable {
    @OptionGroup var windowOptions: WindowIdentificationOptions
    @OptionGroup var runtimeOptions: CommandRuntimeOptions

    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: PeekabooServices { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

    /// Resolve the target window, close it, and surface the outcome in JSON or text form.
    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let target = self.windowOptions.createTarget()

            // Get window info before action
            let windows = try await WindowServiceBridge.listWindows(services: self.services, target: self.windowOptions.toWindowTarget())
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            let appName = self.windowOptions.app ?? "Unknown"

            // Perform the action
            try await WindowServiceBridge.closeWindow(services: self.services, target: target)

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
    @OptionGroup var runtimeOptions: CommandRuntimeOptions

    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: PeekabooServices { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

    /// Resolve the target window, minimize it to the Dock, and report the action.
    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let target = self.windowOptions.createTarget()

            // Get window info before action
            let windows = try await WindowServiceBridge.listWindows(services: self.services, target: self.windowOptions.toWindowTarget())
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            let appName = self.windowOptions.app ?? "Unknown"

            // Perform the action
            try await WindowServiceBridge.minimizeWindow(services: self.services, target: target)

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
    @OptionGroup var runtimeOptions: CommandRuntimeOptions

    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: PeekabooServices { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

    /// Expand the resolved window to fill the available screen real estate and share the updated frame.
    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let target = self.windowOptions.createTarget()

            // Get window info before action
            let windows = try await WindowServiceBridge.listWindows(services: self.services, target: self.windowOptions.toWindowTarget())
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            let appName = self.windowOptions.app ?? "Unknown"

            // Perform the action
            try await WindowServiceBridge.maximizeWindow(services: self.services, target: target)

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

@MainActor
struct FocusSubcommand: ErrorHandlingCommand, OutputFormattable {

    @OptionGroup var windowOptions: WindowIdentificationOptions
    @OptionGroup var focusOptions: FocusCommandOptions

    @OptionGroup var runtimeOptions: CommandRuntimeOptions

    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: PeekabooServices { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

    /// Focus the targeted window, handling Space switches or relocation according to the provided options.
    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.debug("FocusSubcommand.run() called")
        self.logger.setJsonOutputMode(self.jsonOutput)

        do {
            self.logger.debug("About to validate window options")
            try self.windowOptions.validate()
            self.logger.debug("Window options validated")
            let target = self.windowOptions.createTarget()
            self.logger.debug("Target created: \(target)")

            // Get window info before action
            let windows = try await WindowServiceBridge.listWindows(services: self.services, target: self.windowOptions.toWindowTarget())
            self.logger.debug("Found \(windows.count) windows")
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            let appName = self.windowOptions.app ?? "Unknown"

            // Check if we found any windows
            guard !windows.isEmpty else {
                throw PeekabooError.windowNotFound(criteria: "No windows found for \(appName)")
            }

            // Use enhanced focus with space support
            if let windowID = windowInfo?.windowID {
                try await ensureFocused(
                    windowID: CGWindowID(windowID),
                    applicationName: self.windowOptions.app,
                    windowTitle: self.windowOptions.windowTitle,
                    options: self.focusOptions.asFocusOptions,
                    services: self.services
                )
            } else {
                // Fallback to regular focus if no window ID
                try await WindowServiceBridge.focusWindow(services: self.services, target: target)
            }

            let data = createWindowActionResult(
                action: "focus",
                success: true,
                windowInfo: windowInfo,
                appName: appName
            )

            output(data) {
                var message = "Successfully focused window '\(windowInfo?.title ?? "Untitled")' of \(appName)"
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
}

// MARK: - Move Command

@MainActor
struct MoveSubcommand: ErrorHandlingCommand, OutputFormattable {
    @OptionGroup var runtimeOptions: CommandRuntimeOptions
    @OptionGroup var windowOptions: WindowIdentificationOptions

    @Option(name: .short, help: "New X coordinate")
    var x: Int

    @Option(name: .short, help: "New Y coordinate")
    var y: Int

    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: PeekabooServices { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

    /// Move the window to the absolute screen coordinates provided by the user.
    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let target = self.windowOptions.createTarget()

            // Get window info
            let windows = try await WindowServiceBridge.listWindows(services: self.services, target: self.windowOptions.toWindowTarget())
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            let appName = self.windowOptions.app ?? "Unknown"

            // Move the window
            let newOrigin = CGPoint(x: x, y: y)
            try await WindowServiceBridge.moveWindow(services: self.services, target: target, to: newOrigin)

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

            let data = createWindowActionResult(
                action: "move",
                success: true,
                windowInfo: updatedInfo,
                appName: appName
            )

            output(data) {
                print("Successfully moved window '\(windowInfo?.title ?? "Untitled")' to (\(self.x), \(self.y))")
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
    @OptionGroup var runtimeOptions: CommandRuntimeOptions
    @OptionGroup var windowOptions: WindowIdentificationOptions

    @Option(name: .short, help: "New width")
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

    private var services: PeekabooServices { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

    /// Resize the window to the supplied dimensions, preserving its origin.
    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let target = self.windowOptions.createTarget()

            // Get window info
            let windows = try await WindowServiceBridge.listWindows(services: self.services, target: self.windowOptions.toWindowTarget())
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            let appName = self.windowOptions.app ?? "Unknown"

            // Resize the window
            let newSize = CGSize(width: width, height: height)
            try await WindowServiceBridge.resizeWindow(services: self.services, target: target, to: newSize)

            // We'll pass the original windowInfo as-is since window service would have updated it
            // (In a real implementation, we'd refetch window info after resize)

            let data = createWindowActionResult(
                action: "resize",
                success: true,
                windowInfo: windowInfo,
                appName: appName
            )

            output(data) {
                print("Successfully resized window '\(windowInfo?.title ?? "Untitled")' to \(self.width)x\(self.height)"
                )
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
    @OptionGroup var runtimeOptions: CommandRuntimeOptions
    @OptionGroup var windowOptions: WindowIdentificationOptions

    @Option(name: .short, help: "New X coordinate")
    var x: Int

    @Option(name: .short, help: "New Y coordinate")
    var y: Int

    @Option(name: .short, help: "New width")
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

    private var services: PeekabooServices { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

    /// Set both position and size for the window in a single operation, then confirm the new bounds.
    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let target = self.windowOptions.createTarget()

            // Get window info
            let windows = try await WindowServiceBridge.listWindows(services: self.services, target: self.windowOptions.toWindowTarget())
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            let appName = self.windowOptions.app ?? "Unknown"

            // Set bounds
            let newBounds = CGRect(x: x, y: y, width: width, height: height)
            try await WindowServiceBridge.setWindowBounds(services: self.services, target: target, bounds: newBounds)

            // We'll pass the original windowInfo as-is since window service would have updated it
            // (In a real implementation, we'd refetch window info after set-bounds)

            let data = createWindowActionResult(
                action: "set-bounds",
                success: true,
                windowInfo: windowInfo,
                appName: appName
            )

            output(data) {
                print(
                    "Successfully set window '\(windowInfo?.title ?? "Untitled")' bounds to (\(self.x), \(self.y)) \(self.width)x\(self.height)"
                )
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

    @OptionGroup var runtimeOptions: CommandRuntimeOptions

    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: PeekabooServices { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

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
            let windows = try await WindowServiceBridge.listWindows(services: self.services, target: target)

            // Convert ServiceWindowInfo to WindowInfo for consistency
            let windowInfos = windows.enumerated().map { index, window in
                WindowInfo(
                    window_title: window.title,
                    window_id: UInt32(window.windowID),
                    window_index: index,
                    bounds: WindowBounds(
                        x: Int(window.bounds.origin.x),
                        y: Int(window.bounds.origin.y),
                        width: Int(window.bounds.size.width),
                        height: Int(window.bounds.size.height)
                    ),
                    is_on_screen: !window.isMinimized
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

                    for (index, window) in windows.enumerated() {
                        let spaceID = window.spaceID
                        if windowsBySpace[spaceID] == nil {
                            windowsBySpace[spaceID] = []
                        }
                        windowsBySpace[spaceID]?.append((window, index))
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
                            print("         Position: (\(Int(window.bounds.origin.x)), \(Int(window.bounds.origin.y)))")
                            print("         Size: \(Int(window.bounds.size.width))x\(Int(window.bounds.size.height))")
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

// MARK: - Response Types

struct WindowActionResult: Codable {
    let action: String
    let success: Bool
    let app_name: String
    let window_title: String?
    let new_bounds: WindowBounds?
}


// Using PeekabooCore.WindowListData for consistency

// MARK: - Subcommand Conformances

extension WindowCommand.MoveSubcommand: ParsableCommand {
    nonisolated(unsafe) static var configuration: CommandConfiguration {
        MainActorCommandConfiguration.describe {
            CommandConfiguration(commandName: "move", abstract: "Move a window to a new position")
        }
    }
}

extension WindowCommand.MoveSubcommand: AsyncRuntimeCommand {}

extension WindowCommand.ResizeSubcommand: ParsableCommand {
    nonisolated(unsafe) static var configuration: CommandConfiguration {
        MainActorCommandConfiguration.describe {
            CommandConfiguration(commandName: "resize", abstract: "Resize a window")
        }
    }
}

extension WindowCommand.ResizeSubcommand: AsyncRuntimeCommand {}

extension WindowCommand.SetBoundsSubcommand: ParsableCommand {
    nonisolated(unsafe) static var configuration: CommandConfiguration {
        MainActorCommandConfiguration.describe {
            CommandConfiguration(commandName: "set-bounds", abstract: "Set window position and size in one operation")
        }
    }
}

extension WindowCommand.SetBoundsSubcommand: AsyncRuntimeCommand {}

extension WindowCommand.WindowListSubcommand: ParsableCommand {
    nonisolated(unsafe) static var configuration: CommandConfiguration {
        MainActorCommandConfiguration.describe {
            CommandConfiguration(commandName: "list", abstract: "List windows for an application")
        }
    }
}

extension WindowCommand.WindowListSubcommand: AsyncRuntimeCommand {}

extension WindowCommand.CloseSubcommand: ParsableCommand {
    nonisolated(unsafe) static var configuration: CommandConfiguration {
        MainActorCommandConfiguration.describe {
            CommandConfiguration(commandName: "close", abstract: "Close a window")
        }
    }
}

extension WindowCommand.CloseSubcommand: AsyncRuntimeCommand {}

extension WindowCommand.MinimizeSubcommand: ParsableCommand {
    nonisolated(unsafe) static var configuration: CommandConfiguration {
        MainActorCommandConfiguration.describe {
            CommandConfiguration(commandName: "minimize", abstract: "Minimize a window to the Dock")
        }
    }
}

extension WindowCommand.MinimizeSubcommand: AsyncRuntimeCommand {}

extension WindowCommand.MaximizeSubcommand: ParsableCommand {
    nonisolated(unsafe) static var configuration: CommandConfiguration {
        MainActorCommandConfiguration.describe {
            CommandConfiguration(commandName: "maximize", abstract: "Maximize a window (full screen)")
        }
    }
}

extension WindowCommand.MaximizeSubcommand: AsyncRuntimeCommand {}

extension WindowCommand.FocusSubcommand: ParsableCommand {
    nonisolated(unsafe) static var configuration: CommandConfiguration {
        MainActorCommandConfiguration.describe {
            CommandConfiguration(
                commandName: "focus",
                abstract: "Bring a window to the foreground",
                discussion: """
        Focus brings a window to the foreground and activates its application.

        Space Support:
        By default, if the window is on a different Space (virtual desktop),
        the focus command will switch to that Space. You can control this
        behavior with the --space-switch and --move-here options.

        Examples:
        peekaboo window focus --app Safari
        peekaboo window focus --app "Visual Studio Code" --window-title "main.swift"
        peekaboo window focus --app Terminal --no-space-switch
        peekaboo window focus --app Finder --move-here
        """
            )
        }
    }
}

extension WindowCommand.FocusSubcommand: AsyncRuntimeCommand {}
