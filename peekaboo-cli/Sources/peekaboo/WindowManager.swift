import Foundation
import CoreGraphics
import AppKit

class WindowManager {
    
    static func getWindowsForApp(pid: pid_t, includeOffScreen: Bool = false) throws(WindowError) -> [WindowData] {
        Logger.shared.debug("Getting windows for PID: \(pid)")
        
        let options: CGWindowListOption = includeOffScreen 
            ? [.excludeDesktopElements]
            : [.excludeDesktopElements, .optionOnScreenOnly]
        
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            throw WindowError.windowListFailed
        }
        
        var windows: [WindowData] = []
        var windowIndex = 0
        
        for windowInfo in windowList {
            guard let windowPID = windowInfo[kCGWindowOwnerPID as String] as? Int32,
                  windowPID == pid else {
                continue
            }
            
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }
            
            let windowTitle = windowInfo[kCGWindowName as String] as? String ?? "Untitled"
            
            // Get window bounds
            var bounds = CGRect.zero
            if let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any] {
                let x = boundsDict["X"] as? Double ?? 0
                let y = boundsDict["Y"] as? Double ?? 0
                let width = boundsDict["Width"] as? Double ?? 0
                let height = boundsDict["Height"] as? Double ?? 0
                bounds = CGRect(x: x, y: y, width: width, height: height)
            }
            
            // Determine if window is on screen
            let isOnScreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool ?? true
            
            let windowData = WindowData(
                windowId: windowID,
                title: windowTitle,
                bounds: bounds,
                isOnScreen: isOnScreen,
                windowIndex: windowIndex
            )
            
            windows.append(windowData)
            windowIndex += 1
        }
        
        // Sort by window layer (frontmost first)
        windows.sort { (first: WindowData, second: WindowData) -> Bool in
            // Windows with higher layer (closer to front) come first
            return first.windowIndex < second.windowIndex
        }
        
        Logger.shared.debug("Found \(windows.count) windows for PID \(pid)")
        return windows
    }
    
    static func getWindowsInfoForApp(
        pid: pid_t, 
        includeOffScreen: Bool = false,
        includeBounds: Bool = false,
        includeIDs: Bool = false
    ) throws(WindowError) -> [WindowInfo] {
        
        let windowDataArray = try getWindowsForApp(pid: pid, includeOffScreen: includeOffScreen)
        
        return windowDataArray.map { windowData in
            WindowInfo(
                window_title: windowData.title,
                window_id: includeIDs ? windowData.windowId : nil,
                window_index: windowData.windowIndex,
                bounds: includeBounds ? WindowBounds(
                    x: Int(windowData.bounds.origin.x),
                    y: Int(windowData.bounds.origin.y),
                    width: Int(windowData.bounds.size.width),
                    height: Int(windowData.bounds.size.height)
                ) : nil,
                is_on_screen: includeOffScreen ? windowData.isOnScreen : nil
            )
        }
    }
}

// Extension to add the getWindowsForApp function to ImageCommand
extension ImageCommand {
    func getWindowsForApp(pid: pid_t) throws(WindowError) -> [WindowData] {
        return try WindowManager.getWindowsForApp(pid: pid)
    }
}

enum WindowError: Error, LocalizedError {
    case windowListFailed
    case noWindowsFound
    
    var errorDescription: String? {
        switch self {
        case .windowListFailed:
            return "Failed to get window list from system"
        case .noWindowsFound:
            return "No windows found for the specified application"
        }
    }
} 