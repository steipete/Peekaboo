import AppKit
import ArgumentParser
import AXorcist
import Foundation

/// Command for manipulating windows.
///
/// Provides subcommands to close, minimize, maximize, move, resize, and focus windows.
struct WindowCommand: AsyncParsableCommand {
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
          peekaboo window close --session abc123 --element W1

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
        ])
}

// MARK: - Common Options

struct WindowIdentificationOptions: ParsableArguments {
    @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
    var app: String?

    @Option(name: .long, help: "Target window by title (partial match supported)")
    var windowTitle: String?

    @Option(name: .long, help: "Target window by index (0-based, frontmost is 0)")
    var windowIndex: Int?

    @Option(name: .long, help: "Session ID for element-based targeting")
    var session: String?

    @Option(name: .long, help: "Element ID from see command (e.g., W1, W2)")
    var element: String?

    func validate() throws {
        // Ensure we have some way to identify the window
        if self.app == nil, self.session == nil {
            throw ValidationError("Either --app or --session must be specified")
        }

        // If using session, must also specify element
        if self.session != nil, self.element == nil {
            throw ValidationError("When using --session, --element must also be specified")
        }

        // If using app, can't use session/element
        if self.app != nil, self.session != nil || self.element != nil {
            throw ValidationError("Cannot use both --app and --session/--element")
        }
    }
}

// MARK: - Helper Functions

@MainActor
private func findTargetWindow(options: WindowIdentificationOptions) async throws
-> (app: NSRunningApplication, window: Element) {
    if let appIdentifier = options.app {
        // Find app by identifier
        let app = try ApplicationFinder.findApplication(identifier: appIdentifier)

        // Get AX element for the app
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)

        // Get windows
        guard let windows = appElement.windows(), !windows.isEmpty else {
            throw CaptureError.windowNotFound
        }

        // Find specific window if criteria provided
        let targetWindow: Element
        if let title = options.windowTitle {
            // Find by title (partial match)
            guard let window = windows.first(where: { window in
                if let windowTitle = window.title() {
                    return windowTitle.localizedCaseInsensitiveContains(title)
                }
                return false
            }) else {
                throw CaptureError.windowNotFound
            }
            targetWindow = window
        } else if let index = options.windowIndex {
            // Find by index
            guard index >= 0, index < windows.count else {
                throw CaptureError.windowNotFound
            }
            targetWindow = windows[index]
        } else {
            // Default to frontmost window
            targetWindow = windows[0]
        }

        return (app, targetWindow)

    } else if let sessionId = options.session, let elementId = options.element {
        // Load session and find element
        let sessionCache = try SessionCache(sessionId: sessionId, createIfNeeded: false)

        guard let sessionData = await sessionCache.load() else {
            throw CaptureError.invalidArgument("Session \(sessionId) has no data")
        }

        // Find window element - windows have elementIds like W1, W2, etc.
        guard let windowElement = sessionData.uiMap.values
            .first(where: { $0.id == elementId && $0.role == "AXWindow" })
        else {
            throw CaptureError.invalidArgument("Element \(elementId) not found or is not a window")
        }

        // Get app info - use the sessionData's applicationName
        guard let appName = sessionData.applicationName,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: appName).first ??
              NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName })
        else {
            throw CaptureError.appNotFound("\(sessionData.applicationName ?? "Unknown") not found")
        }

        // Recreate AX element from the running app
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)

        // Find the window by matching properties
        guard let windows = appElement.windows(),
              let window = windows.first(where: { window in
                  // Match by title and bounds
                  if let title = window.title(),
                     title == windowElement.title,
                     let pos = window.position(),
                     let size = window.size()
                  {
                      let bounds = CGRect(x: pos.x, y: pos.y, width: size.width, height: size.height)
                      return abs(bounds.origin.x - windowElement.frame.origin.x) < 1 &&
                          abs(bounds.origin.y - windowElement.frame.origin.y) < 1
                  }
                  return false
              })
        else {
            throw CaptureError.windowNotFound
        }

        return (app, window)
    } else {
        throw CaptureError.invalidArgument("Invalid window identification options")
    }
}

