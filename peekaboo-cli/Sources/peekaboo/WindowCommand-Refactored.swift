// Example of how WindowCommand would be refactored with new AXorcist APIs

import ArgumentParser
import Foundation
import ApplicationServices
import AXorcist

struct WindowCommandRefactored: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "window",
        abstract: "Manipulate application windows",
        subcommands: [
            CloseSubcommand.self,
            MinimizeSubcommand.self,
            // ... other subcommands
        ]
    )
}

// MARK: - Close Subcommand (Refactored)

extension WindowCommandRefactored {
    struct CloseSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "close",
            abstract: "Close a window"
        )
        
        @OptionGroup var options: WindowIdentificationOptions
        @Flag var jsonOutput = false
        
        @MainActor
        mutating func run() async throws {
            do {
                let window = try await findTargetWindowRefactored(options: options)
                
                // NEW: Use WindowController instead of manual button finding
                let controller = window.windowController()
                try await controller.close()
                
                if jsonOutput {
                    let data = WindowActionResult(
                        action: "close",
                        success: true,
                        window: window.title() ?? "Unknown",
                        app: options.app ?? "Unknown"
                    )
                    outputJSON(JSONResponse(success: true, data: AnyCodable(data)))
                } else {
                    print("✓ Closed window: \(window.title() ?? "Unknown")")
                }
                
            } catch let error as WindowError {
                handleWindowError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
            }
        }
    }
}

// MARK: - Refactored Window Finding

@MainActor
private func findTargetWindowRefactored(options: WindowIdentificationOptions) async throws -> Element {
    if let appIdentifier = options.app {
        let app = try ApplicationFinder.findApplication(identifier: appIdentifier)
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)
        
        // NEW: Use query API instead of manual iteration
        var query = appElement.query().role("AXWindow")
        
        if let title = options.windowTitle {
            query = query.titleContains(title)
        }
        
        let windows = query.findAll()
        
        if windows.isEmpty {
            throw CaptureError.windowNotFound
        }
        
        if let index = options.windowIndex {
            guard index < windows.count else {
                throw CaptureError.windowNotFound
            }
            return windows[index]
        }
        
        return windows[0] // Return frontmost
        
    } else if let sessionId = options.session, let elementId = options.element {
        // Session-based lookup remains similar but could use state validation
        let sessionCache = try SessionCache(sessionId: sessionId)
        guard let sessionData = await sessionCache.load() else {
            throw CaptureError.invalidArgument("Session \(sessionId) has no data")
        }
        
        // Find window element
        guard let windowData = sessionData.uiMap.values.first(where: { 
            $0.id == elementId && $0.role == "AXWindow" 
        }) else {
            throw CaptureError.invalidArgument("Element \(elementId) not found or is not a window")
        }
        
        // Recreate window element
        guard let appName = sessionData.applicationName,
              let app = NSWorkspace.shared.runningApplications.first(where: { 
                  $0.localizedName == appName || $0.bundleIdentifier == appName 
              }) else {
            throw CaptureError.appNotFound("\(sessionData.applicationName ?? "Unknown")")
        }
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)
        
        // NEW: Use query to find matching window
        let window = appElement.query()
            .role("AXWindow")
            .custom { element in
                if let pos = element.position(),
                   let size = element.size() {
                    let bounds = CGRect(x: pos.x, y: pos.y, width: size.width, height: size.height)
                    return abs(bounds.origin.x - windowData.frame.origin.x) < 1 &&
                           abs(bounds.origin.y - windowData.frame.origin.y) < 1
                }
                return false
            }
            .first()
        
        guard let foundWindow = window else {
            throw CaptureError.windowNotFound
        }
        
        // NEW: Validate window is actionable
        try await foundWindow.waitUntilActionable()
        
        return foundWindow
    }
    
    throw CaptureError.invalidArgument("Must specify either --app or --session/--element")
}