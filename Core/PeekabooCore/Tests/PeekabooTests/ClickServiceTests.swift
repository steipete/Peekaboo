import Testing
@testable import PeekabooCore
import Foundation
import CoreGraphics

@Suite("ClickService Tests", .tags(.ui))
@MainActor
struct ClickServiceTests {
    
    @Test("Initialize ClickService")
    func initializeService() async throws {
        let sessionManager = MockSessionManager()
        let service = ClickService(sessionManager: sessionManager)
        #expect(service != nil)
    }
    
    @Test("Click with coordinates")
    func clickAtCoordinates() async throws {
        let sessionManager = MockSessionManager()
        let service = ClickService(sessionManager: sessionManager)
        
        let point = CGPoint(x: 100, y: 100)
        
        // This will attempt to click at the coordinates
        // In a test environment, we can't verify the actual click happened,
        // but we can verify no errors are thrown
        try await service.click(
            target: .coordinates(point),
            clickType: .single,
            sessionId: nil
        )
    }
    
    @Test("Click element by ID with session")
    func clickElementById() async throws {
        let sessionManager = MockSessionManager()
        
        // Create mock detection result
        let mockElement = DetectedElement(
            id: "test-button",
            type: .button,
            bounds: CGRect(x: 50, y: 50, width: 100, height: 50),
            label: "Test Button",
            value: nil,
            level: 0,
            isEnabled: true,
            keyboardShortcut: nil
        )
        
        let detectedElements = DetectedElements(
            buttons: [mockElement]
        )
        
        let detectionResult = ElementDetectionResult(
            sessionId: "test-session",
            screenshotPath: "/tmp/test.png",
            elements: detectedElements,
            metadata: DetectionMetadata(
                detectionTime: 0.1,
                elementCount: 1,
                method: "AXorcist"
            )
        )
        
        sessionManager.mockDetectionResult = detectionResult
        
        let service = ClickService(sessionManager: sessionManager)
        
        // Should find element in session and click at its center
        try await service.click(
            target: .elementId("test-button"),
            clickType: .single,
            sessionId: "test-session"
        )
    }
    
    @Test("Click element by ID not found")
    func clickElementByIdNotFound() async throws {
        let sessionManager = MockSessionManager()
        let service = ClickService(sessionManager: sessionManager)
        
        // Should throw NotFoundError when element doesn't exist
        await #expect(throws: NotFoundError.self) {
            try await service.click(
                target: .elementId("non-existent"),
                clickType: .single,
                sessionId: nil
            )
        }
    }
    
    @Test("Click types")
    func differentClickTypes() async throws {
        let sessionManager = MockSessionManager()
        let service = ClickService(sessionManager: sessionManager)
        
        let point = CGPoint(x: 100, y: 100)
        
        // Test single click
        try await service.click(
            target: .coordinates(point),
            clickType: .single,
            sessionId: nil
        )
        
        // Test right click
        try await service.click(
            target: .coordinates(point),
            clickType: .right,
            sessionId: nil
        )
        
        // Test double click
        try await service.click(
            target: .coordinates(point),
            clickType: .double,
            sessionId: nil
        )
    }
    
    @Test("Click element by query")
    func clickElementByQuery() async throws {
        let sessionManager = MockSessionManager()
        
        // Create mock detection result with searchable element
        let mockElement = DetectedElement(
            id: "submit-btn",
            type: .button,
            bounds: CGRect(x: 100, y: 100, width: 80, height: 40),
            label: "Submit Form",
            value: nil,
            level: 0,
            isEnabled: true,
            keyboardShortcut: nil
        )
        
        let detectedElements = DetectedElements(
            buttons: [mockElement]
        )
        
        let detectionResult = ElementDetectionResult(
            sessionId: "test-session",
            screenshotPath: "/tmp/test.png",
            elements: detectedElements,
            metadata: DetectionMetadata(
                detectionTime: 0.1,
                elementCount: 1,
                method: "AXorcist"
            )
        )
        
        sessionManager.mockDetectionResult = detectionResult
        
        let service = ClickService(sessionManager: sessionManager)
        
        // Should find element by query and click it
        try await service.click(
            target: .query("submit"),
            clickType: .single,
            sessionId: "test-session"
        )
    }
}

// MARK: - Mock Session Manager

@MainActor
private final class MockSessionManager: SessionManagerProtocol {
    var mockDetectionResult: ElementDetectionResult?
    
    func createSession() async throws -> String {
        return "test-session-\(UUID().uuidString)"
    }
    
    func storeDetectionResult(sessionId: String, result: ElementDetectionResult) async throws {
        // No-op for tests
    }
    
    func getDetectionResult(sessionId: String) async throws -> ElementDetectionResult? {
        return mockDetectionResult
    }
    
    func getMostRecentSession() async -> String? {
        return nil
    }
    
    func listSessions() async throws -> [SessionInfo] {
        return []
    }
    
    func cleanSession(sessionId: String) async throws {
        // No-op for tests
    }
    
    func cleanSessionsOlderThan(days: Int) async throws -> Int {
        return 0
    }
    
    func cleanAllSessions() async throws -> Int {
        return 0
    }
}