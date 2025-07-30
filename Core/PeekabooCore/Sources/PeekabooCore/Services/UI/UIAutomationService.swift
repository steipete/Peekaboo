import AppKit
import ApplicationServices
@preconcurrency import AXorcist
import CoreGraphics
import Foundation
import os.log

/// Default implementation of UI automation operations using specialized services
@MainActor
public final class UIAutomationService: UIAutomationServiceProtocol {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "UIAutomationService")
    private let sessionManager: SessionManagerProtocol

    // Specialized services
    private let elementDetectionService: ElementDetectionService
    private let clickService: ClickService
    private let typeService: TypeService
    private let scrollService: ScrollService
    private let hotkeyService: HotkeyService
    private let gestureService: GestureService
    private let screenCaptureService: ScreenCaptureService

    // Visualizer client for visual feedback
    private let visualizerClient = VisualizationClient.shared

    public init(sessionManager: SessionManagerProtocol? = nil, loggingService: LoggingServiceProtocol? = nil) {
        let manager = sessionManager ?? SessionManager()
        self.sessionManager = manager

        let logger = loggingService ?? LoggingService()

        // Initialize specialized services
        self.elementDetectionService = ElementDetectionService(sessionManager: manager)
        self.clickService = ClickService(sessionManager: manager)
        self.typeService = TypeService(sessionManager: manager, clickService: nil)
        self.scrollService = ScrollService(sessionManager: manager, clickService: nil)
        self.hotkeyService = HotkeyService()
        self.gestureService = GestureService()
        self.screenCaptureService = ScreenCaptureService(loggingService: logger)

        // Connect to visualizer if available
        // Only connect to visualizer if we're not running inside the Mac app
        // The Mac app provides the visualizer service, not consumes it
        let isMacApp = Bundle.main.bundleIdentifier == "boo.peekaboo.mac"
        if !isMacApp {
            self.logger.debug("Connecting to visualizer service (running as CLI/external tool)")
            self.visualizerClient.connect()
        } else {
            self.logger.debug("Skipping visualizer connection (running inside Mac app)")
        }
    }

    // MARK: - Element Detection

    public func detectElements(
        in imageData: Data,
        sessionId: String?,
        windowContext: WindowContext?) async throws -> ElementDetectionResult
    {
        self.logger.debug("Delegating element detection to ElementDetectionService")
        return try await self.elementDetectionService.detectElements(
            in: imageData,
            sessionId: sessionId,
            windowContext: windowContext)
    }

    // MARK: - Click Operations

    public func click(target: ClickTarget, clickType: ClickType, sessionId: String?) async throws {
        self.logger.debug("Delegating click to ClickService")
        try await self.clickService.click(target: target, clickType: clickType, sessionId: sessionId)

        // Show visual feedback if available
        if let clickPoint = try await getClickPoint(for: target, sessionId: sessionId) {
            _ = await self.visualizerClient.showClickFeedback(at: clickPoint, type: clickType)
        }
    }

    private func getClickPoint(for target: ClickTarget, sessionId: String?) async throws -> CGPoint? {
        switch target {
        case let .coordinates(point):
            return point
        case let .elementId(id):
            if let sessionId,
               let result = try? await sessionManager.getDetectionResult(sessionId: sessionId),
               let element = result.elements.findById(id)
            {
                return CGPoint(x: element.bounds.midX, y: element.bounds.midY)
            }
        case .query:
            // For queries, we don't have easy access to the clicked element's position
            // The click service would need to expose this information
            return nil
        }
        return nil
    }

    // MARK: - Typing Operations

    public func type(
        text: String,
        target: String?,
        clearExisting: Bool,
        typingDelay: Int,
        sessionId: String?) async throws
    {
        self.logger.debug("Delegating type to TypeService")
        try await self.typeService.type(
            text: text,
            target: target,
            clearExisting: clearExisting,
            typingDelay: typingDelay,
            sessionId: sessionId)

        // Show visual feedback if available
        let keys = Array(text).map { String($0) }
        _ = await self.visualizerClient.showTypingFeedback(keys: keys, duration: 2.0)
    }

    public func typeActions(_ actions: [TypeAction], typingDelay: Int, sessionId: String?) async throws -> TypeResult {
        self.logger.debug("Delegating typeActions to TypeService")
        return try await self.typeService.typeActions(actions, typingDelay: typingDelay, sessionId: sessionId)
    }

    // MARK: - Scroll Operations

    public func scroll(
        direction: ScrollDirection,
        amount: Int,
        target: String?,
        smooth: Bool,
        delay: Int,
        sessionId: String?) async throws
    {
        self.logger.debug("Delegating scroll to ScrollService")
        try await self.scrollService.scroll(
            direction: direction,
            amount: amount,
            target: target,
            smooth: smooth,
            delay: delay,
            sessionId: sessionId)

        // Show visual feedback if available
        // Get current mouse location for scroll indicator
        let mouseLocation = NSEvent.mouseLocation
        _ = await self.visualizerClient.showScrollFeedback(at: mouseLocation, direction: direction, amount: amount)
    }

    // MARK: - Hotkey Operations

    public func hotkey(keys: String, holdDuration: Int) async throws {
        self.logger.debug("Delegating hotkey to HotkeyService")
        try await self.hotkeyService.hotkey(keys: keys, holdDuration: holdDuration)

        // Show visual feedback if available
        let keyArray = keys.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        _ = await self.visualizerClient.showHotkeyDisplay(keys: keyArray, duration: 1.0)
    }

    // MARK: - Gesture Operations

    public func swipe(from: CGPoint, to: CGPoint, duration: Int, steps: Int) async throws {
        self.logger.debug("Delegating swipe to GestureService")
        try await self.gestureService.swipe(from: from, to: to, duration: duration, steps: steps)

        // Show visual feedback if available
        _ = await self.visualizerClient.showSwipeGesture(from: from, to: to, duration: TimeInterval(duration) / 1000.0)
    }

    public func drag(from: CGPoint, to: CGPoint, duration: Int, steps: Int, modifiers: String?) async throws {
        self.logger.debug("Delegating drag to GestureService")
        try await self.gestureService.drag(
            from: from,
            to: to,
            duration: duration,
            steps: steps,
            modifiers: modifiers)
    }

    public func moveMouse(to: CGPoint, duration: Int, steps: Int) async throws {
        self.logger.debug("Delegating moveMouse to GestureService")

        // Get current mouse position for the animation start point
        let fromPoint = NSEvent.mouseLocation

        try await self.gestureService.moveMouse(to: to, duration: duration, steps: steps)

        // Show visual feedback if available
        _ = await self.visualizerClient.showMouseMovement(
            from: fromPoint,
            to: to,
            duration: TimeInterval(duration) / 1000.0)
    }

    // MARK: - Accessibility and Focus

    public func hasAccessibilityPermission() async -> Bool {
        self.logger.debug("Checking accessibility permission")
        return AXIsProcessTrusted()
    }

    @MainActor
    public func getFocusedElement() -> UIFocusInfo? {
        self.logger.debug("Getting focused element")

        // Get the system-wide focused element
        let systemWide = AXUIElementCreateSystemWide()

        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement)

        guard result == .success,
              let element = focusedElement
        else {
            self.logger.debug("No focused element found")
            return nil
        }

        let axElement = element as! AXUIElement
        let wrappedElement = Element(axElement)

        // Get element properties
        let role = wrappedElement.role() ?? "Unknown"
        let title = wrappedElement.title()
        let value = wrappedElement.stringValue()
        let frame = wrappedElement.frame() ?? .zero

        // Get application info
        var pid: pid_t = 0
        AXUIElementGetPid(axElement, &pid)

        let app = NSRunningApplication(processIdentifier: pid)
        let appName = app?.localizedName ?? "Unknown"
        let bundleId = app?.bundleIdentifier ?? "Unknown"

        return UIFocusInfo(
            role: role,
            title: title,
            value: value,
            frame: frame,
            applicationName: appName,
            bundleIdentifier: bundleId,
            processId: Int(pid))
    }

    // MARK: - Wait for Element

    public func waitForElement(
        target: ClickTarget,
        timeout: TimeInterval,
        sessionId: String?) async throws -> WaitForElementResult
    {
        self.logger.debug("Waiting for element - target: \(String(describing: target)), timeout: \(timeout)s")

        let startTime = Date()
        let deadline = startTime.addingTimeInterval(timeout)
        let retryInterval: UInt64 = 100_000_000 // 100ms in nanoseconds

        while Date() < deadline {
            // Check if element exists
            switch target {
            case let .elementId(id):
                if let sessionId,
                   let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId),
                   let element = detectionResult.elements.findById(id)
                {
                    let waitTime = Date().timeIntervalSince(startTime)
                    self.logger.debug("Found element \(id) after \(waitTime)s")
                    return WaitForElementResult(found: true, element: element, waitTime: waitTime)
                }

            case let .query(query):
                // Try to find in session first
                if let sessionId,
                   let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId)
                {
                    let queryLower = query.lowercased()
                    for element in detectionResult.elements.all {
                        let matches = element.label?.lowercased().contains(queryLower) ?? false ||
                            element.value?.lowercased().contains(queryLower) ?? false

                        if matches, element.isEnabled {
                            let waitTime = Date().timeIntervalSince(startTime)
                            self.logger.debug("Found element matching '\(query)' after \(waitTime)s")
                            return WaitForElementResult(found: true, element: element, waitTime: waitTime)
                        }
                    }
                }

                // Try direct AX search
                let elementInfo = self.findElementByAccessibility(matching: query)

                if elementInfo != nil {
                    let waitTime = Date().timeIntervalSince(startTime)
                    let detectedElement = DetectedElement(
                        id: "wait_found",
                        type: .other,
                        label: elementInfo?.label ?? query,
                        value: nil,
                        bounds: elementInfo?.frame ?? .zero,
                        isEnabled: true,
                        isSelected: nil,
                        attributes: [:])

                    self.logger.debug("Found element via AX matching '\(query)' after \(waitTime)s")
                    return WaitForElementResult(found: true, element: detectedElement, waitTime: waitTime)
                }

            case .coordinates:
                // Coordinates don't need waiting
                let waitTime = Date().timeIntervalSince(startTime)
                return WaitForElementResult(found: true, element: nil, waitTime: waitTime)
            }

            // Wait before retry
            try await Task.sleep(nanoseconds: retryInterval)
        }

        // Timeout reached
        let waitTime = timeout
        self.logger.debug("Element not found after \(waitTime)s timeout")
        return WaitForElementResult(found: false, element: nil, waitTime: waitTime)
    }

    // MARK: - Private Helpers

    @MainActor
    private func findElementByAccessibility(matching query: String)
    -> (element: Element, frame: CGRect, label: String?)? {
        // Find the application at the mouse position
        guard let app = MouseLocationUtilities.findApplicationAtMouseLocation() else {
            return nil
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)

        return self.searchElementRecursively(in: appElement, matching: query.lowercased())
    }

    @MainActor
    private func searchElementRecursively(
        in element: Element,
        matching query: String) -> (element: Element, frame: CGRect, label: String?)?
    {
        // Check current element
        let title = element.title()?.lowercased() ?? ""
        let label = element.label()?.lowercased() ?? ""
        let value = element.stringValue()?.lowercased() ?? ""
        let roleDescription = element.roleDescription()?.lowercased() ?? ""

        if title.contains(query) || label.contains(query) ||
            value.contains(query) || roleDescription.contains(query)
        {
            if let frame = element.frame() {
                let displayLabel = element.title() ?? element.label() ?? element.roleDescription()
                return (element, frame, displayLabel)
            }
        }

        // Search children
        if let children = element.children() {
            for child in children {
                if let found = searchElementRecursively(in: child, matching: query) {
                    return found
                }
            }
        }

        return nil
    }

    // MARK: - Find Element

    public func findElement(
        matching criteria: UIElementSearchCriteria,
        in appName: String?) async throws -> DetectedElement
    {
        self.logger.debug("Finding element matching criteria in app: \(appName ?? "any")")

        // Capture screenshot
        let captureResult: CaptureResult
        if let appName {
            // Try to find the application first
            let appService = ApplicationService()
            _ = try await appService.findApplication(identifier: appName)

            // Capture specific application
            captureResult = try await self.screenCaptureService.captureWindow(
                appIdentifier: appName,
                windowIndex: nil)
        } else {
            // Capture entire screen
            captureResult = try await self.screenCaptureService.captureScreen(displayIndex: nil)
        }

        // Detect elements in the screenshot
        let detectionResult = try await detectElements(
            in: captureResult.imageData,
            sessionId: nil,
            windowContext: nil)

        // Search for matching element
        let allElements = detectionResult.elements.all

        for element in allElements {
            switch criteria {
            case let .label(searchLabel):
                let searchLower = searchLabel.lowercased()
                if let label = element.label?.lowercased(), label.contains(searchLower) {
                    return element
                }
                if let value = element.value?.lowercased(), value.contains(searchLower) {
                    return element
                }

            case let .identifier(searchId):
                if element.id == searchId {
                    return element
                }

            case let .type(searchType):
                if element.type.rawValue.lowercased() == searchType.lowercased() {
                    return element
                }
            }
        }

        // No matching element found
        let description = switch criteria {
        case let .label(label):
            "with label '\(label)'"
        case let .identifier(id):
            "with ID '\(id)'"
        case let .type(type):
            "of type '\(type)'"
        }

        throw PeekabooError.elementNotFound("element \(description) in \(appName ?? "screen")")
    }
}

// MARK: - Supporting Types

/// Information about a focused UI element for automation
public struct UIFocusInfo: Sendable {
    public let role: String
    public let title: String?
    public let value: String?
    public let frame: CGRect
    public let applicationName: String
    public let bundleIdentifier: String
    public let processId: Int

    public init(
        role: String,
        title: String?,
        value: String?,
        frame: CGRect,
        applicationName: String,
        bundleIdentifier: String,
        processId: Int)
    {
        self.role = role
        self.title = title
        self.value = value
        self.frame = frame
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.processId = processId
    }
}
