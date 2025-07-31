import Foundation
import MCP
import AppKit
import UniformTypeIdentifiers

/// MCP tool for capturing screenshots
public struct ImageTool: MCPTool {
    public let name = "image"
    
    public var description: String {
        """
        Captures macOS screen content and optionally analyzes it. \
        Targets can be entire screen, specific app window, or all windows of an app (via app_target). \
        Supports foreground/background capture. Output via file path or inline Base64 data (format: "data"). \
        If a question is provided, image is analyzed by an AI model. \
        Window shadows/frames excluded. \
        Peekaboo \(Version.current.string)
        """
    }
    
    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "path": SchemaBuilder.string(
                    description: "Optional. Base absolute path for saving the image."
                ),
                "format": SchemaBuilder.string(
                    description: "Optional. Output format.",
                    enum: ["png", "jpg", "data"]
                ),
                "app_target": SchemaBuilder.string(
                    description: "Optional. Specifies the capture target."
                ),
                "question": SchemaBuilder.string(
                    description: "Optional. If provided, the captured image will be analyzed."
                ),
                "capture_focus": SchemaBuilder.string(
                    description: "Optional. Focus behavior.",
                    enum: ["background", "auto", "foreground"],
                    default: "auto"
                )
            ],
            required: ["path", "format"]
        )
    }
    
    public init() {}
    
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
        case .screen(let index):
            let result = try await PeekabooServices.shared.screenCapture.captureScreen(displayIndex: index)
            captureResults = [result]
            
        case .frontmost:
            let result = try await PeekabooServices.shared.screenCapture.captureFrontmost()
            captureResults = [result]
            
        case .application(let identifier, let windowIndex):
            // Handle focus if needed
            if captureFocus == .foreground {
                try await PeekabooServices.shared.applications.activateApplication(identifier: identifier)
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            }
            
            if let windowIndex = windowIndex {
                let result = try await PeekabooServices.shared.screenCapture.captureWindow(
                    appIdentifier: identifier,
                    windowIndex: windowIndex
                )
                captureResults = [result]
            } else {
                // Capture all windows
                let windows = try await PeekabooServices.shared.windows.listWindows(for: identifier)
                var results: [CaptureResult] = []
                
                for (index, _) in windows.enumerated() {
                    let result = try await PeekabooServices.shared.screenCapture.captureWindow(
                        appIdentifier: identifier,
                        windowIndex: index
                    )
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
        var savedFiles: [SavedFile] = []
        
        if let basePath = input.path {
            for (index, result) in captureResults.enumerated() {
                let fileName: String
                if captureResults.count > 1 {
                    fileName = generateFileName(
                        basePath: basePath,
                        index: index,
                        metadata: result.metadata,
                        format: format
                    )
                } else {
                    fileName = ensureExtension(basePath, format: format)
                }
                
                try saveImageData(result.imageData, to: fileName, format: format)
                
                savedFiles.append(SavedFile(
                    path: fileName,
                    itemLabel: describeCapture(result.metadata),
                    windowTitle: result.metadata.windowInfo?.title,
                    windowId: nil,
                    windowIndex: index,
                    mimeType: format.mimeType
                ))
            }
        }
        
        // Handle analysis if requested
        if let question = input.question {
            let imagePath = savedFiles.first?.path ?? try saveTemporaryImage(captureResults.first!.imageData)
            let analysis = try await analyzeImage(at: imagePath, question: question)
            
            return ToolResponse.text(
                analysis.text,
                meta: [
                    "model": analysis.modelUsed,
                    "savedFiles": savedFiles.map { $0.path }
                ]
            )
        }
        
        // Return capture result
        if format == .data && captureResults.count == 1 {
            return ToolResponse.image(
                data: captureResults.first!.imageData,
                mimeType: "image/png",
                meta: ["savedFiles": savedFiles.map { $0.path }]
            )
        }
        
        return ToolResponse.text(
            buildImageSummary(savedFiles: savedFiles, captureCount: captureResults.count),
            meta: ["savedFiles": savedFiles.map { $0.path }]
        )
    }
}

// MARK: - Supporting Types

struct ImageInput: Codable {
    let path: String?
    let format: ImageFormat?
    let appTarget: String?
    let question: String?
    let captureFocus: CaptureFocus?
    
    enum CodingKeys: String, CodingKey {
        case path, format, question
        case appTarget = "app_target"
        case captureFocus = "capture_focus"
    }
}

enum CaptureTarget {
    case screen(index: Int?)
    case frontmost
    case application(identifier: String, windowIndex: Int?)
    case menubar
}

// MARK: - Helper Functions

private func parseCaptureTarget(_ appTarget: String?) throws -> CaptureTarget {
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
        
        var windowIndex: Int? = nil
        if parts.count > 1 {
            if let index = Int(String(parts[1])) {
                windowIndex = index
            }
        }
        
        return .application(identifier: appIdentifier, windowIndex: windowIndex)
    }
}

private func normalizeFormat(_ format: ImageFormat?) -> ImageFormat {
    guard let format = format else { return .png }
    
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
        height: 24
    )
    
    return try await PeekabooServices.shared.screenCapture.captureArea(menuBarRect)
}

private func saveImageData(_ data: Data, to path: String, format: ImageFormat) throws {
    let url = URL(fileURLWithPath: path.expandingTildeInPath)
    
    // Create parent directory if needed
    let parentDir = url.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: parentDir.path) {
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
    }
    
    // Convert format if needed
    let outputData: Data
    if format == .jpg {
        // Convert PNG to JPEG
        guard let image = NSImage(data: data),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
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

private func ensureExtension(_ path: String, format: ImageFormat) -> String {
    let expectedExt = format.fileExtension
    let url = URL(fileURLWithPath: path.expandingTildeInPath)
    
    if url.pathExtension.lowercased() != expectedExt {
        return url.deletingPathExtension().appendingPathExtension(expectedExt).path
    }
    
    return path
}

private func generateFileName(basePath: String, index: Int, metadata: CaptureMetadata, format: ImageFormat) -> String {
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

private func buildImageSummary(savedFiles: [SavedFile], captureCount: Int) -> String {
    if savedFiles.isEmpty {
        return "Captured \(captureCount) image(s)"
    }
    
    var lines: [String] = []
    lines.append("📸 Captured \(captureCount) screenshot(s)")
    
    for file in savedFiles {
        lines.append("  • \(file.itemLabel): \(file.path)")
    }
    
    return lines.joined(separator: "\n")
}

private func analyzeImage(at path: String, question: String) async throws -> (text: String, modelUsed: String) {
    let imageData = try Data(contentsOf: URL(fileURLWithPath: path))
    
    let result = try await PeekabooServices.shared.ai.analyzeImage(
        imageData,
        question: question,
        preferredProvider: nil
    )
    
    return (text: result.text, modelUsed: "\(result.provider)/\(result.model)")
}

// MARK: - Supporting Types

struct SavedFile {
    let path: String
    let itemLabel: String
    let windowTitle: String?
    let windowId: String?
    let windowIndex: Int?
    let mimeType: String
}

extension String {
    var expandingTildeInPath: String {
        return (self as NSString).expandingTildeInPath
    }
}