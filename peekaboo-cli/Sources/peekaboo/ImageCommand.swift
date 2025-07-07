import AppKit
import ArgumentParser
import CoreGraphics
import Foundation
import ScreenCaptureKit
import UniformTypeIdentifiers

/// Command for capturing screenshots of screens, applications, or windows.
///
/// Provides comprehensive screenshot functionality with multiple capture modes,
/// flexible window selection, and configurable output options.
struct ImageCommand: AsyncParsableCommand, VerboseCommand {
    static let configuration = CommandConfiguration(
        commandName: "image",
        abstract: "Capture screenshots of screens, applications, or windows",
        discussion: """
        SYNOPSIS:
          peekaboo image [--app NAME] [--mode MODE] [--path PATH] [OPTIONS]

        EXAMPLES:
          peekaboo image --app Safari                    # Capture Safari's frontmost window
          peekaboo image --app Chrome --window-index 1   # Capture Chrome's second window
          peekaboo image --app "com.apple.Notes"         # Use bundle ID
          peekaboo image --app PID:12345                 # Use process ID

          peekaboo image --mode screen                   # Capture all screens
          peekaboo image --mode screen --screen-index 0  # Capture primary screen
          peekaboo image --mode frontmost                # Capture active window
          peekaboo image --mode multi --app Safari       # Capture all Safari windows

          peekaboo image --app Terminal --window-title "~/Projects"
          peekaboo image --app Safari --path screenshot.png --format jpg
          peekaboo image --app Xcode --capture-focus foreground

          # Capture and analyze in one command
          peekaboo image --mode frontmost --analyze "What errors are shown?"
          peekaboo image --app Safari --analyze "Summarize this webpage"
          peekaboo image --mode screen --analyze "Describe the desktop"

          # Scripting examples
          peekaboo image --app Safari --json-output | jq -r '.data.saved_files[0].path'
          peekaboo image --mode frontmost --json-output | jq '.data.saved_files[0].window_title'
          peekaboo image --analyze "Is there an error?" --json-output | jq -r '.data.analysis.text'

        CAPTURE MODES:
          screen     Capture entire screen(s)
          window     Capture specific application window (default with --app)
          multi      Capture all windows of an application
          frontmost  Capture the currently active window

        WINDOW SELECTION:
          When using --app, windows are captured based on:
          1. --window-title: Match by title (partial match supported)
          2. --window-index: Select by index (0 = frontmost)
          3. Default: Capture the frontmost window

        OUTPUT PATHS:
          - With --path: Save to specified location
          - Without --path: Save to current directory with timestamp
          - Multiple captures: Append window index to filename

        FOCUS BEHAVIOR:
          auto       Bring window to front if not visible (default)
          foreground Always bring window to front before capture
          background Never change window focus

        PERMISSIONS:
          Screen Recording: Required (System Settings > Privacy & Security)
          Accessibility: Required only for 'foreground' focus mode
        """
    )

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
        help: ArgumentHelp("Window focus behavior: auto, foreground, or background", valueName: "focus")
    )
    var captureFocus: CaptureFocus = .auto

    @Flag(name: .long, help: "Output results in JSON format for scripting")
    var jsonOutput = false

    @Option(name: .long, help: "Analyze the captured image with AI (provide a question/prompt)")
    var analyze: String?

    @Flag(name: .shortAndLong, help: "Enable verbose logging for detailed output")
    var verbose = false

    func run() async throws {
        configureVerboseLogging()
        Logger.shared.setJsonOutputMode(jsonOutput)
        do {
            try PermissionsChecker.requireScreenRecordingPermission()
            let savedFiles = try await performCapture()

            // If analyze option is provided, analyze the first captured image
            if let analyzePrompt = analyze, let firstFile = savedFiles.first {
                let analysisResult = try await analyzeImage(at: firstFile.path, with: analyzePrompt)
                outputResultsWithAnalysis(savedFiles, analysis: analysisResult)
            } else {
                outputResults(savedFiles)
            }
        } catch {
            handleError(error)
            // Throw a special exit error that AsyncParsableCommand can handle
            throw ExitCode(Int32(1))
        }
    }

    private func performCapture() async throws -> [SavedFile] {
        let captureMode = determineMode()
        Logger.shared.verbose("Starting capture with mode: \(captureMode)")

        switch captureMode {
        case .screen:
            Logger.shared.verbose("Capturing screen(s)")
            return try await captureScreens()
        case .window:
            guard let app else {
                throw CaptureError.appNotFound("No application specified for window capture")
            }
            Logger.shared.verbose("Capturing window for app: \(app)")
            return try await captureApplicationWindow(app)
        case .multi:
            if let app {
                Logger.shared.verbose("Capturing all windows for app: \(app)")
                return try await captureAllApplicationWindows(app)
            } else {
                Logger.shared.verbose("Capturing all screens (multi mode)")
                return try await captureScreens()
            }
        case .frontmost:
            Logger.shared.verbose("Capturing frontmost window")
            return try await captureFrontmostWindow()
        }
    }

    private func outputResults(_ savedFiles: [SavedFile]) {
        let data = ImageCaptureData(saved_files: savedFiles)

        if jsonOutput {
            outputSuccess(data: data)
        } else {
            print("Captured \(savedFiles.count) image(s):")
            for file in savedFiles {
                print("  \(file.path)")
            }
        }
    }

    private func analyzeImage(at path: String, with prompt: String) async throws -> AnalysisResult {
        // Validate image exists
        let imagePath = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: imagePath.path) else {
            throw AnalyzeError.fileNotFound(path)
        }

        // Read image and convert to base64
        let imageData = try Data(contentsOf: imagePath)
        let base64String = imageData.base64EncodedString()

        // Get configured providers
        let aiProvidersString = ConfigurationManager.shared.getAIProviders(cliValue: nil)
        let configuredProviders = AIProviderFactory.createProviders(from: aiProvidersString)

        guard !configuredProviders.isEmpty else {
            throw AnalyzeError.noProvidersConfigured
        }

        // Use first available provider
        let selectedProvider = try await AIProviderFactory.determineProvider(
            requestedType: nil,
            requestedModel: nil,
            configuredProviders: configuredProviders
        )

        // Perform analysis
        let startTime = Date()
        let analysisText = try await selectedProvider.analyze(
            imageBase64: base64String,
            question: prompt
        )
        let duration = Date().timeIntervalSince(startTime)

        return AnalysisResult(
            analysisText: analysisText,
            modelUsed: "\(selectedProvider.name)/\(selectedProvider.model)",
            durationSeconds: duration,
            imagePath: path
        )
    }

    private func outputResultsWithAnalysis(_ savedFiles: [SavedFile], analysis: AnalysisResult) {
        if jsonOutput {
            // Create combined output for JSON
            _ = ImageCaptureData(saved_files: savedFiles)
            // Add analysis data to the output
            let enrichedData: [String: Any] = [
                "saved_files": savedFiles.map { file in
                    [
                        "path": file.path,
                        "mime_type": file.mime_type,
                        "window_title": file.window_title as Any
                    ]
                },
                "analysis": [
                    "text": analysis.analysisText,
                    "model": analysis.modelUsed,
                    "duration_seconds": analysis.durationSeconds
                ]
            ]
            outputSuccess(data: enrichedData)
        } else {
            // Regular output
            print("Captured \(savedFiles.count) image(s):")
            for file in savedFiles {
                print("  \(file.path)")
            }
            print()
            print("\(analysis.analysisText)")
            print()
            print(
                "👻 Peekaboo: Analyzed image with \(analysis.modelUsed) in \(String(format: "%.2f", analysis.durationSeconds))s."
            )
        }
    }

    private func handleError(_ error: Error) {
        ImageErrorHandler.handleError(error, jsonOutput: jsonOutput)
    }

    private func determineMode() -> CaptureMode {
        if let mode {
            return mode
        }
        return app != nil ? .window : .screen
    }

    private func captureScreens() async throws(CaptureError) -> [SavedFile] {
        let handler = ScreenCaptureHandler(format: format, path: path)
        return try await handler.captureScreens(screenIndex: screenIndex)
    }

    private func captureApplicationWindow(_ appIdentifier: String) async throws -> [SavedFile] {
        let handler = WindowCaptureHandler(captureFocus: captureFocus, format: format, path: path)

        let targetApp: NSRunningApplication
        do {
            targetApp = try await findTargetApplication(appIdentifier, handler: handler)
        } catch let error as EarlyReturnError {
            return error.savedFiles
        }
        try await activateAppIfNeeded(targetApp)

        let windows = try WindowManager.getWindowsForApp(pid: targetApp.processIdentifier)
        guard !windows.isEmpty else {
            throw CaptureError.noWindowsFound(targetApp.localizedName ?? appIdentifier)
        }

        let targetWindow = try handler.findTargetWindow(
            from: windows,
            windowTitle: windowTitle,
            windowIndex: windowIndex,
            appName: targetApp.localizedName ?? "Unknown"
        )

        let fileName = FileNameGenerator.generateFileName(
            appName: targetApp.localizedName, windowTitle: targetWindow.title, format: format
        )
        // Single window capture when path is provided
        let isSingleCapture = path != nil
        let filePath = OutputPathResolver.getOutputPath(
            basePath: path,
            fileName: fileName,
            isSingleCapture: isSingleCapture
        )

        try await handler.captureWindow(targetWindow, to: filePath)

        return [createSavedFile(
            path: filePath,
            app: targetApp,
            window: targetWindow,
            windowIndex: targetWindow.windowIndex
        )]
    }

    private func captureAllApplicationWindows(_ appIdentifier: String) async throws -> [SavedFile] {
        let handler = WindowCaptureHandler(captureFocus: captureFocus, format: format, path: path)

        let targetApp: NSRunningApplication
        do {
            targetApp = try await findTargetApplication(appIdentifier, handler: handler)
        } catch let error as EarlyReturnError {
            return error.savedFiles
        }
        try await activateAppIfNeeded(targetApp)

        let windows = try WindowManager.getWindowsForApp(pid: targetApp.processIdentifier)
        guard !windows.isEmpty else {
            throw CaptureError.noWindowsFound(targetApp.localizedName ?? appIdentifier)
        }

        var savedFiles: [SavedFile] = []

        for (index, window) in windows.enumerated() {
            let fileName = FileNameGenerator.generateFileName(
                appName: targetApp.localizedName, windowIndex: index, windowTitle: window.title, format: format
            )
            // Multiple windows means not a single capture
            let filePath = OutputPathResolver.getOutputPath(
                basePath: path,
                fileName: fileName,
                isSingleCapture: false
            )

            try await handler.captureWindow(window, to: filePath)

            savedFiles.append(createSavedFile(
                path: filePath,
                app: targetApp,
                window: window,
                windowIndex: index
            ))
        }

        return savedFiles
    }

    private func captureFrontmostWindow() async throws -> [SavedFile] {
        Logger.shared.debug("Capturing frontmost window")
        let handler = WindowCaptureHandler(captureFocus: captureFocus, format: format, path: path)

        // Get the frontmost (active) application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            throw CaptureError.appNotFound("No frontmost application found")
        }

        Logger.shared.debug("Frontmost app: \(frontmostApp.localizedName ?? "Unknown")")

        // Get windows for the frontmost app
        let windows = try WindowManager.getWindowsForApp(pid: frontmostApp.processIdentifier)
        guard !windows.isEmpty else {
            throw CaptureError.noWindowsFound(frontmostApp.localizedName ?? "frontmost application")
        }

        // Get the frontmost window (index 0)
        let frontmostWindow = windows[0]

        Logger.shared.debug("Capturing frontmost window: '\(frontmostWindow.title)'")

        // Generate output path
        let timestamp = DateFormatter.timestamp.string(from: Date())
        let appName = frontmostApp.localizedName ?? "UnknownApp"
        let safeName = appName.replacingOccurrences(of: " ", with: "_")
        let fileName = "frontmost_\(safeName)_\(timestamp).\(format.rawValue)"
        // Single frontmost window capture when path is provided
        let isSingleCapture = path != nil
        let filePath = OutputPathResolver.getOutputPathWithFallback(
            basePath: path,
            fileName: fileName,
            isSingleCapture: isSingleCapture
        )

        // Capture the window
        try await handler.captureWindow(frontmostWindow, to: filePath)

        return [SavedFile(
            path: filePath,
            item_label: appName,
            window_title: frontmostWindow.title,
            window_id: UInt32(frontmostWindow.windowId),
            window_index: frontmostWindow.windowIndex,
            mime_type: format == .png ? "image/png" : "image/jpeg"
        )]
    }

    // MARK: - Helper Methods

    private func findTargetApplication(
        _ appIdentifier: String,
        handler: WindowCaptureHandler
    ) async throws -> NSRunningApplication {
        do {
            return try ApplicationFinder.findApplication(identifier: appIdentifier)
        } catch let ApplicationError.notFound(identifier) {
            throw CaptureError.appNotFound(identifier)
        } catch let ApplicationError.ambiguous(identifier, matches) {
            // For ambiguous matches, capture all windows from all matching applications
            Logger.shared.debug("Multiple applications match '\(identifier)', capturing all windows from all matches")
            let savedFiles = try await handler.captureWindowsFromMultipleApps(matches, appIdentifier: identifier)
            throw EarlyReturnError(savedFiles: savedFiles)
        }
    }

    private func activateAppIfNeeded(_ app: NSRunningApplication) async throws {
        if captureFocus == .foreground || (captureFocus == .auto && !app.isActive) {
            try PermissionsChecker.requireAccessibilityPermission()
            app.activate()
            try await Task.sleep(nanoseconds: 200_000_000) // Brief delay for activation
        }
    }

    private func createSavedFile(
        path: String,
        app: NSRunningApplication,
        window: WindowData,
        windowIndex: Int
    ) -> SavedFile {
        SavedFile(
            path: path,
            item_label: app.localizedName,
            window_title: window.title,
            window_id: window.windowId,
            window_index: windowIndex,
            mime_type: format == .png ? "image/png" : "image/jpeg"
        )
    }
}

/// Helper error for early return with results.
///
/// Used internally when handling ambiguous application matches to return
/// captured files before the normal flow completes.
private struct EarlyReturnError: Error {
    let savedFiles: [SavedFile]
}
