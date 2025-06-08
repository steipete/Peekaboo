import Foundation

#if os(macOS)
import CoreGraphics
#endif

/// Protocol defining cross-platform screen capture functionality
protocol ScreenCaptureProtocol: Sendable {
    /// Captures the entire screen
    /// - Parameter screenIndex: Index of the screen to capture (0-based)
    /// - Returns: Captured image data
    func captureScreen(screenIndex: Int) async throws -> Data
    
    /// Captures a specific window
    /// - Parameters:
    ///   - windowId: Platform-specific window identifier
    ///   - bounds: Optional bounds to capture within the window
    /// - Returns: Captured image data
    func captureWindow(windowId: String, bounds: CGRect?) async throws -> Data
    
    /// Gets available screens
    /// - Returns: Array of screen information
    func getAvailableScreens() async throws -> [ScreenInfo]
    
    /// Checks if screen capture is available on this platform
    /// - Returns: True if screen capture is supported
    static func isSupported() -> Bool
}

/// Cross-platform screen information
struct ScreenInfo: Sendable, Codable {
    let index: Int
    let bounds: CGRect
    let name: String?
    let isPrimary: Bool
    
    init(index: Int, bounds: CGRect, name: String? = nil, isPrimary: Bool = false) {
        self.index = index
        self.bounds = bounds
        self.name = name
        self.isPrimary = isPrimary
    }
}

