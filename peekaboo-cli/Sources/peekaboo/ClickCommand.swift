import AppKit
import ArgumentParser
import AXorcistLib
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

        do {
            // Load session (don't create new if not found)
            let sessionCache = try SessionCache(sessionId: session, createIfNeeded: false)
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
                    timeout: waitFor)
                clickTarget = .element(element)

            } else if let coordString = coords {
                // Click by coordinates
                let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2,
                      let x = Double(parts[0]),
                      let y = Double(parts[1])
                else {
                    throw ValidationError("Invalid coordinates format. Use: x,y")
                }
                clickTarget = .coordinates(CGPoint(x: x, y: y))

            } else if let searchQuery = query {
                // Find element by query with auto-wait
                let element = try await waitForElementByQuery(
                    query: searchQuery,
                    sessionCache: sessionCache,
                    timeout: waitFor)
                clickTarget = .element(element)

            } else {
                throw ValidationError("Specify an element query, --on, or --coords")
            }

            // Perform the click
            let clickResult = try await performClick(
                target: clickTarget,
                clickType: ClickType(double: double, right: right))

            // Output results
            if self.jsonOutput {
                let output = ClickResult(
                    success: true,
                    clickedElement: clickResult.elementInfo,
                    clickLocation: clickResult.location,
                    waitTime: clickResult.waitTime,
                    executionTime: Date().timeIntervalSince(startTime))
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
            if self.jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .INTERNAL_SWIFT_ERROR)
            } else {
                var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
                print("Error: \(error.localizedDescription)", to: &localStandardErrorStream)
            }
            throw ExitCode.failure
        }
    }

    private func performClick(
        target: ClickTarget,
        clickType: ClickType) async throws -> InternalClickResult
    {
        // Get the click location and element info
        let (clickLocation, elementInfo): (CGPoint, String?) = {
            switch target {
            case let .element(element):
                // Calculate center of element
                let center = CGPoint(
                    x: element.frame.midX,
                    y: element.frame.midY)

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
        timeout: Int) async throws -> SessionCache.SessionData.UIElement
    {
        let startTime = Date()
        let timeoutSeconds = Double(timeout) / 1000.0
        let deadline = startTime.addingTimeInterval(timeoutSeconds)
        let retryInterval: UInt64 = 100_000_000 // 100ms in nanoseconds

        // Load session data to get element properties
        guard let sessionData = await sessionCache.load(),
              let targetElement = sessionData.uiMap[elementId]
        else {
            throw PeekabooError.elementNotFound
        }

        // Create a locator from the cached element's properties
        let locator = ElementLocator(
            role: targetElement.role,
            title: targetElement.title,
            label: targetElement.label,
            value: targetElement.value,
            description: targetElement.description,
            help: targetElement.help,
            roleDescription: targetElement.roleDescription,
            identifier: targetElement.identifier)

        while Date() < deadline {
            // First try to find element at the stored location (fast path)
            if let liveElement = try await findElementAtLocation(
                frame: targetElement.frame,
                role: targetElement.role,
                in: sessionData.applicationName)
            {
                // Verify it matches our expected properties
                if self.matchesLocator(element: liveElement, locator: locator) {
                    if try await self.isElementActionable(liveElement) {
                        // Return element with updated coordinates
                        var updatedElement = targetElement
                        updatedElement.frame = liveElement.frame() ?? targetElement.frame
                        return updatedElement
                    }
                }
            }

            // If not found at stored location, search the entire UI tree
            if let liveElement = try await findLiveElement(
                matching: locator,
                in: sessionData.applicationName)
            {
                if try await self.isElementActionable(liveElement) {
                    // Return element with updated coordinates
                    var updatedElement = targetElement
                    updatedElement.frame = liveElement.frame() ?? targetElement.frame
                    Logger.shared.debug("Element '\(elementId)' found at new location: \(updatedElement.frame)")
                    return updatedElement
                }
            }

            // Wait before retrying
            try await Task.sleep(nanoseconds: retryInterval)
        }

        throw PeekabooError.interactionFailed(
            "Element '\(elementId)' not found or not actionable after \(timeout)ms")
    }

    @MainActor
    private func findElementAtLocation(
        frame: CGRect,
        role: String,
        in appName: String?) async throws -> Element?
    {
        // Find the application using AXorcist
        guard let appName,
              let app = NSWorkspace.shared.runningApplications.first(where: {
                  $0.localizedName == appName || $0.bundleIdentifier == appName
              })
        else {
            return nil
        }

        // Create AXUIElement for the application
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        _ = Element(axApp)

        // Get element at the center of the frame using AXorcist
        let centerPoint = CGPoint(x: frame.midX, y: frame.midY)

        // Use AXorcist's elementAtPoint static method
        if let foundElement = Element.elementAtPoint(centerPoint, pid: app.processIdentifier) {
            // Verify it's the right type of element using AXorcist's role() method
            if foundElement.role() == role {
                return foundElement
            }
        }

        return nil
    }

    @MainActor
    private func findLiveElement(
        matching locator: ElementLocator,
        in appName: String?) async throws -> Element?
    {
        // Find the application
        guard let appName,
              let app = NSWorkspace.shared.runningApplications.first(where: {
                  $0.localizedName == appName || $0.bundleIdentifier == appName
              })
        else {
            return nil
        }

        // Create AXUIElement for the application
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)

        // Search for matching element
        return self.findMatchingElement(in: appElement, matching: locator)
    }

    @MainActor
    private func findMatchingElement(
        in element: Element,
        matching locator: ElementLocator) -> Element?
    {
        // Check if current element matches
        if self.matchesLocator(element: element, locator: locator) {
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
        // Match by role (required)
        guard let role = element.role() else { return false }
        if role != locator.role {
            return false
        }

        // For elements with unique identifiers, match those first
        if let locatorId = locator.identifier, !locatorId.isEmpty {
            return element.identifier() == locatorId
        }

        // For elements with labels (like "italic", "bold"), match by label
        if let locatorLabel = locator.label, !locatorLabel.isEmpty {
            // Check various label-like properties
            let elementLabel = element.descriptionText() ?? element.help() ?? element.roleDescription() ?? element
                .title()
            return elementLabel == locatorLabel
        }

        // Match by title if specified
        if let locatorTitle = locator.title, !locatorTitle.isEmpty {
            return element.title() == locatorTitle
        }

        // Match by value if specified (for text fields, etc.)
        if let locatorValue = locator.value, !locatorValue.isEmpty {
            if let elementValue = element.value() as? String {
                return elementValue == locatorValue
            }
        }

        // For elements without any distinguishing properties, we need more context
        // This handles cases like multiple identical checkboxes
        // In this case, we should rely on position or other heuristics
        let hasAnyProperty = (locator.identifier != nil && !locator.identifier!.isEmpty) ||
            (locator.label != nil && !locator.label!.isEmpty) ||
            (locator.title != nil && !locator.title!.isEmpty) ||
            (locator.value != nil && !locator.value!.isEmpty)

        // If the locator has no properties, it's likely a generic element
        // We should not match based on role alone
        return !hasAnyProperty
    }

    @MainActor
    private func isElementActionable(_ element: Element) async throws -> Bool {
        // Check if element is enabled
        if !(element.isEnabled() ?? true) {
            return false
        }

        // Check if element is visible (not hidden)
        if element.isHidden() == true {
            return false
        }

        // Check frame validity
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
        timeout: Int) async throws -> SessionCache.SessionData.UIElement
    {
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
                    value: element.value,
                    description: element.description,
                    help: element.help,
                    roleDescription: element.roleDescription,
                    identifier: element.identifier)

                if let liveElement = try await findLiveElement(
                    matching: locator,
                    in: sessionData.applicationName)
                {
                    if try await self.isElementActionable(liveElement) {
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
            "No actionable element found matching '\(query)' after \(timeout)ms")
    }
}

// MARK: - Supporting Types

private struct ElementLocator {
    let role: String
    let title: String?
    let label: String?
    let value: String?
    let description: String?
    let help: String?
    let roleDescription: String?
    let identifier: String?
}

private enum ClickTarget {
    case element(SessionCache.SessionData.UIElement)
    case coordinates(CGPoint)
}

private struct ClickType {
    let double: Bool
    let right: Bool

    func toAXClickType() -> String { // TODO: Change to AXMouseButton when available
        self.right ? "right" : "left"
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
        executionTime: TimeInterval)
    {
        self.success = success
        self.clickedElement = clickedElement
        self.clickLocation = ["x": clickLocation.x, "y": clickLocation.y]
        self.waitTime = waitTime
        self.executionTime = executionTime
    }
}
