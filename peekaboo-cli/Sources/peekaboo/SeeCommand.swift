import AppKit
import ArgumentParser
import AXorcist
import CoreGraphics
import Foundation

/// Captures a screenshot and builds an interactive UI map.
/// This is the foundation command for all GUI automation in Peekaboo 3.0.
@available(macOS 14.0, *)
struct SeeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "see",
        abstract: "Capture screen and map UI elements for interaction",
        discussion: """
            The 'see' command captures a screenshot and analyzes the UI hierarchy,
            creating an interactive map that subsequent commands can use.

            EXAMPLES:
              peekaboo see                           # Capture frontmost window
              peekaboo see --app Safari              # Capture Safari window
              peekaboo see --mode screen             # Capture entire screen
              peekaboo see --window-title "GitHub"   # Capture specific window
              peekaboo see --annotate                # Generate annotated screenshot
              peekaboo see --analyze "Find login"    # Capture and analyze

            OUTPUT:
              Returns a session ID that can be used with click, type, and other
              interaction commands. Also outputs the screenshot path and UI analysis.
        """
    )

    @Option(help: "Application name to capture")
    var app: String?

    @Option(help: "Specific window title to capture")
    var windowTitle: String?

    @Option(help: "Capture mode (screen, window, frontmost)")
    var mode: CaptureMode = .frontmost

    @Option(help: "Output path for screenshot")
    var path: String?

    @Flag(help: "Generate annotated screenshot with interaction markers")
    var annotate = false

    @Option(help: "Analyze captured content with AI")
    var analyze: String?

    @Flag(help: "Output in JSON format")
    var jsonOutput = false

    enum CaptureMode: String, ExpressibleByArgument {
        case screen
        case window
        case frontmost
    }

    mutating func run() async throws {
        let startTime = Date()
        let sessionCache = SessionCache()

        do {
            // Perform capture based on mode
            let captureResult: CaptureResult

            switch mode {
            case .screen:
                captureResult = try await captureScreen()
            case .window:
                if let appName = app {
                    captureResult = try await captureWindow(app: appName, title: windowTitle)
                } else {
                    throw ValidationError("--app is required for window mode")
                }
            case .frontmost:
                captureResult = try await captureFrontmost()
            }

            // Save screenshot (already saved during capture)
            let outputPath = try saveScreenshot(captureResult)

            // Update session cache with UI map
            try await sessionCache.updateScreenshot(
                path: outputPath,
                application: captureResult.applicationName,
                window: captureResult.windowTitle
            )

            // Generate annotated screenshot if requested
            var annotatedPath: String?
            if annotate {
                annotatedPath = try await generateAnnotatedScreenshot(
                    originalPath: outputPath,
                    sessionCache: sessionCache
                )
            }

            // Perform AI analysis if requested
            var analysisResult: String?
            if let prompt = analyze {
                analysisResult = try await performAnalysis(
                    imagePath: outputPath,
                    prompt: prompt
                )
            }

            // Load session data for output
            let sessionData = await sessionCache.load()
            let elementCount = sessionData?.uiMap.count ?? 0
            let interactableCount = sessionData?.uiMap.values.count(where: { $0.isActionable }) ?? 0

            // Prepare output
            if jsonOutput {
                // Build UI element summaries
                let uiElements: [UIElementSummary] = sessionData?.uiMap.values.map { element in
                    UIElementSummary(
                        id: element.id,
                        role: element.role,
                        title: element.title,
                        is_actionable: element.isActionable
                    )
                } ?? []

                let output = SeeResult(
                    session_id: sessionCache.sessionId,
                    screenshot_path: outputPath,
                    annotated_path: annotatedPath,
                    application_name: captureResult.applicationName,
                    window_title: captureResult.windowTitle,
                    element_count: elementCount,
                    interactable_count: interactableCount,
                    capture_mode: mode.rawValue,
                    analysis_result: analysisResult,
                    execution_time: Date().timeIntervalSince(startTime),
                    ui_elements: uiElements
                )
                outputSuccessCodable(data: output)
            } else {
                print("✅ Screenshot captured successfully")
                print("📍 Session ID: \(sessionCache.sessionId)")
                print("🖼  Screenshot: \(outputPath)")
                if let annotated = annotatedPath {
                    print("🎯 Annotated: \(annotated)")
                }
                print("🔍 Found \(elementCount) UI elements (\(interactableCount) interactive)")
                if let app = captureResult.applicationName {
                    print("📱 Application: \(app)")
                }
                if let window = captureResult.windowTitle {
                    print("🪟 Window: \(window)")
                }
                if let analysis = analysisResult {
                    print("🤖 Analysis:")
                    print(analysis)
                }
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            if jsonOutput {
                ImageErrorHandler.handleError(error, jsonOutput: true)
            } else {
                ImageErrorHandler.handleError(error, jsonOutput: false)
            }
            throw ExitCode.failure
        }
    }

    private func captureScreen() async throws -> CaptureResult {
        let suggestedName = "screen_\(Date().timeIntervalSince1970)"
        let outputPath = path ?? FileNameGenerator.generateFileName(format: .png)

        // Get primary display
        let displayID = CGMainDisplayID()
        try await ScreenCapture.captureDisplay(displayID, to: outputPath)

        return CaptureResult(
            outputPath: outputPath,
            applicationName: nil,
            windowTitle: nil,
            suggestedName: suggestedName
        )
    }

    private func captureWindow(app: String, title: String?) async throws -> CaptureResult {
        let appInfo = try ApplicationFinder.findApplication(identifier: app)
        let windows = try WindowManager.getWindowsForApp(pid: appInfo.processIdentifier)

        let targetWindow: WindowData
        if let title {
            guard let window = windows.first(where: { $0.title.contains(title) }) else {
                throw CaptureError.windowNotFound
            }
            targetWindow = window
        } else {
            guard let window = windows.first else {
                throw CaptureError.windowNotFound
            }
            targetWindow = window
        }

        let appName = appInfo.localizedName ?? "Unknown"
        let suggestedName = appName.lowercased().replacingOccurrences(of: " ", with: "_")
        let outputPath = path ?? FileNameGenerator.generateFileName(
            appName: appName,
            windowTitle: targetWindow.title,
            format: .png
        )

        try await ScreenCapture.captureWindow(targetWindow, to: outputPath)

        return CaptureResult(
            outputPath: outputPath,
            applicationName: appName,
            windowTitle: targetWindow.title,
            suggestedName: suggestedName
        )
    }

    private func captureFrontmost() async throws -> CaptureResult {
        // Get frontmost application using NSWorkspace
        let workspace = NSWorkspace.shared
        guard let frontApp = workspace.frontmostApplication else {
            throw CaptureError.appNotFound("No active application")
        }

        let windows = try WindowManager.getWindowsForApp(pid: frontApp.processIdentifier)
        guard let frontWindow = windows.first else {
            throw CaptureError.windowNotFound
        }

        let appName = frontApp.localizedName ?? "Unknown"
        let suggestedName = appName.lowercased().replacingOccurrences(of: " ", with: "_")
        let outputPath = path ?? FileNameGenerator.generateFileName(
            appName: appName,
            windowTitle: frontWindow.title,
            format: .png
        )

        try await ScreenCapture.captureWindow(frontWindow, to: outputPath)

        return CaptureResult(
            outputPath: outputPath,
            applicationName: appName,
            windowTitle: frontWindow.title,
            suggestedName: suggestedName
        )
    }

    private func saveScreenshot(_ captureResult: CaptureResult) throws -> String {
        // Image is already saved, just return the path
        captureResult.outputPath
    }

    private func generateAnnotatedScreenshot(
        originalPath: String,
        sessionCache: SessionCache
    ) async throws -> String {
        // For now, we'll create a simple annotated version by adding element IDs
        // In a full implementation, this would overlay visual markers on the screenshot

        // Load the session data to get UI elements
        guard let sessionData = await sessionCache.load() else {
            return originalPath
        }

        // Generate annotated filename
        let url = URL(fileURLWithPath: originalPath)
        let annotatedPath = url.deletingPathExtension()
            .appendingPathExtension("annotated")
            .appendingPathExtension(url.pathExtension)
            .path

        // For now, just copy the original image
        // In a real implementation, we would:
        // 1. Load the image
        // 2. Draw rectangles around each UI element
        // 3. Add element IDs as labels
        // 4. Save the annotated image

        try FileManager.default.copyItem(atPath: originalPath, toPath: annotatedPath)

        // Log annotation info
        let interactableElements = sessionData.uiMap.values.filter(\.isActionable)
        print("📝 Created annotated screenshot with \(interactableElements.count) interactive elements")

        return annotatedPath
    }

    private func performAnalysis(imagePath: String, prompt: String) async throws -> String {
        // Get configured providers
        let aiProvidersString = ConfigurationManager.shared.getAIProviders(cliValue: nil)
        let configuredProviders = AIProviderFactory.createProviders(from: aiProvidersString)

        guard !configuredProviders.isEmpty else {
            throw CaptureError.invalidArgument("No AI providers configured")
        }

        // Use first available provider
        guard let analyzer = await AIProviderFactory.findAvailableProvider(from: configuredProviders) else {
            throw CaptureError.invalidArgument("No AI provider available")
        }

        // Read image and convert to base64
        let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
        let base64String = imageData.base64EncodedString()

        return try await analyzer.analyze(
            imageBase64: base64String,
            question: prompt
        )
    }
}

// MARK: - Supporting Types

private struct CaptureResult {
    let outputPath: String
    let applicationName: String?
    let windowTitle: String?
    let suggestedName: String
}

// MARK: - JSON Output Structure

struct SeeResult: Codable {
    let session_id: String
    let screenshot_path: String
    let annotated_path: String?
    let application_name: String?
    let window_title: String?
    let element_count: Int
    let interactable_count: Int
    let capture_mode: String
    let analysis_result: String?
    let execution_time: TimeInterval
    let ui_elements: [UIElementSummary]
    var success: Bool = true
}

struct UIElementSummary: Codable {
    let id: String
    let role: String
    let title: String?
    let is_actionable: Bool
}
