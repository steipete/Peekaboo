import Foundation
import CoreGraphics

/// Protocol defining cross-platform screen capture functionality
protocol ScreenCaptureProtocol: Sendable {
    /// Captures a screenshot of the specified screen
    /// - Parameter screenIndex: Index of the screen to capture (0 for primary)
    /// - Returns: PNG image data
    func captureScreen(screenIndex: Int) async throws -> Data
    
    /// Captures a screenshot of a specific window
    /// - Parameters:
    ///   - windowId: Platform-specific window identifier
    ///   - bounds: Optional bounds to crop the capture
    /// - Returns: PNG image data
    func captureWindow(windowId: String, bounds: CGRect?) async throws -> Data
    
    /// Gets information about available screens
    /// - Returns: Array of screen information
    func getAvailableScreens() async throws -> [ScreenInfo]
    
    /// Checks if screen capture is available on this platform
    /// - Returns: True if screen capture is supported
    static func isSupported() -> Bool
}

/// Cross-platform screen information
struct ScreenInfo: Sendable, Codable, Identifiable {
    let id = UUID()
    let index: Int
    let bounds: CGRect
    let name: String
    let isPrimary: Bool
    
    init(index: Int, bounds: CGRect, name: String, isPrimary: Bool) {
        self.index = index
        self.bounds = bounds
        self.name = name
        self.isPrimary = isPrimary
    }
}

// MARK: - CGRect Sendable Conformance
extension CGRect: @unchecked Sendable {}
extension CGPoint: @unchecked Sendable {}
extension CGSize: @unchecked Sendable {}

