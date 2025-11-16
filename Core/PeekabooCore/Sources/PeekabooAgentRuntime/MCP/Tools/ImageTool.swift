import Algorithms
import AppKit
import Foundation
import MCP
import PeekabooAutomation
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
            ],
            required: ["path", "format"])
    }

    public init(context: MCPToolContext = .shared) {
        self.context = context
    }

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        let request = try ImageRequest(arguments: arguments)
        let captureResults = try await self.captureImages(for: request)
        let savedFiles = try self.saveCaptures(captureResults, request: request)

        if let question = request.question {
            return try await self.performAnalysis(
                question: question,
                savedFiles: savedFiles,
                captureResults: captureResults)
        }

        return self.buildCaptureResponse(
            format: request.format,
            savedFiles: savedFiles,
            captureResults: captureResults)
    }
}

// MARK: - Supporting Types

extension ImageTool {
    private func captureImages(for request: ImageRequest) async throws -> [CaptureResult] {
        switch request.target {
        case let .screen(index):
            let result = try await self.context.screenCapture.captureScreen(displayIndex: index)
            return [result]
        case .frontmost:
            let result = try await self.context.screenCapture.captureFrontmost()
            return [result]
        case let .application(identifier, windowIndex):
            return try await self.captureApplication(
                identifier: identifier,
                windowIndex: windowIndex,
                focus: request.captureFocus)
        case .menubar:
            return try await [self.captureMenuBar()]
        }
    }

    private func captureApplication(
        identifier: String,
        windowIndex: Int?,
        focus: CaptureFocus) async throws -> [CaptureResult]
    {
        if focus == .foreground {
            try await self.context.applications.activateApplication(identifier: identifier)
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        if let windowIndex {
            let result = try await self.context.screenCapture.captureWindow(
                appIdentifier: identifier,
                windowIndex: windowIndex)
            return [result]
        }

        let windows = try await self.context.windows.listWindows(target: .application(identifier))
        var results: [CaptureResult] = []

        for index in windows.indices {
            let result = try await self.context.screenCapture.captureWindow(
                appIdentifier: identifier,
                windowIndex: index)
            results.append(result)
        }

        return results
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
                    window_id: nil,
                    window_index: index,
                    mime_type: request.format.mimeType))
        }

        return savedFiles
    }

    private func performAnalysis(
        question: String,
        savedFiles: [MCPSavedFile],
        captureResults: [CaptureResult]) async throws -> ToolResponse
    {
        guard let firstCapture = captureResults.first else {
            throw OperationError.captureFailed(reason: "No capture data available")
        }

        let imagePath = try savedFiles.first?.path ?? saveTemporaryImage(firstCapture.imageData)
        let analysis = try await analyzeImage(at: imagePath, question: question)
        let baseMeta: [String: Value] = [
            "model": .string(analysis.modelUsed),
            "savedFiles": .array(savedFiles.map { Value.string($0.path) }),
            "question": .string(question),
        ]
        let summary = ToolEventSummary(
            actionDescription: "Image Analyze",
            notes: question)

        return ToolResponse.text(
            analysis.text,
            meta: ToolEventSummary.merge(summary: summary, into: .object(baseMeta)))
    }

    private func buildCaptureResponse(
        format: ImageFormatOption,
        savedFiles: [MCPSavedFile],
        captureResults: [CaptureResult]) -> ToolResponse
    {
        let baseMeta = Value.object(["savedFiles": .array(savedFiles.map { Value.string($0.path) })])
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

// Extended format that includes "data" option
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

    enum CodingKeys: String, CodingKey {
        case path, format, question
        case appTarget = "app_target"
        case captureFocus = "capture_focus"
    }
}

private struct ImageRequest {
    let path: String?
    let format: ImageFormatOption
    let target: ImageCaptureTarget
    let question: String?
    let captureFocus: CaptureFocus

    init(arguments: ToolArguments) throws {
        let input = try arguments.decode(ImageInput.self)
        self.path = input.path
        self.question = input.question
        self.captureFocus = input.captureFocus ?? .auto
        self.format = input.format ?? .png
        self.target = try parseCaptureTarget(input.appTarget)
    }
}

enum ImageCaptureTarget {
    case screen(index: Int?)
    case frontmost
    case application(identifier: String, windowIndex: Int?)
    case menubar
}

// MARK: - Helper Functions

private func parseCaptureTarget(_ appTarget: String?) throws -> ImageCaptureTarget {
    guard let target = appTarget else {
        return .screen(index: nil)
    }

    // Parse screen:N format
    if target.hasPrefix("screen:") {
        let indexStr = String(target.dropFirst(7))
        if let index = Int(indexStr) {
            return .screen(index: index)
        }
        throw PeekabooError.invalidInput("Invalid screen index: \(indexStr)")
    }

    // Special values
    switch target.lowercased() {
    case "", "screen":
        return .screen(index: nil)
    case "frontmost":
        return .frontmost
    case "menubar":
        return .menubar
    default:
        // Parse app[:window] format
        let parts = target.split(separator: ":", maxSplits: 1)
        let appIdentifier = String(parts[0])

        var windowIndex: Int?
        if parts.count > 1 {
            if let index = Int(String(parts[1])) {
                windowIndex = index
            }
        }

        return .application(identifier: appIdentifier, windowIndex: windowIndex)
    }
}

extension ImageTool {
    private func captureMenuBar() async throws -> CaptureResult {
        guard let mainScreen = NSScreen.main else {
            throw OperationError.captureFailed(reason: "No main screen available")
        }

        let screenBounds = mainScreen.frame
        let menuBarRect = CGRect(
            x: screenBounds.minX,
            y: screenBounds.maxY - 24,
            width: screenBounds.width,
            height: 24)

        return try await self.context.screenCapture.captureArea(menuBarRect)
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

    // Convert to ImageFormat for actual image saving
    var imageFormat: ImageFormat {
        switch self {
        case .png, .data: .png
        case .jpg: .jpg
        }
    }
}
