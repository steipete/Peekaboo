import Foundation

#if os(macOS)
import CoreGraphics
#endif

/// Protocol defining cross-platform window management functionality
protocol WindowManagerProtocol: Sendable {
    /// Gets all windows for a specific application
    /// - Parameter applicationId: Platform-specific application identifier
    /// - Returns: Array of window information
    func getWindows(for applicationId: String) async throws -> [PlatformWindowInfo]
    
    /// Gets all visible windows on the system
    /// - Returns: Array of all visible windows
    func getAllWindows() async throws -> [PlatformWindowInfo]
    
    /// Gets window information by window ID
    /// - Parameter windowId: Platform-specific window identifier
    /// - Returns: Window information if found
    func getWindow(by windowId: String) async throws -> PlatformWindowInfo?
    
    /// Checks if window management is available on this platform
    /// - Returns: True if window management is supported
    static func isSupported() -> Bool
}

/// Cross-platform window information for internal use
struct PlatformWindowInfo: Sendable, Codable, Identifiable {
    let id: String
    let title: String
    let bounds: CGRect
    let applicationName: String
    let applicationId: String
    let isVisible: Bool
    let isMinimized: Bool
    let level: Int
    
    init(
        id: String,
        title: String,
        bounds: CGRect,
        applicationName: String,
        applicationId: String,
        isVisible: Bool = true,
        isMinimized: Bool = false,
        level: Int = 0
    ) {
        self.id = id
        self.title = title
        self.bounds = bounds
        self.applicationName = applicationName
        self.applicationId = applicationId
        self.isVisible = isVisible
        self.isMinimized = isMinimized
        self.level = level
    }
}

