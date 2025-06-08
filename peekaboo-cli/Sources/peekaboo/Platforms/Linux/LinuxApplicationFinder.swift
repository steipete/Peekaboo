#if os(Linux)
import Foundation
import SystemPackage

/// Linux implementation of application finding using /proc filesystem
struct LinuxApplicationFinder: ApplicationFinderProtocol {
    
    func findApplications(matching query: String) async throws -> [ApplicationInfo] {
        let runningApps = try await getRunningApplications()
        let lowercaseQuery = query.lowercased()
        
        return runningApps.filter { app in
            app.name.lowercased().contains(lowercaseQuery) ||
            app.executablePath?.lowercased().contains(lowercaseQuery) == true ||
            app.id.contains(query)
        }
    }
    
    func getRunningApplications() async throws -> [ApplicationInfo] {
        var applications: [ApplicationInfo] = []
        
        // Read /proc directory to get all running processes
        let procURL = URL(fileURLWithPath: "/proc")
        
        do {
            let procContents = try FileManager.default.contentsOfDirectory(at: procURL, includingPropertiesForKeys: nil)
            
            for procDir in procContents {
                // Check if directory name is a number (process ID)
                guard let processId = Int(procDir.lastPathComponent) else { continue }
                
                if let appInfo = try? getApplicationInfo(processId: processId) {
                    applications.append(appInfo)
                }
            }
        } catch {
            throw LinuxApplicationFinderError.failedToReadProcDirectory
        }
        
        return applications
    }
    
    func getApplication(by identifier: String) async throws -> ApplicationInfo? {
        // Try to parse as process ID
        if let processId = Int(identifier) {
            return try? getApplicationInfo(processId: processId)
        }
        
        // Search by name
        let runningApps = try await getRunningApplications()
        return runningApps.first { app in
            app.name.lowercased() == identifier.lowercased() ||
            app.executablePath?.lowercased().contains(identifier.lowercased()) == true
        }
    }
    
    static func isSupported() -> Bool {
        return FileManager.default.fileExists(atPath: "/proc")
    }
    
    // MARK: - Private Methods
    
    private func getApplicationInfo(processId: Int) throws -> ApplicationInfo {
        let procPath = "/proc/\\(processId)"
        
        // Check if process still exists
        guard FileManager.default.fileExists(atPath: procPath) else {
            throw LinuxApplicationFinderError.processNotFound(processId)
        }
        
        // Get process name from /proc/PID/comm
        var processName = "Unknown"
        let commPath = "\\(procPath)/comm"
        if let comm = try? String(contentsOfFile: commPath, encoding: .utf8) {
            processName = comm.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Get executable path from /proc/PID/exe
        var executablePath: String?
        let exePath = "\\(procPath)/exe"
        if let resolvedPath = try? FileManager.default.destinationOfSymbolicLink(atPath: exePath) {
            executablePath = resolvedPath
            
            // If we couldn't get the name from comm, try to extract it from the executable path
            if processName == "Unknown" {
                processName = URL(fileURLWithPath: resolvedPath).lastPathComponent
            }
        }
        
        // Get command line arguments from /proc/PID/cmdline
        let cmdlinePath = "\\(procPath)/cmdline"
        if let cmdlineData = try? Data(contentsOf: URL(fileURLWithPath: cmdlinePath)) {
            let cmdlineString = String(data: cmdlineData, encoding: .utf8) ?? ""
            let arguments = cmdlineString.components(separatedBy: "\\0").filter { !$0.isEmpty }
            
            if let firstArg = arguments.first, executablePath == nil {
                executablePath = firstArg
                if processName == "Unknown" {
                    processName = URL(fileURLWithPath: firstArg).lastPathComponent
                }
            }
        }
        
        return ApplicationInfo(
            id: String(processId),
            name: processName,
            bundleIdentifier: nil, // Linux doesn't have bundle identifiers
            executablePath: executablePath,
            isRunning: true,
            processId: processId
        )
    }
}

// MARK: - Error Types

enum LinuxApplicationFinderError: Error, LocalizedError {
    case failedToReadProcDirectory
    case processNotFound(Int)
    
    var errorDescription: String? {
        switch self {
        case .failedToReadProcDirectory:
            return "Failed to read /proc directory"
        case .processNotFound(let processId):
            return "Process not found: \\(processId)"
        }
    }
}

#endif

