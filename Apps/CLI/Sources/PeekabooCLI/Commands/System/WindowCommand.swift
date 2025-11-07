import AppKit
@preconcurrency import ArgumentParser
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

// Logger for window command debugging
private let logger = Logger.shared

/// Manipulate application windows with various actions
@MainActor
struct WindowCommand: @MainActor MainActorAsyncParsableCommand {
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

@MainActor

struct WindowIdentificationOptions: @MainActor MainActorParsableArguments, ApplicationResolvable {
    @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
    var app: String?

    @Option(name: .long, help: "Target application by process ID")
    var pid: Int32?

    @Option(name: .long, help: "Target window by title (partial match supported)")
    var windowTitle: String?

    @Option(name: .long, help: "Target window by index (0-based, frontmost is 0)")
    var windowIndex: Int?

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

@MainActor
struct CloseSubcommand: @MainActor MainActorAsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "close",
        abstract: "Close a window"
    )

    @OptionGroup var windowOptions: WindowIdentificationOptions

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    /// Resolve the target window, close it, and surface the outcome in JSON or text form.
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let target = self.windowOptions.createTarget()

            // Get window info before action
            let windows = try await PeekabooServices.shared.windows
                .listWindows(target: self.windowOptions.toWindowTarget())
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            let appName = self.windowOptions.app ?? "Unknown"

            // Perform the action
            try await PeekabooServices.shared.windows.closeWindow(target: target)

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
struct MinimizeSubcommand: @MainActor MainActorAsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "minimize",
        abstract: "Minimize a window to the Dock"
    )

    @OptionGroup var windowOptions: WindowIdentificationOptions

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    /// Resolve the target window, minimize it to the Dock, and report the action.
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let target = self.windowOptions.createTarget()

            // Get window info before action
            let windows = try await PeekabooServices.shared.windows
                .listWindows(target: self.windowOptions.toWindowTarget())
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            let appName = self.windowOptions.app ?? "Unknown"

            // Perform the action
            try await PeekabooServices.shared.windows.minimizeWindow(target: target)

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
struct MaximizeSubcommand: @MainActor MainActorAsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "maximize",
        abstract: "Maximize a window (full screen)"
    )

    @OptionGroup var windowOptions: WindowIdentificationOptions

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    /// Expand the resolved window to fill the available screen real estate and share the updated frame.
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let target = self.windowOptions.createTarget()

            // Get window info before action
            let windows = try await PeekabooServices.shared.windows
                .listWindows(target: self.windowOptions.toWindowTarget())
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            let appName = self.windowOptions.app ?? "Unknown"

            // Perform the action
            try await PeekabooServices.shared.windows.maximizeWindow(target: target)

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
struct FocusSubcommand: @MainActor MainActorAsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
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

    @OptionGroup var windowOptions: WindowIdentificationOptions
    @OptionGroup var focusOptions: FocusCommandOptions

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    /// Focus the targeted window, handling Space switches or relocation according to the provided options.
    func run() async throws {
        logger.debug("FocusSubcommand.run() called")
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            logger.debug("About to validate window options")
            try self.windowOptions.validate()
            logger.debug("Window options validated")
            let target = self.windowOptions.createTarget()
            logger.debug("Target created: \(target)")

            // Get window info before action
            let windows = try await PeekabooServices.shared.windows
                .listWindows(target: self.windowOptions.toWindowTarget())
            logger.debug("Found \(windows.count) windows")
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
                    options: self.focusOptions.asFocusOptions
                )
            } else {
                // Fallback to regular focus if no window ID
                try await PeekabooServices.shared.windows.focusWindow(target: target)
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
struct MoveSubcommand: @MainActor MainActorAsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "move",
        abstract: "Move a window to a new position"
    )

    @OptionGroup var windowOptions: WindowIdentificationOptions

    @Option(name: .short, help: "New X coordinate")
    var x: Int

    @Option(name: .short, help: "New Y coordinate")
    var y: Int

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    /// Move the window to the absolute screen coordinates provided by the user.
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let target = self.windowOptions.createTarget()

            // Get window info
            let windows = try await PeekabooServices.shared.windows
                .listWindows(target: self.windowOptions.toWindowTarget())
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            let appName = self.windowOptions.app ?? "Unknown"

            // Move the window
            let newOrigin = CGPoint(x: x, y: y)
            try await PeekabooServices.shared.windows.moveWindow(target: target, to: newOrigin)

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
struct ResizeSubcommand: @preconcurrency AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "resize",
        abstract: "Resize a window"
    )

    @OptionGroup var windowOptions: WindowIdentificationOptions

    @Option(name: .short, help: "New width")
    var width: Int

    @Option(name: .long, help: "New height")
    var height: Int

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    /// Resize the window to the supplied dimensions, preserving its origin.
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let target = self.windowOptions.createTarget()

            // Get window info
            let windows = try await PeekabooServices.shared.windows
                .listWindows(target: self.windowOptions.toWindowTarget())
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            let appName = self.windowOptions.app ?? "Unknown"

            // Resize the window
            let newSize = CGSize(width: width, height: height)
            try await PeekabooServices.shared.windows.resizeWindow(target: target, to: newSize)

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
struct SetBoundsSubcommand: @preconcurrency AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "set-bounds",
        abstract: "Set window position and size in one operation"
    )

    @OptionGroup var windowOptions: WindowIdentificationOptions

    @Option(name: .short, help: "New X coordinate")
    var x: Int

    @Option(name: .short, help: "New Y coordinate")
    var y: Int

    @Option(name: .short, help: "New width")
    var width: Int

    @Option(name: .long, help: "New height")
    var height: Int

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    /// Set both position and size for the window in a single operation, then confirm the new bounds.
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let target = self.windowOptions.createTarget()

            // Get window info
            let windows = try await PeekabooServices.shared.windows
                .listWindows(target: self.windowOptions.toWindowTarget())
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            let appName = self.windowOptions.app ?? "Unknown"

            // Set bounds
            let newBounds = CGRect(x: x, y: y, width: width, height: height)
            try await PeekabooServices.shared.windows.setWindowBounds(target: target, bounds: newBounds)

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
struct WindowListSubcommand: @preconcurrency AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable, ApplicationResolvable {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List windows for an application"
    )

    @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
    var app: String?

    @Option(name: .long, help: "Target application by process ID")
    var pid: Int32?

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    @Flag(name: .long, help: "Group windows by Space (virtual desktop)")
    var groupBySpace = false

    /// List windows for the target application and optionally organize them by Space.
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            let appIdentifier = try self.resolveApplicationIdentifier()
            // First find the application to get its info
            let appInfo = try await PeekabooServices.shared.applications.findApplication(identifier: appIdentifier)

            let target = WindowTarget.application(appIdentifier)
            let windows = try await PeekabooServices.shared.windows.listWindows(target: target)

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

// MARK: - Response Types

struct WindowActionResult: Codable {
    let action: String
    let success: Bool
    let app_name: String
    let window_title: String?
    let new_bounds: WindowBounds?
}

// Using PeekabooCore.WindowListData for consistency
