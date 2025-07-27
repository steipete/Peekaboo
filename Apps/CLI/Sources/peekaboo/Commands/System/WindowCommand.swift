import AppKit
import ArgumentParser
import CoreGraphics
import Foundation
import PeekabooCore

/// Manipulate application windows with various actions
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

    func validate() throws {
        // Ensure we have some way to identify the window
        if self.app == nil {
            throw ValidationError("--app must be specified")
        }
    }

    /// Convert to WindowTarget for service layer
    func toWindowTarget() -> WindowTarget {
        if let app {
            if let index = windowIndex {
                .index(app: app, index: index)
            } else if self.windowTitle != nil {
                // For title matching, we still need the app context
                // The service will handle finding the right window
                .application(app)
            } else {
                // Default to app's frontmost window
                .application(app)
            }
        } else {
            // Should not reach here due to validation
            .frontmost
        }
    }
}

// MARK: - Helper Functions

private func createWindowActionResult(
    action: String,
    success: Bool,
    windowInfo: ServiceWindowInfo?,
    appName: String? = nil) -> WindowActionResult
{
    let bounds: WindowBounds? = if let windowInfo {
        WindowBounds(
            x: Int(windowInfo.bounds.origin.x),
            y: Int(windowInfo.bounds.origin.y),
            width: Int(windowInfo.bounds.size.width),
            height: Int(windowInfo.bounds.size.height))
    } else {
        nil
    }

    return WindowActionResult(
        action: action,
        success: success,
        app_name: appName ?? "Unknown",
        window_title: windowInfo?.title,
        new_bounds: bounds)
}

// MARK: - Base Window Command

/// Base class for window manipulation commands
class WindowManipulationCommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    @OptionGroup var windowOptions: WindowIdentificationOptions
    
    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false
    
    /// The action name for result reporting
    var actionName: String { "" }
    
    /// Perform the window manipulation
    func performAction(target: WindowTarget) async throws {
        // Subclasses override this
    }
    
    /// Create success message for human output
    func createSuccessMessage(windowInfo: ServiceWindowInfo?, appName: String) -> String {
        "Successfully performed \(actionName) on window '\(windowInfo?.title ?? "Untitled")' of \(appName)"
    }
    
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)
        
        do {
            try self.windowOptions.validate()
            let target = self.windowOptions.toWindowTarget()
            
            // Get window info before action
            let windows = try await PeekabooServices.shared.windows.listWindows(target: target)
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            let appName = self.windowOptions.app ?? "Unknown"
            
            // Perform the action
            try await performAction(target: self.windowOptions.createTarget())
            
            let data = createWindowActionResult(
                action: actionName,
                success: true,
                windowInfo: windowInfo,
                appName: appName)
            
            output(data) {
                print(createSuccessMessage(windowInfo: windowInfo, appName: appName))
            }
            
        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
}

// MARK: - Subcommands

final class CloseSubcommand: WindowManipulationCommand {
    static let configuration = CommandConfiguration(
        commandName: "close",
        abstract: "Close a window")
    
    override var actionName: String { "close" }
    
    override func performAction(target: WindowTarget) async throws {
        try await PeekabooServices.shared.windows.closeWindow(target: target)
    }
    
    override func createSuccessMessage(windowInfo: ServiceWindowInfo?, appName: String) -> String {
        "Successfully closed window '\(windowInfo?.title ?? "Untitled")' of \(appName)"
    }
}

final class MinimizeSubcommand: WindowManipulationCommand {
    static let configuration = CommandConfiguration(
        commandName: "minimize",
        abstract: "Minimize a window to the Dock")
    
    override var actionName: String { "minimize" }
    
    override func performAction(target: WindowTarget) async throws {
        try await PeekabooServices.shared.windows.minimizeWindow(target: target)
    }
    
    override func createSuccessMessage(windowInfo: ServiceWindowInfo?, appName: String) -> String {
        "Successfully minimized window '\(windowInfo?.title ?? "Untitled")' of \(appName)"
    }
}

final class MaximizeSubcommand: WindowManipulationCommand {
    static let configuration = CommandConfiguration(
        commandName: "maximize",
        abstract: "Maximize a window (full screen)")
    
    override var actionName: String { "maximize" }
    
    override func performAction(target: WindowTarget) async throws {
        try await PeekabooServices.shared.windows.maximizeWindow(target: target)
    }
    
    override func createSuccessMessage(windowInfo: ServiceWindowInfo?, appName: String) -> String {
        "Successfully maximized window '\(windowInfo?.title ?? "Untitled")' of \(appName)"
    }
}

final class FocusSubcommand: WindowManipulationCommand {
    static let configuration = CommandConfiguration(
        commandName: "focus",
        abstract: "Bring a window to the foreground")
    
    override var actionName: String { "focus" }
    
    override func performAction(target: WindowTarget) async throws {
        try await PeekabooServices.shared.windows.focusWindow(target: target)
    }
    
    override func createSuccessMessage(windowInfo: ServiceWindowInfo?, appName: String) -> String {
        "Successfully focused window '\(windowInfo?.title ?? "Untitled")' of \(appName)"
    }
}

// MARK: - Move Command

