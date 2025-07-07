import Foundation
import CoreGraphics
import ScreenCaptureKit
import AppKit

/// Default implementation of screen capture operations
public final class ScreenCaptureService: ScreenCaptureServiceProtocol {
    
    public init() {}
    
    public func captureScreen(displayIndex: Int?) async throws -> CaptureResult {
        // Check permissions first
        guard await hasScreenRecordingPermission() else {
            throw CaptureError.permissionDeniedScreenRecording
        }
        
        // Get available displays
        let content = try await SCShareableContent.current
        let displays = content.displays
        
        guard !displays.isEmpty else {
            throw CaptureError.noDisplaysFound
        }
        
        // Select display
        let targetDisplay: SCDisplay
        if let index = displayIndex {
            guard index >= 0 && index < displays.count else {
                throw CaptureError.invalidDisplayIndex(index, availableCount: displays.count)
            }
            targetDisplay = displays[index]
        } else {
            // Use main display
            targetDisplay = displays.first!
        }
        
        // Create screenshot
        let image = try await createScreenshot(of: targetDisplay)
        let imageData = try image.pngData()
        
        // Create metadata
        let metadata = CaptureMetadata(
            size: CGSize(width: image.width, height: image.height),
            mode: .screen,
            displayInfo: DisplayInfo(
                index: displayIndex ?? 0,
                name: targetDisplay.displayID.description,
                bounds: targetDisplay.frame,
                scaleFactor: 2.0  // Default for Retina displays
            )
        )
        
        return CaptureResult(
            imageData: imageData,
            metadata: metadata
        )
    }
    
    public func captureWindow(appIdentifier: String, windowIndex: Int?) async throws -> CaptureResult {
        // Check permissions
        guard await hasScreenRecordingPermission() else {
            throw CaptureError.permissionDeniedScreenRecording
        }
        
        // Find application
        let app = try await findApplication(matching: appIdentifier)
        
        // Get windows for the application
        let content = try await SCShareableContent.current
        let appWindows = content.windows.filter { window in
            window.owningApplication?.processID == app.processIdentifier
        }
        
        guard !appWindows.isEmpty else {
            throw CaptureError.noWindowsFound(app.name)
        }
        
        // Select window
        let targetWindow: SCWindow
        if let index = windowIndex {
            guard index >= 0 && index < appWindows.count else {
                throw CaptureError.invalidWindowIndex(index, availableCount: appWindows.count)
            }
            targetWindow = appWindows[index]
        } else {
            // Use frontmost window
            targetWindow = appWindows.first!
        }
        
        // Create screenshot
        let image = try await createScreenshot(of: targetWindow)
        let imageData = try image.pngData()
        
        // Create metadata
        let metadata = CaptureMetadata(
            size: CGSize(width: image.width, height: image.height),
            mode: .window,
            applicationInfo: app,
            windowInfo: ServiceWindowInfo(
                windowID: Int(targetWindow.windowID),
                title: targetWindow.title ?? "",
                bounds: targetWindow.frame,
                windowLevel: Int(targetWindow.windowLayer),
                alpha: 1.0,  // Default alpha
                index: windowIndex ?? 0
            )
        )
        
        return CaptureResult(
            imageData: imageData,
            metadata: metadata
        )
    }
    
    public func captureFrontmost() async throws -> CaptureResult {
        // Check permissions
        guard await hasScreenRecordingPermission() else {
            throw CaptureError.permissionDeniedScreenRecording
        }
        
        // Get frontmost application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            throw CaptureError.noFrontmostApplication
        }
        
