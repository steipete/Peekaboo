import Foundation
import CoreGraphics

/// Protocol defining the interface for screen capture operations across all platforms
protocol ScreenCaptureProtocol {
    /// Capture a screenshot of a specific display
    /// - Parameter displayIndex: Index of the display to capture (nil for all displays)
    /// - Returns: Array of captured images with metadata
    func captureScreen(displayIndex: Int?) async throws -> [CapturedImage]
    
    /// Capture a screenshot of a specific window
    /// - Parameter windowId: Unique identifier of the window to capture
    /// - Returns: Captured image with metadata
    func captureWindow(windowId: UInt32) async throws -> CapturedImage
    
    /// Capture screenshots of all windows for a specific application
    /// - Parameters:
    ///   - pid: Process ID of the target application
    ///   - windowIndex: Specific window index to capture (nil for all windows)
    /// - Returns: Array of captured images with metadata
    func captureApplication(pid: pid_t, windowIndex: Int?) async throws -> [CapturedImage]
    
    /// Get information about available displays
    /// - Returns: Array of display information
    func getAvailableDisplays() throws -> [DisplayInfo]
    
    /// Check if screen capture is supported on this platform
    /// - Returns: True if screen capture is supported
    func isScreenCaptureSupported() -> Bool
    
    /// Get the preferred image format for this platform
    /// - Returns: The preferred image format
    func getPreferredImageFormat() -> ImageFormat
}

/// Represents a captured image with associated metadata
struct CapturedImage {
    let image: CGImage
    let metadata: CaptureMetadata
}

/// Metadata associated with a captured image
struct CaptureMetadata {
    let captureTime: Date
    let displayIndex: Int?
    let windowId: UInt32?
    let windowTitle: String?
    let applicationName: String?
    let bounds: CGRect
    let scaleFactor: CGFloat
    let colorSpace: CGColorSpace?
}

/// Information about a display/monitor
struct DisplayInfo {
    let displayId: UInt32
    let index: Int
    let bounds: CGRect
    let workArea: CGRect
    let scaleFactor: CGFloat
    let isPrimary: Bool
    let name: String?
    let colorSpace: CGColorSpace?
}


/// Errors that can occur during screen capture operations
enum ScreenCaptureError: Error, LocalizedError {
    case notSupported
    case permissionDenied
    case displayNotFound(Int)
    case windowNotFound(UInt32)
    case captureFailure(String)
    case invalidConfiguration
    case systemError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Screen capture is not supported on this platform"
        case .permissionDenied:
            return "Permission denied for screen capture"
        case .displayNotFound(let index):
            return "Display with index \(index) not found"
        case .windowNotFound(let id):
            return "Window with ID \(id) not found"
        case .captureFailure(let reason):
            return "Screen capture failed: \(reason)"
        case .invalidConfiguration:
            return "Invalid capture configuration"
        case .systemError(let error):
            return "System error: \(error.localizedDescription)"
        }
    }
}
