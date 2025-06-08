#if os(macOS)
import Foundation
import AppKit
import CoreGraphics
import ScreenCaptureKit
import UniformTypeIdentifiers

/// macOS-specific implementation of screen capture using ScreenCaptureKit
class macOSScreenCapture: ScreenCaptureProtocol {
    
    func captureScreen(displayIndex: Int?) async throws -> [CapturedImage] {
        let displays = try getAvailableDisplays()
        var capturedImages: [CapturedImage] = []
        
        if let displayIndex = displayIndex {
            if displayIndex >= 0 && displayIndex < displays.count {
                let display = displays[displayIndex]
                let image = try await captureSingleDisplay(display)
                capturedImages.append(image)
            } else {
                throw ScreenCaptureError.displayNotFound(displayIndex)
            }
        } else {
            // Capture all displays
            for display in displays {
                let image = try await captureSingleDisplay(display)
                capturedImages.append(image)
            }
        }
        
        return capturedImages
    }
    
    func captureWindow(windowId: UInt32) async throws -> CapturedImage {
        do {
            // Get available content
            let availableContent = try await SCShareableContent.current
            
            // Find the window by ID
            guard let scWindow = availableContent.windows.first(where: { $0.windowID == windowId }) else {
                throw ScreenCaptureError.windowNotFound(windowId)
            }
            
            // Create content filter for the specific window
            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            
            // Configure capture settings
            let configuration = SCStreamConfiguration()
            configuration.width = Int(scWindow.frame.width)
            configuration.height = Int(scWindow.frame.height)
            configuration.backgroundColor = .clear
            configuration.shouldBeOpaque = true
            configuration.showsCursor = false
            
            // Capture the image
            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            
            let metadata = CaptureMetadata(
                captureTime: Date(),
                displayIndex: nil,
                windowId: windowId,
                windowTitle: scWindow.title,
                applicationName: scWindow.owningApplication?.applicationName,
                bounds: scWindow.frame,
                scaleFactor: 1.0, // ScreenCaptureKit handles scaling
                colorSpace: cgImage.colorSpace
            )
            
            return CapturedImage(image: cgImage, metadata: metadata)
            
        } catch {
            if isScreenRecordingPermissionError(error) {
                throw ScreenCaptureError.permissionDenied
            }
            throw ScreenCaptureError.captureFailure(error.localizedDescription)
        }
    }
    
    func captureApplication(pid: pid_t, windowIndex: Int?) async throws -> [CapturedImage] {
        do {
            let availableContent = try await SCShareableContent.current
            
            // Find windows for the application
            let appWindows = availableContent.windows.filter { $0.owningApplication?.processID == pid }
            
            if appWindows.isEmpty {
                throw ScreenCaptureError.captureFailure("No windows found for application with PID \(pid)")
            }
            
            var capturedImages: [CapturedImage] = []
            
            if let windowIndex = windowIndex {
                // Capture specific window
                if windowIndex >= 0 && windowIndex < appWindows.count {
                    let window = appWindows[windowIndex]
                    let image = try await captureWindow(windowId: window.windowID)
                    capturedImages.append(image)
                } else {
                    throw ScreenCaptureError.captureFailure("Window index \(windowIndex) out of range")
                }
            } else {
                // Capture all windows
                for window in appWindows {
                    let image = try await captureWindow(windowId: window.windowID)
                    capturedImages.append(image)
                }
            }
            
            return capturedImages
            
        } catch {
            if isScreenRecordingPermissionError(error) {
                throw ScreenCaptureError.permissionDenied
            }
            throw ScreenCaptureError.captureFailure(error.localizedDescription)
        }
    }
    
