import AppKit
@preconcurrency import AXorcist
import CoreGraphics
import Foundation
import os.log

/// Service for handling click operations
@MainActor
public final class ClickService {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "ClickService")
    private let sessionManager: SessionManagerProtocol

    public init(sessionManager: SessionManagerProtocol? = nil) {
        self.sessionManager = sessionManager ?? SessionManager()
    }

    /// Perform a click operation
    @MainActor
    public func click(target: ClickTarget, clickType: ClickType, sessionId: String?) async throws {
        self.logger.debug("Click requested - target: \(String(describing: target)), type: \(clickType)")

        do {
            switch target {
            case let .elementId(id):
                try await self.clickElementById(id: id, clickType: clickType, sessionId: sessionId)

            case let .coordinates(point):
                try await self.performClick(at: point, clickType: clickType)

            case let .query(query):
                try await self.clickElementByQuery(query: query, clickType: clickType, sessionId: sessionId)
            }
        } catch {
            self.logger.error("Click failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Private Methods

    private func clickElementById(id: String, clickType: ClickType, sessionId: String?) async throws {
        // Get element from session
        if let sessionId,
           let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId),
           let element = detectionResult.elements.findById(id)
        {
            // Click at element center
            let center = CGPoint(x: element.bounds.midX, y: element.bounds.midY)
            try await self.performClick(at: center, clickType: clickType)
            self.logger.debug("Clicked element \(id) at (\(center.x), \(center.y))")
        } else {
            throw NotFoundError.element(id)
        }
    }

    @MainActor
    private func clickElementByQuery(query: String, clickType: ClickType, sessionId: String?) async throws {
        // First try to find in session data if available (much faster)
        var found = false
        var clickFrame: CGRect?

        if let sessionId,
           let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId)
        {
            // Search through session elements
            let queryLower = query.lowercased()
            for element in detectionResult.elements.all {
                let matches = element.label?.lowercased().contains(queryLower) ?? false ||
                    element.value?.lowercased().contains(queryLower) ?? false ||
                    element.type.rawValue.lowercased().contains(queryLower)

                if matches, element.isEnabled {
                    found = true
                    clickFrame = element.bounds
                    self.logger.debug("Found element in session matching query: \(query)")
                    break
                }
            }
        }

        // Fall back to searching through all applications if not found in session
        if !found {
            let elementInfo = self.findElementByQuery(query)
            if let element = elementInfo {
                found = true
                clickFrame = element.frame()
                self.logger.debug("Found element via AX search matching query: \(query)")
            }
        }

        // Perform click if element found
        if found, let frame = clickFrame {
            let center = CGPoint(x: frame.midX, y: frame.midY)
            try await self.performClick(at: center, clickType: clickType)
            self.logger.debug("Clicked element matching '\(query)' at (\(center.x), \(center.y))")
        } else {
            throw NotFoundError.element(query)
        }
    }

    /// Find element by query string
    @MainActor
    private func findElementByQuery(_ query: String) -> Element? {
        let queryLower = query.lowercased()

        // Find the application at the mouse position
        guard let app = MouseLocationUtilities.findApplicationAtMouseLocation() else {
            return nil
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)

        // Search recursively
        return self.searchElement(in: appElement, matching: queryLower)
    }

    @MainActor
    private func searchElement(in element: Element, matching query: String) -> Element? {
        // Check current element
        let title = element.title()?.lowercased() ?? ""
        let label = element.label()?.lowercased() ?? ""
        let value = element.stringValue()?.lowercased() ?? ""
        let roleDescription = element.roleDescription()?.lowercased() ?? ""

        if title.contains(query) || label.contains(query) ||
            value.contains(query) || roleDescription.contains(query)
        {
            return element
        }

        // Search children
        if let children = element.children() {
            for child in children {
                if let found = searchElement(in: child, matching: query) {
                    return found
                }
            }
        }

        return nil
    }

    /// Perform actual click at coordinates
    private func performClick(at point: CGPoint, clickType: ClickType) async throws {
        self.logger.debug("Performing \(clickType) click at (\(point.x), \(point.y))")

        // Create mouse events based on click type
        switch clickType {
        case .single:
            try await self.performSingleClick(at: point, button: .left)
        case .right:
            try await self.performSingleClick(at: point, button: .right)
        case .double:
            try await self.performDoubleClick(at: point)
        }
    }

    private func performSingleClick(at point: CGPoint, button: CGMouseButton) async throws {
        // Move mouse to position
        guard let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: button)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }
        moveEvent.post(tap: .cghidEventTap)

        // Small delay
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Mouse down
        let downType: CGEventType = switch button {
        case .left: .leftMouseDown
        case .right: .rightMouseDown
        case .center: .otherMouseDown
        @unknown default: .leftMouseDown
        }

        guard let downEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: downType,
            mouseCursorPosition: point,
            mouseButton: button)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }
        downEvent.post(tap: .cghidEventTap)

        // Small delay
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Mouse up
        let upType: CGEventType = switch button {
        case .left: .leftMouseUp
        case .right: .rightMouseUp
        case .center: .otherMouseUp
        @unknown default: .leftMouseUp
        }

        guard let upEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: upType,
            mouseCursorPosition: point,
            mouseButton: button)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }
        upEvent.post(tap: .cghidEventTap)
    }

    private func performDoubleClick(at point: CGPoint) async throws {
        // Move to position
        guard let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }
        moveEvent.post(tap: .cghidEventTap)

        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Create double click event
        guard let downEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }

        downEvent.setIntegerValueField(.mouseEventClickState, value: 2)
        downEvent.post(tap: .cghidEventTap)

        guard let upEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }

        upEvent.setIntegerValueField(.mouseEventClickState, value: 2)
        upEvent.post(tap: .cghidEventTap)
    }

    private func performTripleClick(at point: CGPoint) async throws {
        // Move to position
        guard let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }
        moveEvent.post(tap: .cghidEventTap)

        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Create triple click event
        guard let downEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }

        downEvent.setIntegerValueField(.mouseEventClickState, value: 3)
        downEvent.post(tap: .cghidEventTap)

        guard let upEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }

        upEvent.setIntegerValueField(.mouseEventClickState, value: 3)
        upEvent.post(tap: .cghidEventTap)
    }

    private func performForceClick(at point: CGPoint) async throws {
        // Force click is simulated with a longer press
        guard let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }
        moveEvent.post(tap: .cghidEventTap)

        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Mouse down
        guard let downEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }

        // Set pressure for force click
        downEvent.setDoubleValueField(.mouseEventPressure, value: 2.0)
        downEvent.post(tap: .cghidEventTap)

        // Hold for force click duration
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Mouse up
        guard let upEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }
        upEvent.post(tap: .cghidEventTap)
    }
}

// MARK: - Extensions for ClickType

extension ClickType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .single: "single"
        case .right: "right"
        case .double: "double"
        }
    }
}
