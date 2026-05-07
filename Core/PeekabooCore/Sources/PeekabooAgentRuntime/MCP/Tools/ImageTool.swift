import Algorithms
import AppKit
import Foundation
import MCP
import PeekabooAutomation
import PeekabooAutomationKit
import PeekabooFoundation
import TachikomaMCP
import UniformTypeIdentifiers

/// MCP tool for capturing screenshots
public struct ImageTool: MCPTool {
    private let context: MCPToolContext

    public let name = "image"

    public var description: String {
        """
        Captures macOS screen content and optionally analyzes it.
        Targets include entire displays, the frontmost window, app-specific windows (`app_target`),
        or the menu bar. Supports background or foreground capture workflows.
        Output can be written to disk or returned inline as Base64 data (`format: "data"`).
        When `question` is supplied the capture is analyzed with the configured AI model (GPT-5 by
        default). Window shadows/frames are excluded automatically.
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "path": SchemaBuilder.string(
                    description: "Optional. Base absolute path for saving the image."),
                "format": SchemaBuilder.string(
                    description: "Optional. Output format.",
                    enum: ["png", "jpg", "data"]),
                "app_target": SchemaBuilder.string(
                    description: "Optional. Specifies the capture target."),
                "question": SchemaBuilder.string(
                    description: "Optional. If provided, the captured image will be analyzed."),
                "capture_focus": SchemaBuilder.string(
                    description: "Optional. Focus behavior.",
                    enum: ["background", "auto", "foreground"],
                    default: "auto"),
                "scale": SchemaBuilder.string(
                    description: "Optional. Capture scale: logical|1x or native|retina|2x.",
                    enum: ["logical", "1x", "native", "retina", "2x"],
                    default: "logical"),
                "retina": SchemaBuilder.boolean(
                    description: "Optional. Shorthand for scale=native.",
                    default: false),
            ],
            required: [])
    }

    public init(context: MCPToolContext = .shared) {
        self.context = context
    }

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        let request = try ImageRequest(arguments: arguments)
        guard await self.context.screenCapture.hasScreenRecordingPermission() else {
            return self.screenRecordingPermissionError()
        }

        let captureSet: ImageCaptureSet
        do {
            captureSet = try await self.captureImages(for: request)
        } catch PeekabooError.permissionDeniedScreenRecording {
            return self.screenRecordingPermissionError()
        }
        let captureResults = captureSet.captures
        let savedFiles = try self.saveCaptures(captureResults, request: request)

        if let question = request.question {
            return try await self.performAnalysis(
                question: question,
                savedFiles: savedFiles,
                captureResults: captureResults,
                observation: captureSet.observation)
        }

        return self.buildCaptureResponse(
            format: request.format,
            savedFiles: savedFiles,
            captureResults: captureResults,
            observation: captureSet.observation)
    }

    private func screenRecordingPermissionError() -> ToolResponse {
        let responseText = "Screen Recording permission is required. " +
            "Grant via: System Settings > Privacy & Security > Screen Recording"
        let summary = ToolEventSummary(actionDescription: "Image Capture", notes: "Screen Recording missing")
        return ToolResponse.error(responseText, meta: ToolEventSummary.merge(summary: summary, into: nil))
    }
}

// MARK: - Supporting Types

private struct ImageCaptureSet {
    let captures: [CaptureResult]
    let observation: DesktopObservationResult?
}

extension ImageTool {
    private func captureImages(for request: ImageRequest) async throws -> ImageCaptureSet {
        switch request.target {
        case .menubar:
            let observation = try await self.captureObservation(for: request)
            return ImageCaptureSet(captures: [observation.capture], observation: observation)
        default:
            let result = try await self.captureObservation(for: request)
            return ImageCaptureSet(captures: [result.capture], observation: result)
        }
    }

    private func captureObservation(for request: ImageRequest) async throws -> DesktopObservationResult {
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
            detection: DesktopDetectionOptions(mode: .none)))
    }

    private func saveCaptures(_ results: [CaptureResult], request: ImageRequest) throws -> [MCPSavedFile] {
        guard let basePath = request.path else { return [] }
        var savedFiles: [MCPSavedFile] = []

        for (index, result) in results.indexed() {
            let fileName = results.count > 1 ?
                generateFileName(
                    basePath: basePath,
                    index: index,
                    metadata: result.metadata,
                    format: request.format) :
                ensureExtension(basePath, format: request.format)

            try saveImageData(result.imageData, to: fileName, format: request.format)
            savedFiles.append(
                MCPSavedFile(
                    path: fileName,
                    item_label: describeCapture(result.metadata),
                    window_title: result.metadata.windowInfo?.title,
                    window_id: result.metadata.windowInfo.map { String($0.windowID) },
                    window_index: result.metadata.windowInfo?.index ?? index,
                    mime_type: request.format.mimeType))
        }

        return savedFiles
    }

    private func performAnalysis(
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

    private func buildCaptureResponse(
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

/// Extended format that includes "data" option
enum ImageFormatOption: String, Codable {
    case png
    case jpg
    case data // Return as base64 data
}

struct ImageInput: Codable {
    let path: String?
    let format: ImageFormatOption?
    let appTarget: String?
    let question: String?
    let captureFocus: CaptureFocus?
    let scale: String?
    let retina: Bool?

    enum CodingKeys: String, CodingKey {
        case path, format, question, scale, retina
        case appTarget = "app_target"
        case captureFocus = "capture_focus"
    }
}

private struct ImageRequest {
    let path: String?
    let format: ImageFormatOption
    let target: ObservationTargetArgument
    let question: String?
    let captureFocus: CaptureFocus
    let scale: CaptureScalePreference

    init(arguments: ToolArguments) throws {
        let input = try arguments.decode(ImageInput.self)
        self.path = input.path
        self.question = input.question
        self.captureFocus = input.captureFocus ?? .auto
        self.format = input.format ?? .png
        self.target = try ObservationTargetArgument.parse(input.appTarget)
        self.scale = try Self.captureScale(scale: input.scale, retina: input.retina)
    }

    private static func captureScale(scale: String?, retina: Bool?) throws -> CaptureScalePreference {
        if retina == true {
            return .native
        }

        guard let scale else {
            return .logical1x
        }

        switch scale.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "", "logical", "logical1x", "1x":
            return .logical1x
        case "native", "retina", "2x":
            return .native
        default:
            throw PeekabooError.invalidInput("Invalid image scale: \(scale)")
        }
    }
}

extension ImageRequest {
    fileprivate var focusIdentifier: String? {
        self.target.focusIdentifier
    }
}

private func saveImageData(_ data: Data, to path: String, format: ImageFormatOption) throws {
    let url = URL(fileURLWithPath: path.expandingTildeInPath)

    // Create parent directory if needed
    let parentDir = url.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: parentDir.path) {
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
    }

    // Convert format if needed
    let outputData: Data
    if format.imageFormat == .jpg {
        // Convert PNG to JPEG
        guard let image = NSImage(data: data),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        else {
            throw OperationError.captureFailed(reason: "Failed to convert image to JPEG")
        }
        outputData = jpegData
    } else {
        outputData = data
    }

    try outputData.write(to: url)
}

private func saveTemporaryImage(_ data: Data) throws -> String {
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = "peekaboo-\(UUID().uuidString).png"
    let url = tempDir.appendingPathComponent(fileName)
    try data.write(to: url)
    return url.path
}

private func ensureExtension(_ path: String, format: ImageFormatOption) -> String {
    let expectedExt = format.fileExtension
    let url = URL(fileURLWithPath: path.expandingTildeInPath)

    if url.pathExtension.lowercased() != expectedExt {
        return url.deletingPathExtension().appendingPathExtension(expectedExt).path
    }

    return path
}

private func generateFileName(
    basePath: String,
    index: Int,
    metadata: CaptureMetadata,
    format: ImageFormatOption) -> String
{
    let url = URL(fileURLWithPath: basePath.expandingTildeInPath)
    let basename = url.deletingPathExtension().lastPathComponent
    let directory = url.deletingLastPathComponent()

    var filename = basename
    if let appInfo = metadata.applicationInfo {
        filename += "-\(appInfo.name.replacingOccurrences(of: " ", with: "_"))"
    }
    if let windowInfo = metadata.windowInfo {
        let sanitizedTitle = windowInfo.title
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .prefix(50)
        filename += "-\(sanitizedTitle)"
    }
    filename += "-\(index)"

    return directory
        .appendingPathComponent(filename)
        .appendingPathExtension(format.fileExtension)
        .path
}

private func describeCapture(_ metadata: CaptureMetadata) -> String {
    if let appInfo = metadata.applicationInfo {
        if let windowInfo = metadata.windowInfo {
            return "\(appInfo.name) - \(windowInfo.title)"
        }
        return appInfo.name
    }

    if let displayInfo = metadata.displayInfo {
        return "Screen \(displayInfo.index)"
    }

    return "Screenshot"
}

private func buildImageSummary(savedFiles: [MCPSavedFile], captureCount: Int) -> String {
    if savedFiles.isEmpty {
        return "Captured \(captureCount) image(s)"
    }

    var lines: [String] = []
    lines.append("📸 Captured \(captureCount) screenshot(s)")

    for file in savedFiles {
        lines.append("  • \(file.item_label): \(file.path)")
    }

    return lines.joined(separator: "\n")
}

private func analyzeImage(at path: String, question: String) async throws -> (text: String, modelUsed: String) {
    let aiService = await MainActor.run { PeekabooAIService() }
    let result = try await aiService.analyzeImageFile(at: path, question: question)
    return (text: result, modelUsed: "gpt-5.1")
}

// MARK: - Supporting Types

struct MCPSavedFile {
    let path: String
    let item_label: String
    let window_title: String?
    let window_id: String?
    let window_index: Int?
    let mime_type: String
}

extension String {
    var expandingTildeInPath: String {
        (self as NSString).expandingTildeInPath
    }
}

extension ImageFormatOption {
    var mimeType: String {
        switch self {
        case .png, .data: "image/png"
        case .jpg: "image/jpeg"
        }
    }

    var fileExtension: String {
        switch self {
        case .png, .data: "png"
        case .jpg: "jpg"
        }
    }

    /// Convert to ImageFormat for actual image saving
    var imageFormat: ImageFormat {
        switch self {
        case .png, .data: .png
        case .jpg: .jpg
        }
    }
}
