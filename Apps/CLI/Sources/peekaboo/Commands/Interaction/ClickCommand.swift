import AppKit
import ArgumentParser
import CoreGraphics
import Foundation
import PeekabooCore

/// Click on UI elements identified in the current session using intelligent element finding and smart waiting.
@available(macOS 14.0, *)
struct ClickCommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "click",
        abstract: "Click on UI elements or coordinates",
        discussion: """
            The 'click' command interacts with UI elements captured by 'see'.
            It supports intelligent element finding, actionability checks, and
            automatic waiting for elements to become available.

            FEATURES:
              • Fuzzy matching - Partial text and case-insensitive search
              • Smart waiting - Automatically waits for elements to appear
              • Helpful errors - Clear guidance when elements aren't found
              • Menu bar support - Works with menu bar items

            EXAMPLES:
              peekaboo click "Sign In"              # Click button with text
              peekaboo click "sign"                 # Partial match (fuzzy)
              peekaboo click --id element_42        # Click specific element ID
              peekaboo click --coords 100,200       # Click at coordinates
              peekaboo click "Submit" --wait-for 5000  # Wait up to 5s for element
              peekaboo click "Menu" --double        # Double-click
              peekaboo click "File" --right         # Right-click

            ELEMENT MATCHING:
              Elements are matched by searching text in:
              - Title/Label content (case-insensitive)
              - Value text (partial matching)
              - Role descriptions

              Use --id for precise element targeting from 'see' output.
              
            TROUBLESHOOTING:
              If elements aren't found:
              - Run 'peekaboo see' first to capture the UI
              - Use 'peekaboo menubar list' for menu bar items
              - Try partial text matching
              - Increase --wait-for timeout
        """
    )

    @Argument(help: "Element text or query to click")
    var query: String?

    @Option(help: "Session ID (uses latest if not specified)")
    var session: String?

    @Option(help: "Element ID to click (e.g., B1, T2)")
    var on: String?

    @Option(name: .customLong("id"), help: "Element ID to click (alias for --on)")
    var id: String?

    @Option(help: "Application name to focus before clicking")
    var app: String?

    @Option(help: "Click at coordinates (x,y)")
    var coords: String?

    @Option(help: "Maximum milliseconds to wait for element")
    var waitFor: Int = 5000

    @Flag(help: "Double-click instead of single click")
    var double = false

    @Flag(help: "Right-click (secondary click)")
    var right = false

    @Flag(help: "Output in JSON format")
    var jsonOutput = false

    @OptionGroup var focusOptions: FocusOptions

    mutating func run() async throws {
        let startTime = Date()
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            // Determine click target first to check if we need a session
            let clickTarget: ClickTarget
            let waitResult: WaitForElementResult
            let activeSessionId: String

            // Check if we're clicking by coordinates (doesn't need session)
            if let coordString = coords {
                // Click by coordinates (no session needed)
                let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2,
                      let x = Double(parts[0]),
                      let y = Double(parts[1])
                else {
                    throw ArgumentParser.ValidationError("Invalid coordinates format. Use: x,y")
                }
                clickTarget = .coordinates(CGPoint(x: x, y: y))
                waitResult = WaitForElementResult(found: true, element: nil, waitTime: 0)
                activeSessionId = "" // Not needed for coordinate clicks

            } else {
                // For element-based clicks, try to get a session but allow fallback
                let sessionId: String? = if let providedSession = session {
                    providedSession
                } else {
                    await PeekabooServices.shared.sessions.getMostRecentSession()
                }
                // Use session if available, otherwise use empty string to indicate no session
                activeSessionId = sessionId ?? ""

                // If app is specified, focus it first
                if let appName = app {
                    // Focus the specified app
                    try await PeekabooServices.shared.windows.focusWindow(target: .application(appName))
                    // Brief delay to ensure focus is complete
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }

                // Ensure window is focused before clicking (if auto-focus is enabled)
                try await self.ensureFocused(
                    sessionId: activeSessionId,
                    options: self.focusOptions
                )

                // Check if both --on and --id are specified
                if self.on != nil && self.id != nil {
                    throw ArgumentParser.ValidationError("Cannot specify both --on and --id")
                }

                // Use whichever element ID parameter was provided
                let elementId = self.on ?? self.id

                if let elementId {
                    // Click by element ID with auto-wait
                    clickTarget = .elementId(elementId)
                    waitResult = try await PeekabooServices.shared.automation.waitForElement(
                        target: clickTarget,
                        timeout: TimeInterval(self.waitFor) / 1000.0,
                        sessionId: activeSessionId.isEmpty ? nil : activeSessionId
                    )

                    if !waitResult.found {
                        var message = "Element with ID '\(elementId)' not found"
                        message += "\n\n💡 Hints:"
                        message += "\n  • Run 'peekaboo see' first to capture UI elements"
                        message += "\n  • Check that the element ID is correct (e.g., B1, T2)"
                        message += "\n  • Element may have disappeared or changed"
                        throw PeekabooError.elementNotFound(message)
                    }

                } else if let searchQuery = query {
                    // Find element by query with auto-wait
                    clickTarget = .query(searchQuery)
                    waitResult = try await PeekabooServices.shared.automation.waitForElement(
                        target: clickTarget,
                        timeout: TimeInterval(self.waitFor) / 1000.0,
                        sessionId: activeSessionId.isEmpty ? nil : activeSessionId
                    )

                    if !waitResult.found {
                        var message = "No actionable element found matching '\(searchQuery)' after \(self.waitFor)ms"
                        message += "\n\n💡 Hints:"
                        message += "\n  • Menu bar items often require clicking on their icon coordinates"
                        message += "\n  • Try 'peekaboo see' first to get element IDs"
                        message += "\n  • Use partial text matching (case-insensitive)"
                        message += "\n  • Element might be disabled or not visible"
                        message += "\n  • Try increasing --wait-for timeout"
                        throw PeekabooError.elementNotFound(message)
                    }

                } else {
                    throw ArgumentParser.ValidationError("Specify an element query, --on/--id, or --coords. Did you mean to pass the query as a positional argument? Usage: `peekaboo click \"button text\"`")
                }
            }

            // Determine click type
            let clickType: ClickType = self.right ? .right : (self.double ? .double : .single)

            // Perform the click
            if case .coordinates = clickTarget {
                // For coordinate clicks, pass nil session ID
                try await PeekabooServices.shared.automation.click(
                    target: clickTarget,
                    clickType: clickType,
                    sessionId: nil
                )
            } else {
                // For element-based clicks, pass the session ID
                try await PeekabooServices.shared.automation.click(
                    target: clickTarget,
                    clickType: clickType,
                    sessionId: activeSessionId.isEmpty ? nil : activeSessionId
                )
            }

            // Brief delay to ensure click is processed
            try await Task.sleep(nanoseconds: 20_000_000) // 0.02 seconds

            // Get the frontmost app after clicking
            let frontmostApp = NSWorkspace.shared.frontmostApplication
            let appName = frontmostApp?.localizedName ?? "Unknown"

            // Prepare result
            let clickLocation: CGPoint
            let clickedElement: String?

            switch clickTarget {
            case let .elementId(id):
                if let element = waitResult.element {
                    clickLocation = CGPoint(x: element.bounds.midX, y: element.bounds.midY)
                    clickedElement = self.formatElementInfo(element)
                } else {
                    // Shouldn't happen but handle gracefully
                    clickLocation = .zero
                    clickedElement = "Element ID: \(id)"
                }

            case let .coordinates(point):
                clickLocation = point
                clickedElement = nil

            case let .query(query):
                if let element = waitResult.element {
                    clickLocation = CGPoint(x: element.bounds.midX, y: element.bounds.midY)
                    clickedElement = self.formatElementInfo(element)
                } else {
                    // Use a default description
                    clickLocation = .zero
                    clickedElement = "Element matching: \(query)"
                }
            }

            // Output results
            let result = ClickResult(
                success: true,
                clickedElement: clickedElement,
                clickLocation: clickLocation,
                waitTime: waitResult.waitTime,
                executionTime: Date().timeIntervalSince(startTime),
                targetApp: appName
            )

            output(result) {
                print("✅ Click successful")
                print("🎯 App: \(appName)")
                if let info = clickedElement {
                    print("📱 Clicked: \(info)")
                }
                print("📍 Location: (\(Int(clickLocation.x)), \(Int(clickLocation.y)))")
                if waitResult.waitTime > 0 {
                    print("⏳ Waited: \(String(format: "%.1f", waitResult.waitTime))s")
                }
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            self.handleError(error)
            throw ExitCode.failure
        }
    }

    private func formatElementInfo(_ element: DetectedElement) -> String {
        let roleDescription = element.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        let label = element.label ?? element.value ?? element.id
        return "\(roleDescription): \(label)"
    }

    // Error handling is provided by ErrorHandlingCommand protocol
}