// MARK: - Subcommands

struct CloseSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "close",
        abstract: "Close a window")

    @OptionGroup var windowOptions: WindowIdentificationOptions

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    @MainActor func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let (app, window) = try await findTargetWindow(options: windowOptions)

            // Try to find the close button
            if let closeButton = window.closeButton() {
                // Press the close button
                try closeButton.performAction(.press)

                let data = WindowActionResult(
                    action: "close",
                    success: true,
                    app_name: app.localizedName ?? "Unknown",
                    window_title: window.title())

                if self.jsonOutput {
                    outputSuccess(data: data)
                } else {
                    print("Successfully closed window '\(data.window_title ?? "Untitled")' of \(data.app_name)")
                }
            } else {
                // Fallback: try to perform close action on the window itself
                let supportedActions = window.supportedActions() ?? []
                if supportedActions.contains("AXClose") {
                    try window.performAction("AXClose")

                    let data = WindowActionResult(
                        action: "close",
                        success: true,
                        app_name: app.localizedName ?? "Unknown",
                        window_title: window.title())

                    if self.jsonOutput {
                        outputSuccess(data: data)
                    } else {
                        print("Successfully closed window '\(data.window_title ?? "Untitled")' of \(data.app_name)")
                    }
                } else {
                    throw CaptureError.invalidArgument("Window does not support close action")
                }
            }

        } catch {
            self.handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        let captureError = error as? CaptureError ?? .unknownError(error.localizedDescription)

        if self.jsonOutput {
            outputError(
                message: captureError.localizedDescription,
                code: .WINDOW_MANIPULATION_ERROR,
                details: "Failed to close window")
        } else {
            fputs("Error: \(captureError.localizedDescription)\n", stderr)
        }
        Foundation.exit(1)
    }
}

struct MinimizeSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "minimize",
        abstract: "Minimize a window to the Dock")

    @OptionGroup var windowOptions: WindowIdentificationOptions

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    @MainActor func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let (app, window) = try await findTargetWindow(options: windowOptions)

            // Try to find the minimize button
            if let minimizeButton = window.minimizeButton() {
                // Press the minimize button
                try minimizeButton.performAction(.press)

                let data = WindowActionResult(
                    action: "minimize",
                    success: true,
                    app_name: app.localizedName ?? "Unknown",
                    window_title: window.title())

                if self.jsonOutput {
                    outputSuccess(data: data)
                } else {
                    print("Successfully minimized window '\(data.window_title ?? "Untitled")' of \(data.app_name)")
                }
            } else {
                // Fallback: try to set minimized attribute
                let error = window.setMinimized(true)
                if error == .success {
                    let data = WindowActionResult(
                        action: "minimize",
                        success: true,
                        app_name: app.localizedName ?? "Unknown",
                        window_title: window.title())

                    if self.jsonOutput {
                        outputSuccess(data: data)
                    } else {
                        print("Successfully minimized window '\(data.window_title ?? "Untitled")' of \(data.app_name)")
                    }
                } else {
                    throw CaptureError.invalidArgument("Failed to minimize window: \(error)")
                }
            }

        } catch {
            self.handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        let captureError = error as? CaptureError ?? .unknownError(error.localizedDescription)

        if self.jsonOutput {
            outputError(
                message: captureError.localizedDescription,
                code: .WINDOW_MANIPULATION_ERROR,
                details: "Failed to minimize window")
        } else {
            fputs("Error: \(captureError.localizedDescription)\n", stderr)
        }
        Foundation.exit(1)
    }
}

