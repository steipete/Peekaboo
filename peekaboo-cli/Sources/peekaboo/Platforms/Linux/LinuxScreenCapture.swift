#if os(Linux)
import Foundation
import CoreGraphics

/// Linux-specific implementation of screen capture supporting both X11 and Wayland
class LinuxScreenCapture: ScreenCaptureProtocol {
    
    private let displayServer: LinuxDisplayServer
    
    init() {
        // Detect display server
        if ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] != nil {
            self.displayServer = .wayland
        } else if ProcessInfo.processInfo.environment["DISPLAY"] != nil {
            self.displayServer = .x11
        } else {
            self.displayServer = .unknown
        }
    }
    
    func captureScreen(displayIndex: Int?) async throws -> [CapturedImage] {
        switch displayServer {
        case .x11:
            return try await captureScreenX11(displayIndex: displayIndex)
        case .wayland:
            return try await captureScreenWayland(displayIndex: displayIndex)
        case .unknown:
            throw ScreenCaptureError.notSupported
        }
    }
    
    func captureWindow(windowId: UInt32) async throws -> CapturedImage {
        switch displayServer {
        case .x11:
            return try await captureWindowX11(windowId: windowId)
        case .wayland:
            return try await captureWindowWayland(windowId: windowId)
        case .unknown:
            throw ScreenCaptureError.notSupported
        }
    }
    
    func captureApplication(pid: pid_t, windowIndex: Int?) async throws -> [CapturedImage] {
        // Get windows for the application
        let windowManager = LinuxWindowManager()
        let windows = try windowManager.getWindowsForApp(pid: pid, includeOffScreen: false)
        
        if windows.isEmpty {
            throw ScreenCaptureError.captureFailure("No windows found for application with PID \(pid)")
        }
        
        var capturedImages: [CapturedImage] = []
        
        if let windowIndex = windowIndex {
            if windowIndex >= 0 && windowIndex < windows.count {
                let window = windows[windowIndex]
                let image = try await captureWindow(windowId: window.windowId)
                capturedImages.append(image)
            } else {
                throw ScreenCaptureError.captureFailure("Window index \(windowIndex) out of range")
            }
        } else {
            // Capture all windows
            for window in windows {
                let image = try await captureWindow(windowId: window.windowId)
                capturedImages.append(image)
            }
        }
        
        return capturedImages
    }
    
    func getAvailableDisplays() throws -> [DisplayInfo] {
        switch displayServer {
        case .x11:
            return try getAvailableDisplaysX11()
        case .wayland:
            return try getAvailableDisplaysWayland()
        case .unknown:
            throw ScreenCaptureError.notSupported
        }
    }
    
    func isScreenCaptureSupported() -> Bool {
        return displayServer != .unknown
    }
    
    func getPreferredImageFormat() -> PlatformImageFormat {
        return .png
    }
    
    // MARK: - X11 Implementation
    
    private func captureScreenX11(displayIndex: Int?) async throws -> [CapturedImage] {
        // Use external tools for X11 screen capture
        let displays = try getAvailableDisplaysX11()
        var capturedImages: [CapturedImage] = []
        
        if let displayIndex = displayIndex {
            if displayIndex >= 0 && displayIndex < displays.count {
                let display = displays[displayIndex]
                let image = try await captureSingleDisplayX11(display)
                capturedImages.append(image)
            } else {
                throw ScreenCaptureError.displayNotFound(displayIndex)
            }
        } else {
            // Capture all displays (or just the root window for simplicity)
            let image = try await captureRootWindowX11()
            capturedImages.append(image)
        }
        
        return capturedImages
    }
    
    private func captureWindowX11(windowId: UInt32) async throws -> CapturedImage {
        // Use xwininfo and import/xwd for window capture
        let tempFile = "/tmp/peekaboo_window_\(windowId)_\(Date().timeIntervalSince1970).png"
        
        // Try using import (ImageMagick) first
        let importResult = try await runCommand([
            "import", "-window", String(windowId), tempFile
        ])
        
        if importResult.exitCode != 0 {
            // Fallback to xwd + convert
            let xwdFile = tempFile.replacingOccurrences(of: ".png", with: ".xwd")
            
            let xwdResult = try await runCommand([
                "xwd", "-id", String(windowId), "-out", xwdFile
            ])
            
            if xwdResult.exitCode != 0 {
                throw ScreenCaptureError.captureFailure("Failed to capture window: \(xwdResult.stderr)")
            }
            
            let convertResult = try await runCommand([
                "convert", xwdFile, tempFile
            ])
            
            if convertResult.exitCode != 0 {
                throw ScreenCaptureError.captureFailure("Failed to convert window capture: \(convertResult.stderr)")
            }
            
            // Clean up xwd file
            try? FileManager.default.removeItem(atPath: xwdFile)
        }
        
        // Load the captured image
        guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: tempFile)),
              let cgImage = createCGImageFromPNG(imageData) else {
            throw ScreenCaptureError.captureFailure("Failed to load captured image")
        }
        
        // Clean up temp file
        try? FileManager.default.removeItem(atPath: tempFile)
        
        // Get window information
        let windowInfo = try getWindowInfoX11(windowId: windowId)
        
        let metadata = CaptureMetadata(
            captureTime: Date(),
            displayIndex: nil,
            windowId: windowId,
            windowTitle: windowInfo.title,
            applicationName: nil,
            bounds: windowInfo.bounds,
            scaleFactor: 1.0,
            colorSpace: cgImage.colorSpace
        )
        
        return CapturedImage(image: cgImage, metadata: metadata)
    }
    
    private func captureSingleDisplayX11(_ display: DisplayInfo) async throws -> CapturedImage {
        return try await captureRootWindowX11()
    }
    
    private func captureRootWindowX11() async throws -> CapturedImage {
        let tempFile = "/tmp/peekaboo_screen_\(Date().timeIntervalSince1970).png"
        
        // Use import to capture root window
        let result = try await runCommand([
            "import", "-window", "root", tempFile
        ])
        
        if result.exitCode != 0 {
            throw ScreenCaptureError.captureFailure("Failed to capture screen: \(result.stderr)")
        }
        
        // Load the captured image
        guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: tempFile)),
              let cgImage = createCGImageFromPNG(imageData) else {
            throw ScreenCaptureError.captureFailure("Failed to load captured image")
        }
        
        // Clean up temp file
        try? FileManager.default.removeItem(atPath: tempFile)
        
        let metadata = CaptureMetadata(
            captureTime: Date(),
            displayIndex: 0,
            windowId: nil,
            windowTitle: nil,
            applicationName: nil,
            bounds: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height),
            scaleFactor: 1.0,
            colorSpace: cgImage.colorSpace
        )
        
        return CapturedImage(image: cgImage, metadata: metadata)
    }
    
    private func getAvailableDisplaysX11() throws -> [DisplayInfo] {
        // For simplicity, return a single display representing the root window
        // A full implementation would use Xrandr to get multiple displays
        return [
            DisplayInfo(
                displayId: 0,
                index: 0,
                bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080), // Default, should be detected
                workArea: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                scaleFactor: 1.0,
                isPrimary: true,
                name: "Display 1",
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
        ]
    }
    
    private func getWindowInfoX11(windowId: UInt32) throws -> (title: String, bounds: CGRect) {
        // Use xwininfo to get window information
        let result = try runCommandSync([
            "xwininfo", "-id", String(windowId)
        ])
        
        if result.exitCode != 0 {
            throw ScreenCaptureError.windowNotFound(windowId)
        }
        
        // Parse xwininfo output
        var title = "Untitled"
        var x: CGFloat = 0, y: CGFloat = 0, width: CGFloat = 0, height: CGFloat = 0
        
        let lines = result.stdout.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Window id:") && line.contains("\"") {
                let parts = line.components(separatedBy: "\"")
                if parts.count >= 2 {
                    title = parts[1]
                }
            } else if line.contains("Absolute upper-left X:") {
                x = CGFloat(extractNumber(from: line) ?? 0)
            } else if line.contains("Absolute upper-left Y:") {
                y = CGFloat(extractNumber(from: line) ?? 0)
            } else if line.contains("Width:") {
                width = CGFloat(extractNumber(from: line) ?? 0)
            } else if line.contains("Height:") {
                height = CGFloat(extractNumber(from: line) ?? 0)
            }
        }
        
        return (title, CGRect(x: x, y: y, width: width, height: height))
    }
    
    // MARK: - Wayland Implementation
    
    private func captureScreenWayland(displayIndex: Int?) async throws -> [CapturedImage] {
        // Use grim for Wayland screen capture
        let tempFile = "/tmp/peekaboo_screen_\(Date().timeIntervalSince1970).png"
        
        let result = try await runCommand([
            "grim", tempFile
        ])
        
        if result.exitCode != 0 {
            throw ScreenCaptureError.captureFailure("Failed to capture screen with grim: \(result.stderr)")
        }
        
        // Load the captured image
        guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: tempFile)),
              let cgImage = createCGImageFromPNG(imageData) else {
            throw ScreenCaptureError.captureFailure("Failed to load captured image")
        }
        
        // Clean up temp file
        try? FileManager.default.removeItem(atPath: tempFile)
        
        let metadata = CaptureMetadata(
            captureTime: Date(),
            displayIndex: displayIndex ?? 0,
            windowId: nil,
            windowTitle: nil,
            applicationName: nil,
            bounds: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height),
            scaleFactor: 1.0,
            colorSpace: cgImage.colorSpace
        )
        
        return [CapturedImage(image: cgImage, metadata: metadata)]
    }
    
    private func captureWindowWayland(windowId: UInt32) async throws -> CapturedImage {
        // Wayland window capture is more complex and may require compositor-specific tools
        // For now, fall back to screen capture
        let screenImages = try await captureScreenWayland(displayIndex: nil)
        guard let screenImage = screenImages.first else {
            throw ScreenCaptureError.captureFailure("Failed to capture screen for window")
        }
        
        // Update metadata to indicate this was a window capture attempt
        let metadata = CaptureMetadata(
            captureTime: screenImage.metadata.captureTime,
            displayIndex: nil,
            windowId: windowId,
            windowTitle: "Window \(windowId)",
            applicationName: nil,
            bounds: screenImage.metadata.bounds,
            scaleFactor: screenImage.metadata.scaleFactor,
            colorSpace: screenImage.metadata.colorSpace
        )
        
        return CapturedImage(image: screenImage.image, metadata: metadata)
    }
    
    private func getAvailableDisplaysWayland() throws -> [DisplayInfo] {
        // For simplicity, return a single display
        // A full implementation would use wlr-randr or similar tools
        return [
            DisplayInfo(
                displayId: 0,
                index: 0,
                bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080), // Default, should be detected
                workArea: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                scaleFactor: 1.0,
                isPrimary: true,
                name: "Display 1",
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
        ]
    }
    
    // MARK: - Helper Methods
    
    private func createCGImageFromPNG(_ data: Data) -> CGImage? {
        guard let dataProvider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            return nil
        }
        return cgImage
    }
    
    private func extractNumber(from line: String) -> Int? {
        let components = line.components(separatedBy: CharacterSet.decimalDigits.inverted)
        for component in components {
            if let number = Int(component) {
                return number
            }
        }
        return nil
    }
    
    private func runCommand(_ arguments: [String]) async throws -> CommandResult {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    let result = try self.runCommandSync(arguments)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func runCommandSync(_ arguments: [String]) throws -> CommandResult {
        guard !arguments.isEmpty else {
            throw ScreenCaptureError.invalidConfiguration
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        try process.run()
        process.waitUntilExit()
        
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        
        return CommandResult(
            exitCode: Int(process.terminationStatus),
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }
}

// MARK: - Supporting Types

private enum LinuxDisplayServer {
    case x11
    case wayland
    case unknown
}

private struct CommandResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}
#endif
