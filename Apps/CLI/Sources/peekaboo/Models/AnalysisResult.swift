import Foundation

/// Result of an image analysis operation
public struct AnalysisResult: Codable {
    public let analysisText: String
    public let modelUsed: String
    public let durationSeconds: Double?
    public let imagePath: String?
    
    public init(analysisText: String, modelUsed: String, durationSeconds: Double? = nil, imagePath: String? = nil) {
        self.analysisText = analysisText
        self.modelUsed = modelUsed
        self.durationSeconds = durationSeconds
        self.imagePath = imagePath
    }
}