import AppKit
import ArgumentParser
import CoreGraphics
import Foundation
import PeekabooCore

/// Refactored ClickCommand using PeekabooCore services
/// Clicks on UI elements identified in the current session using intelligent element finding and smart waiting.
@available(macOS 14.0, *)
struct ClickCommandV2: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "click-v2",
        abstract: "Click on UI elements or coordinates using PeekabooCore services",
        discussion: """
            This is a refactored version of the click command that uses PeekabooCore services
            instead of direct implementation. It maintains the same interface but delegates
            all operations to the service layer.
            
            The 'click' command interacts with UI elements captured by 'see'.
            It supports intelligent element finding, actionability checks, and
            automatic waiting for elements to become available.

            EXAMPLES:
              peekaboo click-v2 "Sign In"              # Click button with text
              peekaboo click-v2 --id element_42        # Click specific element ID
              peekaboo click-v2 --coords 100,200       # Click at coordinates
              peekaboo click-v2 "Submit" --wait 5      # Wait up to 5s for element
              peekaboo click-v2 "Menu" --double        # Double-click
              peekaboo click-v2 "File" --right         # Right-click

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

    private let services = PeekabooServices.shared

    mutating func run() async throws {
        let startTime = Date()
        Logger.shared.setJsonOutputMode(jsonOutput)

        do {
            // Determine session ID - use provided or get most recent
            let sessionId = session ?? (await services.sessions.getMostRecentSession())
            guard let activeSessionId = sessionId else {
                throw PeekabooError.sessionNotFound
            }

            // Determine click target
            let clickTarget: ClickTarget
            let waitResult: WaitForElementResult

            if let elementId = on {
                // Click by element ID with auto-wait
                clickTarget = .elementId(elementId)
                waitResult = try await services.automation.waitForElement(
                    target: clickTarget,
                    timeout: TimeInterval(waitFor) / 1000.0,
                    sessionId: activeSessionId
                )
                
                if !waitResult.found {
                    throw PeekabooError.elementNotFound
                }

            } else if let coordString = coords {
                // Click by coordinates (no waiting needed)
                let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2,
                      let x = Double(parts[0]),
                      let y = Double(parts[1])
                else {
                    throw ValidationError("Invalid coordinates format. Use: x,y")
                }
                clickTarget = .coordinates(CGPoint(x: x, y: y))
                waitResult = WaitForElementResult(found: true, element: nil, waitTime: 0)

            } else if let searchQuery = query {
                // Find element by query with auto-wait
                clickTarget = .query(searchQuery)
                waitResult = try await services.automation.waitForElement(
                    target: clickTarget,
                    timeout: TimeInterval(waitFor) / 1000.0,
                    sessionId: activeSessionId
                )
                
                if !waitResult.found {
                    throw PeekabooError.interactionFailed(
                        "No actionable element found matching '\(searchQuery)' after \(waitFor)ms"
                    )
                }

            } else {
                throw ValidationError("Specify an element query, --on, or --coords")
            }

            // Determine click type
            let clickType: ClickType = right ? .right : (double ? .double : .single)

            // Perform the click
            try await services.automation.click(
                target: clickTarget,
                clickType: clickType,
                sessionId: activeSessionId
            )

            // Small delay to ensure click is processed
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Prepare result
            let clickLocation: CGPoint
            let clickedElement: String?

            switch clickTarget {
            case .elementId(let id):
                if let element = waitResult.element {
                    clickLocation = CGPoint(x: element.bounds.midX, y: element.bounds.midY)
                    clickedElement = formatElementInfo(element)
                } else {
                    // Shouldn't happen but handle gracefully
                    clickLocation = .zero
                    clickedElement = "Element ID: \(id)"
                }
                
            case .coordinates(let point):
                clickLocation = point
                clickedElement = nil
                
            case .query(let query):
                if let element = waitResult.element {
                    clickLocation = CGPoint(x: element.bounds.midX, y: element.bounds.midY)
                    clickedElement = formatElementInfo(element)
                } else {
                    // Use a default description
                    clickLocation = .zero
                    clickedElement = "Element matching: \(query)"
                }
            }

            // Output results
            if jsonOutput {
                let result = ClickResult(
                    success: true,
                    clickedElement: clickedElement,
                    clickLocation: clickLocation,
                    waitTime: waitResult.waitTime,
                    executionTime: Date().timeIntervalSince(startTime)
                )
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
            handleError(error)
            throw ExitCode.failure
        }
    }

    private func formatElementInfo(_ element: DetectedElement) -> String {
        let roleDescription = element.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        let label = element.label ?? element.value ?? element.id
        return "\(roleDescription): \(label)"
    }

    private func handleError(_ error: Error) {
        if jsonOutput {
            let errorCode: ErrorCode
            if error is PeekabooError {
                switch error as? PeekabooError {
                case .sessionNotFound:
                    errorCode = .SESSION_NOT_FOUND
                case .elementNotFound:
                    errorCode = .ELEMENT_NOT_FOUND
                case .interactionFailed:
                    errorCode = .INTERACTION_FAILED
                default:
                    errorCode = .INTERNAL_SWIFT_ERROR
                }
            } else if error is ValidationError {
                errorCode = .INVALID_INPUT
            } else {
                errorCode = .INTERNAL_SWIFT_ERROR
            }
            
            outputError(
                message: error.localizedDescription,
                code: errorCode
            )
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