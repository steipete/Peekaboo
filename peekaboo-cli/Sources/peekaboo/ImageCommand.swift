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

struct ImageCommand: ParsableCommand {
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

    func run() {
        Logger.shared.setJsonOutputMode(jsonOutput)
        
        // Check platform support
        guard PlatformFactory.isPlatformSupported() else {
            handleError(CaptureError.unknownError("Platform not supported"))
            return
        }
        
        do {
            // Use platform factory to get implementations
            let permissionsManager = PlatformFactory.createPermissionsManager()
            let screenCapture = PlatformFactory.createScreenCapture()
            let windowManager = PlatformFactory.createWindowManager()
            let applicationFinder = PlatformFactory.createApplicationFinder()
            
            // Check permissions
            try permissionsManager.requireScreenCapturePermission()
            
            let savedFiles = try performCapture(
                screenCapture: screenCapture,
                windowManager: windowManager,
                applicationFinder: applicationFinder,
                permissionsManager: permissionsManager
            )
            outputResults(savedFiles)
        } catch {
            handleError(error)
        }
    }

    private func performCapture(
        screenCapture: ScreenCaptureProtocol,
        windowManager: WindowManagerProtocol,
        applicationFinder: ApplicationFinderProtocol,
        permissionsManager: PermissionsProtocol
    ) throws -> [SavedFile] {
        let captureMode = determineMode()

        switch captureMode {
        case .screen:
            return try captureScreens(screenCapture: screenCapture)
        case .window:
            guard let app else {
                throw CaptureError.appNotFound("No application specified for window capture")
            }
            return try captureApplicationWindow(
                app,
                screenCapture: screenCapture,
                windowManager: windowManager,
                applicationFinder: applicationFinder,
                permissionsManager: permissionsManager
            )
        case .multi:
            if let app {
                return try captureAllApplicationWindows(
                    app,
                    screenCapture: screenCapture,
                    windowManager: windowManager,
                    applicationFinder: applicationFinder,
                    permissionsManager: permissionsManager
                )
            } else {
                return try captureScreens(screenCapture: screenCapture)
            }
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
        let captureError: CaptureError = if let err = error as? CaptureError {
            err
        } else {
            .unknownError(error.localizedDescription)
        }

        // Log the full error details for debugging
        Logger.shared.debug("Image capture error: \(error)")

        // If it's a CaptureError with an underlying error, log that too
        switch captureError {
        case let .captureCreationFailed(underlyingError):
            if let underlying = underlyingError {
                Logger.shared.debug("Underlying capture creation error: \(underlying)")
            }
        case let .windowCaptureFailed(underlyingError):
            if let underlying = underlyingError {
                Logger.shared.debug("Underlying window capture error: \(underlying)")
            }
        case let .fileWriteError(_, underlyingError):
            if let underlying = underlyingError {
                Logger.shared.debug("Underlying file write error: \(underlying)")
            }
        default:
            break
        }

        if jsonOutput {
            let code: ErrorCode = switch captureError {
            case .screenRecordingPermissionDenied:
                .PERMISSION_ERROR_SCREEN_RECORDING
            case .accessibilityPermissionDenied:
                .PERMISSION_ERROR_ACCESSIBILITY
            case .appNotFound:
                .APP_NOT_FOUND
            case .windowNotFound, .noWindowsFound:
                .WINDOW_NOT_FOUND
            case .fileWriteError:
                .FILE_IO_ERROR
            case .invalidArgument:
                .INVALID_ARGUMENT
            case .unknownError:
                .UNKNOWN_ERROR
            default:
                .CAPTURE_FAILED
            }

            // Provide additional details for app not found errors
            var details: String? = nil
            if case .appNotFound = captureError {
                let runningApps = NSWorkspace.shared.runningApplications
                    .filter { $0.activationPolicy == .regular }
                    .compactMap(\.localizedName)
                    .sorted()
                    .joined(separator: ", ")
                details = "Available applications: \(runningApps)"
            }

            outputError(
                message: captureError.localizedDescription,
                code: code,
                details: details ?? "Image capture operation failed"
            )
        } else {
            var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
            print("Error: \(captureError.localizedDescription)", to: &localStandardErrorStream)
        }
        Foundation.exit(captureError.exitCode)
    }

    private func determineMode() -> CaptureMode {
        if let mode {
            return mode
        }
        return app != nil ? .window : .screen
    }

    private func captureScreens(screenCapture: ScreenCaptureProtocol) throws -> [SavedFile] {
        let task = Task {
            do {
                let capturedImages = try await screenCapture.captureScreen(displayIndex: screenIndex)
                var savedFiles: [SavedFile] = []
                
                for (index, capturedImage) in capturedImages.enumerated() {
                    let fileName = generateFileName(displayIndex: capturedImage.metadata.displayIndex ?? index)
                    let filePath = getOutputPath(fileName)
                    
                    // Save the image using the cross-platform method
                    try saveImageToDisk(capturedImage.image, to: filePath, format: format)
                    
                    let savedFile = SavedFile(
                        path: filePath,
                        item_label: "Display \(index + 1)",
                        window_title: nil,
                        window_id: nil,
                        window_index: nil,
                        mime_type: format == .png ? "image/png" : "image/jpeg"
                    )
                    savedFiles.append(savedFile)
                }
                
                return savedFiles
            } catch let error as ScreenCaptureError {
                throw mapScreenCaptureError(error)
            } catch {
                throw CaptureError.unknownError(error.localizedDescription)
            }
        }
        
        return try awaitTask(task)
    }

    private func getActiveDisplays() throws -> [DisplayInfo] {
        let screenCapture = PlatformFactory.createScreenCapture()
        return try screenCapture.getAvailableDisplays()
    }




    private func captureApplicationWindow(
        _ appIdentifier: String,
        screenCapture: ScreenCaptureProtocol,
        windowManager: WindowManagerProtocol,
        applicationFinder: ApplicationFinderProtocol,
        permissionsManager: PermissionsProtocol
    ) throws -> [SavedFile] {
        let targetApp: RunningApplication
        do {
            targetApp = try applicationFinder.findApplication(identifier: appIdentifier)
        } catch let ApplicationError.notFound(identifier) {
            throw CaptureError.appNotFound(identifier)
        } catch let ApplicationError.ambiguous(identifier, matches) {
            let appNames = matches.map { $0.localizedName ?? $0.bundleIdentifier ?? "Unknown" }
            throw CaptureError
                .unknownError("Multiple applications match '\(identifier)': \(appNames.joined(separator: ", "))")
        }

        if captureFocus == .foreground || (captureFocus == .auto && !targetApp.isActive) {
            try permissionsManager.requireApplicationManagementPermission()
            try applicationFinder.activateApplication(pid: targetApp.processIdentifier)
            Thread.sleep(forTimeInterval: 0.2) // Brief delay for activation
        }

        let windows = try windowManager.getWindowsForApp(pid: targetApp.processIdentifier, includeOffScreen: false)
        guard !windows.isEmpty else {
            throw CaptureError.noWindowsFound(targetApp.localizedName ?? appIdentifier)
        }

        let targetWindow: WindowData
        if let windowTitle {
            guard let window = windows.first(where: { $0.title.contains(windowTitle) }) else {
                throw CaptureError.windowNotFound
            }
            targetWindow = window
        } else if let windowIndex {
            guard windowIndex >= 0 && windowIndex < windows.count else {
                throw CaptureError.invalidWindowIndex(windowIndex)
            }
            targetWindow = windows[windowIndex]
        } else {
            targetWindow = windows[0] // Use first window
        }

        let task = Task {
            do {
                let capturedImage = try await screenCapture.captureWindow(windowId: targetWindow.windowId)
                
                let fileName = generateFileName(appName: targetApp.localizedName, windowTitle: targetWindow.title)
                let filePath = getOutputPath(fileName)

                try saveImageToDisk(capturedImage.image, to: filePath, format: format)

                return SavedFile(
                    path: filePath,
                    item_label: targetWindow.title,
                    window_title: targetWindow.title,
                    window_id: targetWindow.windowId,
                    window_index: targetWindow.windowIndex,
                    mime_type: format == .png ? "image/png" : "image/jpeg"
                )
            } catch let error as ScreenCaptureError {
                throw mapScreenCaptureError(error)
            } catch {
                throw CaptureError.unknownError(error.localizedDescription)
            }
        }
        
        return [try awaitTask(task)]
    }

    private func captureAllApplicationWindows(
        _ appIdentifier: String,
        screenCapture: ScreenCaptureProtocol,
        windowManager: WindowManagerProtocol,
        applicationFinder: ApplicationFinderProtocol,
        permissionsManager: PermissionsProtocol
    ) throws -> [SavedFile] {
        let targetApp: RunningApplication
        do {
            targetApp = try applicationFinder.findApplication(identifier: appIdentifier)
        } catch let ApplicationError.notFound(identifier) {
            throw CaptureError.appNotFound(identifier)
        } catch let ApplicationError.ambiguous(identifier, matches) {
            let appNames = matches.map { $0.localizedName ?? $0.bundleIdentifier ?? "Unknown" }
            throw CaptureError
                .unknownError("Multiple applications match '\(identifier)': \(appNames.joined(separator: ", "))")
        }

        if captureFocus == .foreground || (captureFocus == .auto && !targetApp.isActive) {
            try permissionsManager.requireApplicationManagementPermission()
            try applicationFinder.activateApplication(pid: targetApp.processIdentifier)
            Thread.sleep(forTimeInterval: 0.2)
        }

        let windows = try windowManager.getWindowsForApp(pid: targetApp.processIdentifier, includeOffScreen: false)
        guard !windows.isEmpty else {
            throw CaptureError.noWindowsFound(targetApp.localizedName ?? appIdentifier)
        }

        let task = Task {
            do {
                let capturedImages = try await screenCapture.captureApplication(
                    pid: targetApp.processIdentifier,
                    windowIndex: nil
                )
                
                var savedFiles: [SavedFile] = []
                
                for (index, capturedImage) in capturedImages.enumerated() {
                    let fileName = generateFileName(
                        appName: targetApp.localizedName,
                        windowIndex: index,
                        windowTitle: capturedImage.metadata.windowTitle
                    )
                    let filePath = getOutputPath(fileName)

                    try saveImageToDisk(capturedImage.image, to: filePath, format: format)

                    let savedFile = SavedFile(
                        path: filePath,
                        item_label: capturedImage.metadata.windowTitle ?? "Window \(index)",
                        window_title: capturedImage.metadata.windowTitle,
                        window_id: capturedImage.metadata.windowId,
                        window_index: index,
                        mime_type: format == .png ? "image/png" : "image/jpeg"
                    )
                    savedFiles.append(savedFile)
                }
                
                return savedFiles
            } catch let error as ScreenCaptureError {
                throw mapScreenCaptureError(error)
            } catch {
                throw CaptureError.unknownError(error.localizedDescription)
            }
        }
        
        return try awaitTask(task)
    }





    private func isScreenRecordingPermissionError(_ error: Error) -> Bool {
        let errorString = error.localizedDescription.lowercased()

        // Check for specific screen recording related errors
        if errorString.contains("screen recording") {
            return true
        }

        // Check for NSError codes specific to screen capture permissions
        if let nsError = error as NSError? {
            // ScreenCaptureKit specific error codes
            if nsError.domain == "com.apple.screencapturekit" && nsError.code == -3801 {
                // SCStreamErrorUserDeclined = -3801
                return true
            }

            // CoreGraphics error codes for screen capture
            if nsError.domain == "com.apple.coregraphics" && nsError.code == 1002 {
                // kCGErrorCannotComplete when permissions are denied
                return true
            }
        }

        // Only consider it a permission error if it mentions both "permission" and capture-related terms
        if errorString.contains("permission") &&
            (errorString.contains("capture") || errorString.contains("recording") || errorString.contains("screen")) {
            return true
        }

        return false
    }

    private func saveImage(_ image: CGImage, to path: String) throws(CaptureError) {
        let url = URL(fileURLWithPath: path)

        // Check if the parent directory exists
        let directory = url.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            let error = NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileNoSuchFileError,
                userInfo: [NSLocalizedDescriptionKey: "No such file or directory"]
            )
            throw CaptureError.fileWriteError(path, error)
        }

