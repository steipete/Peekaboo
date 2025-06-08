#if os(Windows)
import Foundation
import WinSDK

/// Windows implementation of application finding using Win32 APIs
struct WindowsApplicationFinder: ApplicationFinderProtocol {
    
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
        
        // Get list of all processes
        var processIds = Array<DWORD>(repeating: 0, count: 1024)
        var bytesReturned: DWORD = 0
        
        guard EnumProcesses(&processIds, DWORD(processIds.count * MemoryLayout<DWORD>.size), &bytesReturned) != 0 else {
            throw WindowsApplicationFinderError.failedToEnumerateProcesses
        }
        
        let processCount = Int(bytesReturned) / MemoryLayout<DWORD>.size
        
        for i in 0..<processCount {
            let processId = processIds[i]
            
            // Skip system idle process
            guard processId != 0 else { continue }
            
            if let appInfo = try? getApplicationInfo(processId: processId) {
                applications.append(appInfo)
            }
        }
        
        return applications
    }
    
    func getApplication(by identifier: String) async throws -> ApplicationInfo? {
        // Try to parse as process ID
        if let processId = DWORD(identifier) {
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
        return true // Windows always supports application finding
    }
    
    // MARK: - Private Methods
    
    private func getApplicationInfo(processId: DWORD) throws -> ApplicationInfo {
        let processHandle = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, processId)
        guard let processHandle = processHandle else {
            throw WindowsApplicationFinderError.failedToOpenProcess(processId)
        }
        defer { CloseHandle(processHandle) }
        
        // Get process executable path
        var executablePath: String?
        var pathBuffer = Array<WCHAR>(repeating: 0, count: MAX_PATH)
        var pathSize = DWORD(MAX_PATH)
        
        if QueryFullProcessImageNameW(processHandle, 0, &pathBuffer, &pathSize) != 0 {
            executablePath = String(decodingCString: pathBuffer, as: UTF16.self)
        }
        
        // Get process name from executable path
        var processName = "Unknown"
        if let path = executablePath {
            processName = URL(fileURLWithPath: path).lastPathComponent
            if processName.hasSuffix(".exe") {
                processName = String(processName.dropLast(4))
            }
        } else {
            // Fallback: get module name
            var moduleHandle: HMODULE = HMODULE(bitPattern: 0)!
            var needed: DWORD = 0
            
            if EnumProcessModules(processHandle, &moduleHandle, DWORD(MemoryLayout<HMODULE>.size), &needed) != 0 {
                var moduleNameBuffer = Array<WCHAR>(repeating: 0, count: MAX_PATH)
                if GetModuleBaseNameW(processHandle, moduleHandle, &moduleNameBuffer, DWORD(MAX_PATH)) != 0 {
                    let moduleName = String(decodingCString: moduleNameBuffer, as: UTF16.self)
                    if moduleName.hasSuffix(".exe") {
                        processName = String(moduleName.dropLast(4))
                    } else {
                        processName = moduleName
                    }
                }
            }
        }
        
        return ApplicationInfo(
            id: String(processId),
            name: processName,
            bundleIdentifier: nil, // Windows doesn't have bundle identifiers
            executablePath: executablePath,
            isRunning: true,
            processId: Int(processId)
        )
    }
}

// MARK: - Error Types

enum WindowsApplicationFinderError: Error, LocalizedError {
    case failedToEnumerateProcesses
    case failedToOpenProcess(DWORD)
    
    var errorDescription: String? {
        switch self {
        case .failedToEnumerateProcesses:
            return "Failed to enumerate running processes"
        case .failedToOpenProcess(let processId):
            return "Failed to open process with ID: \\(processId)"
        }
    }
}

#endif

