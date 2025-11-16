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
    private let sessionManager: any SessionManagerProtocol
    private let clickService: ClickService

    public init(sessionManager: (any SessionManagerProtocol)? = nil, clickService: ClickService? = nil) {
        let manager = sessionManager ?? SessionManager()
        self.sessionManager = manager
        self.clickService = clickService ?? ClickService(sessionManager: manager)
    }

    /// Perform scroll operation
    @MainActor
    public func scroll(_ request: ScrollRequest) async throws {
        let description =
            "Scroll requested - direction: \(request.direction), amount: \(request.amount), " +
            "smooth: \(request.smooth)"
        self.logger.debug("\(description, privacy: .public)")

        let scrollPoint = try await self.resolveScrollPoint(request)
        let (deltaX, deltaY) = self.getScrollDeltas(for: request.direction)
        let context = ScrollExecutionContext(
            startingPoint: scrollPoint,
            deltas: (deltaX, deltaY),
            amount: request.amount,
            smooth: request.smooth,
            delay: request.delay)

        try await self.performScroll(context)
        self.logger.debug("Scroll completed")
    }

    private func resolveScrollPoint(_ request: ScrollRequest) async throws -> CGPoint {
        guard let target = request.target else {
            let location = self.getCurrentMouseLocation()
            self.logger.debug(
                "Scrolling at current location: (\(location.x, privacy: .public), \(location.y, privacy: .public))")
            return location
        }

        if let sessionPoint = try await self.lookupElementCenter(target: target, sessionId: request.sessionId) {
            try await self.moveMouseToPoint(sessionPoint)
            return sessionPoint
        }

        guard let frame = try await self.findElementFrame(query: target, sessionId: request.sessionId) else {
            throw NotFoundError.element(target)
        }

        let point = CGPoint(x: frame.midX, y: frame.midY)
        try await self.moveMouseToPoint(point)
        self.logger.debug(
            "Scrolling on element at (\(point.x, privacy: .public), \(point.y, privacy: .public))")
        return point
    }

    private func lookupElementCenter(target: String, sessionId: String?) async throws -> CGPoint? {
        guard let sessionId,
              let detectionResult = try? await self.sessionManager.getDetectionResult(sessionId: sessionId),
              let element = detectionResult.elements.findById(target)
        else {
            return nil
        }

        return CGPoint(x: element.bounds.midX, y: element.bounds.midY)
    }

    private func performScroll(_ context: ScrollExecutionContext) async throws {
        let absoluteAmount = abs(context.amount)
        let (tickCount, tickSize) = self.tickConfiguration(amount: absoluteAmount, smooth: context.smooth)
        self.logger.debug("Scrolling \(tickCount, privacy: .public) ticks of size \(tickSize, privacy: .public)")

        for tick in 0..<tickCount {
            try self.postScrollTick(context: context, tickSize: tickSize)
            try await self.sleepBetweenTicks(context: context)
            if tick % 10 == 0 {
                self.logger.debug("Scroll progress: \(tick)/\(tickCount)")
            }
        }
    }

    private func postScrollTick(context: ScrollExecutionContext, tickSize: Int) throws {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(context.deltas.deltaY * tickSize),
            wheel2: Int32(context.deltas.deltaX * tickSize),
            wheel3: 0)
        else {
            throw PeekabooError.operationError(message: "Failed to create scroll event")
        }

        event.location = context.startingPoint
        event.post(tap: .cghidEventTap)
    }

    private func sleepBetweenTicks(context: ScrollExecutionContext) async throws {
        if context.delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(context.delay) * 1_000_000)
        } else if context.smooth {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func tickConfiguration(amount: Int, smooth: Bool) -> (count: Int, size: Int) {
        if smooth {
            return (amount * 10, 1)
        }

        return (amount, 10)
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
                let identifierMatch = element.attributes["identifier"]?.lowercased().contains(queryLower) ?? false
                let matches = element.label?.lowercased().contains(queryLower) ?? false ||
                    element.value?.lowercased().contains(queryLower) ?? false ||
                    identifierMatch

                if matches {
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

private struct ScrollExecutionContext {
    let startingPoint: CGPoint
    let deltas: (deltaX: Int, deltaY: Int)
    let amount: Int
    let smooth: Bool
    let delay: Int
}

// MARK: - Extensions

// CustomStringConvertible conformance is now in PeekabooFoundation
