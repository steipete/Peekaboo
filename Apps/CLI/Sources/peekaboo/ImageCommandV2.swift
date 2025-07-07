import AppKit
import ArgumentParser
import CoreGraphics
import Foundation
import PeekabooCore
import UniformTypeIdentifiers

/// Refactored ImageCommand using PeekabooCore services
struct ImageCommandV2: AsyncParsableCommand, VerboseCommand {
    static let configuration = CommandConfiguration(
        commandName: "image-v2",
        abstract: "Capture screenshots using PeekabooCore services",
        discussion: """
        This is a refactored version of the image command that uses PeekabooCore services
        instead of direct implementation. It maintains the same interface but delegates
        all operations to the service layer.
        """)
    
    @Option(name: .long, help: "Target application name, bundle ID, or 'PID:12345' for process ID")
    var app: String?
    
    @Option(name: .long, help: "Output path for saved image (e.g., ~/Desktop/screenshot.png)")
    var path: String?
    
    @Option(name: .long, help: ArgumentHelp("Capture mode", valueName: "mode"))
    var mode: CaptureMode?
    
    @Option(name: .long, help: "Capture window with specific title (use with --app)")
    var windowTitle: String?
    
    @Option(name: .long, help: "Window index to capture (0=frontmost, use with --app)")
    var windowIndex: Int?
    
    @Option(name: .long, help: "Screen index to capture (0-based, use with --mode screen)")
    var screenIndex: Int?
    
    @Option(name: .long, help: ArgumentHelp("Image format: png or jpg", valueName: "format"))
    var format: ImageFormat = .png
    
    @Option(
        name: .long,
        help: ArgumentHelp("Window focus behavior: auto, foreground, or background", valueName: "focus"))
    var captureFocus: CaptureFocus = .auto
    
    @Flag(name: .long, help: "Output results in JSON format for scripting")
    var jsonOutput = false
    
    @Option(name: .long, help: "Analyze the captured image with AI (provide a question/prompt)")
    var analyze: String?
    
    @Flag(name: .shortAndLong, help: "Enable verbose logging for detailed output")
    var verbose = false
    
    private let services = PeekabooServices.shared
    
