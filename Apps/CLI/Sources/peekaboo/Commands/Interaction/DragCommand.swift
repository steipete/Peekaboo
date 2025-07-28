import AppKit
import ArgumentParser
import AXorcist
import CoreGraphics
import Foundation
import PeekabooCore

/// Perform drag and drop operations using intelligent element finding
@available(macOS 14.0, *)
struct DragCommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "drag",
        abstract: "Perform drag and drop operations",
        discussion: """
        Execute click-and-drag operations for moving elements, selecting text, or dragging files.

        EXAMPLES:
          # Drag between UI elements
          peekaboo drag --from B1 --to T2

          # Drag with coordinates
          peekaboo drag --from-coords "100,200" --to-coords "400,300"

          # Drag to an application
          peekaboo drag --from B1 --to-app Trash

          # Slow drag for precise operations
          peekaboo drag --from S1 --to-coords "500,250" --duration 2000

          # Multi-select with modifier keys
          peekaboo drag --from T1 --to T5 --modifiers shift
        """,
        version: "2.0.0")

    @Option(help: "Starting element ID from session")
    var from: String?

    @Option(help: "Starting coordinates as 'x,y'")
    var fromCoords: String?

    @Option(help: "Target element ID from session")
    var to: String?

    @Option(help: "Target coordinates as 'x,y'")
    var toCoords: String?

    @Option(help: "Target application (e.g., 'Trash', 'Finder')")
    var toApp: String?

    @Option(help: "Session ID for element resolution")
    var session: String?

    @Option(help: "Duration of drag in milliseconds (default: 500)")
    var duration: Int = 500

    @Option(help: "Number of intermediate steps (default: 20)")
    var steps: Int = 20

    @Option(help: "Modifier keys to hold during drag (comma-separated: cmd,shift,option,ctrl)")
    var modifiers: String?

    @Flag(help: "Output in JSON format")
    var jsonOutput = false
    
    @OptionGroup var focusOptions: FocusOptions

    mutating func run() async throws {
        let startTime = Date()
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            // Validate inputs
            guard self.from != nil || self.fromCoords != nil else {
                throw ArgumentParser.ValidationError("Must specify either --from or --from-coords")
            }

            guard self.to != nil || self.toCoords != nil || self.toApp != nil else {
                throw ArgumentParser.ValidationError("Must specify either --to, --to-coords, or --to-app")
            }

            // Determine session ID - use provided or get most recent
            let sessionId: String? = if let providedSession = session {
                providedSession
            } else {
                await PeekabooServices.shared.sessions.getMostRecentSession()
            }
            
            // Ensure window is focused before dragging (if we have a session and auto-focus is enabled)
            if let sessionId = sessionId {
                try await self.ensureFocused(
                    sessionId: sessionId,
                    options: focusOptions
                )
            }

            // Resolve starting point
            let startPoint = try await resolvePoint(
                elementId: from,
                coords: fromCoords,
                sessionId: sessionId,
                description: "from",
                waitTimeout: 5.0)

            // Resolve ending point
            let endPoint: CGPoint = if let targetApp = toApp {
                // Find application window or dock item
                try await self.findApplicationPoint(targetApp)
            } else {
                try await self.resolvePoint(
                    elementId: self.to,
                    coords: self.toCoords,
                    sessionId: sessionId,
                    description: "to",
                    waitTimeout: 5.0)
            }

            // Perform the drag using UIAutomationService
            try await PeekabooServices.shared.automation.drag(
                from: startPoint,
                to: endPoint,
                duration: self.duration,
                steps: self.steps,
                modifiers: self.modifiers)

            // Small delay to ensure drag is processed
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Output results
            let result = DragResult(
                success: true,
                from: ["x": Int(startPoint.x), "y": Int(startPoint.y)],
                to: ["x": Int(endPoint.x), "y": Int(endPoint.y)],
                duration: self.duration,
                steps: self.steps,
                modifiers: self.modifiers ?? "none",
                executionTime: Date().timeIntervalSince(startTime))
                
            output(result) {
                print("✅ Drag successful")
                print("📍 From: (\(Int(startPoint.x)), \(Int(startPoint.y)))")
                print("📍 To: (\(Int(endPoint.x)), \(Int(endPoint.y)))")
                print("⏱️  Duration: \(self.duration)ms with \(self.steps) steps")
                if let mods = modifiers {
                    print("⌨️  Modifiers: \(mods)")
                }
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            self.handleError(error)
            throw ExitCode.failure
        }
    }

    @MainActor
    private func resolvePoint(
        elementId: String?,
        coords: String?,
        sessionId: String?,
        description: String,
        waitTimeout: TimeInterval) async throws -> CGPoint
    {
        if let coordString = coords {
            // Parse coordinates
            let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2,
                  let x = Double(parts[0]),
                  let y = Double(parts[1])
            else {
                throw ArgumentParser.ValidationError("Invalid coordinates format: '\(coordString)'. Expected 'x,y'")
            }
            return CGPoint(x: x, y: y)
        } else if let element = elementId, let activeSessionId = sessionId {
            // Resolve from session using waitForElement
            let target = ClickTarget.elementId(element)
            let waitResult = try await PeekabooServices.shared.automation.waitForElement(
                target: target,
                timeout: waitTimeout,
                sessionId: activeSessionId)

            if !waitResult.found {
                throw PeekabooError.elementNotFound("Element with ID '\(element)' not found")
            }

            guard let foundElement = waitResult.element else {
                throw PeekabooError.clickFailed("Element '\(element)' found but has no bounds")
            }

            // Return center of element
            return CGPoint(
                x: foundElement.bounds.origin.x + foundElement.bounds.width / 2,
                y: foundElement.bounds.origin.y + foundElement.bounds.height / 2)
        } else if elementId != nil {
            throw ArgumentParser.ValidationError("Session ID required when using element IDs")
        } else {
            throw ArgumentParser.ValidationError("No \(description) point specified")
        }
    }

    @MainActor
    private func findApplicationPoint(_ appName: String) async throws -> CGPoint {
        // Special handling for Trash
        if appName.lowercased() == "trash" {
            // Find Dock and locate Trash
            if let dock = findDockApplication() {
                if let dockList = dock.children()?.first(where: { $0.role() == "AXList" }) {
                    let items = dockList.children() ?? []

                    // Trash is typically the last item
                    if let trash = items.last {
                        if let position = trash.position(),
                           let size = trash.size()
                        {
                            return CGPoint(
                                x: position.x + size.width / 2,
                                y: position.y + size.height / 2)
                        }
                    }
                }
            }
            throw PeekabooError.appNotFound("Trash")
        }

        // Try to find application window using ApplicationService
        do {
            _ = try await PeekabooServices.shared.applications.findApplication(identifier: appName)
            let windows = try await PeekabooServices.shared.applications.listWindows(for: appName)

            if let firstWindow = windows.first {
                // Return center of window
                return CGPoint(
                    x: firstWindow.bounds.origin.x + firstWindow.bounds.width / 2,
                    y: firstWindow.bounds.origin.y + firstWindow.bounds.height / 2)
            }

            throw PeekabooError.windowNotFound(criteria: "No window found for application '\(appName)'")
        } catch {
            // If not found as running app, try dock
            if let dock = findDockApplication() {
                if let dockList = dock.children()?.first(where: { $0.role() == "AXList" }) {
                    let items = dockList.children() ?? []

                    if let appItem = items.first(where: { item in
                        item.title() == appName ||
                            item.title()?.contains(appName) == true
                    }) {
                        if let position = appItem.position(),
                           let size = appItem.size()
                        {
                            return CGPoint(
                                x: position.x + size.width / 2,
                                y: position.y + size.height / 2)
                        }
                    }
                }
            }

            throw PeekabooError.appNotFound(appName)
        }
    }

    @MainActor
    private func findDockApplication() -> Element? {
        let workspace = NSWorkspace.shared
        guard let dockApp = workspace.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.dock"
        }) else {
            return nil
        }

        return Element(AXUIElementCreateApplication(dockApp.processIdentifier))
    }

    // Error handling is provided by ErrorHandlingCommand protocol
}

// MARK: - JSON Output Structure

struct DragResult: Codable {
    let success: Bool
    let from: [String: Int]
    let to: [String: Int]
    let duration: Int
    let steps: Int
    let modifiers: String
    let executionTime: TimeInterval
}
