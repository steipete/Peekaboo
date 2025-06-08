import Foundation

/// Protocol defining cross-platform application discovery functionality
protocol ApplicationFinderProtocol: Sendable {
    /// Finds applications by name or identifier
    /// - Parameter query: Search query (name or identifier)
    /// - Returns: Array of matching applications
    func findApplications(matching query: String) async throws -> [ApplicationInfo]
    
    /// Gets all running applications
    /// - Returns: Array of all running applications
    func getRunningApplications() async throws -> [ApplicationInfo]
    
    /// Gets application information by identifier
    /// - Parameter identifier: Platform-specific application identifier
    /// - Returns: Application information if found
    func getApplication(by identifier: String) async throws -> ApplicationInfo?
    
    /// Checks if application finding is available on this platform
    /// - Returns: True if application finding is supported
    static func isSupported() -> Bool
}

/// Cross-platform application information
struct ApplicationInfo: Sendable, Codable, Identifiable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let executablePath: String?
    let isRunning: Bool
    let processId: Int?
    
    init(
        id: String,
        name: String,
        bundleIdentifier: String? = nil,
        executablePath: String? = nil,
        isRunning: Bool = false,
        processId: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.executablePath = executablePath
        self.isRunning = isRunning
        self.processId = processId
    }
}

