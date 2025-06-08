#if os(Windows)
import Foundation
import CoreGraphics
import WinSDK

/// Windows-specific implementation of window management using Win32 APIs
class WindowsWindowManager: WindowManagerProtocol {
    
    func getWindowsForApp(pid: pid_t, includeOffScreen: Bool = false) throws -> [WindowData] {
        var windows: [WindowData] = []
        var windowIndex = 0
        
        let enumProc: WNDENUMPROC = { (hwnd, lParam) in
            var processId: DWORD = 0
            GetWindowThreadProcessId(hwnd, &processId)
            
            let targetPid = UInt32(lParam)
            if processId == targetPid {
                // Check visibility if needed
                let isVisible = IsWindowVisible(hwnd) != 0
                if !includeOffScreen && !isVisible {
                    return TRUE
                }
                
                if let windowData = createWindowData(from: hwnd, index: windowIndex, isVisible: isVisible) {
                    let windows = Unmanaged<NSMutableArray>.fromOpaque(UnsafeRawPointer(bitPattern: UInt(lParam))!).takeUnretainedValue()
                    windows.add(windowData)
                    windowIndex += 1
                }
            }
            
            return TRUE
        }
        
        let windowsArray = NSMutableArray()
        let context = Unmanaged.passUnretained(windowsArray).toOpaque()
        
        EnumWindows(enumProc, UInt(bitPattern: context))
        
        return windowsArray.compactMap { $0 as? WindowData }.sorted { $0.windowIndex < $1.windowIndex }
    }
    
    func getWindowInfo(windowId: UInt32) throws -> WindowData? {
        let hwnd = HWND(bitPattern: UInt(windowId))
        guard hwnd != nil, IsWindow(hwnd) != 0 else {
            return nil
        }
        
        let isVisible = IsWindowVisible(hwnd) != 0
        return createWindowData(from: hwnd, index: 0, isVisible: isVisible)
    }
    
    func getAllWindows(includeOffScreen: Bool = false) throws -> [WindowData] {
        var windows: [WindowData] = []
        var windowIndex = 0
        
        let enumProc: WNDENUMPROC = { (hwnd, lParam) in
            let isVisible = IsWindowVisible(hwnd) != 0
            if !includeOffScreen && !isVisible {
                return TRUE
            }
            
            if let windowData = createWindowData(from: hwnd, index: windowIndex, isVisible: isVisible) {
                let windows = Unmanaged<NSMutableArray>.fromOpaque(UnsafeRawPointer(bitPattern: UInt(lParam))!).takeUnretainedValue()
                windows.add(windowData)
                windowIndex += 1
            }
            
            return TRUE
        }
        
        let windowsArray = NSMutableArray()
        let context = Unmanaged.passUnretained(windowsArray).toOpaque()
        
        EnumWindows(enumProc, UInt(bitPattern: context))
        
        return windowsArray.compactMap { $0 as? WindowData }
    }
    
    func getWindowsByApplication(includeOffScreen: Bool = false) throws -> [pid_t: [WindowData]] {
        var windowsByApp: [pid_t: [WindowData]] = [:]
        var windowIndicesByPID: [pid_t: Int] = [:]
        
        let enumProc: WNDENUMPROC = { (hwnd, lParam) in
            var processId: DWORD = 0
            GetWindowThreadProcessId(hwnd, &processId)
            
            let isVisible = IsWindowVisible(hwnd) != 0
            if !includeOffScreen && !isVisible {
                return TRUE
            }
            
            let pid = pid_t(processId)
            let currentIndex = windowIndicesByPID[pid] ?? 0
            windowIndicesByPID[pid] = currentIndex + 1
            
            if let windowData = createWindowData(from: hwnd, index: currentIndex, isVisible: isVisible) {
                if windowsByApp[pid] == nil {
                    windowsByApp[pid] = []
                }
                windowsByApp[pid]?.append(windowData)
            }
            
            return TRUE
        }
        
        EnumWindows(enumProc, 0)
        
        // Sort windows within each application
        for pid in windowsByApp.keys {
            windowsByApp[pid]?.sort { $0.windowIndex < $1.windowIndex }
        }
        
        return windowsByApp
    }
    
