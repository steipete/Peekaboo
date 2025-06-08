import Foundation
import CoreGraphics

/// Protocol defining the interface for window management operations across all platforms
protocol WindowManagerProtocol {
    /// Get all windows for a specific application
    /// - Parameters:
    ///   - pid: Process ID of the target application
    ///   - includeOffScreen: Whether to include off-screen windows
    /// - Returns: Array of window data
    func getWindowsForApp(pid: pid_t, includeOffScreen: Bool) throws -> [WindowData]
    
    /// Get information about a specific window
    /// - Parameter windowId: Unique identifier of the window
    /// - Returns: Window data if found
    func getWindowInfo(windowId: UInt32) throws -> WindowData?
    
    /// Get all visible windows on the system
    /// - Parameter includeOffScreen: Whether to include off-screen windows
    /// - Returns: Array of all window data
    func getAllWindows(includeOffScreen: Bool) throws -> [WindowData]
    
    /// Get windows for all applications
    /// - Parameter includeOffScreen: Whether to include off-screen windows
    /// - Returns: Dictionary mapping process IDs to their windows
    func getWindowsByApplication(includeOffScreen: Bool) throws -> [pid_t: [WindowData]]
    
    /// Check if window management is supported on this platform
    /// - Returns: True if window management is supported
    func isWindowManagementSupported() -> Bool
    
    /// Refresh the window cache (if applicable)
    func refreshWindowCache() throws
}

/// Extended window information for listing operations
struct WindowInfo {
    let window_title: String
    let window_id: UInt32?
    let window_index: Int
    let bounds: WindowBounds?
    let is_on_screen: Bool?
    let application_name: String?
    let process_id: pid_t?
}

/// Window bounds information
struct WindowBounds {
    let xCoordinate: Int
    let yCoordinate: Int
    let width: Int
    let height: Int
}

/// Errors that can occur during window management operations
enum WindowManagementError: Error, LocalizedError {
    case notSupported
    case permissionDenied
    case windowNotFound(UInt32)
    case applicationNotFound(pid_t)
    case systemError(Error)
    case accessDenied
    
    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Window management is not supported on this platform"
        case .permissionDenied:
            return "Permission denied for window management"
        case .windowNotFound(let id):
            return "Window with ID \(id) not found"
        case .applicationNotFound(let pid):
            return "Application with PID \(pid) not found"
        case .systemError(let error):
            return "System error: \(error.localizedDescription)"
        case .accessDenied:
            return "Access denied to window information"
        }
    }
}

