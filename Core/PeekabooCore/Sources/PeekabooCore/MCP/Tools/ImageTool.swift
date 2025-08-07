import AppKit
import Foundation
import TachikomaMCP
import MCP
import UniformTypeIdentifiers

/// MCP tool for capturing screenshots
public struct ImageTool: MCPTool {
    public let name = "image"

    public var description: String {
        """
        Captures macOS screen content and optionally analyzes it. Targets can be entire screen, specific app window, or all windows of an app (via app_target). Supports foreground/background capture. Output via file path or inline Base64 data (format: "data"). If a question is provided, image is analyzed by an AI model (auto-selected from PEEKABOO_AI_PROVIDERS). Window shadows/frames excluded. Peekaboo MCP 3.0.0-beta.2 using anthropic/claude-opus-4-20250514, ollama/llava:latest
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

    public init() {}

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        let input = try arguments.decode(ImageInput.self)

        // Parse capture target
        let target = try parseCaptureTarget(input.appTarget)

        // Determine capture focus
        let captureFocus = input.captureFocus ?? .auto

        // Normalize format
        let format = normalizeFormat(input.format ?? .png)

        // Perform capture based on target
        let captureResults: [CaptureResult]

        switch target {
        case let .screen(index):
            let result = try await PeekabooServices.shared.screenCapture.captureScreen(displayIndex: index)
            captureResults = [result]

        case .frontmost:
            let result = try await PeekabooServices.shared.screenCapture.captureFrontmost()
            captureResults = [result]

        case let .application(identifier, windowIndex):
            // Handle focus if needed
            if captureFocus == .foreground {
                try await PeekabooServices.shared.applications.activateApplication(identifier: identifier)
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            }

            if let windowIndex {
                let result = try await PeekabooServices.shared.screenCapture.captureWindow(
                    appIdentifier: identifier,
                    windowIndex: windowIndex)
                captureResults = [result]
            } else {
                // Capture all windows
                let windows = try await PeekabooServices.shared.windows.listWindows(target: .application(identifier))
                var results: [CaptureResult] = []

                for (index, _) in windows.enumerated() {
                    let result = try await PeekabooServices.shared.screenCapture.captureWindow(
                        appIdentifier: identifier,
                        windowIndex: index)
                    results.append(result)
                }

                captureResults = results
            }

        case .menubar:
            // Special case for menu bar
            let result = try await captureMenuBar()
            captureResults = [result]
        }

        // Save images if path provided
        var savedFiles: [MCPSavedFile] = []

        if let basePath = input.path {
            for (index, result) in captureResults.enumerated() {
                let fileName: String = if captureResults.count > 1 {
                    generateFileName(
                        basePath: basePath,
                        index: index,
                        metadata: result.metadata,
                        format: format)
                } else {
                    ensureExtension(basePath, format: format)
                }

                try saveImageData(result.imageData, to: fileName, format: format)

                savedFiles.append(MCPSavedFile(
                    path: fileName,
                    item_label: describeCapture(result.metadata),
                    window_title: result.metadata.windowInfo?.title,
                    window_id: nil,
                    window_index: index,
                    mime_type: format.mimeType))
            }
        }

        // Handle analysis if requested
        if let question = input.question {
            let imagePath = try savedFiles.first?.path ?? saveTemporaryImage(captureResults.first!.imageData)
            let analysis = try await analyzeImage(at: imagePath, question: question)

            return ToolResponse.text(
                analysis.text,
                meta: .object([
                    "model": .string(analysis.modelUsed),
                    "savedFiles": .array(savedFiles.map { Value.string($0.path) }),
                ]))
        }

        // Return capture result
        if format == .data, captureResults.count == 1 {
            return ToolResponse.image(
                data: captureResults.first!.imageData,
                mimeType: "image/png",
                meta: .object(["savedFiles": .array(savedFiles.map { Value.string($0.path) })]))
        }

        return ToolResponse.text(
            buildImageSummary(savedFiles: savedFiles, captureCount: captureResults.count),
            meta: .object(["savedFiles": .array(savedFiles.map { Value.string($0.path) })]))
    }
}

// MARK: - Supporting Types

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

private func normalizeFormat(_ format: ImageFormatOption?) -> ImageFormatOption {
    guard let format else { return .png }

    // The jpeg alias is handled by ImageFormat's Codable implementation
    return format
}

private func captureMenuBar() async throws -> CaptureResult {
    // Get main screen bounds
    guard let mainScreen = NSScreen.main else {
        throw OperationError.captureFailed(reason: "No main screen available")
    }

    let screenBounds = mainScreen.frame
    let menuBarRect = CGRect(
        x: screenBounds.minX,
        y: screenBounds.maxY - 24, // Menu bar is 24px high
        width: screenBounds.width,
        height: 24)

    return try await PeekabooServices.shared.screenCapture.captureArea(menuBarRect)
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
    // Use the AI service to analyze the image
    let aiService = await PeekabooAIService()
    let result = try await aiService.analyzeImageFile(at: path, question: question)
    return (text: result, modelUsed: "gpt-4o")
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
