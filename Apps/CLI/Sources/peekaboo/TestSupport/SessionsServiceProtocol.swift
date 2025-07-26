import Foundation

// Test-specific protocol for session management
public protocol SessionsServiceProtocol: Sendable {
    func create(screenshot: Data) async throws -> DetectionResult
    func get(sessionId: String) async throws -> DetectionResult
    func find(elementId: String, in sessionId: String) async throws -> DetectedElement?
    func findElementByText(_ text: String, in sessionId: String) async throws -> AXElement?
}