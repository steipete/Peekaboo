#if os(Windows)
import Foundation
import WinSDK

/// Windows-specific implementation of application discovery and management
class WindowsApplicationFinder: ApplicationFinderProtocol {
    
    func findApplication(identifier: String) throws -> RunningApplication {
        let runningApps = getRunningApplications(includeBackground: true)
        
        // Try to find by PID first
        if let pid = pid_t(identifier) {
            if let app = runningApps.first(where: { $0.processIdentifier == pid }) {
                return app
            }
        }
        
        // Try exact matches first
        var matches = runningApps.filter { app in
            return app.localizedName?.lowercased() == identifier.lowercased() ||
                   app.executablePath?.lastPathComponent.lowercased() == identifier.lowercased()
        }
        
        // If no exact matches, try fuzzy matching
        if matches.isEmpty {
            matches = runningApps.filter { app in
                return app.localizedName?.localizedCaseInsensitiveContains(identifier) == true ||
                       app.executablePath?.lastPathComponent.localizedCaseInsensitiveContains(identifier) == true
            }
        }
        
        if matches.isEmpty {
            throw ApplicationError.notFound(identifier)
        } else if matches.count > 1 {
            throw ApplicationError.ambiguous(identifier, matches)
        }
        
        return matches[0]
    }
    
    func getRunningApplications(includeBackground: Bool = false) -> [RunningApplication] {
        var applications: [RunningApplication] = []
        
        // Take a snapshot of all processes
        let snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
        guard snapshot != INVALID_HANDLE_VALUE else {
            return applications
        }
        defer { CloseHandle(snapshot) }
        
        var processEntry = PROCESSENTRY32W()
        processEntry.dwSize = DWORD(MemoryLayout<PROCESSENTRY32W>.size)
        
        // Get first process
        guard Process32FirstW(snapshot, &processEntry) != 0 else {
            return applications
        }
        
        repeat {
            let pid = pid_t(processEntry.th32ProcessID)
            
            // Skip system processes
            if pid <= 4 {
                continue
            }
            
            // Get process information
            if let appInfo = getProcessInfo(pid: pid, includeBackground: includeBackground) {
                applications.append(appInfo)
            }
            
        } while Process32NextW(snapshot, &processEntry) != 0
        
        return applications
    }
    
    func activateApplication(pid: pid_t) throws {
        // Find the main window for the process
        var mainWindow: HWND? = nil
        
        let enumProc: WNDENUMPROC = { (hwnd, lParam) in
            var processId: DWORD = 0
            GetWindowThreadProcessId(hwnd, &processId)
            
            let targetPid = UInt32(lParam)
            if processId == targetPid {
                // Check if this is a main window (visible, has title bar, not tool window)
                if IsWindowVisible(hwnd) != 0 {
                    let style = GetWindowLongW(hwnd, GWL_STYLE)
                    let exStyle = GetWindowLongW(hwnd, GWL_EXSTYLE)
                    
                    if (style & WS_CAPTION) != 0 && (exStyle & WS_EX_TOOLWINDOW) == 0 {
                        let mainWindowPtr = UnsafeMutablePointer<HWND?>(bitPattern: UInt(lParam))
                        mainWindowPtr?.pointee = hwnd
                        return FALSE // Stop enumeration
                    }
                }
            }
            
            return TRUE
        }
        
        withUnsafeMutablePointer(to: &mainWindow) { ptr in
            EnumWindows(enumProc, UInt(bitPattern: ptr))
        }
        
        guard let window = mainWindow else {
            throw ApplicationError.activationFailed(pid)
        }
        
        // Bring window to foreground
        if SetForegroundWindow(window) == 0 {
            // If SetForegroundWindow fails, try alternative methods
            ShowWindow(window, SW_RESTORE)
            BringWindowToTop(window)
        }
    }
    
    func isApplicationRunning(identifier: String) -> Bool {
        do {
            _ = try findApplication(identifier: identifier)
            return true
        } catch {
            return false
        }
    }
    
