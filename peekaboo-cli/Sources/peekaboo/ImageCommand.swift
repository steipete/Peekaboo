import ArgumentParser
import CoreGraphics
import Foundation

#if os(macOS)
import AppKit
import ScreenCaptureKit
import UniformTypeIdentifiers
#endif

// Define the wrapper struct
struct FileHandleTextOutputStream: TextOutputStream {
    private let fileHandle: FileHandle

    init(_ fileHandle: FileHandle) {
        self.fileHandle = fileHandle
    }

    mutating func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        fileHandle.write(data)
    }
}

struct ImageCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "image",
        abstract: "Capture screen or window images"
    )

    @Option(name: .long, help: "Target application identifier")
    var app: String?

    @Option(name: .long, help: "Base output path for saved images")
    var path: String?

    @Option(name: .long, help: "Capture mode")
    var mode: CaptureMode?

    @Option(name: .long, help: "Window title to capture")
    var windowTitle: String?

    @Option(name: .long, help: "Window index to capture (0=frontmost)")
    var windowIndex: Int?

    @Option(name: .long, help: "Screen index to capture (0-based)")
    var screenIndex: Int?

    @Option(name: .long, help: "Image format")
    var format: ImageFormat = .png

    @Option(name: .long, help: "Capture focus behavior")
    var captureFocus: CaptureFocus = .auto

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    func run() async throws {
        Logger.shared.setJsonOutputMode(jsonOutput)
        
        // Check platform support
        guard PlatformFactory.isSupported else {
            let error = CaptureError.platformNotSupported(PlatformFactory.currentPlatform)
            handleError(error)
            throw ExitCode(Int32(1))
        }
        
        let capabilities = PlatformFactory.capabilities
        guard capabilities.screenCapture else {
            let error = CaptureError.featureNotSupported("Screen capture", PlatformFactory.currentPlatform)
            handleError(error)
            throw ExitCode(Int32(1))
        }
        
        do {
            // Check permissions using platform-specific checker
            let permissionsChecker = PlatformFactory.createPermissionsChecker()
            let hasPermission = await permissionsChecker.hasScreenRecordingPermission()
            
            if !hasPermission {
                let instructions = permissionsChecker.getPermissionInstructions()
                let error = CaptureError.screenRecordingPermissionDenied
                Logger.shared.error("Screen recording permission required. \(instructions)")
                handleError(error)
                throw ExitCode(Int32(1))
            }
            
            let savedFiles = try await performCapture()
            outputResults(savedFiles)
        } catch {
            handleError(error)
            throw ExitCode(Int32(1))
        }
    }

    private func performCapture() async throws -> [SavedFile] {
        let captureMode = determineMode()

        switch captureMode {
        case .screen:
            return try await captureScreens()
        case .window:
            guard let app else {
                throw CaptureError.appNotFound("No application specified for window capture")
            }
            return try await captureApplicationWindow(app)
        case .multi:
            if let app {
                return try await captureAllApplicationWindows(app)
            } else {
                return try await captureScreens()
            }
        case .frontmost:
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

    private func handleError(_ error: Error) {
        ImageErrorHandler.handleError(error, jsonOutput: jsonOutput)
    }

    private func determineMode() -> CaptureMode {
        if let mode {
            return mode
        }
        return app != nil ? .window : .screen
    }

    private func captureScreens() async throws -> [SavedFile] {
        let screenCapture = PlatformFactory.createScreenCapture()
        let screens = try await screenCapture.getAvailableScreens()
        
        guard !screens.isEmpty else {
            throw CaptureError.noDisplaysAvailable
        }
        
        var savedFiles: [SavedFile] = []

        if let screenIndex {
            savedFiles = try await captureSpecificScreen(screens: screens, screenIndex: screenIndex)
        } else {
            savedFiles = try await captureAllScreens(screens: screens)
        }

        return savedFiles
    }

    private func captureSpecificScreen(
        screens: [ScreenInfo],
        screenIndex: Int
    ) async throws -> [SavedFile] {
        if screenIndex >= 0 && screenIndex < screens.count {
            let screen = screens[screenIndex]
            let labelSuffix = " (Index \(screenIndex))"
            return try await [captureSingleScreen(screen: screen, labelSuffix: labelSuffix)]
        } else {
            Logger.shared.debug("Screen index \(screenIndex) is out of bounds. Capturing all screens instead.")
            return try await captureAllScreensWithFallback(screens: screens)
        }
    }

    private func captureAllScreens(screens: [ScreenInfo]) async throws -> [SavedFile] {
        var savedFiles: [SavedFile] = []
        for screen in screens {
            let savedFile = try await captureSingleScreen(screen: screen, labelSuffix: "")
            savedFiles.append(savedFile)
        }
        return savedFiles
    }

    private func captureAllScreensWithFallback(screens: [ScreenInfo]) async throws -> [SavedFile] {
        var savedFiles: [SavedFile] = []
        for screen in screens {
            let savedFile = try await captureSingleScreenWithFallback(screen: screen, labelSuffix: "")
            savedFiles.append(savedFile)
        }
        return savedFiles
    }

    private func captureSingleScreen(
        screen: ScreenInfo,
        labelSuffix: String
    ) async throws -> SavedFile {
        let fileName = FileNameGenerator.generateFileName(displayIndex: screen.index, format: format)
        let filePath = OutputPathResolver.getOutputPath(basePath: path, fileName: fileName)

        try await captureScreen(screen, to: filePath)

        return SavedFile(
            path: filePath,
            item_label: "Display \(screen.index + 1)\(labelSuffix)",
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: format == .png ? "image/png" : "image/jpeg"
        )
    }

    private func captureSingleScreenWithFallback(
        screen: ScreenInfo,
        labelSuffix: String
    ) async throws -> SavedFile {
        let fileName = FileNameGenerator.generateFileName(displayIndex: screen.index, format: format)
        let filePath = OutputPathResolver.getOutputPathWithFallback(basePath: path, fileName: fileName)

        try await captureScreen(screen, to: filePath)

        return SavedFile(
            path: filePath,
            item_label: "Display \(screen.index + 1)\(labelSuffix)",
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: format == .png ? "image/png" : "image/jpeg"
        )
    }

    private func captureApplicationWindow(_ appIdentifier: String) async throws -> [SavedFile] {
        let applicationFinder = PlatformFactory.createApplicationFinder()
        let windowManager = PlatformFactory.createWindowManager()
        
        // Find the application
        let apps = try await applicationFinder.findApplications(matching: appIdentifier)
        guard !apps.isEmpty else {
            throw CaptureError.appNotFound(appIdentifier)
        }
        
        let targetApp = apps.first!
        
        // Handle focus behavior (platform-specific)
        if captureFocus == .foreground || captureFocus == .auto {
            await handleApplicationFocus(targetApp)
        }

        let windows = try await windowManager.getWindows(for: targetApp.id)
        guard !windows.isEmpty else {
            throw CaptureError.noWindowsFound(targetApp.name)
        }

        let targetWindow: PlatformWindowInfo
        if let windowTitle {
            guard let window = windows.first(where: { $0.title.contains(windowTitle) }) else {
                let availableTitles = windows.map { "\"\($0.title)\"" }.joined(separator: ", ")
                throw CaptureError.windowTitleNotFound(windowTitle, targetApp.name, availableTitles)
            }
            targetWindow = window
        } else if let windowIndex {
            guard windowIndex >= 0 && windowIndex < windows.count else {
                throw CaptureError.invalidWindowIndex(windowIndex)
            }
            targetWindow = windows[windowIndex]
        } else {
            targetWindow = windows[0] // frontmost window
        }

        let fileName = FileNameGenerator.generateFileName(
            appName: targetApp.name, windowTitle: targetWindow.title, format: format
        )
        let filePath = OutputPathResolver.getOutputPath(basePath: path, fileName: fileName)

        try await captureWindow(targetWindow, to: filePath)

        let savedFile = SavedFile(
            path: filePath,
            item_label: targetApp.name,
            window_title: targetWindow.title,
            window_id: targetWindow.id,
            window_index: 0, // This would need to be calculated properly
            mime_type: format == .png ? "image/png" : "image/jpeg"
        )

        return [savedFile]
    }

    private func captureAllApplicationWindows(_ appIdentifier: String) async throws -> [SavedFile] {
        let applicationFinder = PlatformFactory.createApplicationFinder()
        let windowManager = PlatformFactory.createWindowManager()
        
        // Find the application
        let apps = try await applicationFinder.findApplications(matching: appIdentifier)
        guard !apps.isEmpty else {
            throw CaptureError.appNotFound(appIdentifier)
        }
        
        var allSavedFiles: [SavedFile] = []
        
        for targetApp in apps {
            // Handle focus behavior (platform-specific)
            if captureFocus == .foreground || captureFocus == .auto {
                await handleApplicationFocus(targetApp)
            }

            let windows = try await windowManager.getWindows(for: targetApp.id)
            if windows.isEmpty {
                Logger.shared.debug("No windows found for app: \(targetApp.name)")
                continue
            }

            for (index, window) in windows.enumerated() {
                let fileName = FileNameGenerator.generateFileName(
                    appName: targetApp.name, windowIndex: index, windowTitle: window.title, format: format
                )
                let filePath = OutputPathResolver.getOutputPath(basePath: path, fileName: fileName)

                try await captureWindow(window, to: filePath)

                let savedFile = SavedFile(
                    path: filePath,
                    item_label: targetApp.name,
                    window_title: window.title,
                    window_id: window.id,
                    window_index: index,
                    mime_type: format == .png ? "image/png" : "image/jpeg"
                )
                allSavedFiles.append(savedFile)
            }
        }

        guard !allSavedFiles.isEmpty else {
            throw CaptureError.noWindowsFound("No windows found for any matching applications of '\(appIdentifier)'")
        }

        return allSavedFiles
    }

    private func captureScreen(_ screen: ScreenInfo, to path: String) async throws {
        let screenCapture = PlatformFactory.createScreenCapture()
        
        do {
            let imageData = try await screenCapture.captureScreen(screenIndex: screen.index)
            try imageData.write(to: URL(fileURLWithPath: path))
        } catch {
            throw CaptureError.captureCreationFailed(error)
        }
    }

    private func captureWindow(_ window: PlatformWindowInfo, to path: String) async throws {
        let screenCapture = PlatformFactory.createScreenCapture()
        
        do {
            let imageData = try await screenCapture.captureWindow(windowId: window.id, bounds: window.bounds)
            try imageData.write(to: URL(fileURLWithPath: path))
        } catch {
            throw CaptureError.windowCaptureFailed(error)
        }
    }

    private func captureFrontmostWindow() async throws -> [SavedFile] {
        Logger.shared.debug("Capturing frontmost window")

        // This is platform-specific and would need different implementations
        #if os(macOS)
        return try await captureFrontmostWindowMacOS()
        #else
        // For other platforms, we'd need to implement frontmost window detection
        throw CaptureError.featureNotSupported("Frontmost window capture", PlatformFactory.currentPlatform)
        #endif
    }
    
    #if os(macOS)
    private func captureFrontmostWindowMacOS() async throws -> [SavedFile] {
        // Get the frontmost (active) application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            throw CaptureError.appNotFound("No frontmost application found")
        }

        Logger.shared.debug("Frontmost app: \(frontmostApp.localizedName ?? "Unknown")")

        // Use the cross-platform window manager
        let windowManager = PlatformFactory.createWindowManager()
        let windows = try await windowManager.getWindows(for: String(frontmostApp.processIdentifier))
        
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
        let filePath = OutputPathResolver.getOutputPathWithFallback(basePath: path, fileName: fileName)

        // Capture the window
        try await captureWindow(frontmostWindow, to: filePath)

        return [SavedFile(
            path: filePath,
            item_label: appName,
            window_title: frontmostWindow.title,
            window_id: frontmostWindow.id,
            window_index: 0,
            mime_type: format == .png ? "image/png" : "image/jpeg"
        )]
    }
    #endif
    
    private func handleApplicationFocus(_ app: ApplicationInfo) async {
        #if os(macOS)
        // On macOS, we can activate applications
        if let pid = app.processId {
            let runningApp = NSRunningApplication(processIdentifier: pid_t(pid))
            runningApp?.activate()
            try? await Task.sleep(nanoseconds: 200_000_000) // Brief delay for activation
        }
        #else
        // On other platforms, focus handling would be different or not available
        Logger.shared.debug("Application focus handling not implemented for \(PlatformFactory.currentPlatform)")
        #endif
    }
}
