import AppKit
import ArgumentParser
import CoreGraphics
import Foundation
import PeekabooCore

/// Refactored WindowCommand using PeekabooCore services
struct WindowCommandV2: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "window-v2",
        abstract: "Manipulate application windows using PeekabooCore services",
        discussion: """
        This is a refactored version of the window command that uses PeekabooCore services
        instead of direct implementation. It maintains the same interface but delegates
        all operations to the service layer.
        
        SYNOPSIS:
          peekaboo window-v2 SUBCOMMAND [OPTIONS]

        DESCRIPTION:
          Provides window manipulation capabilities including closing, minimizing,
          maximizing, moving, resizing, and focusing windows.

        EXAMPLES:
          # Close a window
          peekaboo window-v2 close --app Safari
          peekaboo window-v2 close --app Safari --window-title "GitHub"

          # Minimize/maximize windows
          peekaboo window-v2 minimize --app Finder
          peekaboo window-v2 maximize --app Terminal

          # Move and resize windows
          peekaboo window-v2 move --app TextEdit --x 100 --y 100
          peekaboo window-v2 resize --app Safari --width 1200 --height 800
          peekaboo window-v2 set-bounds --app Chrome --x 50 --y 50 --width 1024 --height 768

          # Focus a window
          peekaboo window-v2 focus --app "Visual Studio Code"
          peekaboo window-v2 focus --app Safari --window-title "Apple"

          # List windows (convenience shortcut)
          peekaboo window-v2 list --app Safari

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
            CloseSubcommandV2.self,
            MinimizeSubcommandV2.self,
            MaximizeSubcommandV2.self,
            MoveSubcommandV2.self,
            ResizeSubcommandV2.self,
            SetBoundsSubcommandV2.self,
            FocusSubcommandV2.self,
            WindowListSubcommandV2.self,
        ])
}

// MARK: - Common Options

struct WindowIdentificationOptionsV2: ParsableArguments {
    @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
    var app: String?

    @Option(name: .long, help: "Target window by title (partial match supported)")
    var windowTitle: String?

    @Option(name: .long, help: "Target window by index (0-based, frontmost is 0)")
    var windowIndex: Int?

    func validate() throws {
        // Ensure we have some way to identify the window
        if app == nil {
            throw ValidationError("--app must be specified")
        }
    }
    
    /// Convert to WindowTarget for service layer
    func toWindowTarget() -> WindowTarget {
        if let app = app {
            if let index = windowIndex {
                return .index(app: app, index: index)
            } else if let title = windowTitle {
                // For title matching, we still need the app context
                // The service will handle finding the right window
                return .application(app)
            } else {
                // Default to app's frontmost window
                return .application(app)
            }
        } else {
            // Should not reach here due to validation
            return .frontmost
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
    let bounds: WindowBounds?
    if let windowInfo = windowInfo {
        bounds = WindowBounds(
            x: Int(windowInfo.bounds.origin.x),
            y: Int(windowInfo.bounds.origin.y),
            width: Int(windowInfo.bounds.size.width),
            height: Int(windowInfo.bounds.size.height)
        )
    } else {
        bounds = nil
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

struct CloseSubcommandV2: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "close",
        abstract: "Close a window")

    @OptionGroup var windowOptions: WindowIdentificationOptionsV2

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    private let services = PeekabooServices.shared

    func run() async throws {
        Logger.shared.setJsonOutputMode(jsonOutput)

        do {
            try windowOptions.validate()
            let target = windowOptions.toWindowTarget()
            
            // Get window info before closing
            let windows = try await services.windows.listWindows(target: target)
            let windowInfo = selectTargetWindow(windows: windows, options: windowOptions)
            let appName = windowOptions.app ?? "Unknown"
            
            // Close the window
            try await services.windows.closeWindow(target: createSpecificTarget())
            
            let data = createWindowActionResult(
                action: "close",
                success: true,
                windowInfo: windowInfo,
                appName: appName
            )

            if jsonOutput {
                outputSuccess(data: data)
            } else {
                print("Successfully closed window '\(data.window_title ?? "Untitled")' of \(data.app_name)")
            }

        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
    
    private func createSpecificTarget() -> WindowTarget {
        if let app = windowOptions.app {
            if let index = windowOptions.windowIndex {
                return .index(app: app, index: index)
            } else if let title = windowOptions.windowTitle {
                return .title(title)
            } else {
                return .application(app)
            }
        }
        return .frontmost
    }
    
    private func selectTargetWindow(windows: [ServiceWindowInfo], options: WindowIdentificationOptionsV2) -> ServiceWindowInfo? {
        if let title = options.windowTitle {
            return windows.first { $0.title.localizedCaseInsensitiveContains(title) }
        } else if let index = options.windowIndex, index < windows.count {
            return windows[index]
        } else {
            return windows.first
        }
    }

    private func handleError(_ error: Error) {
        if jsonOutput {
            outputError(
                message: error.localizedDescription,
                code: .WINDOW_MANIPULATION_ERROR,
                details: "Failed to close window")
        } else {
            fputs("Error: \(error.localizedDescription)\n", stderr)
        }
    }
}

struct MinimizeSubcommandV2: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "minimize",
        abstract: "Minimize a window to the Dock")

    @OptionGroup var windowOptions: WindowIdentificationOptionsV2

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    private let services = PeekabooServices.shared

    func run() async throws {
        Logger.shared.setJsonOutputMode(jsonOutput)

        do {
            try windowOptions.validate()
            
            // Get window info
            let windows = try await services.windows.listWindows(target: windowOptions.toWindowTarget())
            let windowInfo = selectTargetWindow(windows: windows, options: windowOptions)
            let appName = windowOptions.app ?? "Unknown"
            
            // Minimize the window
            try await services.windows.minimizeWindow(target: createSpecificTarget())
            
            let data = createWindowActionResult(
                action: "minimize",
                success: true,
                windowInfo: windowInfo,
                appName: appName
            )

            if jsonOutput {
                outputSuccess(data: data)
            } else {
                print("Successfully minimized window '\(data.window_title ?? "Untitled")' of \(data.app_name)")
            }

        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
    
    private func createSpecificTarget() -> WindowTarget {
        if let app = windowOptions.app {
            if let index = windowOptions.windowIndex {
                return .index(app: app, index: index)
            } else if let title = windowOptions.windowTitle {
                return .title(title)
            } else {
                return .application(app)
            }
        }
        return .frontmost
    }
    
    private func selectTargetWindow(windows: [ServiceWindowInfo], options: WindowIdentificationOptionsV2) -> ServiceWindowInfo? {
        if let title = options.windowTitle {
            return windows.first { $0.title.localizedCaseInsensitiveContains(title) }
        } else if let index = options.windowIndex, index < windows.count {
            return windows[index]
        } else {
            return windows.first
        }
    }

    private func handleError(_ error: Error) {
        if jsonOutput {
            outputError(
                message: error.localizedDescription,
                code: .WINDOW_MANIPULATION_ERROR,
                details: "Failed to minimize window")
        } else {
            fputs("Error: \(error.localizedDescription)\n", stderr)
        }
    }
}

struct MaximizeSubcommandV2: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "maximize",
        abstract: "Maximize a window (full screen)")

    @OptionGroup var windowOptions: WindowIdentificationOptionsV2

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    private let services = PeekabooServices.shared

    func run() async throws {
        Logger.shared.setJsonOutputMode(jsonOutput)

        do {
            try windowOptions.validate()
            
            // Get window info
            let windows = try await services.windows.listWindows(target: windowOptions.toWindowTarget())
            let windowInfo = selectTargetWindow(windows: windows, options: windowOptions)
            let appName = windowOptions.app ?? "Unknown"
            
            // Maximize the window
            try await services.windows.maximizeWindow(target: createSpecificTarget())
            
            let data = createWindowActionResult(
                action: "maximize",
                success: true,
                windowInfo: windowInfo,
                appName: appName
            )

            if jsonOutput {
                outputSuccess(data: data)
            } else {
                print("Successfully maximized window '\(data.window_title ?? "Untitled")' of \(data.app_name)")
            }

        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
    
    private func createSpecificTarget() -> WindowTarget {
        if let app = windowOptions.app {
            if let index = windowOptions.windowIndex {
                return .index(app: app, index: index)
            } else if let title = windowOptions.windowTitle {
                return .title(title)
            } else {
                return .application(app)
            }
        }
        return .frontmost
    }
    
    private func selectTargetWindow(windows: [ServiceWindowInfo], options: WindowIdentificationOptionsV2) -> ServiceWindowInfo? {
        if let title = options.windowTitle {
            return windows.first { $0.title.localizedCaseInsensitiveContains(title) }
        } else if let index = options.windowIndex, index < windows.count {
            return windows[index]
        } else {
            return windows.first
        }
    }

    private func handleError(_ error: Error) {
        if jsonOutput {
            outputError(
                message: error.localizedDescription,
                code: .WINDOW_MANIPULATION_ERROR,
                details: "Failed to maximize window")
        } else {
            fputs("Error: \(error.localizedDescription)\n", stderr)
        }
    }
}

struct MoveSubcommandV2: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "move",
        abstract: "Move a window to a new position")

    @OptionGroup var windowOptions: WindowIdentificationOptionsV2

    @Option(name: .long, help: "New X coordinate")
    var x: Int

    @Option(name: .long, help: "New Y coordinate")
    var y: Int

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    private let services = PeekabooServices.shared

    func run() async throws {
        Logger.shared.setJsonOutputMode(jsonOutput)

        do {
            try windowOptions.validate()
            
            // Get window info
            let windows = try await services.windows.listWindows(target: windowOptions.toWindowTarget())
            let windowInfo = selectTargetWindow(windows: windows, options: windowOptions)
            let appName = windowOptions.app ?? "Unknown"
            
            // Move the window
            let newPosition = CGPoint(x: x, y: y)
            try await services.windows.moveWindow(target: createSpecificTarget(), to: newPosition)
            
            // Create result with updated position
            var updatedBounds = windowInfo?.bounds ?? CGRect.zero
            updatedBounds.origin = newPosition
            
            let data = WindowActionResult(
                action: "move",
                success: true,
                app_name: appName,
                window_title: windowInfo?.title,
                new_bounds: WindowBounds(
                    x: x,
                    y: y,
                    width: Int(updatedBounds.width),
                    height: Int(updatedBounds.height)
                )
            )

            if jsonOutput {
                outputSuccess(data: data)
            } else {
                print("Successfully moved window '\(data.window_title ?? "Untitled")' of \(data.app_name) to (\(x), \(y))")
            }

        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
    
    private func createSpecificTarget() -> WindowTarget {
        if let app = windowOptions.app {
            if let index = windowOptions.windowIndex {
                return .index(app: app, index: index)
            } else if let title = windowOptions.windowTitle {
                return .title(title)
            } else {
                return .application(app)
            }
        }
        return .frontmost
    }
    
    private func selectTargetWindow(windows: [ServiceWindowInfo], options: WindowIdentificationOptionsV2) -> ServiceWindowInfo? {
        if let title = options.windowTitle {
            return windows.first { $0.title.localizedCaseInsensitiveContains(title) }
        } else if let index = options.windowIndex, index < windows.count {
            return windows[index]
        } else {
            return windows.first
        }
    }

    private func handleError(_ error: Error) {
        if jsonOutput {
            outputError(
                message: error.localizedDescription,
                code: .WINDOW_MANIPULATION_ERROR,
                details: "Failed to move window")
        } else {
            fputs("Error: \(error.localizedDescription)\n", stderr)
        }
    }
}

struct ResizeSubcommandV2: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "resize",
        abstract: "Resize a window")

    @OptionGroup var windowOptions: WindowIdentificationOptionsV2

    @Option(name: .long, help: "New width")
    var width: Int

    @Option(name: .long, help: "New height")
    var height: Int

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    private let services = PeekabooServices.shared

    func run() async throws {
        Logger.shared.setJsonOutputMode(jsonOutput)

        do {
            try windowOptions.validate()
            
            // Get window info
            let windows = try await services.windows.listWindows(target: windowOptions.toWindowTarget())
            let windowInfo = selectTargetWindow(windows: windows, options: windowOptions)
            let appName = windowOptions.app ?? "Unknown"
            
            // Resize the window
            let newSize = CGSize(width: width, height: height)
            try await services.windows.resizeWindow(target: createSpecificTarget(), to: newSize)
            
            // Create result with updated size
            let currentPosition = windowInfo?.bounds.origin ?? CGPoint.zero
            
            let data = WindowActionResult(
                action: "resize",
                success: true,
                app_name: appName,
                window_title: windowInfo?.title,
                new_bounds: WindowBounds(
                    x: Int(currentPosition.x),
                    y: Int(currentPosition.y),
                    width: width,
                    height: height
                )
            )

            if jsonOutput {
                outputSuccess(data: data)
            } else {
                print("Successfully resized window '\(data.window_title ?? "Untitled")' of \(data.app_name) to \(width)×\(height)")
            }

        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
    
    private func createSpecificTarget() -> WindowTarget {
        if let app = windowOptions.app {
            if let index = windowOptions.windowIndex {
                return .index(app: app, index: index)
            } else if let title = windowOptions.windowTitle {
                return .title(title)
            } else {
                return .application(app)
            }
        }
        return .frontmost
    }
    
    private func selectTargetWindow(windows: [ServiceWindowInfo], options: WindowIdentificationOptionsV2) -> ServiceWindowInfo? {
        if let title = options.windowTitle {
            return windows.first { $0.title.localizedCaseInsensitiveContains(title) }
        } else if let index = options.windowIndex, index < windows.count {
            return windows[index]
        } else {
            return windows.first
        }
    }

    private func handleError(_ error: Error) {
        if jsonOutput {
            outputError(
                message: error.localizedDescription,
                code: .WINDOW_MANIPULATION_ERROR,
                details: "Failed to resize window")
        } else {
            fputs("Error: \(error.localizedDescription)\n", stderr)
        }
    }
}

struct SetBoundsSubcommandV2: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set-bounds",
        abstract: "Set window position and size in one operation")

    @OptionGroup var windowOptions: WindowIdentificationOptionsV2

    @Option(name: .long, help: "New X coordinate")
    var x: Int

    @Option(name: .long, help: "New Y coordinate")
    var y: Int

    @Option(name: .long, help: "New width")
    var width: Int

    @Option(name: .long, help: "New height")
    var height: Int

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    private let services = PeekabooServices.shared

    func run() async throws {
        Logger.shared.setJsonOutputMode(jsonOutput)

        do {
            try windowOptions.validate()
            
            // Get window info
            let windows = try await services.windows.listWindows(target: windowOptions.toWindowTarget())
            let windowInfo = selectTargetWindow(windows: windows, options: windowOptions)
            let appName = windowOptions.app ?? "Unknown"
            
            // Set window bounds
            let newBounds = CGRect(x: x, y: y, width: width, height: height)
            try await services.windows.setWindowBounds(target: createSpecificTarget(), bounds: newBounds)
            
            let data = WindowActionResult(
                action: "set-bounds",
                success: true,
                app_name: appName,
                window_title: windowInfo?.title,
                new_bounds: WindowBounds(x: x, y: y, width: width, height: height)
            )

            if jsonOutput {
                outputSuccess(data: data)
            } else {
                print("Successfully set bounds for window '\(data.window_title ?? "Untitled")' of \(data.app_name)")
                print("New bounds: (\(x), \(y)) \(width)×\(height)")
            }

        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
    
    private func createSpecificTarget() -> WindowTarget {
        if let app = windowOptions.app {
            if let index = windowOptions.windowIndex {
                return .index(app: app, index: index)
            } else if let title = windowOptions.windowTitle {
                return .title(title)
            } else {
                return .application(app)
            }
        }
        return .frontmost
    }
    
    private func selectTargetWindow(windows: [ServiceWindowInfo], options: WindowIdentificationOptionsV2) -> ServiceWindowInfo? {
        if let title = options.windowTitle {
            return windows.first { $0.title.localizedCaseInsensitiveContains(title) }
        } else if let index = options.windowIndex, index < windows.count {
            return windows[index]
        } else {
            return windows.first
        }
    }

    private func handleError(_ error: Error) {
        if jsonOutput {
            outputError(
                message: error.localizedDescription,
                code: .WINDOW_MANIPULATION_ERROR,
                details: "Failed to set window bounds")
        } else {
            fputs("Error: \(error.localizedDescription)\n", stderr)
        }
    }
}

struct FocusSubcommandV2: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "focus",
        abstract: "Bring a window to the foreground")

    @OptionGroup var windowOptions: WindowIdentificationOptionsV2

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    private let services = PeekabooServices.shared

    func run() async throws {
        Logger.shared.setJsonOutputMode(jsonOutput)

        do {
            try windowOptions.validate()
            
            // Get window info
            let windows = try await services.windows.listWindows(target: windowOptions.toWindowTarget())
            let windowInfo = selectTargetWindow(windows: windows, options: windowOptions)
            let appName = windowOptions.app ?? "Unknown"
            
            // Focus the window
            try await services.windows.focusWindow(target: createSpecificTarget())
            
            let data = createWindowActionResult(
                action: "focus",
                success: true,
                windowInfo: windowInfo,
                appName: appName
            )

            if jsonOutput {
                outputSuccess(data: data)
            } else {
                print("Successfully focused window '\(data.window_title ?? "Untitled")' of \(data.app_name)")
            }

        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
    
    private func createSpecificTarget() -> WindowTarget {
        if let app = windowOptions.app {
            if let index = windowOptions.windowIndex {
                return .index(app: app, index: index)
            } else if let title = windowOptions.windowTitle {
                return .title(title)
            } else {
                return .application(app)
            }
        }
        return .frontmost
    }
    
    private func selectTargetWindow(windows: [ServiceWindowInfo], options: WindowIdentificationOptionsV2) -> ServiceWindowInfo? {
        if let title = options.windowTitle {
            return windows.first { $0.title.localizedCaseInsensitiveContains(title) }
        } else if let index = options.windowIndex, index < windows.count {
            return windows[index]
        } else {
            return windows.first
        }
    }

    private func handleError(_ error: Error) {
        if jsonOutput {
            outputError(
                message: error.localizedDescription,
                code: .WINDOW_MANIPULATION_ERROR,
                details: "Failed to focus window")
        } else {
            fputs("Error: \(error.localizedDescription)\n", stderr)
        }
    }
}

struct WindowListSubcommandV2: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List windows for an application (convenience shortcut)")

    @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
    var app: String

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    private let services = PeekabooServices.shared

    func run() async throws {
        Logger.shared.setJsonOutputMode(jsonOutput)
        
        do {
            // Get application info
            let appInfo = try await services.applications.findApplication(identifier: app)
            
            // List windows
            let windows = try await services.applications.listWindows(for: app)
            
            // Convert to output format
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
            
            let targetAppInfo = TargetApplicationInfo(
                app_name: appInfo.name,
                bundle_id: appInfo.bundleIdentifier,
                pid: appInfo.processIdentifier
            )
            
            let data = WindowListData(
                windows: windowInfos,
                target_application_info: targetAppInfo
            )
            
            if jsonOutput {
                outputSuccess(data: data)
            } else {
                print("\(appInfo.name) (\(appInfo.bundleIdentifier ?? "unknown")) - \(windows.count) windows:")
                for (index, window) in windows.enumerated() {
                    let bounds = window.bounds
                    print("  [\(index)] \(window.title) (ID: \(window.windowID), Bounds: \(Int(bounds.origin.x)),\(Int(bounds.origin.y)) \(Int(bounds.width))×\(Int(bounds.height)))")
                }
            }
            
        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
    
    private func handleError(_ error: Error) {
        if jsonOutput {
            outputError(
                message: error.localizedDescription,
                code: .WINDOW_NOT_FOUND,
                details: "Failed to list windows")
        } else {
            fputs("Error: \(error.localizedDescription)\n", stderr)
        }
    }
}

// MARK: - Data Structures

struct WindowActionResult: Codable {
    let action: String
    let success: Bool
    let app_name: String
    let window_title: String?
    let new_bounds: WindowBounds?

    init(action: String, success: Bool, app_name: String, window_title: String?, new_bounds: WindowBounds? = nil) {
        self.action = action
        self.success = success
        self.app_name = app_name
        self.window_title = window_title
        self.new_bounds = new_bounds
    }
}