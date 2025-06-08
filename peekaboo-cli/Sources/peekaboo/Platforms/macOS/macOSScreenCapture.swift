#if os(macOS)
import Foundation
import CoreGraphics
import ScreenCaptureKit
import AppKit

/// macOS implementation of screen capture using ScreenCaptureKit
struct macOSScreenCapture: ScreenCaptureProtocol {
    
    func captureScreen(screenIndex: Int) async throws -> Data {
        let screens = NSScreen.screens
        guard screenIndex < screens.count else {
            throw ScreenCaptureError.invalidScreenIndex(screenIndex)
        }
        
        let screen = screens[screenIndex]
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
        
        // Try ScreenCaptureKit first (macOS 12.3+)
        if #available(macOS 12.3, *) {
            return try await captureWithScreenCaptureKit(displayID: displayID)
        } else {
            // Fallback to CGImage
            return try captureWithCGImage(displayID: displayID)
        }
    }
    
    func captureWindow(windowId: String, bounds: CGRect?) async throws -> Data {
        guard let windowNumber = Int(windowId) else {
            throw ScreenCaptureError.invalidWindowId(windowId)
        }
        
        // Try ScreenCaptureKit first (macOS 12.3+)
        if #available(macOS 12.3, *) {
            return try await captureWindowWithScreenCaptureKit(windowNumber: windowNumber)
        } else {
            // Fallback to CGImage
            return try captureWindowWithCGImage(windowNumber: windowNumber, bounds: bounds)
        }
    }
    
    func getAvailableScreens() async throws -> [ScreenInfo] {
        let screens = NSScreen.screens
        return screens.enumerated().map { index, screen in
            let frame = screen.frame
            let bounds = CGRect(
                x: frame.origin.x,
                y: frame.origin.y,
                width: frame.size.width,
                height: frame.size.height
            )
            
            return ScreenInfo(
                index: index,
                bounds: bounds,
                name: screen.localizedName,
                isPrimary: screen == NSScreen.main
            )
        }
    }
    
    static func isSupported() -> Bool {
        return true // macOS always supports screen capture
    }
    
    // MARK: - Private Methods
    
    @available(macOS 12.3, *)
    private func captureWithScreenCaptureKit(displayID: CGDirectDisplayID) async throws -> Data {
        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        guard let display = availableContent.displays.first(where: { $0.displayID == displayID }) else {
            throw ScreenCaptureError.displayNotFound(displayID)
        }
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = Int(display.width)
        configuration.height = Int(display.height)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return try convertCGImageToPNG(image)
    }
    
    private func captureWithCGImage(displayID: CGDirectDisplayID) throws -> Data {
        guard let image = CGDisplayCreateImage(displayID) else {
            throw ScreenCaptureError.captureFailedForDisplay(displayID)
        }
        return try convertCGImageToPNG(image)
    }
    
    @available(macOS 12.3, *)
    private func captureWindowWithScreenCaptureKit(windowNumber: Int) async throws -> Data {
        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        guard let window = availableContent.windows.first(where: { $0.windowID == CGWindowID(windowNumber) }) else {
            throw ScreenCaptureError.windowNotFound(windowNumber)
        }
        
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = Int(window.frame.width)
        configuration.height = Int(window.frame.height)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return try convertCGImageToPNG(image)
    }
    
    private func captureWindowWithCGImage(windowNumber: Int, bounds: CGRect?) throws -> Data {
        let windowID = CGWindowID(windowNumber)
        let imageOption: CGWindowImageOption = [.boundsIgnoreFraming, .shouldBeOpaque]
        
        guard let image = CGWindowListCreateImage(bounds ?? .null, .optionIncludingWindow, windowID, imageOption) else {
            throw ScreenCaptureError.windowCaptureFailedForWindow(windowNumber)
        }
        
        return try convertCGImageToPNG(image)
    }
    
    private func convertCGImageToPNG(_ image: CGImage) throws -> Data {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, kUTTypePNG, 1, nil) else {
            throw ScreenCaptureError.imageConversionFailed
        }
        
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ScreenCaptureError.imageConversionFailed
        }
        
        return mutableData as Data
    }
}

// MARK: - Error Types

enum ScreenCaptureError: Error, LocalizedError {
    case invalidScreenIndex(Int)
    case invalidWindowId(String)
    case displayNotFound(CGDirectDisplayID)
    case windowNotFound(Int)
    case captureFailedForDisplay(CGDirectDisplayID)
    case windowCaptureFailedForWindow(Int)
    case imageConversionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidScreenIndex(let index):
            return "Invalid screen index: \\(index)"
        case .invalidWindowId(let id):
            return "Invalid window ID: \\(id)"
        case .displayNotFound(let displayID):
            return "Display not found: \\(displayID)"
        case .windowNotFound(let windowNumber):
            return "Window not found: \\(windowNumber)"
        case .captureFailedForDisplay(let displayID):
            return "Failed to capture display: \\(displayID)"
        case .windowCaptureFailedForWindow(let windowNumber):
            return "Failed to capture window: \\(windowNumber)"
        case .imageConversionFailed:
            return "Failed to convert image to PNG"
        }
    }
}

#endif