struct MoveSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "move",
        abstract: "Move a window to a new position")
    
    @OptionGroup var windowOptions: WindowIdentificationOptions
    
    @Option(name: .short, help: "New X coordinate")
    var x: Int
    
    @Option(name: .short, help: "New Y coordinate")
    var y: Int
    
    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false
    
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)
        
        do {
            try self.windowOptions.validate()
            let target = self.windowOptions.createTarget()
            
            // Get window info
            let windows = try await PeekabooServices.shared.windows.listWindows(target: self.windowOptions.toWindowTarget())
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            let appName = self.windowOptions.app ?? "Unknown"
            
            // Move the window
            let newOrigin = CGPoint(x: x, y: y)
            try await PeekabooServices.shared.windows.moveWindow(target: target, to: newOrigin)
            
            // Create result with new bounds
            var updatedInfo = windowInfo
            updatedInfo?.bounds.origin = newOrigin
            
            let data = createWindowActionResult(
                action: "move",
                success: true,
                windowInfo: updatedInfo,
                appName: appName)
            
            output(data) {
                print("Successfully moved window '\(windowInfo?.title ?? "Untitled")' to (\(x), \(y))")
            }
            
        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
}

// MARK: - Resize Command

struct ResizeSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "resize",
        abstract: "Resize a window")
    
    @OptionGroup var windowOptions: WindowIdentificationOptions
    
    @Option(name: .short, help: "New width")
    var width: Int
    
    @Option(name: .long, help: "New height")
    var height: Int
    
    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false
    
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)
        
        do {
            try self.windowOptions.validate()
            let target = self.windowOptions.createTarget()
            
            // Get window info
            let windows = try await PeekabooServices.shared.windows.listWindows(target: self.windowOptions.toWindowTarget())
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            let appName = self.windowOptions.app ?? "Unknown"
            
            // Resize the window
            let newSize = CGSize(width: width, height: height)
            try await PeekabooServices.shared.windows.resizeWindow(target: target, to: newSize)
            
            // Create result with new bounds
            var updatedInfo = windowInfo
            updatedInfo?.bounds.size = newSize
            
            let data = createWindowActionResult(
                action: "resize",
                success: true,
                windowInfo: updatedInfo,
                appName: appName)
            
            output(data) {
                print("Successfully resized window '\(windowInfo?.title ?? "Untitled")' to \(width)x\(height)")
            }
            
        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
}

// MARK: - Set Bounds Command

struct SetBoundsSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "set-bounds",
        abstract: "Set window position and size in one operation")
    
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
    
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)
        
        do {
            try self.windowOptions.validate()
            let target = self.windowOptions.createTarget()
            
            // Get window info
            let windows = try await PeekabooServices.shared.windows.listWindows(target: self.windowOptions.toWindowTarget())
            let windowInfo = self.windowOptions.selectWindow(from: windows)
            let appName = self.windowOptions.app ?? "Unknown"
            
            // Set bounds
            let newBounds = CGRect(x: x, y: y, width: width, height: height)
            try await PeekabooServices.shared.windows.setWindowBounds(target: target, bounds: newBounds)
            
            // Create result with new bounds
            var updatedInfo = windowInfo
            updatedInfo?.bounds = newBounds
            
            let data = createWindowActionResult(
                action: "set-bounds",
                success: true,
                windowInfo: updatedInfo,
                appName: appName)
            
            output(data) {
                print("Successfully set window '\(windowInfo?.title ?? "Untitled")' bounds to (\(x), \(y)) \(width)x\(height)")
            }
            
        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
}

// MARK: - List Command

struct WindowListSubcommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List windows for an application")
    
    @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345'")
    var app: String
    
    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false
    
    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)
        
        do {
            let target = WindowTarget.application(app)
            let windows = try await PeekabooServices.shared.windows.listWindows(target: target)
            
            let windowListData = windows.enumerated().map { index, window in
                WindowListItem(
                    index: index,
                    title: window.title,
                    bounds: WindowBounds(
                        x: Int(window.bounds.origin.x),
                        y: Int(window.bounds.origin.y),
                        width: Int(window.bounds.size.width),
                        height: Int(window.bounds.size.height)
                    ),
                    is_minimized: window.isMinimized,
                    is_fullscreen: window.isFullscreen
                )
            }
            
            let data = WindowListData(
                app_name: app,
                window_count: windows.count,
                windows: windowListData
            )
            
            output(data) {
                print("\(app) has \(windows.count) window(s):")
                for (index, window) in windows.enumerated() {
                    let status = window.isMinimized ? " [minimized]" : window.isFullscreen ? " [fullscreen]" : ""
                    print("  [\(index)] \"\(window.title)\"\(status)")
                    print("       Position: (\(Int(window.bounds.origin.x)), \(Int(window.bounds.origin.y)))")
                    print("       Size: \(Int(window.bounds.size.width))x\(Int(window.bounds.size.height))")
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

struct WindowBounds: Codable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

struct WindowListData: Codable {
    let app_name: String
    let window_count: Int
    let windows: [WindowListItem]
}

struct WindowListItem: Codable {
    let index: Int
    let title: String
    let bounds: WindowBounds
    let is_minimized: Bool
    let is_fullscreen: Bool
}