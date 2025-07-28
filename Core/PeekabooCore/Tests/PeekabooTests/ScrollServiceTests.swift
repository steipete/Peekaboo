import Testing
@testable import PeekabooCore
import Foundation
import CoreGraphics

@Suite("ScrollService Tests", .tags(.ui))
struct ScrollServiceTests {
    
    @Test("Initialize ScrollService")
    func initializeService() async throws {
        let service = await ScrollService()
        #expect(service != nil)
    }
    
    @Test("Scroll directions")
    func scrollInAllDirections() async throws {
        let service = await ScrollService()
        
        // Test scrolling in each direction
        try await service.scroll(
            direction: .up,
            amount: 5,
            target: nil,
            sessionId: nil
        )
        
        try await service.scroll(
            direction: .down,
            amount: 5,
            target: nil,
            sessionId: nil
        )
        
        try await service.scroll(
            direction: .left,
            amount: 5,
            target: nil,
            sessionId: nil
        )
        
        try await service.scroll(
            direction: .right,
            amount: 5,
            target: nil,
            sessionId: nil
        )
    }
    
    @Test("Scroll amounts")
    func differentScrollAmounts() async throws {
        let service = await ScrollService()
        
        // Test different scroll amounts
        let amounts = [1, 5, 10, 20]
        
        for amount in amounts {
            try await service.scroll(
                direction: .down,
                amount: amount,
                target: nil,
                sessionId: nil
            )
        }
    }
    
    @Test("Scroll at coordinates")
    func scrollAtSpecificCoordinates() async throws {
        let service = await ScrollService()
        
        let point = CGPoint(x: 500, y: 500)
        
        try await service.scroll(
            direction: .down,
            amount: 3,
            target: .coordinates(point),
            sessionId: nil
        )
    }
    
    @Test("Scroll to top")
    func scrollToTop() async throws {
        let service = await ScrollService()
        
        try await service.scrollToTop(
            target: nil,
            sessionId: nil
        )
    }
    
    @Test("Scroll to bottom")
    func scrollToBottom() async throws {
        let service = await ScrollService()
        
        try await service.scrollToBottom(
            target: nil,
            sessionId: nil
        )
    }
    
    @Test("Page navigation")
    func pageUpAndDown() async throws {
        let service = await ScrollService()
        
        // Test page up
        try await service.pageUp(
            target: nil,
            sessionId: nil
        )
        
        // Test page down
        try await service.pageDown(
            target: nil,
            sessionId: nil
        )
    }
    
    @Test("Smooth scroll")
    func smoothScrolling() async throws {
        let service = await ScrollService()
        
        // Test smooth scrolling (multiple small scrolls)
        try await service.smoothScroll(
            direction: .down,
            totalAmount: 10,
            target: nil,
            sessionId: nil
        )
    }
    
    @Test("Scroll with element target")
    func scrollInElement() async throws {
        let service = await ScrollService()
        
        // Test scrolling within a specific element
        // In test environment, element may not exist
        do {
            try await service.scroll(
                direction: .down,
                amount: 5,
                target: .query("scrollable area"),
                sessionId: nil
            )
        } catch is NotFoundError {
            // Expected in test environment
        }
    }
    
    @Test("Zero scroll amount")
    func zeroScrollAmount() async throws {
        let service = await ScrollService()
        
        // Should handle zero amount gracefully
        try await service.scroll(
            direction: .down,
            amount: 0,
            target: nil,
            sessionId: nil
        )
    }
    
    @Test("Negative scroll amount")
    func negativeScrollAmount() async throws {
        let service = await ScrollService()
        
        // Negative amounts should be treated as absolute values
        try await service.scroll(
            direction: .up,
            amount: -5,
            target: nil,
            sessionId: nil
        )
    }
}