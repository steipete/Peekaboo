import Foundation
import CoreGraphics
import PeekabooCore

// Test-specific type for element detection result
public struct DetectionResult {
    public let elements: DetectedElements
    public let screenshot: Data
    public let metadata: TestDetectionMetadata
    
    public init(elements: DetectedElements, screenshot: Data, metadata: TestDetectionMetadata) {
        self.elements = elements
        self.screenshot = screenshot
        self.metadata = metadata
    }
}

// Test-specific metadata about the detection (different from PeekabooCore's DetectionMetadata)
public struct TestDetectionMetadata {
    public let detectionTime: Date
    public let screenSize: CGSize
    public let scaleFactor: Double
    
    public init(detectionTime: Date, screenSize: CGSize, scaleFactor: Double) {
        self.detectionTime = detectionTime
        self.screenSize = screenSize
        self.scaleFactor = scaleFactor
    }
}