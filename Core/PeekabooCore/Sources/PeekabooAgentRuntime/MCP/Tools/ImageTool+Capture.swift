import Foundation
import MCP
import PeekabooAutomation
import PeekabooAutomationKit
import PeekabooFoundation
import TachikomaMCP

struct ImageCaptureSet {
    let captures: [CaptureResult]
    let observation: DesktopObservationResult?
}

extension ImageTool {
    func captureImages(for request: ImageRequest) async throws -> ImageCaptureSet {
        switch request.target {
        case .menubar:
            let observation = try await self.captureObservation(for: request)
            return ImageCaptureSet(captures: [observation.capture], observation: observation)
        default:
            let result = try await self.captureObservation(for: request)
            return ImageCaptureSet(captures: [result.capture], observation: result)
        }
    }

    func captureObservation(for request: ImageRequest) async throws -> DesktopObservationResult {
        if request.captureFocus == .foreground, let identifier = request.focusIdentifier {
            try await self.context.applications.activateApplication(identifier: identifier)
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        return try await self.context.desktopObservation.observe(DesktopObservationRequest(
            target: request.target.observationTarget,
            capture: DesktopCaptureOptions(
                scale: request.scale,
                focus: request.captureFocus,
                visualizerMode: .screenshotFlash),
            detection: DesktopDetectionOptions(mode: .none),
            output: DesktopObservationOutputOptions(
                path: request.outputPath,
                format: request.format.imageFormat,
                saveRawScreenshot: request.outputPath != nil)))
    }

    func savedFiles(for captureSet: ImageCaptureSet, request: ImageRequest) throws -> [MCPSavedFile] {
        guard request.outputPath != nil else { return [] }
        guard let result = captureSet.captures.first else { return [] }
        guard let path = captureSet.observation?.files.rawScreenshotPath else {
            throw OperationError.captureFailed(reason: "Observation completed without a saved screenshot path")
        }

        return [
            MCPSavedFile(
                path: path,
                item_label: describeCapture(result.metadata),
                window_title: result.metadata.windowInfo?.title,
                window_id: result.metadata.windowInfo.map { String($0.windowID) },
                window_index: result.metadata.windowInfo?.index,
                mime_type: request.format.mimeType),
        ]
    }

    func performAnalysis(
        question: String,
        savedFiles: [MCPSavedFile],
        captureResults: [CaptureResult],
        observation: DesktopObservationResult?) async throws -> ToolResponse
    {
        guard let firstCapture = captureResults.first else {
            throw OperationError.captureFailed(reason: "No capture data available")
        }

        let imagePath = try savedFiles.first?.path ?? saveTemporaryImage(firstCapture.imageData)
        let analysis = try await analyzeImage(at: imagePath, question: question)
        let baseMeta = ObservationDiagnosticsMetadata.merge(observation, into: .object([
            "model": .string(analysis.modelUsed),
            "savedFiles": .array(savedFiles.map { Value.string($0.path) }),
            "question": .string(question),
        ]))
        let summary = ToolEventSummary(
            actionDescription: "Image Analyze",
            notes: question)

        return ToolResponse.text(
            analysis.text,
            meta: ToolEventSummary.merge(summary: summary, into: baseMeta))
    }

    func buildCaptureResponse(
        format: ImageFormatOption,
        savedFiles: [MCPSavedFile],
        captureResults: [CaptureResult],
        observation: DesktopObservationResult?) -> ToolResponse
    {
        let baseMeta = ObservationDiagnosticsMetadata.merge(observation, into: .object([
            "savedFiles": .array(savedFiles.map { Value.string($0.path) }),
        ]))
        let captureNote: String = if savedFiles.isEmpty {
            "Captured image"
        } else if savedFiles.count == 1, let label = savedFiles.first?.item_label {
            label
        } else {
            "Captured \(savedFiles.count) images"
        }
        let summary = ToolEventSummary(
            actionDescription: "Image Capture",
            notes: captureNote)
        let meta = ToolEventSummary.merge(summary: summary, into: baseMeta)

        if format == .data, let capture = captureResults.first, captureResults.count == 1 {
            return ToolResponse.image(data: capture.imageData, mimeType: "image/png", meta: meta)
        }

        return ToolResponse.text(
            buildImageSummary(savedFiles: savedFiles, captureCount: captureResults.count),
            meta: meta)
    }
}
