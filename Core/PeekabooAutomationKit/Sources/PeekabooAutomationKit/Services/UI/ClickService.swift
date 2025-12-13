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
            // Search through snapshot elements
            let queryLower = query.lowercased()
            for element in detectionResult.elements.all {
                let matches = element.label?.lowercased().contains(queryLower) ?? false ||
                    element.value?.lowercased().contains(queryLower) ?? false ||
                    element.type.rawValue.lowercased().contains(queryLower)

                if matches, element.isEnabled {
                    found = true
                    clickFrame = element.bounds
                    self.logger.debug("Found element in snapshot matching query: \(query)")
                    break
                }
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
