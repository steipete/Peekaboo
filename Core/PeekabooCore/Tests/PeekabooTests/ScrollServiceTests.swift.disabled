import CoreGraphics
import Foundation
import Testing
@testable import PeekabooCore

@Suite("ScrollService Tests", .tags(.ui))
@MainActor
struct ScrollServiceTests {
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
        try await service.scroll(
            direction: .up,
            amount: 5,
            target: nil,
            smooth: false,
            delay: 10,
            sessionId: nil)

        try await service.scroll(
            direction: .down,
            amount: 5,
            target: nil,
            smooth: false,
            delay: 10,
            sessionId: nil)

        try await service.scroll(
            direction: .left,
            amount: 5,
            target: nil,
            smooth: false,
            delay: 10,
            sessionId: nil)

        try await service.scroll(
            direction: .right,
            amount: 5,
            target: nil,
            smooth: false,
            delay: 10,
            sessionId: nil)
    }

    @Test("Scroll amounts")
    func differentScrollAmounts() async throws {
        let service = ScrollService()

        // Test different scroll amounts
        let amounts = [1, 5, 10, 20]

        for amount in amounts {
            try await service.scroll(
                direction: .down,
                amount: amount,
                target: nil,
                smooth: false,
                delay: 10,
                sessionId: nil)
        }
    }

    @Test("Scroll at coordinates")
    func scrollAtSpecificCoordinates() async throws {
        let service = ScrollService()

        // Note: ScrollService doesn't support coordinate-based targets directly
        // It expects element IDs or queries
        try await service.scroll(
            direction: .down,
            amount: 3,
            target: nil, // Scroll at current mouse position
            smooth: false,
            delay: 10,
            sessionId: nil)
    }

    @Test("Scroll up large amount")
    func scrollUpLargeAmount() async throws {
        let service = ScrollService()

        // Simulate scroll to top by scrolling up a large amount
        try await service.scroll(
            direction: .up,
            amount: 50,
            target: nil,
            smooth: false,
            delay: 10,
            sessionId: nil)
    }

    @Test("Scroll down large amount")
    func scrollDownLargeAmount() async throws {
        let service = ScrollService()

        // Simulate scroll to bottom by scrolling down a large amount
        try await service.scroll(
            direction: .down,
            amount: 50,
            target: nil,
            smooth: false,
            delay: 10,
            sessionId: nil)
    }

    @Test("Page-like scrolling")
    func pageLikeScrolling() async throws {
        let service = ScrollService()

        // Simulate page up with larger scroll amount
        try await service.scroll(
            direction: .up,
            amount: 10,
            target: nil,
            smooth: false,
            delay: 10,
            sessionId: nil)

        // Simulate page down with larger scroll amount
        try await service.scroll(
            direction: .down,
            amount: 10,
            target: nil,
            smooth: false,
            delay: 10,
            sessionId: nil)
    }

    @Test("Smooth scroll")
    func smoothScrolling() async throws {
        let service = ScrollService()

        // Test smooth scrolling
        try await service.scroll(
            direction: .down,
            amount: 10,
            target: nil,
            smooth: true,
            delay: 50,
            sessionId: nil)
    }

    @Test("Scroll with element target")
    func scrollInElement() async throws {
        let service = ScrollService()

        // Test scrolling within a specific element
        // In test environment, element may not exist
        do {
            try await service.scroll(
                direction: .down,
                amount: 5,
                target: "scrollable area",
                smooth: false,
                delay: 10,
                sessionId: nil)
        } catch is NotFoundError {
            // Expected in test environment
        }
    }

    @Test("Zero scroll amount")
    func zeroScrollAmount() async throws {
        let service = ScrollService()

        // Should handle zero amount gracefully
        try await service.scroll(
            direction: .down,
            amount: 0,
            target: nil,
            smooth: false,
            delay: 10,
            sessionId: nil)
    }

    @Test("Negative scroll amount")
    func negativeScrollAmount() async throws {
        let service = ScrollService()

        // Negative amounts should be treated as absolute values
        try await service.scroll(
            direction: .up,
            amount: -5,
            target: nil,
            smooth: false,
            delay: 10,
            sessionId: nil)
    }
}