    func getApplicationInfo(pid: pid_t) throws -> ApplicationInfo {
        guard let basicInfo = getProcessInfo(pid: pid, includeBackground: true) else {
            throw ApplicationError.notFound("PID \(pid)")
        }
        
        // Get additional detailed information
        let memoryUsage = getProcessMemoryUsage(pid: pid)
        let cpuUsage = getProcessCPUUsage(pid: pid)
        let windowCount = getWindowCount(pid: pid)
        let version = getProcessVersion(executablePath: basicInfo.executablePath)
        
        return ApplicationInfo(
            processIdentifier: pid,
            bundleIdentifier: nil, // Windows doesn't have bundle identifiers
            localizedName: basicInfo.localizedName,
            executablePath: basicInfo.executablePath,
            bundlePath: basicInfo.executablePath?.deletingLastPathComponent,
            version: version,
            isActive: basicInfo.isActive,
            activationPolicy: basicInfo.activationPolicy,
            launchDate: basicInfo.launchDate,
            memoryUsage: memoryUsage,
            cpuUsage: cpuUsage,
            windowCount: windowCount,
            icon: basicInfo.icon,
            architecture: getProcessArchitecture(pid: pid)
        )
    }
    
    func isApplicationManagementSupported() -> Bool {
        return true
    }
    
    func refreshApplicationCache() throws {
        // Windows process list is always fresh, no caching needed
    }
    
    // MARK: - Private Helper Methods
    
    private func getProcessInfo(pid: pid_t, includeBackground: Bool) -> RunningApplication? {
        // Open process handle
        let processHandle = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, DWORD(pid))
        guard processHandle != nil else {
            return nil
        }
        defer { CloseHandle(processHandle) }
        
        // Get executable path
        var pathBuffer = [WCHAR](repeating: 0, count: MAX_PATH)
        var pathSize = DWORD(MAX_PATH)
        
        var executablePath: String? = nil
        if QueryFullProcessImageNameW(processHandle, 0, &pathBuffer, &pathSize) != 0 {
            executablePath = String(decodingCString: pathBuffer, as: UTF16.self)
        }
        
        // Get process name from path
        let processName = executablePath?.lastPathComponent.deletingPathExtension
        
        // Determine if this is a background process
        let hasWindows = getWindowCount(pid: pid) > 0
        let activationPolicy: ApplicationActivationPolicy = hasWindows ? .regular : .prohibited
        
        if !includeBackground && activationPolicy != .regular {
            return nil
        }
        
        // Check if process is active (has foreground window)
        let isActive = isProcessActive(pid: pid)
        
        // Get process creation time (approximate launch date)
        let launchDate = getProcessCreationTime(processHandle: processHandle)
        
        // Get process icon (basic implementation)
        let icon = getProcessIcon(executablePath: executablePath)
        