    func run() async throws {
        configureVerboseLogging()
        Logger.shared.setJsonOutputMode(jsonOutput)
        
        do {
            // Check permissions
            guard await services.screenCapture.hasScreenRecordingPermission() else {
                throw CaptureError.screenRecordingPermissionDenied
            }
            
            // Perform capture
            let savedFiles = try await performCapture()
            
            // Analyze if requested
            if let analyzePrompt = analyze, let firstFile = savedFiles.first {
                let analysisResult = try await analyzeImage(at: firstFile.path, with: analyzePrompt)
                outputResultsWithAnalysis(savedFiles, analysis: analysisResult)
            } else {
                outputResults(savedFiles)
            }
        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
    
    private func performCapture() async throws -> [SavedFile] {
        let captureMode = determineMode()
        Logger.shared.verbose("Starting capture with mode: \(captureMode)")
        
        var results: [SavedFile] = []
        
        switch captureMode {
        case .screen:
            results = try await captureScreens()
        case .window:
            guard let app else {
                throw CaptureError.appNotFound("No application specified for window capture")
            }
            results = try await captureApplicationWindow(app)
        case .multi:
            if let app {
                results = try await captureAllApplicationWindows(app)
            } else {
                results = try await captureScreens()
            }
        case .frontmost:
            results = try await captureFrontmost()
        }
        
        return results
    }
    
    private func captureScreens() async throws -> [SavedFile] {
        Logger.shared.verbose("Capturing screen(s)")
        
        let result = try await services.screenCapture.captureScreen(displayIndex: screenIndex)
        let savedPath = try saveImage(result.imageData, name: "screen")
        
        return [SavedFile(
            path: savedPath,
            item_label: "Screen \(screenIndex ?? 0)",
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: format.mimeType
        )]
    }
    
    private func captureApplicationWindow(_ appIdentifier: String) async throws -> [SavedFile] {
        Logger.shared.verbose("Capturing window for app: \(appIdentifier)")
        
        // Handle focus if needed
        if captureFocus == .foreground {
            try await services.applications.activateApplication(identifier: appIdentifier)
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }
        
        let result = try await services.screenCapture.captureWindow(
            appIdentifier: appIdentifier,
            windowIndex: windowIndex
        )
        
        let savedPath = try saveImage(result.imageData, name: appIdentifier)
        
        return [SavedFile(
            path: savedPath,
            item_label: result.metadata.applicationInfo?.name,
            window_title: result.metadata.windowInfo?.title,
            window_id: UInt32(result.metadata.windowInfo?.windowID ?? 0),
            window_index: windowIndex,
            mime_type: format.mimeType
        )]
    }
    
    private func captureAllApplicationWindows(_ appIdentifier: String) async throws -> [SavedFile] {
        Logger.shared.verbose("Capturing all windows for app: \(appIdentifier)")
        
        // Get window count
        let windows = try await services.applications.listWindows(for: appIdentifier)
        var savedFiles: [SavedFile] = []
        
        for (index, window) in windows.enumerated() {
            Logger.shared.verbose("Capturing window \(index): \(window.title)")
            
            let result = try await services.screenCapture.captureWindow(
                appIdentifier: appIdentifier,
                windowIndex: index
            )
            
            let savedPath = try saveImage(result.imageData, name: "\(appIdentifier)_\(index)")
            
            savedFiles.append(SavedFile(
                path: savedPath,
                item_label: result.metadata.applicationInfo?.name,
                window_title: window.title,
                window_id: UInt32(window.windowID),
                window_index: index,
                mime_type: format.mimeType
            ))
        }
        
        return savedFiles
    }
    
    private func captureFrontmost() async throws -> [SavedFile] {
        Logger.shared.verbose("Capturing frontmost window")
        
        let result = try await services.screenCapture.captureFrontmost()
        let savedPath = try saveImage(result.imageData, name: "frontmost")
        
        return [SavedFile(
            path: savedPath,
            item_label: result.metadata.applicationInfo?.name,
            window_title: result.metadata.windowInfo?.title,
            window_id: UInt32(result.metadata.windowInfo?.windowID ?? 0),
            window_index: 0,
            mime_type: format.mimeType
        )]
    }
    
    private func saveImage(_ data: Data, name: String) throws -> String {
        let outputPath: String
        
        if let providedPath = path {
            outputPath = NSString(string: providedPath).expandingTildeInPath
        } else {
            let timestamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let filename = "peekaboo_\(name)_\(timestamp).\(format.rawValue)"
            outputPath = FileManager.default.currentDirectoryPath + "/" + filename
        }
        
        // Create directory if needed
        let directory = (outputPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        
        // Save the image
        try data.write(to: URL(fileURLWithPath: outputPath))
        Logger.shared.verbose("Saved image to: \(outputPath)")
        
        return outputPath
    }
    
    private func determineMode() -> CaptureMode {
        if let mode = self.mode {
            return mode
        } else if app != nil {
            return .window
        } else {
            return .screen
        }
    }
    
    private func analyzeImage(at path: String, with prompt: String) async throws -> ImageAnalysisData {
        // TODO: Implement using AI provider from services
        // For now, return placeholder
        return ImageAnalysisData(
            provider: "none",
            model: "none",
            text: "AI analysis not yet implemented in service layer"
        )
    }
    
    // MARK: - Output Methods
    
    private func outputResults(_ savedFiles: [SavedFile]) {
        if jsonOutput {
            outputJSON(CommandResponse(
                success: true,
                data: ImageCaptureData(saved_files: savedFiles)
            ))
        } else {
            for file in savedFiles {
                print(file.path)
            }
        }
    }
    
    private func outputResultsWithAnalysis(_ savedFiles: [SavedFile], analysis: ImageAnalysisData) {
        if jsonOutput {
            let data = ImageCaptureWithAnalysisData(
                saved_files: savedFiles,
                analysis: analysis
            )
            outputJSON(CommandResponse(success: true, data: data))
        } else {
            for file in savedFiles {
                print(file.path)
            }
            print("\nAnalysis (\(analysis.provider)/\(analysis.model)):")
            print(analysis.text)
        }
    }
    
    private func handleError(_ error: Error) {
        if jsonOutput {
            outputJSON(CommandResponse<EmptyData>(
                success: false,
                error: ErrorResponse(from: error),
                debug_logs: Logger.shared.getDebugLogs()
            ))
        } else {
            Logger.shared.error(error.localizedDescription)
        }
    }
}

// MARK: - Helper Types

private struct ImageCaptureWithAnalysisData: Codable {
    let saved_files: [SavedFile]
    let analysis: ImageAnalysisData
}

private extension ImageFormat {
    var mimeType: String {
        switch self {
        case .png: return "image/png"
        case .jpg: return "image/jpeg"
        }
    }
}