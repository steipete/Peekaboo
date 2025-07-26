import Foundation

// Test-specific type for element detection result
public struct DetectionResult {
    public let elements: [DetectedElement]
    public let sessionId: String
    
    public init(elements: [DetectedElement], sessionId: String) {
        self.elements = elements
        self.sessionId = sessionId
    }
}