        return RunningApplication(
            processIdentifier: pid,
            bundleIdentifier: nil,
            localizedName: processName,
            executablePath: executablePath,
            isActive: isActive,
            activationPolicy: activationPolicy,
            launchDate: launchDate,
            icon: icon
        )
    }
    
    private func getWindowCount(pid: pid_t) -> Int {
        var count = 0
        
        let enumProc: WNDENUMPROC = { (hwnd, lParam) in
            var processId: DWORD = 0
            GetWindowThreadProcessId(hwnd, &processId)
            
            let targetPid = UInt32(lParam)
            if processId == targetPid && IsWindowVisible(hwnd) != 0 {
                let countPtr = UnsafeMutablePointer<Int>(bitPattern: UInt(lParam))
                countPtr?.pointee += 1
            }
            
            return TRUE
        }
        
        withUnsafeMutablePointer(to: &count) { ptr in
            EnumWindows(enumProc, UInt(bitPattern: ptr))
        }
        
        return count
    }
    
    private func isProcessActive(pid: pid_t) -> Bool {
        let foregroundWindow = GetForegroundWindow()
        guard foregroundWindow != nil else { return false }
        
        var processId: DWORD = 0
        GetWindowThreadProcessId(foregroundWindow, &processId)
        
        return processId == DWORD(pid)
    }
    
    private func getProcessCreationTime(processHandle: HANDLE?) -> Date? {
        guard let processHandle = processHandle else { return nil }
        
        var creationTime = FILETIME()
        var exitTime = FILETIME()
        var kernelTime = FILETIME()
        var userTime = FILETIME()
        
        guard GetProcessTimes(processHandle, &creationTime, &exitTime, &kernelTime, &userTime) != 0 else {
            return nil
        }
        
        // Convert FILETIME to Date
        let fileTime = UInt64(creationTime.dwHighDateTime) << 32 | UInt64(creationTime.dwLowDateTime)
        let windowsEpoch = Date(timeIntervalSince1970: -11644473600) // Windows epoch (1601) to Unix epoch (1970)
        let timeInterval = TimeInterval(fileTime) / 10_000_000 // Convert from 100-nanosecond intervals to seconds
        
        return windowsEpoch.addingTimeInterval(timeInterval)
    }
    
    private func getProcessIcon(executablePath: String?) -> Data? {
        // Basic implementation - would need to extract icon from executable
        // This is a placeholder for now
        return nil
    }
    
    private func getProcessMemoryUsage(pid: pid_t) -> UInt64? {
        let processHandle = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, DWORD(pid))
        guard processHandle != nil else { return nil }
        defer { CloseHandle(processHandle) }
        
        var memCounters = PROCESS_MEMORY_COUNTERS()
        memCounters.cb = DWORD(MemoryLayout<PROCESS_MEMORY_COUNTERS>.size)
        
        guard GetProcessMemoryInfo(processHandle, &memCounters, memCounters.cb) != 0 else {
            return nil
        }
        
        return UInt64(memCounters.WorkingSetSize)
    }
    
    private func getProcessCPUUsage(pid: pid_t) -> Double? {
        // CPU usage calculation would require sampling over time
        // This is a placeholder for now
        return nil
    }
    
    private func getProcessVersion(executablePath: String?) -> String? {
        guard let path = executablePath else { return nil }
        
        // Get file version info
        let pathWide = path.withCString(encodedAs: UTF16.self) { $0 }
        let versionInfoSize = GetFileVersionInfoSizeW(pathWide, nil)
        
        guard versionInfoSize > 0 else { return nil }
        
        let versionInfo = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(versionInfoSize))
        defer { versionInfo.deallocate() }
        
        guard GetFileVersionInfoW(pathWide, 0, versionInfoSize, versionInfo) != 0 else {
            return nil
        }
        
        var fileInfo: UnsafeMutableRawPointer? = nil
        var fileInfoSize: UINT = 0
        
        guard VerQueryValueW(versionInfo, "\\", &fileInfo, &fileInfoSize) != 0,
              let info = fileInfo?.assumingMemoryBound(to: VS_FIXEDFILEINFO.self) else {
            return nil
        }
        
        let major = HIWORD(info.pointee.dwFileVersionMS)
        let minor = LOWORD(info.pointee.dwFileVersionMS)
        let build = HIWORD(info.pointee.dwFileVersionLS)
        let revision = LOWORD(info.pointee.dwFileVersionLS)
        
        return "\(major).\(minor).\(build).\(revision)"
    }
    
    private func getProcessArchitecture(pid: pid_t) -> ProcessArchitecture {
        let processHandle = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, DWORD(pid))
        guard processHandle != nil else { return .unknown }
        defer { CloseHandle(processHandle) }
        
        var isWow64: BOOL = FALSE
        if IsWow64Process(processHandle, &isWow64) != 0 {
            if isWow64 != 0 {
                return .x86 // 32-bit process on 64-bit system
            } else {
                // Could be 64-bit process or 32-bit process on 32-bit system
                // Additional checks would be needed to determine exact architecture
                return .x86_64
            }
        }
        
        return .unknown
    }
}

// MARK: - String Extensions

private extension String {
    var lastPathComponent: String {
        return (self as NSString).lastPathComponent
    }
    
    var deletingLastPathComponent: String {
        return (self as NSString).deletingLastPathComponent
    }
    
    var deletingPathExtension: String {
        return (self as NSString).deletingPathExtension
    }
}
#endif