struct MaximizeSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "maximize",
        abstract: "Maximize a window (full screen)")

    @OptionGroup var windowOptions: WindowIdentificationOptions

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    @MainActor func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let (app, window) = try await findTargetWindow(options: windowOptions)

            // Try to find the zoom/maximize button
            if let zoomButton = window.zoomButton() {
                // Press the zoom button
                try zoomButton.performAction(.press)

                let data = WindowActionResult(
                    action: "maximize",
                    success: true,
                    app_name: app.localizedName ?? "Unknown",
                    window_title: window.title())

                if self.jsonOutput {
                    outputSuccess(data: data)
                } else {
                    print("Successfully maximized window '\(data.window_title ?? "Untitled")' of \(data.app_name)")
                }
            } else if let fullScreenButton = window.fullScreenButton() {
                // Try full screen button
                try fullScreenButton.performAction(.press)

                let data = WindowActionResult(
                    action: "maximize",
                    success: true,
                    app_name: app.localizedName ?? "Unknown",
                    window_title: window.title())

                if self.jsonOutput {
                    outputSuccess(data: data)
                } else {
                    print("Successfully maximized window '\(data.window_title ?? "Untitled")' of \(data.app_name)")
                }
            } else {
                // Fallback: try to set full screen attribute
                let error = window.setFullScreen(true)
                if error == .success {
                    let data = WindowActionResult(
                        action: "maximize",
                        success: true,
                        app_name: app.localizedName ?? "Unknown",
                        window_title: window.title())

                    if self.jsonOutput {
                        outputSuccess(data: data)
                    } else {
                        print("Successfully maximized window '\(data.window_title ?? "Untitled")' of \(data.app_name)")
                    }
                } else {
                    throw CaptureError.invalidArgument("Failed to maximize window: \(error)")
                }
            }

        } catch {
            self.handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        let captureError = error as? CaptureError ?? .unknownError(error.localizedDescription)

        if self.jsonOutput {
            outputError(
                message: captureError.localizedDescription,
                code: .WINDOW_MANIPULATION_ERROR,
                details: "Failed to maximize window")
        } else {
            fputs("Error: \(captureError.localizedDescription)\n", stderr)
        }
        Foundation.exit(1)
    }
}

struct MoveSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "move",
        abstract: "Move a window to a new position")

    @OptionGroup var windowOptions: WindowIdentificationOptions

    @Option(name: .long, help: "New X coordinate")
    var x: Int

    @Option(name: .long, help: "New Y coordinate")
    var y: Int

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    @MainActor func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let (app, window) = try await findTargetWindow(options: windowOptions)

            let newPosition = CGPoint(x: x, y: y)
            let error = window.setPosition(newPosition)

            if error == .success {
                let data = WindowActionResult(
                    action: "move",
                    success: true,
                    app_name: app.localizedName ?? "Unknown",
                    window_title: window.title(),
                    new_bounds: WindowBounds(
                        x: self.x,
                        y: self.y,
                        width: Int(window.size()?.width ?? 0),
                        height: Int(window.size()?.height ?? 0)))

                if self.jsonOutput {
                    outputSuccess(data: data)
                } else {
                    print(
                        "Successfully moved window '\(data.window_title ?? "Untitled")' of \(data.app_name) to (\(self.x), \(self.y))")
                }
            } else {
                throw CaptureError.invalidArgument("Failed to move window: \(error)")
            }

        } catch {
            self.handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        let captureError = error as? CaptureError ?? .unknownError(error.localizedDescription)

        if self.jsonOutput {
            outputError(
                message: captureError.localizedDescription,
                code: .WINDOW_MANIPULATION_ERROR,
                details: "Failed to move window")
        } else {
            fputs("Error: \(captureError.localizedDescription)\n", stderr)
        }
        Foundation.exit(1)
    }
}

struct ResizeSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "resize",
        abstract: "Resize a window")

    @OptionGroup var windowOptions: WindowIdentificationOptions

    @Option(name: .long, help: "New width")
    var width: Int

    @Option(name: .long, help: "New height")
    var height: Int

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    @MainActor func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let (app, window) = try await findTargetWindow(options: windowOptions)

            let newSize = CGSize(width: width, height: height)
            let error = window.setSize(newSize)

            if error == .success {
                let data = WindowActionResult(
                    action: "resize",
                    success: true,
                    app_name: app.localizedName ?? "Unknown",
                    window_title: window.title(),
                    new_bounds: WindowBounds(
                        x: Int(window.position()?.x ?? 0),
                        y: Int(window.position()?.y ?? 0),
                        width: self.width,
                        height: self.height))

                if self.jsonOutput {
                    outputSuccess(data: data)
                } else {
                    print(
                        "Successfully resized window '\(data.window_title ?? "Untitled")' of \(data.app_name) to \(self.width)×\(self.height)")
                }
            } else {
                throw CaptureError.invalidArgument("Failed to resize window: \(error)")
            }

        } catch {
            self.handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        let captureError = error as? CaptureError ?? .unknownError(error.localizedDescription)

        if self.jsonOutput {
            outputError(
                message: captureError.localizedDescription,
                code: .WINDOW_MANIPULATION_ERROR,
                details: "Failed to resize window")
        } else {
            fputs("Error: \(captureError.localizedDescription)\n", stderr)
        }
        Foundation.exit(1)
    }
}

