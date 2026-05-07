import Foundation
import PeekabooCore
import PeekabooFoundation

struct ImageAnalysisData: Codable {
    let provider: String
    let model: String
    let text: String
}

struct ImageCapturedFile {
    let file: SavedFile
    let observation: ImageObservationDiagnostics
}

struct ImageObservationDiagnostics: Codable {
    let spans: [SeeObservationSpan]
    let warnings: [String]
    let state_snapshot: SeeDesktopStateSnapshotSummary?
    let target: SeeObservationTargetDiagnostics?

    init(timings: ObservationTimings, diagnostics: DesktopObservationDiagnostics) {
        self.spans = timings.spans.map(SeeObservationSpan.init)
        self.warnings = diagnostics.warnings
        self.state_snapshot = diagnostics.stateSnapshot.map(SeeDesktopStateSnapshotSummary.init)
        self.target = diagnostics.target.map(SeeObservationTargetDiagnostics.init)
    }
}

struct ImageCaptureResult: Codable {
    let files: [SavedFile]
    let observations: [ImageObservationDiagnostics]
}

struct ImageAnalyzeResult: Codable {
    let files: [SavedFile]
    let analysis: ImageAnalysisData
    let observations: [ImageObservationDiagnostics]
}

@MainActor
extension ImageCommand {
    func outputResults(_ captures: [ImageCapturedFile]) {
        let output = ImageCaptureResult(
            files: captures.map(\.file),
            observations: captures.map(\.observation)
        )
        if self.jsonOutput {
            outputSuccessCodable(data: output, logger: self.outputLogger)
        } else {
            captures.map(\.file).forEach { print("📸 \(self.describeSavedFile($0))") }
        }
    }

    func outputResultsWithAnalysis(_ captures: [ImageCapturedFile], analysis: ImageAnalysisData) {
        let output = ImageAnalyzeResult(
            files: captures.map(\.file),
            analysis: analysis,
            observations: captures.map(\.observation)
        )
        if self.jsonOutput {
            outputSuccessCodable(data: output, logger: self.outputLogger)
        } else {
            captures.map(\.file).forEach { print("📸 \(self.describeSavedFile($0))") }
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
