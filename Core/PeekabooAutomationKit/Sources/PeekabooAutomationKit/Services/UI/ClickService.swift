import AppKit
@preconcurrency import AXorcist
import CoreGraphics
import Foundation
import os.log
import PeekabooFoundation

/**
 * Specialized click service providing precise mouse interaction capabilities.
 *
 * Handles all types of click operations with intelligent targeting, snapshot integration,
 * and multiple targeting modes. Supports element-based clicking via snapshot cache,
 * coordinate-based clicking, and query-based element discovery.
 *
 * ## Click Types
 * - Single, double, right-click, and middle-click
 * - Coordinate-based and element-based targeting
 * - Query-based element discovery and interaction
 *
 * ## Usage Example
 * ```swift
 * let clickService = ClickService(snapshotManager: snapshotManager)
 *
 * // Click by element ID
 * try await clickService.click(
 *     target: .elementId("B1"),
 *     clickType: .single,
 *     snapshotId: "snapshot_123"
 * )
 *
 * // Click by coordinates
 * try await clickService.click(
 *     target: .coordinates(CGPoint(x: 100, y: 200)),
 *     clickType: .right,
 *     snapshotId: nil
 * )
 * ```
 *
 * - Note: Part of UIAutomationService's specialized service architecture
 * - Since: PeekabooCore 1.0.0
 */
@MainActor
public final class ClickService {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "ClickService")
    private let snapshotManager: any SnapshotManagerProtocol

    public init(snapshotManager: (any SnapshotManagerProtocol)? = nil) {
        self.snapshotManager = snapshotManager ?? SnapshotManager()
    }

    /// Perform a click operation
    @MainActor
    public func click(target: ClickTarget, clickType: ClickType, snapshotId: String?) async throws {
        self.logger.debug("Click requested - target: \(String(describing: target)), type: \(clickType)")

        do {
            switch target {
            case let .elementId(id):
                try await self.clickElementById(id: id, clickType: clickType, snapshotId: snapshotId)

            case let .coordinates(point):
                try await self.performClick(at: point, clickType: clickType)

            case let .query(query):
                try await self.clickElementByQuery(query: query, clickType: clickType, snapshotId: snapshotId)
            }
        } catch {
            self.logger.error("Click failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Private Methods

    private func clickElementById(id: String, clickType: ClickType, snapshotId: String?) async throws {
        // Get element from snapshot
        if let snapshotId,
           let detectionResult = try? await snapshotManager.getDetectionResult(snapshotId: snapshotId),
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
    private func clickElementByQuery(query: String, clickType: ClickType, snapshotId: String?) async throws {
        // First try to find in snapshot data if available (much faster)
        var found = false
        var clickFrame: CGRect?

        if let snapshotId,
           let detectionResult = try? await snapshotManager.getDetectionResult(snapshotId: snapshotId)
        {
            if let match = Self.resolveTargetElement(query: query, in: detectionResult) {
                found = true
                clickFrame = match.bounds
                self.logger.debug("Found element in snapshot matching query: \(query)")
            }
        }

        // Fall back to searching through all applications if not found in snapshot
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

    @MainActor
    static func resolveTargetElement(query: String, in detectionResult: ElementDetectionResult) -> DetectedElement? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let queryLower = trimmed.lowercased()
        guard !queryLower.isEmpty else { return nil }

        var bestMatch: DetectedElement?
        var bestScore = Int.min

        for element in detectionResult.elements.all where element.isEnabled {
            let label = element.label?.lowercased()
            let value = element.value?.lowercased()
            let identifier = element.attributes["identifier"]?.lowercased()
            let title = element.attributes["title"]?.lowercased()
            let description = element.attributes["description"]?.lowercased()
            let role = element.attributes["role"]?.lowercased()

            let candidates = [label, value, identifier, title, description, role].compactMap(\.self)
            guard candidates.contains(where: { $0.contains(queryLower) }) else { continue }

            var score = 0
            if identifier == queryLower { score += 400 }
            if label == queryLower { score += 350 }
            if title == queryLower { score += 300 }
            if value == queryLower { score += 200 }

            if identifier?.contains(queryLower) == true { score += 200 }
            if label?.contains(queryLower) == true { score += 160 }
            if title?.contains(queryLower) == true { score += 120 }
            if value?.contains(queryLower) == true { score += 80 }
            if description?.contains(queryLower) == true { score += 50 }

            if element.type.rawValue.lowercased() == queryLower { score += 40 }
            if element.type == .button { score += 20 }

            if score > bestScore {
                bestScore = score
                bestMatch = element
            }
        }

        return bestMatch
    }

    /// Find element by query string
    @MainActor
    private func findElementByQuery(_ query: String) -> Element? {
        let queryLower = query.lowercased()

        // Find the application at the mouse position
        guard let app = MouseLocationUtilities.findApplicationAtMouseLocation() else {
            return nil
        }

        let axApp = AXApp(app)
        let appElement = axApp.element

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

    /// Perform actual click at coordinates using AXorcist InputDriver.
    private func performClick(at point: CGPoint, clickType: ClickType) async throws {
        self.logger.debug("Performing \(clickType) click at (\(point.x), \(point.y))")

        switch clickType {
        case .single:
            try InputDriver.click(at: point, button: .left, count: 1)
        case .right:
            try InputDriver.click(at: point, button: .right, count: 1)
        case .double:
            try InputDriver.click(at: point, button: .left, count: 2)
        }
    }

    private func performForceClick(at point: CGPoint) async throws {
        try InputDriver.move(to: point)
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        try InputDriver.pressHold(at: point, button: .left, duration: 0.5)
    }
}

// MARK: - Extensions for ClickType

// CustomStringConvertible conformance is now in PeekabooFoundation