        let appIdentifier = frontmostApp.bundleIdentifier ?? frontmostApp.localizedName ?? "Unknown"
        return try await captureWindow(appIdentifier: appIdentifier, windowIndex: nil)
    }
    
    public func captureArea(_ rect: CGRect) async throws -> CaptureResult {
        // Check permissions
        guard await hasScreenRecordingPermission() else {
            throw CaptureError.permissionDeniedScreenRecording
        }
        
        // Find display containing the rect
        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.frame.contains(rect) }) else {
            throw CaptureError.invalidCaptureArea
        }
        
        // Create content filter for the area
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        // Configure stream for single frame capture
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int(rect.width)
        config.height = Int(rect.height)
        config.showsCursor = false
        
        // Capture the area
        let image = try await captureWithStream(filter: filter, configuration: config)
        let imageData = try image.pngData()
        
        // Create metadata
        let metadata = CaptureMetadata(
            size: CGSize(width: image.width, height: image.height),
            mode: .area,
            displayInfo: DisplayInfo(
                index: 0,
                name: display.displayID.description,
                bounds: display.frame,
                scaleFactor: 2.0  // Default for Retina displays
            )
        )
        
        return CaptureResult(
            imageData: imageData,
            metadata: metadata
        )
    }
    
    public func hasScreenRecordingPermission() async -> Bool {
        // Check if we have permission by trying to get content
        do {
            _ = try await SCShareableContent.current
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Private Helpers
    
    private func createScreenshot(of display: SCDisplay) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        
        return try await captureWithStream(filter: filter, configuration: config)
    }
    
    private func createScreenshot(of window: SCWindow) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.captureResolution = .best
        config.showsCursor = false
        
        // Configure for best quality
        config.showsCursor = false
        
        return try await captureWithStream(filter: filter, configuration: config)
    }
    
    private func captureWithStream(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws -> CGImage {
        // Create a stream for single frame capture
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        
        // Add stream output
        let output = CaptureOutput()
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: nil)
        
        // Start capture
        try await stream.startCapture()
        
        // Wait for frame
        let image = try await output.waitForImage()
        
        // Stop capture
        try await stream.stopCapture()
        
        return image
    }
    
    private func findApplication(matching identifier: String) async throws -> ServiceApplicationInfo {
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Try exact bundle ID match first
        if let app = runningApps.first(where: { $0.bundleIdentifier == identifier }) {
            return ServiceApplicationInfo(
                processIdentifier: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier,
                name: app.localizedName ?? "Unknown",
                bundlePath: app.bundleURL?.path,
                isActive: app.isActive,
                isHidden: app.isHidden
            )
        }
        
        // Try name match (case-insensitive)
        let lowercaseIdentifier = identifier.lowercased()
        if let app = runningApps.first(where: { 
            $0.localizedName?.lowercased() == lowercaseIdentifier 
        }) {
            return ServiceApplicationInfo(
                processIdentifier: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier,
                name: app.localizedName ?? "Unknown",
                bundlePath: app.bundleURL?.path,
                isActive: app.isActive,
                isHidden: app.isHidden
            )
        }
        
        // Try fuzzy match
        let matches = runningApps.filter { app in
            guard let name = app.localizedName else { return false }
            return name.lowercased().contains(lowercaseIdentifier) ||
                   (app.bundleIdentifier?.lowercased().contains(lowercaseIdentifier) ?? false)
        }
        
        if matches.count == 1 {
            let app = matches[0]
            return ServiceApplicationInfo(
                processIdentifier: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier,
                name: app.localizedName ?? "Unknown",
                bundlePath: app.bundleURL?.path,
                isActive: app.isActive,
                isHidden: app.isHidden
            )
        } else if matches.count > 1 {
            let names = matches.compactMap { $0.localizedName }.joined(separator: ", ")
            throw CaptureError.ambiguousAppIdentifier(identifier, candidates: names)
        }
        
        throw CaptureError.appNotFound(identifier)
    }
}

// MARK: - Capture Output Handler

private final class CaptureOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    private var continuation: CheckedContinuation<CGImage, Error>?
    
    func waitForImage() async throws -> CGImage {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            continuation?.resume(throwing: CaptureError.captureFailed("No image buffer"))
            continuation = nil
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            continuation?.resume(throwing: CaptureError.captureFailed("Failed to create CGImage"))
            continuation = nil
            return
        }
        
        continuation?.resume(returning: cgImage)
        continuation = nil
    }
}

// MARK: - Extensions

extension CGImage {
    // Width and height are already properties of CGImage
    
    func pngData() throws -> Data {
        let nsImage = NSImage(cgImage: self, size: NSSize(width: width, height: height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw CaptureError.imageConversionFailed
        }
        return pngData
    }
}