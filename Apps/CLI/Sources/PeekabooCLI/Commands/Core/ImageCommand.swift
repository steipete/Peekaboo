import AppKit
import ArgumentParser
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation
import UniformTypeIdentifiers

// Helper function for async operations with timeout (uses withTimeout from CommandUtilities)
func withTimeoutOrNil<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async -> T) async -> T? {
    do {
        return try await withTimeout(seconds: seconds) {
            await operation()
        }
    } catch {
        return nil
    }
}

// Structure for image analysis results
struct ImageAnalysisData: Codable {
    let provider: String
    let model: String
    let text: String
}

struct ImageCommand: AsyncParsableCommand, VerboseCommand, ErrorHandlingCommand, OutputFormattable,
ApplicationResolvable {
    static let configuration = CommandConfiguration(
        commandName: "image",
        abstract: "Capture screenshots",
        discussion: """
        Captures screenshots of applications, windows, or the entire screen.

        SPECIAL APP VALUES:
          • menubar   - Capture just the menu bar area (24px height)
          • frontmost - Capture the currently active window

        EXAMPLES:
          peekaboo image --app Safari                    # Capture Safari window
          peekaboo image --app menubar                   # Capture menu bar only
          peekaboo image --app frontmost                 # Capture active window
          peekaboo image --pid 12345                     # Capture by process ID
          peekaboo image --mode screen                   # Capture entire screen
          peekaboo image --app Finder --window-index 0   # Capture specific window
          peekaboo image --app Safari --analyze "What is shown?"  # Capture and analyze with AI

        OUTPUT:
          Screenshots are saved to ~/Desktop by default, or use --path to specify location.
          Use --format jpg for smaller file sizes.
        """
    )

    @Option(
        name: .long,
        help: "Target application name, bundle ID, 'PID:12345' for process ID, or special values: 'menubar', 'frontmost'"
    )
    var app: String?

    @Option(name: .long, help: "Target application by process ID")
    var pid: Int32?

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
        help: ArgumentHelp("Window focus behavior: auto, foreground, or background", valueName: "focus")
    )
    var captureFocus: CaptureFocus = .auto

    @Flag(name: .long, help: "Output results in JSON format for scripting")
    var jsonOutput = false

    @Option(name: .long, help: "Analyze the captured image with AI (provide a question/prompt)")
    var analyze: String?

    @Flag(name: .shortAndLong, help: "Enable verbose logging for detailed output")
    var verbose = false

    /// Validate permissions, capture the requested imagery, optionally run AI analysis, then render output.
    func run() async throws {
        configureVerboseLogging()
        Logger.shared.setJsonOutputMode(self.jsonOutput)
        Logger.shared.operationStart("image_command", metadata: [
            "mode": self.mode?.rawValue ?? "auto",
            "app": self.app ?? "none",
            "pid": self.pid ?? 0,
            "annotate": false,
            "hasAnalyzePrompt": self.analyze != nil
        ])

        do {
            // Check permissions
            Logger.shared.debug("Checking screen recording permission...")
            try await requireScreenRecordingPermission()
            Logger.shared.debug("Screen recording permission granted")

            // Perform capture
            Logger.shared.startTimer("image_capture")
            let savedFiles = try await performCapture()
            Logger.shared.stopTimer("image_capture")

            // Analyze if requested
            if let analyzePrompt = analyze, let firstFile = savedFiles.first {
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: firstFile.path)[.size] as? Int) ?? 0
                Logger.shared.verbose(
                    "Starting AI analysis",
                    category: "AI",
                    metadata: [
                        "imagePath": firstFile.path,
                        "imageSizeBytes": fileSize,
                        "promptLength": analyzePrompt.count
                    ]
                )
                Logger.shared.operationStart(
                    "ai_analysis",
                    metadata: ["promptPreview": String(analyzePrompt.prefix(80))]
                )
                Logger.shared.startTimer("ai_generate")
                let analysisResult = try await analyzeImage(at: firstFile.path, with: analyzePrompt)
                Logger.shared.stopTimer("ai_generate")
                Logger.shared.operationComplete("ai_analysis", success: true, metadata: [
                    "provider": analysisResult.provider,
                    "model": analysisResult.model
                ])
                self.outputResultsWithAnalysis(savedFiles, analysis: analysisResult)
            } else {
                self.outputResults(savedFiles)
            }
        } catch {
            self.handleError(error)
            Logger.shared.operationComplete("image_command", success: false, metadata: [
                "error": error.localizedDescription
            ])
            throw ExitCode(1)
        }
    }

    private func performCapture() async throws -> [SavedFile] {
        // Handle special app cases
        if let appName = self.app?.lowercased() {
            switch appName {
            case "menubar":
                return try await self.captureMenuBar()
            case "frontmost":
                return try await self.captureFrontmost()
            default:
                break
            }
        }

        let captureMode = self.determineMode()
        Logger.shared.verbose("Starting capture with mode: \(captureMode)")

        var results: [SavedFile] = []

        switch captureMode {
        case .screen:
            results = try await self.captureScreens()
        case .window:
            let appIdentifier = try self.resolveApplicationIdentifier()
            results = try await self.captureApplicationWindow(appIdentifier)
        case .multi:
            if self.app != nil || self.pid != nil {
                let appIdentifier = try self.resolveApplicationIdentifier()
                results = try await self.captureAllApplicationWindows(appIdentifier)
            } else {
                results = try await self.captureScreens()
            }
        case .frontmost:
            results = try await self.captureFrontmost()
        case .area:
            // Area mode is not yet supported in the service layer
            throw CaptureError.captureFailed("Area capture mode is not yet implemented")
        }

        return results
    }

    private func captureScreens() async throws -> [SavedFile] {
        Logger.shared.verbose("Capturing screen(s)")

        let result = try await PeekabooServices.shared.screenCapture.captureScreen(displayIndex: self.screenIndex)
        let savedPath = try saveImage(result.imageData, name: "screen")

        return [SavedFile(
            path: savedPath,
            item_label: "Screen \(self.screenIndex ?? 0)",
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: self.format.mimeType
        )]
    }

    private func captureApplicationWindow(_ appIdentifier: String) async throws -> [SavedFile] {
        Logger.shared.verbose("Capturing window for app: \(appIdentifier)")
        let startTime = Date()

        // Handle focus if needed
        if self.captureFocus == .foreground {
            Logger.shared.debug("Activating application...")
            try await PeekabooServices.shared.applications.activateApplication(identifier: appIdentifier)
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            Logger.shared.debug("Application activated (took \(Date().timeIntervalSince(startTime))s)")
        }

        Logger.shared.debug("Starting window capture...")
        let captureStart = Date()

        // Add timeout to window capture
        let captureTask = Task {
            try await PeekabooServices.shared.screenCapture.captureWindow(
                appIdentifier: appIdentifier,
                windowIndex: self.windowIndex
            )
        }

        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            captureTask.cancel()
        }

        do {
            let result = try await captureTask.value
            timeoutTask.cancel()
            Logger.shared.debug("Window capture completed (took \(Date().timeIntervalSince(captureStart))s)")
            return try await self.processCapture(result, appIdentifier: appIdentifier)
        } catch {
            timeoutTask.cancel()
            if captureTask.isCancelled {
                Logger.shared.error("Window capture timed out after 5 seconds")
                throw OperationError.timeout(operation: "Window capture", duration: 5.0)
            }
            throw error
        }
    }

    private func processCapture(_ result: CaptureResult, appIdentifier: String) async throws -> [SavedFile] {
        let savedPath = try saveImage(result.imageData, name: appIdentifier)

        return [SavedFile(
            path: savedPath,
            item_label: result.metadata.applicationInfo?.name,
            window_title: result.metadata.windowInfo?.title,
            window_id: UInt32(result.metadata.windowInfo?.windowID ?? 0),
            window_index: self.windowIndex,
            mime_type: self.format.mimeType
        )]
    }

    private func captureAllApplicationWindows(_ appIdentifier: String) async throws -> [SavedFile] {
        Logger.shared.verbose("Capturing all windows for app: \(appIdentifier)")

        // Get window count
        let windowsOutput = try await PeekabooServices.shared.applications.listWindows(for: appIdentifier, timeout: nil)
        var savedFiles: [SavedFile] = []

        for (index, window) in windowsOutput.data.windows.enumerated() {
            Logger.shared.verbose("Capturing window \(index): \(window.title)")

            let result = try await PeekabooServices.shared.screenCapture.captureWindow(
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
                mime_type: self.format.mimeType
            ))
        }

        return savedFiles
    }

    private func captureFrontmost() async throws -> [SavedFile] {
        Logger.shared.verbose("Capturing frontmost window")

        let result = try await PeekabooServices.shared.screenCapture.captureFrontmost()
        let savedPath = try saveImage(result.imageData, name: "frontmost")

        return [SavedFile(
            path: savedPath,
            item_label: result.metadata.applicationInfo?.name,
            window_title: result.metadata.windowInfo?.title,
            window_id: UInt32(result.metadata.windowInfo?.windowID ?? 0),
            window_index: 0,
            mime_type: self.format.mimeType
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
            // Use temporary directory instead of current directory to avoid polluting workspaces
            let tempDir = NSTemporaryDirectory()
            outputPath = tempDir + filename
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
            mode
        } else if self.app != nil || self.pid != nil {
            .window
        } else {
            .screen
        }
    }

    private func captureMenuBar() async throws -> [SavedFile] {
        Logger.shared.verbose("Capturing menu bar area")

        // Get the main screen bounds
        guard let mainScreen = NSScreen.main else {
            throw PeekabooError.captureFailed("No main screen found")
        }

        // Menu bar is at the top of the screen
        let menuBarHeight: CGFloat = 24.0 // Standard macOS menu bar height
        let menuBarRect = CGRect(
            x: mainScreen.frame.origin.x,
            y: mainScreen.frame.origin.y + mainScreen.frame.height - menuBarHeight,
            width: mainScreen.frame.width,
            height: menuBarHeight
        )

        // Capture the menu bar area
        let result = try await PeekabooServices.shared.screenCapture.captureArea(menuBarRect)

        let savedPath = try saveImage(result.imageData, name: "menubar")

        return [SavedFile(
            path: savedPath,
            item_label: "Menu Bar",
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: self.format.mimeType
        )]
    }

    private func analyzeImage(at path: String, with prompt: String) async throws -> ImageAnalysisData {
        let ai = await PeekabooAIService()
        let result = try await ai.analyzeImageFileDetailed(at: path, question: prompt, model: nil)
        return ImageAnalysisData(provider: result.provider, model: result.model, text: result.text)
    }

    // MARK: - Output Methods

    private func outputResults(_ savedFiles: [SavedFile]) {
        output(ImageCaptureData(saved_files: savedFiles)) {
            for file in savedFiles {
                print(file.path)
            }
        }
    }

    private func outputResultsWithAnalysis(_ savedFiles: [SavedFile], analysis: ImageAnalysisData) {
        let data = ImageCaptureWithAnalysisData(
            saved_files: savedFiles,
            analysis: analysis
        )
        output(data) {
            for file in savedFiles {
                print(file.path)
            }
            print("\nAnalysis (\(analysis.provider)/\(analysis.model)):")
            print(analysis.text)
        }
    }

    // Error handling is provided by ErrorHandlingCommand protocol
}

// MARK: - Helper Types

private struct ImageCaptureWithAnalysisData: Codable {
    let saved_files: [SavedFile]
    let analysis: ImageAnalysisData
}

extension ImageFormat {
    fileprivate var mimeType: String {
        switch self {
        case .png: "image/png"
        case .jpg: "image/jpeg"
        }
    }
}
