import Testing
@testable import PeekabooCore
import Foundation
import CoreGraphics

@Suite("ClickService Tests", .tags(.ui))
struct ClickServiceTests {
    
    @Test("Initialize ClickService")
    func initializeService() async throws {
        let sessionManager = MockSessionManager()
        let service = await ClickService(sessionManager: sessionManager)
        #expect(service != nil)
    }
    
    @Test("Click with coordinates")
    func clickAtCoordinates() async throws {
        let sessionManager = MockSessionManager()
        let service = await ClickService(sessionManager: sessionManager)
        
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
        
        let detectionResult = ElementDetectionResult(
            sessionId: "test-session",
            screenshot: ScreenshotMetadata(
                path: "/tmp/test.png",
                width: 1920,
                height: 1080,
                scaleFactor: 2.0,
                colorSpace: "sRGB"
            ),
            elements: ElementCollection(all: [mockElement]),
            timestamp: Date()
        )
        
        sessionManager.mockDetectionResult = detectionResult
        
        let service = await ClickService(sessionManager: sessionManager)
        
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
        let service = await ClickService(sessionManager: sessionManager)
        
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
        let service = await ClickService(sessionManager: sessionManager)
        
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
        
        let detectionResult = ElementDetectionResult(
            sessionId: "test-session",
            screenshot: ScreenshotMetadata(
                path: "/tmp/test.png",
                width: 1920,
                height: 1080,
                scaleFactor: 2.0,
                colorSpace: "sRGB"
            ),
            elements: ElementCollection(all: [mockElement]),
            timestamp: Date()
        )
        
        sessionManager.mockDetectionResult = detectionResult
        
        let service = await ClickService(sessionManager: sessionManager)
        
        // Should find element by query and click it
        try await service.click(
            target: .query("submit"),
            clickType: .single,
            sessionId: "test-session"
        )
    }
}

// MARK: - Mock Session Manager

private actor MockSessionManager: SessionManagerProtocol {
    var mockDetectionResult: ElementDetectionResult?
    
    func createSession(sessionId: String) async throws {
        // No-op for tests
    }
    
    func getSession(sessionId: String) async throws -> PeekabooSession {
        PeekabooSession(
            sessionId: sessionId,
            createdAt: Date(),
            lastAccessedAt: Date(),
            screenshotCount: 1
        )
    }
    
    func updateLastAccessed(sessionId: String) async throws {
        // No-op for tests
    }
    
    func storeScreenshot(sessionId: String, path: String, metadata: ScreenshotMetadata) async throws {
        // No-op for tests
    }
    
    func storeDetectionResult(sessionId: String, result: ElementDetectionResult) async throws {
        // No-op for tests
    }
    
    func getDetectionResult(sessionId: String) async throws -> ElementDetectionResult? {
        return mockDetectionResult
    }
    
    func cleanupOldSessions(olderThan: TimeInterval) async throws {
        // No-op for tests
    }
    
    func getAllSessions() async throws -> [PeekabooSession] {
        return []
    }
}