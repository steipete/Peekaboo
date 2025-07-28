import Testing
@testable import PeekabooCore
import Foundation
import CoreGraphics

@Suite("GestureService Tests", .tags(.ui))
struct GestureServiceTests {
    
    @Test("Initialize GestureService")
    func initializeService() async throws {
        let service = GestureService()
        #expect(service != nil)
    }
    
    @Test("Move mouse to position")
    func moveMouseToPosition() async throws {
        let service = GestureService()
        
        // Test moving mouse to various positions
        let positions = [
            CGPoint(x: 0, y: 0),        // Top-left
            CGPoint(x: 100, y: 100),
            CGPoint(x: 500, y: 300),
            CGPoint(x: 1000, y: 600),
        ]
        
        for position in positions {
            try await service.moveMouse(to: position)
        }
    }
    
    @Test("Drag from point to point")
    func dragBetweenPoints() async throws {
        let service = GestureService()
        
        let start = CGPoint(x: 100, y: 100)
        let end = CGPoint(x: 500, y: 500)
        
        try await service.drag(from: start, to: end)
    }
    
    @Test("Drag with duration")
    func dragWithCustomDuration() async throws {
        let service = GestureService()
        
        let start = CGPoint(x: 200, y: 200)
        let end = CGPoint(x: 600, y: 400)
        
        let startTime = Date()
        try await service.drag(from: start, to: end, duration: 1.0)  // 1 second drag
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Should take approximately 1 second
        #expect(elapsed >= 0.9 && elapsed <= 1.2)
    }
    
    @Test("Swipe gestures")
    func swipeInAllDirections() async throws {
        let service = GestureService()
        
        let center = CGPoint(x: 500, y: 500)
        
        // Test swipes in all directions
        try await service.swipe(direction: .left, at: center)
        try await service.swipe(direction: .right, at: center)
        try await service.swipe(direction: .up, at: center)
        try await service.swipe(direction: .down, at: center)
    }
    
    @Test("Swipe with custom distance")
    func swipeWithDistance() async throws {
        let service = GestureService()
        
        let center = CGPoint(x: 500, y: 500)
        let distances: [CGFloat] = [50, 100, 200, 400]
        
        for distance in distances {
            try await service.swipe(
                direction: .right,
                at: center,
                distance: distance
            )
        }
    }
    
    @Test("Pinch gesture")
    func pinchGesture() async throws {
        let service = GestureService()
        
        let center = CGPoint(x: 500, y: 500)
        
        // Test pinch in (zoom out)
        try await service.pinch(
            at: center,
            scale: 0.5,     // Pinch in to 50%
            duration: 0.5
        )
        
        // Test pinch out (zoom in)
        try await service.pinch(
            at: center,
            scale: 2.0,     // Pinch out to 200%
            duration: 0.5
        )
    }
    
    @Test("Rotate gesture")
    func rotateGesture() async throws {
        let service = GestureService()
        
        let center = CGPoint(x: 500, y: 500)
        
        // Test various rotation angles
        let angles: [CGFloat] = [45, 90, 180, -45, -90]
        
        for angle in angles {
            try await service.rotate(
                at: center,
                angle: angle,
                duration: 0.5
            )
        }
    }
    
    @Test("Multi-touch tap")
    func multiTouchTap() async throws {
        let service = GestureService()
        
        let points = [
            CGPoint(x: 300, y: 300),
            CGPoint(x: 400, y: 300),
            CGPoint(x: 350, y: 400)
        ]
        
        // Simulate three-finger tap
        try await service.multiTouchTap(at: points)
    }
    
    @Test("Long press")
    func longPress() async throws {
        let service = GestureService()
        
        let point = CGPoint(x: 500, y: 500)
        
        let startTime = Date()
        try await service.longPress(at: point, duration: 1.0)
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Should hold for approximately 1 second
        #expect(elapsed >= 0.9)
    }
    
    @Test("Complex gesture sequence")
    func complexGestureSequence() async throws {
        let service = GestureService()
        
        // Simulate a complex interaction sequence
        let startPoint = CGPoint(x: 100, y: 100)
        let midPoint = CGPoint(x: 300, y: 300)
        let endPoint = CGPoint(x: 500, y: 500)
        
        // Move to start
        try await service.moveMouse(to: startPoint)
        
        // Drag to middle
        try await service.drag(from: startPoint, to: midPoint, duration: 0.5)
        
        // Continue drag to end
        try await service.drag(from: midPoint, to: endPoint, duration: 0.5)
        
        // Swipe back
        try await service.swipe(direction: .left, at: endPoint, distance: 200)
    }
    
    @Test("Hover gesture")
    func hoverOverPoint() async throws {
        let service = GestureService()
        
        let hoverPoint = CGPoint(x: 400, y: 400)
        
        // Move to point and hover
        try await service.hover(at: hoverPoint, duration: 0.5)
    }
}