import AppKit
import ArgumentParser
import CoreGraphics
import Foundation
import PeekabooCore

/// Click on UI elements identified in the current session using intelligent element finding and smart waiting.
@available(macOS 14.0, *)
struct ClickCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "click",
        abstract: "Click on UI elements or coordinates",
        discussion: """
            The 'click' command interacts with UI elements captured by 'see'.
            It supports intelligent element finding, actionability checks, and
            automatic waiting for elements to become available.

            EXAMPLES:
              peekaboo click "Sign In"              # Click button with text
              peekaboo click --id element_42        # Click specific element ID
              peekaboo click --coords 100,200       # Click at coordinates
              peekaboo click "Submit" --wait 5      # Wait up to 5s for element
              peekaboo click "Menu" --double        # Double-click
              peekaboo click "File" --right         # Right-click

            ELEMENT MATCHING:
              Elements are matched by searching text in:
              - Title/Label content
              - Value text
              - Role descriptions

              Use --id for precise element targeting from 'see' output.
        """)

    @Argument(help: "Element text or query to click")
    var query: String?

    @Option(help: "Session ID (uses latest if not specified)")
    var session: String?

    @Option(help: "Element ID to click (e.g., B1, T2)")
    var on: String?

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
                // For element-based clicks, we need a session
                let sessionId: String? = if let providedSession = session {
                    providedSession
                } else {
                    await PeekabooServices.shared.sessions.getMostRecentSession()
                }
                guard let foundSessionId = sessionId else {
                    throw CLIError.sessionNotFound
                }
                activeSessionId = foundSessionId
                
                if let elementId = on {
                    // Click by element ID with auto-wait
                    clickTarget = .elementId(elementId)
                    waitResult = try await PeekabooServices.shared.automation.waitForElement(
                        target: clickTarget,
                        timeout: TimeInterval(self.waitFor) / 1000.0,
                        sessionId: activeSessionId)

                    if !waitResult.found {
                        throw CLIError.elementNotFound
                    }

                } else if let searchQuery = query {
                    // Find element by query with auto-wait
                    clickTarget = .query(searchQuery)
                    waitResult = try await PeekabooServices.shared.automation.waitForElement(
                        target: clickTarget,
                        timeout: TimeInterval(self.waitFor) / 1000.0,
                        sessionId: activeSessionId)

                    if !waitResult.found {
                        throw CLIError.interactionFailed(
                            "No actionable element found matching '\(searchQuery)' after \(self.waitFor)ms")
                    }

                } else {
                    throw ArgumentParser.ValidationError("Specify an element query, --on, or --coords")
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
                    sessionId: nil)
            } else {
                // For element-based clicks, pass the session ID
                try await PeekabooServices.shared.automation.click(
                    target: clickTarget,
                    clickType: clickType,
                    sessionId: activeSessionId)
            }

            // Brief delay to ensure click is processed
            try await Task.sleep(nanoseconds: 20_000_000) // 0.02 seconds

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
            if self.jsonOutput {
                let result = ClickResult(
                    success: true,
                    clickedElement: clickedElement,
                    clickLocation: clickLocation,
                    waitTime: waitResult.waitTime,
                    executionTime: Date().timeIntervalSince(startTime))
                outputSuccessCodable(data: result)
            } else {
                print("✅ Click successful")
                if let info = clickedElement {
                    print("🎯 Clicked: \(info)")
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

    private func handleError(_ error: Error) {
        if self.jsonOutput {
            let errorCode: ErrorCode = if error is PeekabooError {
                switch error as? CLIError {
                case .sessionNotFound:
                    .SESSION_NOT_FOUND
                case .elementNotFound:
                    .ELEMENT_NOT_FOUND
                case .interactionFailed:
                    .INTERACTION_FAILED
                default:
                    .INTERNAL_SWIFT_ERROR
                }
            } else if error is ArgumentParser.ValidationError {
                .INVALID_INPUT
            } else {
                .INTERNAL_SWIFT_ERROR
            }

            outputError(
                message: error.localizedDescription,
                code: errorCode)
        } else {
            var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
            print("Error: \(error.localizedDescription)", to: &localStandardErrorStream)
        }
    }
}

// MARK: - JSON Output Structure

struct ClickResult: Codable {
    let success: Bool
    let clickedElement: String?
    let clickLocation: [String: Double]
    let waitTime: Double
    let executionTime: TimeInterval

    init(
        success: Bool,
        clickedElement: String?,
        clickLocation: CGPoint,
        waitTime: Double,
        executionTime: TimeInterval)
    {
        self.success = success
        self.clickedElement = clickedElement
        self.clickLocation = ["x": clickLocation.x, "y": clickLocation.y]
        self.waitTime = waitTime
        self.executionTime = executionTime
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
            return ("id", String(query.dropFirst()))
        } else if query.hasPrefix(".") {
            return ("class", String(query.dropFirst()))
        } else if query.hasPrefix("//") || query.hasPrefix("/") {
            return ("xpath", query)
        } else {
            return ("text", query)
        }
    }
}