// MARK: - JSON Output Structure

struct ClickResult: Codable {
    let success: Bool
    let clickedElement: String?
    let clickLocation: [String: Double]
    let waitTime: Double
    let executionTime: TimeInterval
    let targetApp: String

    init(
        success: Bool,
        clickedElement: String?,
        clickLocation: CGPoint,
        waitTime: Double,
        executionTime: TimeInterval,
        targetApp: String
    ) {
        self.success = success
        self.clickedElement = clickedElement
        self.clickLocation = ["x": clickLocation.x, "y": clickLocation.y]
        self.waitTime = waitTime
        self.executionTime = executionTime
        self.targetApp = targetApp
    }
}

// MARK: - Static Helper Methods for Testing

extension ClickCommand {
    /// Parse coordinates string (e.g., "100,200") into CGPoint
    static func parseCoordinates(_ coords: String) -> CGPoint? {
        let parts = coords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let x = Double(parts[0]),
              let y = Double(parts[1]) else {
            return nil
        }
        return CGPoint(x: x, y: y)
    }

    /// Create element locator from query string
    static func createLocatorFromQuery(_ query: String) -> (type: String, value: String) {
        // Simple heuristic for determining locator type
        if query.hasPrefix("#") {
            ("id", String(query.dropFirst()))
        } else if query.hasPrefix(".") {
            ("class", String(query.dropFirst()))
        } else if query.hasPrefix("//") || query.hasPrefix("/") {
            ("xpath", query)
        } else {
            ("text", query)
        }
    }
}