    func isWindowManagementSupported() -> Bool {
        return true
    }
    
    func refreshWindowCache() throws {
        // Windows doesn't cache window information, always fresh
    }
    
    // MARK: - Private Helper Methods
    
    private func createWindowData(from hwnd: HWND?, index: Int, isVisible: Bool) -> WindowData? {
        guard let hwnd = hwnd else { return nil }
        
        let windowId = UInt32(bitPattern: hwnd) ?? 0
        
        // Get window title
        let titleLength = GetWindowTextLengthW(hwnd)
        var title = "Untitled"
        if titleLength > 0 {
            let buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(titleLength + 1))
            defer { buffer.deallocate() }
            if GetWindowTextW(hwnd, buffer, titleLength + 1) > 0 {
                title = String(decodingCString: buffer, as: UTF16.self)
            }
        }
        
        // Get window rectangle
        var rect = RECT()
        guard GetWindowRect(hwnd, &rect) != 0 else {
            return nil
        }
        
        let bounds = CGRect(
            x: CGFloat(rect.left),
            y: CGFloat(rect.top),
            width: CGFloat(rect.right - rect.left),
            height: CGFloat(rect.bottom - rect.top)
        )
        
        return WindowData(
            windowId: windowId,
            title: title,
            bounds: bounds,
            isOnScreen: isVisible,
            windowIndex: index
        )
    }
    
    /// Get window class name for additional filtering
    private func getWindowClassName(_ hwnd: HWND?) -> String? {
        guard let hwnd = hwnd else { return nil }
        
        let buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: 256)
        defer { buffer.deallocate() }
        
        let length = GetClassNameW(hwnd, buffer, 256)
        if length > 0 {
            return String(decodingCString: buffer, as: UTF16.self)
        }
        
        return nil
    }
    
    /// Check if window is a tool window (should be excluded from normal window lists)
    private func isToolWindow(_ hwnd: HWND?) -> Bool {
        guard let hwnd = hwnd else { return false }
        
        let exStyle = GetWindowLongW(hwnd, GWL_EXSTYLE)
        return (exStyle & WS_EX_TOOLWINDOW) != 0
    }
    
    /// Check if window has a visible title bar
    private func hasVisibleTitleBar(_ hwnd: HWND?) -> Bool {
        guard let hwnd = hwnd else { return false }
        
        let style = GetWindowLongW(hwnd, GWL_STYLE)
        return (style & WS_CAPTION) != 0
    }
}

// MARK: - Extension for backward compatibility

extension WindowsWindowManager {
    /// Get windows info for app in the format expected by the existing CLI
    func getWindowsInfoForApp(
        pid: pid_t,
        includeOffScreen: Bool = false,
        includeBounds: Bool = false,
        includeIDs: Bool = false
    ) throws -> [WindowInfo] {
        let windowDataArray = try getWindowsForApp(pid: pid, includeOffScreen: includeOffScreen)
        
        return windowDataArray.map { windowData in
            WindowInfo(
                window_title: windowData.title,
                window_id: includeIDs ? windowData.windowId : nil,
                window_index: windowData.windowIndex,
                bounds: includeBounds ? WindowBounds(
                    xCoordinate: Int(windowData.bounds.origin.x),
                    yCoordinate: Int(windowData.bounds.origin.y),
                    width: Int(windowData.bounds.size.width),
                    height: Int(windowData.bounds.size.height)
                ) : nil,
                is_on_screen: includeOffScreen ? windowData.isOnScreen : nil,
                application_name: nil, // Would need to look up from PID
                process_id: pid
            )
        }
    }
}
#endif

