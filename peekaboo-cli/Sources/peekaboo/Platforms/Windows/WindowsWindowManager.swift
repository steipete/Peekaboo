#if os(Windows)
import Foundation
import WinSDK

/// Windows implementation of window management using Win32 APIs
struct WindowsWindowManager: WindowManagerProtocol {
    
    func getWindows(for applicationId: String) async throws -> [WindowInfo] {
        let allWindows = try await getAllWindows()
        return allWindows.filter { $0.applicationId == applicationId }
    }
    
    func getAllWindows() async throws -> [WindowInfo] {
        var windows: [WindowInfo] = []
        
        // Enumerate all top-level windows
        let enumProc: WNDENUMPROC = { hwnd, lParam in
            guard let hwnd = hwnd else { return TRUE }
            
            let windowsPtr = UnsafeMutablePointer<[WindowInfo]>(bitPattern: UInt(lParam))!
            
            // Check if window is visible
            guard IsWindowVisible(hwnd) != 0 else { return TRUE }
            
            // Get window title
            let titleLength = GetWindowTextLengthW(hwnd)
            guard titleLength > 0 else { return TRUE }
            
            var titleBuffer = Array<WCHAR>(repeating: 0, count: Int(titleLength + 1))
            GetWindowTextW(hwnd, &titleBuffer, titleLength + 1)
            let title = String(decodingCString: titleBuffer, as: UTF16.self)
            
            // Skip windows with empty titles
            guard !title.isEmpty else { return TRUE }
            
            // Get window rectangle
            var rect = RECT()
            guard GetWindowRect(hwnd, &rect) != 0 else { return TRUE }
            
            let bounds = CGRect(
                x: CGFloat(rect.left),
                y: CGFloat(rect.top),
                width: CGFloat(rect.right - rect.left),
                height: CGFloat(rect.bottom - rect.top)
            )
            
            // Skip very small windows
            guard bounds.width > 50 && bounds.height > 50 else { return TRUE }
            
            // Get process ID
            var processId: DWORD = 0
            GetWindowThreadProcessId(hwnd, &processId)
            
            // Get process name
            let processHandle = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, processId)
            var processName = "Unknown"
            
            if let processHandle = processHandle {
                var moduleHandle: HMODULE = HMODULE(bitPattern: 0)!
                var needed: DWORD = 0
                
                if EnumProcessModules(processHandle, &moduleHandle, DWORD(MemoryLayout<HMODULE>.size), &needed) != 0 {
                    var moduleNameBuffer = Array<WCHAR>(repeating: 0, count: MAX_PATH)
                    if GetModuleBaseNameW(processHandle, moduleHandle, &moduleNameBuffer, DWORD(MAX_PATH)) != 0 {
                        processName = String(decodingCString: moduleNameBuffer, as: UTF16.self)
                    }
                }
                
                CloseHandle(processHandle)
            }
            
            // Check if window is minimized
            let isMinimized = IsIconic(hwnd) != 0
            
            let windowInfo = WindowInfo(
                id: String(format: "%p", hwnd),
                title: title,
                bounds: bounds,
                applicationName: processName,
                applicationId: String(processId),
                isVisible: true,
                isMinimized: isMinimized,
                level: 0
            )
            
            windowsPtr.pointee.append(windowInfo)
            
            return TRUE
        }
        
        withUnsafeMutablePointer(to: &windows) { windowsPtr in
            EnumWindows(enumProc, LPARAM(UInt(bitPattern: windowsPtr)))
        }
        
        return windows
    }
    
    func getWindow(by windowId: String) async throws -> WindowInfo? {
        guard let hwnd = parseWindowHandle(windowId) else {
            return nil
        }
        
        // Check if window exists and is visible
        guard IsWindow(hwnd) != 0, IsWindowVisible(hwnd) != 0 else {
            return nil
        }
        
        // Get window title
        let titleLength = GetWindowTextLengthW(hwnd)
        guard titleLength > 0 else { return nil }
        
        var titleBuffer = Array<WCHAR>(repeating: 0, count: Int(titleLength + 1))
        GetWindowTextW(hwnd, &titleBuffer, titleLength + 1)
        let title = String(decodingCString: titleBuffer, as: UTF16.self)
        
        // Get window rectangle
        var rect = RECT()
        guard GetWindowRect(hwnd, &rect) != 0 else { return nil }
        
        let bounds = CGRect(
            x: CGFloat(rect.left),
            y: CGFloat(rect.top),
            width: CGFloat(rect.right - rect.left),
            height: CGFloat(rect.bottom - rect.top)
        )
        
        // Get process ID and name
        var processId: DWORD = 0
        GetWindowThreadProcessId(hwnd, &processId)
        
        let processHandle = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, processId)
        var processName = "Unknown"
        
        if let processHandle = processHandle {
            var moduleHandle: HMODULE = HMODULE(bitPattern: 0)!
            var needed: DWORD = 0
            
            if EnumProcessModules(processHandle, &moduleHandle, DWORD(MemoryLayout<HMODULE>.size), &needed) != 0 {
                var moduleNameBuffer = Array<WCHAR>(repeating: 0, count: MAX_PATH)
                if GetModuleBaseNameW(processHandle, moduleHandle, &moduleNameBuffer, DWORD(MAX_PATH)) != 0 {
                    processName = String(decodingCString: moduleNameBuffer, as: UTF16.self)
                }
            }
            
            CloseHandle(processHandle)
        }
        
        let isMinimized = IsIconic(hwnd) != 0
        
        return WindowInfo(
            id: windowId,
            title: title,
            bounds: bounds,
            applicationName: processName,
            applicationId: String(processId),
            isVisible: true,
            isMinimized: isMinimized,
            level: 0
        )
    }
    
    static func isSupported() -> Bool {
        return true // Windows always supports window management
    }
    
    // MARK: - Private Methods
    
    private func parseWindowHandle(_ windowId: String) -> HWND? {
        // Parse hex string to HWND
        guard let handle = UInt(windowId.dropFirst(2), radix: 16) else {
            return nil
        }
        return HWND(bitPattern: handle)
    }
}

#endif

