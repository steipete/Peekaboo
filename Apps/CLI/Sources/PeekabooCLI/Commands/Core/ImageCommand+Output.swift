import Foundation
import PeekabooCore
import PeekabooFoundation

struct ImageAnalysisData: Codable {
    let provider: String
    let model: String
    let text: String
}

struct ImageCaptureResult: Codable {
    let files: [SavedFile]
}

struct ImageAnalyzeResult: Codable {
    let files: [SavedFile]
    let analysis: ImageAnalysisData
}

@MainActor
extension ImageCommand {
    func outputResults(_ files: [SavedFile]) {
        let output = ImageCaptureResult(files: files)
        if self.jsonOutput {
            outputSuccessCodable(data: output, logger: self.outputLogger)
        } else {
            files.forEach { print("📸 \(self.describeSavedFile($0))") }
        }
    }

    func outputResultsWithAnalysis(_ files: [SavedFile], analysis: ImageAnalysisData) {
        let output = ImageAnalyzeResult(files: files, analysis: analysis)
        if self.jsonOutput {
            outputSuccessCodable(data: output, logger: self.outputLogger)
        } else {
            files.forEach { print("📸 \(self.describeSavedFile($0))") }
            print("\n🤖 Analysis (\(analysis.provider)) - \(analysis.model):")
            print(analysis.text)
        }
    }

    func analyzeImage(at path: String, with prompt: String) async throws -> ImageAnalysisData {
        let aiService = PeekabooAIService()
        let response = try await aiService.analyzeImageFileDetailed(at: path, question: prompt, model: nil)
        return ImageAnalysisData(provider: response.provider, model: response.model, text: response.text)
    }

    private func describeSavedFile(_ file: SavedFile) -> String {
        var segments: [String] = []
        if let label = file.item_label ?? file.window_title {
            segments.append(label)
        } else if let index = file.window_index {
            segments.append("window \(index)")
        }
        segments.append("→ \(file.path)")
        return segments.joined(separator: " ")
    }
}

extension ImageFormat {
    var fileExtension: String {
        switch self {
        case .png: "png"
        case .jpg: "jpg"
        }
    }

    var mimeType: String {
        switch self {
        case .png: "image/png"
        case .jpg: "image/jpeg"
        }
    }
}
