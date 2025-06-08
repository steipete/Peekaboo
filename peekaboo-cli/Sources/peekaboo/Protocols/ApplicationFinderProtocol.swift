import Foundation

/// Protocol defining the interface for application discovery and management across all platforms
protocol ApplicationFinderProtocol {
    /// Find a running application by identifier (name, bundle ID, or PID)
    /// - Parameter identifier: Application identifier (name, bundle ID, or PID as string)
    /// - Returns: Running application information
    func findApplication(identifier: String) throws -> RunningApplication
    
    /// Get all currently running applications
    /// - Parameter includeBackground: Whether to include background applications
    /// - Returns: Array of running applications
    func getRunningApplications(includeBackground: Bool) -> [RunningApplication]
    
    /// Activate (bring to foreground) an application
    /// - Parameter pid: Process ID of the application to activate
    func activateApplication(pid: pid_t) throws
    
    /// Check if an application is currently running
    /// - Parameter identifier: Application identifier
    /// - Returns: True if the application is running
    func isApplicationRunning(identifier: String) -> Bool
    
    /// Get detailed information about a running application
    /// - Parameter pid: Process ID of the application
    /// - Returns: Detailed application information
    func getApplicationInfo(pid: pid_t) throws -> ApplicationInfo
    
    /// Check if application management is supported on this platform
    /// - Returns: True if application management is supported
    func isApplicationManagementSupported() -> Bool
    
    /// Refresh the application cache (if applicable)
    func refreshApplicationCache() throws
}

/// Represents a running application
struct RunningApplication {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
    let localizedName: String?
    let executablePath: String?
    let isActive: Bool
    let activationPolicy: ApplicationActivationPolicy
    let launchDate: Date?
    let icon: Data? // Platform-specific icon data
}

/// Detailed application information
struct ApplicationInfo {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
    let localizedName: String?
    let executablePath: String?
    let bundlePath: String?
    let version: String?
    let isActive: Bool
    let activationPolicy: ApplicationActivationPolicy
    let launchDate: Date?
    let memoryUsage: UInt64?
    let cpuUsage: Double?
    let windowCount: Int?
    let icon: Data?
    let architecture: ProcessArchitecture?
}

/// Application activation policy
enum ApplicationActivationPolicy {
    case regular      // Normal applications with UI
    case accessory    // Applications that don't appear in Dock
    case prohibited   // Background-only applications
    case unknown      // Unknown or platform-specific policy
}

/// Process architecture information
enum ProcessArchitecture {
    case x86_64
    case arm64
    case x86
    case unknown
}

/// Errors that can occur during application discovery and management
enum ApplicationError: Error, LocalizedError {
    case notFound(String)
    case ambiguous(String, [RunningApplication])
    case notSupported
    case permissionDenied
    case activationFailed(pid_t)
    case systemError(Error)
    case invalidIdentifier(String)
    
    var errorDescription: String? {
        switch self {
        case .notFound(let identifier):
            return "Application '\(identifier)' not found"
        case .ambiguous(let identifier, let matches):
            let names = matches.compactMap { $0.localizedName ?? $0.bundleIdentifier }.joined(separator: ", ")
            return "Multiple applications match '\(identifier)': \(names)"
        case .notSupported:
            return "Application management is not supported on this platform"
        case .permissionDenied:
            return "Permission denied for application management"
        case .activationFailed(let pid):
            return "Failed to activate application with PID \(pid)"
        case .systemError(let error):
            return "System error: \(error.localizedDescription)"
        case .invalidIdentifier(let identifier):
            return "Invalid application identifier: \(identifier)"
        }
    }
}