        let utType: UTType = format == .png ? .png : .jpeg
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            utType.identifier as CFString,
            1,
            nil
        ) else {
            // Try to create a more specific error for common cases
            if !FileManager.default.isWritableFile(atPath: directory.path) {
                let error = NSError(
                    domain: NSPOSIXErrorDomain,
                    code: Int(EACCES),
                    userInfo: [NSLocalizedDescriptionKey: "Permission denied"]
                )
                throw CaptureError.fileWriteError(path, error)
            }
            throw CaptureError.fileWriteError(path, nil)
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw CaptureError.fileWriteError(path, nil)
        }
    }

    private func saveImageToDisk(_ image: CGImage, to path: String, format: ImageFormat) throws {
        #if os(macOS)
        // Use the macOS-specific implementation for backward compatibility
        let macOSCapture = macOSScreenCapture()
        try macOSCapture.saveImage(image, to: path, format: format)
        #else
        // For other platforms, implement a basic PNG/JPEG writer
        try saveImageCrossPlatform(image, to: path, format: format)
        #endif
    }

    #if !os(macOS)
    private func saveImageCrossPlatform(_ image: CGImage, to path: String, format: ImageFormat) throws {
        let url = URL(fileURLWithPath: path)
        
        // Check if the parent directory exists
        let directory = url.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            let error = NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileNoSuchFileError,
                userInfo: [NSLocalizedDescriptionKey: "No such file or directory"]
            )
            throw CaptureError.fileWriteError(path, error)
        }
        
        // Create image destination
        let utType = format == .png ? "public.png" : "public.jpeg"
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            utType as CFString,
            1,
            nil
        ) else {
            throw CaptureError.fileWriteError(path, nil)
        }
        
        CGImageDestinationAddImage(destination, image, nil)
        
        guard CGImageDestinationFinalize(destination) else {
            throw CaptureError.fileWriteError(path, nil)
        }
    }
    #endif

    private func generateFileName(
        displayIndex: Int? = nil,
        appName: String? = nil,
        windowIndex: Int? = nil,
        windowTitle: String? = nil
    ) -> String {
        let timestamp = DateFormatter.timestamp.string(from: Date())
        let ext = format.rawValue

        if let displayIndex {
            return "screen_\(displayIndex + 1)_\(timestamp).\(ext)"
        } else if let appName {
            let cleanAppName = appName.replacingOccurrences(of: " ", with: "_")
            if let windowIndex {
                return "\(cleanAppName)_window_\(windowIndex)_\(timestamp).\(ext)"
            } else if let windowTitle {
                let cleanTitle = windowTitle.replacingOccurrences(of: " ", with: "_").prefix(20)
                return "\(cleanAppName)_\(cleanTitle)_\(timestamp).\(ext)"
            } else {
                return "\(cleanAppName)_\(timestamp).\(ext)"
            }
        } else {
            return "capture_\(timestamp).\(ext)"
        }
    }

    func getOutputPath(_ fileName: String) -> String {
        if let basePath = path {
            determineOutputPath(basePath: basePath, fileName: fileName)
        } else {
            "/tmp/\(fileName)"
        }
    }

    func determineOutputPath(basePath: String, fileName: String) -> String {
        // Check if basePath looks like a file (has extension and doesn't end with /)
        // Exclude special directory cases like "." and ".."
        let isLikelyFile = basePath.contains(".") && !basePath.hasSuffix("/") &&
            basePath != "." && basePath != ".."

        if isLikelyFile {
            // Create parent directory if needed
            let parentDir = (basePath as NSString).deletingLastPathComponent
            if !parentDir.isEmpty && parentDir != "/" {
                do {
                    try FileManager.default.createDirectory(
                        atPath: parentDir,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                } catch {
                    // Log but don't fail - maybe directory already exists
                    // Logger.debug("Could not create parent directory \(parentDir): \(error)")
                }
            }

            // For multiple screens, append screen index to avoid overwriting
            if screenIndex == nil {
                // Multiple screens - modify filename to include screen info
                let pathExtension = (basePath as NSString).pathExtension
                let pathWithoutExtension = (basePath as NSString).deletingPathExtension

                // Extract screen info from fileName (e.g., "screen_1_20250608_120000.png" -> "1_20250608_120000")
                let fileNameWithoutExt = (fileName as NSString).deletingPathExtension
                let screenSuffix = fileNameWithoutExt.replacingOccurrences(of: "screen_", with: "")

                return "\(pathWithoutExtension)_\(screenSuffix).\(pathExtension)"
            }

            return basePath
        } else {
            // Treat as directory - ensure it exists
            do {
                try FileManager.default.createDirectory(
                    atPath: basePath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                // Log but don't fail - maybe directory already exists
                // Logger.debug("Could not create directory \(basePath): \(error)")
            }
            return "\(basePath)/\(fileName)"
        }
    }

    private func awaitTask<T>(_ task: Task<T, Error>) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<T, Error>?
        
        Task {
            do {
                let value = try await task.value
                result = .success(value)
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        switch result! {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
    
    private func mapScreenCaptureError(_ error: ScreenCaptureError) -> CaptureError {
        switch error {
        case .permissionDenied:
            return .screenRecordingPermissionDenied
        case .displayNotFound(let index):
            return .unknownError("Display \(index) not found")
        case .windowNotFound(let id):
            return .windowNotFound
        case .captureFailure(let reason):
            return .unknownError(reason)
        case .notSupported:
            return .unknownError("Screen capture not supported on this platform")
        case .invalidConfiguration:
            return .invalidArgument("Invalid capture configuration")
        case .systemError(let error):
            return .unknownError(error.localizedDescription)
        }
    }
}

extension DateFormatter {
    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}
