import AppKit
import ArgumentParser
import AXorcist
import CoreGraphics
import Foundation

/// Clicks on UI elements identified in the current session.
/// Supports element queries, coordinates, and smart waiting.
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
        """
    )

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

        do {
            // Load session
            let sessionCache = SessionCache(sessionId: session)
            guard await sessionCache.load() != nil else {
                throw PeekabooError.sessionNotFound
            }

            // Determine click target
            let clickTarget: ClickTarget

            if let elementId = on {
                // Click by element ID with auto-wait
                let element = try await waitForElement(
                    elementId: elementId,
                    sessionCache: sessionCache,
                    timeout: waitFor
                )
                clickTarget = .element(element)

            } else if let coordString = coords {
                // Click by coordinates
                let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2,
                      let x = Double(parts[0]),
                      let y = Double(parts[1]) else {
                    throw ValidationError("Invalid coordinates format. Use: x,y")
                }
                clickTarget = .coordinates(CGPoint(x: x, y: y))

            } else if let searchQuery = query {
                // Find element by query with auto-wait
                let element = try await waitForElementByQuery(
                    query: searchQuery,
                    sessionCache: sessionCache,
                    timeout: waitFor
                )
                clickTarget = .element(element)

            } else {
                throw ValidationError("Specify an element query, --on, or --coords")
            }

            // Perform the click
            let clickResult = try await performClick(
                target: clickTarget,
                clickType: ClickType(double: double, right: right)
            )

            // Output results
            if jsonOutput {
                let output = ClickResult(
                    success: true,
                    clickedElement: clickResult.elementInfo,
                    clickLocation: clickResult.location,
                    waitTime: clickResult.waitTime,
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output)
            } else {
                print("✅ Click successful")
                if let info = clickResult.elementInfo {
                    print("🎯 Clicked: \(info)")
                }
                print("📍 Location: (\(Int(clickResult.location.x)), \(Int(clickResult.location.y)))")
                if clickResult.waitTime > 0 {
                    print("⏳ Waited: \(String(format: "%.1f", clickResult.waitTime))s")
                }
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            if jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .INTERNAL_SWIFT_ERROR
                )
            } else {
                var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
                print("Error: \(error.localizedDescription)", to: &localStandardErrorStream)
            }
            throw ExitCode.failure
        }
    }

    private func performClick(
        target: ClickTarget,
        clickType: ClickType
    ) async throws -> InternalClickResult {
        // Get the click location and element info
        let (clickLocation, elementInfo): (CGPoint, String?) = {
            switch target {
            case let .element(element):
                // Calculate center of element
                let center = CGPoint(
                    x: element.frame.midX,
                    y: element.frame.midY
                )

                let info = "\(element.role): \(element.title ?? element.label ?? element.id)"
                return (center, info)

            case let .coordinates(point):
                return (point, nil)
            }
        }()

        // Perform the actual click using CoreGraphics events
        let clickPoint = CGPoint(x: clickLocation.x, y: clickLocation.y)
        let mouseButton: InputEvents.MouseButton = clickType.right ? .right : .left
        let clickCount = clickType.double ? 2 : 1

        try InputEvents.click(at: clickPoint, button: mouseButton, clickCount: clickCount)

        // Small delay to ensure click is processed
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        return InternalClickResult(
            location: clickLocation,
            elementInfo: elementInfo,
            waitTime: 0 // Wait time is now handled in waitForElement
        )
    }

    @MainActor
    private func waitForElement(
        elementId: String,
        sessionCache: SessionCache,
        timeout: Int
    ) async throws -> SessionCache.SessionData.UIElement {
        let startTime = Date()
        let timeoutSeconds = Double(timeout) / 1000.0
        let deadline = startTime.addingTimeInterval(timeoutSeconds)
        let retryInterval: UInt64 = 100_000_000 // 100ms in nanoseconds

        // Load session data to get element properties
        guard let sessionData = await sessionCache.load(),
              let targetElement = sessionData.uiMap[elementId] else {
            throw PeekabooError.elementNotFound
        }

        // Create locator from element properties
        let locator = ElementLocator(
            role: targetElement.role,
            title: targetElement.title,
            label: targetElement.label,
            value: targetElement.value
        )

        // Enter retry loop with live accessibility queries
        while Date() < deadline {
            // Re-query the accessibility tree for live element
            if let liveElement = try await findLiveElement(
                matching: locator,
                in: sessionData.applicationName
            ) {
                // Perform actionability checks
                if try await isElementActionable(liveElement) {
                    // Update element with live coordinates
                    var updatedElement = targetElement
                    updatedElement.frame = liveElement.frame() ?? .zero
                    return updatedElement
                }
            }

            // Wait before retrying
            try await Task.sleep(nanoseconds: retryInterval)
        }

        throw PeekabooError.interactionFailed(
            "Element '\(elementId)' not found or not actionable after \(timeout)ms"
        )
    }
    
    @MainActor
    private func findLiveElement(
        matching locator: ElementLocator,
        in appName: String?
    ) async throws -> Element? {
        // Find the application
        guard let appName = appName,
              let app = NSWorkspace.shared.runningApplications.first(where: {
                  $0.localizedName == appName || $0.bundleIdentifier == appName
              }) else {
            return nil
        }
        
        // Create AXUIElement for the application
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)
        
        // Search for matching element
        return findMatchingElement(in: appElement, matching: locator)
    }
    
    @MainActor
    private func findMatchingElement(
        in element: Element,
        matching locator: ElementLocator
    ) -> Element? {
        // Check if current element matches
        if matchesLocator(element: element, locator: locator) {
            return element
        }
        
        // Recursively search children
        if let children = element.children() {
            for child in children {
                if let match = findMatchingElement(in: child, matching: locator) {
                    return match
                }
            }
        }
        
        return nil
    }
    
    @MainActor
    private func matchesLocator(element: Element, locator: ElementLocator) -> Bool {
        // Match by role
        if let role = element.role(), role != locator.role {
            return false
        }
        
        // Match by title if specified
        if let locatorTitle = locator.title {
            if element.title() != locatorTitle {
                return false
            }
        }
        
        // Match by value if specified
        if let locatorValue = locator.value,
           let elementValue = element.value() as? String {
            if elementValue != locatorValue {
                return false
            }
        }
        
        return true
    }
    
    @MainActor
    private func isElementActionable(_ element: Element) async throws -> Bool {
        // Check if element is enabled
        if !(element.isEnabled() ?? true) {
            return false
        }
        
        // Check if element is visible (not hidden)
        // AXorcist doesn't expose hidden attribute directly, so we check frame
        guard let frame = element.frame() else {
            return false
        }
        if frame.width <= 0 || frame.height <= 0 {
            return false
        }
        
        // Check if element is on screen
        if let mainScreen = NSScreen.main {
            let screenBounds = mainScreen.frame
            if !screenBounds.intersects(frame) {
                return false
            }
        } else {
            return false
        }
        
        return true
    }

    @MainActor
    private func waitForElementByQuery(
        query: String,
        sessionCache: SessionCache,
        timeout: Int
    ) async throws -> SessionCache.SessionData.UIElement {
        let startTime = Date()
        let timeoutSeconds = Double(timeout) / 1000.0
        let deadline = startTime.addingTimeInterval(timeoutSeconds)
        let retryInterval: UInt64 = 100_000_000 // 100ms in nanoseconds

        // Load session data to get application context
        guard let sessionData = await sessionCache.load() else {
            throw PeekabooError.sessionNotFound
        }

        while Date() < deadline {
            // Find elements matching the query from cached data
            let elements = await sessionCache.findElements(matching: query)
                .filter(\.isActionable)

            // For each matching element, verify it's still live and actionable
            for element in elements {
                let locator = ElementLocator(
                    role: element.role,
                    title: element.title,
                    label: element.label,
                    value: element.value
                )
                
                if let liveElement = try await findLiveElement(
                    matching: locator,
                    in: sessionData.applicationName
                ) {
                    if try await isElementActionable(liveElement) {
                        // Update element with live coordinates
                        var updatedElement = element
                        updatedElement.frame = liveElement.frame() ?? .zero
                        return updatedElement
                    }
                }
            }

            // Wait before retrying
            try await Task.sleep(nanoseconds: retryInterval)
        }

        throw PeekabooError.interactionFailed(
            "No actionable element found matching '\(query)' after \(timeout)ms"
        )
    }
}

// MARK: - Supporting Types

private struct ElementLocator {
    let role: String
    let title: String?
    let label: String?
    let value: String?
}

private enum ClickTarget {
    case element(SessionCache.SessionData.UIElement)
    case coordinates(CGPoint)
}

private struct ClickType {
    let double: Bool
    let right: Bool

    func toAXClickType() -> String { // TODO: Change to AXMouseButton when available
        right ? "right" : "left"
    }
}

private struct InternalClickResult {
    let location: CGPoint
    let elementInfo: String?
    let waitTime: Double
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
        executionTime: TimeInterval
    ) {
        self.success = success
        self.clickedElement = clickedElement
        self.clickLocation = ["x": clickLocation.x, "y": clickLocation.y]
        self.waitTime = waitTime
        self.executionTime = executionTime
    }
}