struct SetBoundsSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set-bounds",
        abstract: "Set window position and size in one operation")

    @OptionGroup var windowOptions: WindowIdentificationOptions

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

    @MainActor func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let (app, window) = try await findTargetWindow(options: windowOptions)

            // Set position first
            let newPosition = CGPoint(x: x, y: y)
            var error = window.setPosition(newPosition)

            if error == .success {
                // Then set size
                let newSize = CGSize(width: width, height: height)
                error = window.setSize(newSize)

                if error == .success {
                    let data = WindowActionResult(
                        action: "set-bounds",
                        success: true,
                        app_name: app.localizedName ?? "Unknown",
                        window_title: window.title(),
                        new_bounds: WindowBounds(x: self.x, y: self.y, width: self.width, height: self.height))

                    if self.jsonOutput {
                        outputSuccess(data: data)
                    } else {
                        print(
                            "Successfully set bounds for window '\(data.window_title ?? "Untitled")' of \(data.app_name)")
                        print("New bounds: (\(self.x), \(self.y)) \(self.width)×\(self.height)")
                    }
                } else {
                    throw CaptureError.invalidArgument("Failed to resize window: \(error)")
                }
            } else {
                throw CaptureError.invalidArgument("Failed to move window: \(error)")
            }

        } catch {
            self.handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        let captureError = error as? CaptureError ?? .unknownError(error.localizedDescription)

        if self.jsonOutput {
            outputError(
                message: captureError.localizedDescription,
                code: .WINDOW_MANIPULATION_ERROR,
                details: "Failed to set window bounds")
        } else {
            fputs("Error: \(captureError.localizedDescription)\n", stderr)
        }
        Foundation.exit(1)
    }
}

struct FocusSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "focus",
        abstract: "Bring a window to the foreground")

    @OptionGroup var windowOptions: WindowIdentificationOptions

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    @MainActor func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            try self.windowOptions.validate()
            let (app, window) = try await findTargetWindow(options: windowOptions)

            // First, activate the application
            app.activate()

            // Then raise the window
            let supportedActions = window.supportedActions() ?? []
            if supportedActions.contains(AXActionNames.kAXRaiseAction) {
                try window.performAction(.raise)
            }

            let data = WindowActionResult(
                action: "focus",
                success: true,
                app_name: app.localizedName ?? "Unknown",
                window_title: window.title())

            if self.jsonOutput {
                outputSuccess(data: data)
            } else {
                print("Successfully focused window '\(data.window_title ?? "Untitled")' of \(data.app_name)")
            }

        } catch {
            self.handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        let captureError = error as? CaptureError ?? .unknownError(error.localizedDescription)

        if self.jsonOutput {
            outputError(
                message: captureError.localizedDescription,
                code: .WINDOW_MANIPULATION_ERROR,
                details: "Failed to focus window")
        } else {
            fputs("Error: \(captureError.localizedDescription)\n", stderr)
        }
        Foundation.exit(1)
    }
}

struct WindowListSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List windows for an application (convenience shortcut)")

    @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
    var app: String

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    @MainActor func run() async throws {
        // Delegate to the existing list windows command
        var listCommand = WindowsSubcommand()
        listCommand.app = self.app
        listCommand.jsonOutput = self.jsonOutput
        listCommand.includeDetails = "bounds,ids"
        try await listCommand.run()
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
