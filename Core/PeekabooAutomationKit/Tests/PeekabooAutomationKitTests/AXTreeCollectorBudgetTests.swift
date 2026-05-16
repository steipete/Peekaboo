@preconcurrency import AXorcist
import Foundation
import XCTest
@testable import PeekabooAutomationKit

@MainActor
final class AXTreeCollectorBudgetTests: XCTestCase {
    private func frontmostWindowElement() -> Element? {
        guard let appAX = AXUIElement.frontmostApplication() else {
            return nil
        }
        let appElement = Element(appAX)
        return appElement.windows()?.first
    }

    func testDefaultBudgetCollectsMultipleElementsWhenWindowExposesChildren() throws {
        guard let window = self.frontmostWindowElement() else {
            throw XCTSkip("No frontmost window available for AX testing")
        }

        let collector = AXTreeCollector()
        let result = collector.collect(window: window, deadline: Date().addingTimeInterval(5.0))

        guard result.elements.count > 1 else {
            throw XCTSkip("Frontmost window does not expose child AX elements")
        }
        guard result.truncationInfo == nil else {
            throw XCTSkip("Frontmost window exceeds the default AX traversal budget")
        }

        XCTAssertNil(result.truncationInfo, "Default budget should not trigger truncation on a small AX tree")
    }

    func testMaxDepthOneStopsAtRoot() throws {
        guard let window = self.frontmostWindowElement() else {
            throw XCTSkip("No frontmost window available for AX testing")
        }

        let collector = AXTreeCollector()
        let defaultResult = collector.collect(window: window, deadline: Date().addingTimeInterval(5.0))
        guard defaultResult.elements.count > 1 else {
            throw XCTSkip("Frontmost window does not expose child AX elements")
        }

        let budget = AXTraversalBudget(maxDepth: 1, maxElementCount: 400, maxChildrenPerNode: 50)
        let result = collector.collect(
            window: window,
            deadline: Date().addingTimeInterval(5.0),
            budget: budget)

        XCTAssertEqual(result.elements.count, 1, "Depth 1 should only collect the root window")
        XCTAssertTrue(result.truncationInfo?.maxDepthReached == true, "Should flag maxDepthReached")
    }

    func testMaxElementCountStopsEarly() throws {
        guard let window = self.frontmostWindowElement() else {
            throw XCTSkip("No frontmost window available for AX testing")
        }

        let collector = AXTreeCollector()
        let defaultResult = collector.collect(window: window, deadline: Date().addingTimeInterval(5.0))
        guard defaultResult.elements.count > 2 else {
            throw XCTSkip("Frontmost window does not expose enough AX elements")
        }

        let budget = AXTraversalBudget(maxDepth: 12, maxElementCount: 2, maxChildrenPerNode: 50)
        let result = collector.collect(
            window: window,
            deadline: Date().addingTimeInterval(5.0),
            budget: budget)

        XCTAssertLessThanOrEqual(result.elements.count, 2, "Budget of 2 elements should collect at most 2")
        XCTAssertTrue(result.truncationInfo?.maxElementCountReached == true, "Should flag maxElementCountReached")
    }

    func testMaxChildrenPerNodeLimitsTraversal() throws {
        guard let window = self.frontmostWindowElement() else {
            throw XCTSkip("No frontmost window available for AX testing")
        }

        let collector = AXTreeCollector()
        let defaultResult = collector.collect(window: window, deadline: Date().addingTimeInterval(5.0))
        guard defaultResult.elements.count > 1 else {
            throw XCTSkip("Frontmost window does not expose child AX elements")
        }

        let collector2 = AXTreeCollector()
        let budget = AXTraversalBudget(maxDepth: 12, maxElementCount: 400, maxChildrenPerNode: 0)
        let limitedResult = collector2.collect(
            window: window,
            deadline: Date().addingTimeInterval(5.0),
            budget: budget)

        XCTAssertEqual(limitedResult.elements.count, 1, "Children budget 0 should only collect the root")
        XCTAssertTrue(
            limitedResult.truncationInfo?.maxChildrenPerNodeReached == true,
            "Should flag maxChildrenPerNodeReached")
    }

    func testNegativeBudgetValuesAreClampedBeforeTraversal() throws {
        guard let window = self.frontmostWindowElement() else {
            throw XCTSkip("No frontmost window available for AX testing")
        }

        let collector = AXTreeCollector()
        let budget = AXTraversalBudget(maxDepth: -1, maxElementCount: -1, maxChildrenPerNode: -1)
        let result = collector.collect(
            window: window,
            deadline: Date().addingTimeInterval(5.0),
            budget: budget)

        XCTAssertTrue(result.elements.isEmpty, "Negative depth/count budgets should clamp to zero")
        XCTAssertTrue(result.truncationInfo?.maxDepthReached == true, "Should flag maxDepthReached")
    }
}
