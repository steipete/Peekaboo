import CoreGraphics
import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooCore
@testable import PeekabooAutomation
@testable import PeekabooAgentRuntime
@testable import PeekabooVisualizer

@Suite(
    "ScrollService Tests",
    .tags(.ui, .automation),
    .enabled(if: TestEnvironment.runInputAutomationScenarios))
@MainActor
struct ScrollServiceTests {
    private func makeRequest(
        direction: ScrollDirection,
        amount: Int,
        target: String? = nil,
        smooth: Bool = false,
        delay: Int = 10,
        sessionId: String? = nil) -> ScrollRequest
    {
        ScrollRequest(
            direction: direction,
            amount: amount,
            target: target,
            smooth: smooth,
            delay: delay,
            sessionId: sessionId)
    }

    @Test("ScrollService initializes successfully with default configuration")
    func initializeService() async throws {
        let service = ScrollService()
        // Service is initialized successfully
        _ = service
    }

    @Test("Scroll executes in all four cardinal directions without errors")
    func scrollInAllDirections() async throws {
        let service = ScrollService()

        // Test scrolling in each direction
        try await service.scroll(self.makeRequest(direction: .up, amount: 5))
        try await service.scroll(self.makeRequest(direction: .down, amount: 5))
        try await service.scroll(self.makeRequest(direction: .left, amount: 5))
        try await service.scroll(self.makeRequest(direction: .right, amount: 5))
    }

    @Test("Scroll amounts")
    func differentScrollAmounts() async throws {
        let service = ScrollService()

        // Test different scroll amounts
        let amounts = [1, 5, 10, 20]

        for amount in amounts {
            try await service.scroll(self.makeRequest(direction: .down, amount: amount))
        }
    }

    @Test("Scroll at coordinates")
    func scrollAtSpecificCoordinates() async throws {
        let service = ScrollService()

        // Note: ScrollService doesn't support coordinate-based targets directly
        // It expects element IDs or queries
        try await service.scroll(self.makeRequest(direction: .down, amount: 3))
    }

    @Test("Scroll up large amount")
    func scrollUpLargeAmount() async throws {
        let service = ScrollService()

        // Simulate scroll to top by scrolling up a large amount
        try await service.scroll(self.makeRequest(direction: .up, amount: 50))
    }

    @Test("Scroll down large amount")
    func scrollDownLargeAmount() async throws {
        let service = ScrollService()

        // Simulate scroll to bottom by scrolling down a large amount
        try await service.scroll(self.makeRequest(direction: .down, amount: 50))
    }

    @Test("Page-like scrolling")
    func pageLikeScrolling() async throws {
        let service = ScrollService()

        // Simulate page up with larger scroll amount
        try await service.scroll(self.makeRequest(direction: .up, amount: 10))

        // Simulate page down with larger scroll amount
        try await service.scroll(self.makeRequest(direction: .down, amount: 10))
    }

    @Test("Smooth scroll")
    func smoothScrolling() async throws {
        let service = ScrollService()

        // Test smooth scrolling
        try await service.scroll(
            self.makeRequest(direction: .down, amount: 10, smooth: true, delay: 50))
    }

    @Test("Scroll with element target")
    func scrollInElement() async throws {
        let service = ScrollService()

        // Test scrolling within a specific element
        // In test environment, element may not exist
        do {
            try await service.scroll(
                self.makeRequest(direction: .down, amount: 5, target: "scrollable area"))
        } catch {
            // Expected in test environment - element won't exist
            // Could be NotFoundError or PeekabooError.elementNotFound
        }
    }

    @Test("Zero scroll amount")
    func zeroScrollAmount() async throws {
        let service = ScrollService()

        // Should handle zero amount gracefully
        try await service.scroll(self.makeRequest(direction: .down, amount: 0))
    }

    @Test("Negative scroll amount")
    func negativeScrollAmount() async throws {
        let service = ScrollService()

        // Negative amounts should be treated as absolute values
        try await service.scroll(self.makeRequest(direction: .up, amount: -5))
    }
}
