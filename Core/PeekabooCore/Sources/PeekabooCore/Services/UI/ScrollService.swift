import AppKit
@preconcurrency import AXorcist
import CoreGraphics
import Foundation
import os.log
import PeekabooFoundation

/// Service for handling scroll operations
@MainActor
public final class ScrollService {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "ScrollService")
    private let sessionManager: SessionManagerProtocol
    private let clickService: ClickService

    public init(sessionManager: SessionManagerProtocol? = nil, clickService: ClickService? = nil) {
        let manager = sessionManager ?? SessionManager()
        self.sessionManager = manager
        self.clickService = clickService ?? ClickService(sessionManager: manager)
    }

    /// Perform scroll operation
    @MainActor
    public func scroll(
        direction: PeekabooFoundation.ScrollDirection,
        amount: Int,
        target: String?,
        smooth: Bool,
        delay: Int,
        sessionId: String?) async throws
    {
        self.logger.debug("Scroll requested - direction: \(direction), amount: \(amount), smooth: \(smooth)")

        let scrollPoint: CGPoint

        // If target specified, scroll on that element
        if let target {
            var elementFrame: CGRect?

            // Try to find element by ID first
            if let sessionId,
               let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId),
               let element = detectionResult.elements.findById(target)
            {
                elementFrame = element.bounds
            }

            // If not found by ID, search by query
            if elementFrame == nil {
                elementFrame = try await self.findElementFrame(query: target, sessionId: sessionId)
            }

            guard let frame = elementFrame else {
                throw NotFoundError.element(target)
            }

            // Use center of element as scroll point
            scrollPoint = CGPoint(x: frame.midX, y: frame.midY)
            self.logger.debug("Scrolling on element at (\(scrollPoint.x), \(scrollPoint.y))")

            // Move mouse to element first
            try await self.moveMouseToPoint(scrollPoint)
        } else {
            // Use current mouse location
            scrollPoint = self.getCurrentMouseLocation()
            self.logger.debug("Scrolling at current location: (\(scrollPoint.x), \(scrollPoint.y))")
        }

        // Perform scroll
        let (deltaX, deltaY) = self.getScrollDeltas(for: direction)

        // Ensure amount is positive
        let absoluteAmount = abs(amount)

        // Calculate ticks based on smoothness
        let (tickCount, tickSize): (Int, Int) = if smooth {
            // Smooth scroll with many small ticks
            (absoluteAmount * 10, 1)
        } else {
            // Normal scroll with fewer larger ticks
            (absoluteAmount, 10)
        }

        self.logger.debug("Scrolling \(tickCount) ticks of size \(tickSize)")

        // Perform scroll events
        for i in 0..<tickCount {
            guard let scrollEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 2,
                wheel1: Int32(deltaY * tickSize),
                wheel2: Int32(deltaX * tickSize),
                wheel3: 0)
            else {
                throw PeekabooError.operationError(message: "Failed to create scroll event")
            }

            scrollEvent.location = scrollPoint
            scrollEvent.post(tap: .cghidEventTap)

            // Delay between scroll ticks
            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
            } else if smooth {
                // Small delay for smooth scrolling
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }

            // Log progress periodically
            if i % 10 == 0 {
                self.logger.debug("Scroll progress: \(i)/\(tickCount)")
            }
        }

        self.logger.debug("Scroll completed")
    }

    // MARK: - Private Methods

    private func getScrollDeltas(for direction: PeekabooFoundation.ScrollDirection) -> (deltaX: Int, deltaY: Int) {
        switch direction {
        case .up:
            (0, 5)
        case .down:
            (0, -5)
        case .left:
            (5, 0)
        case .right:
            (-5, 0)
        }
    }

    @MainActor
    private func findElementFrame(query: String, sessionId: String?) async throws -> CGRect? {
        // Search in session first
        if let sessionId,
           let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId)
        {
            let queryLower = query.lowercased()

            for element in detectionResult.elements.all {
                let matches = element.label?.lowercased().contains(queryLower) ?? false ||
                    element.value?.lowercased().contains(queryLower) ?? false

                if matches, element.isEnabled {
                    return element.bounds
                }
            }
        }

        // Fall back to AX search
        if let element = findScrollableElement(matching: query) {
            return element.frame()
        }

        return nil
    }

    @MainActor
    private func findScrollableElement(matching query: String) -> Element? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let axApp = AXUIElementCreateApplication(frontApp.processIdentifier)
        let appElement = Element(axApp)

        return self.searchScrollableElement(in: appElement, matching: query.lowercased())
    }

    @MainActor
    private func searchScrollableElement(in element: Element, matching query: String) -> Element? {
        // Check current element
        let title = element.title()?.lowercased() ?? ""
        let label = element.label()?.lowercased() ?? ""
        let roleDescription = element.roleDescription()?.lowercased() ?? ""

        if title.contains(query) || label.contains(query) || roleDescription.contains(query) {
            // Check if scrollable
            let role = element.role()?.lowercased() ?? ""
            if role.contains("scroll") || role.contains("list") || role.contains("table") ||
                role.contains("outline") || role.contains("text")
            {
                return element
            }
        }

        // Search children
        if let children = element.children() {
            for child in children {
                if let found = searchScrollableElement(in: child, matching: query) {
                    return found
                }
            }
        }

        return nil
    }

    private func getCurrentMouseLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? CGPoint.zero
    }

    private func moveMouseToPoint(_ point: CGPoint) async throws {
        guard let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left)
        else {
            throw PeekabooError.operationError(message: "Failed to create move event")
        }

        moveEvent.post(tap: .cghidEventTap)

        // Small delay after move
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }
}

// MARK: - Extensions

// CustomStringConvertible conformance is now in PeekabooFoundation