    func getAvailableDisplays() throws -> [DisplayInfo] {
        var displayCount: UInt32 = 0
        let result = CGGetActiveDisplayList(0, nil, &displayCount)
        guard result == .success && displayCount > 0 else {
            throw ScreenCaptureError.captureFailure("No displays available")
        }
        
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        let listResult = CGGetActiveDisplayList(displayCount, &displays, nil)
        guard listResult == .success else {
            throw ScreenCaptureError.captureFailure("Failed to get display list")
        }
        
        return displays.enumerated().map { index, displayID in
            let bounds = CGDisplayBounds(displayID)
            let mode = CGDisplayCopyDisplayMode(displayID)
            let scaleFactor = mode?.pixelWidth != nil && mode?.width != nil ? 
                CGFloat(mode!.pixelWidth) / CGFloat(mode!.width) : 1.0
            
            return DisplayInfo(
                displayId: displayID,
                index: index,
                bounds: bounds,
                workArea: bounds, // macOS doesn't distinguish work area in this API
                scaleFactor: scaleFactor,
                isPrimary: CGDisplayIsMain(displayID) != 0,
                name: getDisplayName(displayID),
                colorSpace: CGDisplayCopyColorSpace(displayID)
            )
        }
    }
    
    func isScreenCaptureSupported() -> Bool {
        return true
    }
    
    func getPreferredImageFormat() -> PlatformImageFormat {
        return .png
    }
    
    // MARK: - Private Helper Methods
    
    private func captureSingleDisplay(_ display: DisplayInfo) async throws -> CapturedImage {
        do {
            let availableContent = try await SCShareableContent.current
            
            // Find the SCDisplay for this display ID
            guard let scDisplay = availableContent.displays.first(where: { $0.displayID == display.displayId }) else {
                throw ScreenCaptureError.displayNotFound(display.index)
            }
            
            // Create content filter for the display
            let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
            
            // Configure capture settings
            let configuration = SCStreamConfiguration()
            configuration.width = scDisplay.width
            configuration.height = scDisplay.height
            configuration.backgroundColor = .black
            configuration.shouldBeOpaque = true
            configuration.showsCursor = true
            
            // Capture the image
            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            
            let metadata = CaptureMetadata(
                captureTime: Date(),
                displayIndex: display.index,
                windowId: nil,
                windowTitle: nil,
                applicationName: nil,
                bounds: display.bounds,
                scaleFactor: display.scaleFactor,
                colorSpace: cgImage.colorSpace
            )
            
            return CapturedImage(image: cgImage, metadata: metadata)
            
        } catch {
            if isScreenRecordingPermissionError(error) {
                throw ScreenCaptureError.permissionDenied
            }
            throw ScreenCaptureError.captureFailure(error.localizedDescription)
        }
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
    
    private func getDisplayName(_ displayID: CGDirectDisplayID) -> String? {
        // Try to get the display name from IOKit
        let servicePort = CGDisplayIOServicePort(displayID)
        if servicePort != MACH_PORT_NULL {
            if let displayName = IODisplayCreateInfoDictionary(servicePort, IOOptionBits(kIODisplayOnlyPreferredName))?.takeRetainedValue() as? [String: Any] {
                if let names = displayName[kDisplayProductName] as? [String: String] {
                    return names.values.first
                }
            }
        }
        return "Display \(displayID)"
    }
}

// MARK: - Backward Compatibility Extensions

extension macOSScreenCapture {
    /// Save a CGImage to a file path with the specified format
    func saveImage(_ image: CGImage, to path: String, format: PlatformImageFormat = .png) throws {
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
            throw ScreenCaptureError.systemError(error)
        }
        
        let utType: UTType = {
            switch format {
            case .png: return .png
            case .jpeg: return .jpeg
            case .bmp: return .bmp
            case .tiff: return .tiff
            }
        }()
        
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
                throw ScreenCaptureError.systemError(error)
            }
            throw ScreenCaptureError.captureFailure("Failed to create image destination")
        }
        
        CGImageDestinationAddImage(destination, image, nil)
        
        guard CGImageDestinationFinalize(destination) else {
            throw ScreenCaptureError.captureFailure("Failed to write image to file")
        }
    }
}
#endif
