#if os(macOS)
import Foundation
import AppKit
import CoreGraphics

/// macOS-specific implementation of window management
class macOSWindowManager: WindowManagerProtocol {
    
    func getWindowsForApp(pid: pid_t, includeOffScreen: Bool = false) throws -> [WindowData] {
        Logger.shared.debug("Getting windows for PID: \(pid)")

        // In CI environment, return empty array to avoid accessing window server
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            return []
        }

        let windowList = try fetchWindowList(includeOffScreen: includeOffScreen)
        let windows = extractWindowsForPID(pid, from: windowList)

        Logger.shared.debug("Found \(windows.count) windows for PID \(pid)")
        return windows.sorted { $0.windowIndex < $1.windowIndex }
    }
    
    func getWindowInfo(windowId: UInt32) throws -> WindowData? {
        let windowList = try fetchWindowList(includeOffScreen: true)
        
        for windowInfo in windowList {
            if let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
               windowID == windowId {
                return parseWindowInfo(windowInfo, targetPID: nil, index: 0)
            }
        }
        
        return nil
    }
    
    func getAllWindows(includeOffScreen: Bool = false) throws -> [WindowData] {
        let windowList = try fetchWindowList(includeOffScreen: includeOffScreen)
        var windows: [WindowData] = []
        var windowIndex = 0
        
        for windowInfo in windowList {
            if let window = parseWindowInfo(windowInfo, targetPID: nil, index: windowIndex) {
                windows.append(window)
                windowIndex += 1
            }
        }
        
        return windows
    }
    
    func getWindowsByApplication(includeOffScreen: Bool = false) throws -> [pid_t: [WindowData]] {
        let windowList = try fetchWindowList(includeOffScreen: includeOffScreen)
        var windowsByApp: [pid_t: [WindowData]] = [:]
        var windowIndicesByPID: [pid_t: Int] = [:]
        
        for windowInfo in windowList {
            guard let windowPID = windowInfo[kCGWindowOwnerPID as String] as? Int32 else {
                continue
            }
            
            let currentIndex = windowIndicesByPID[windowPID] ?? 0
            windowIndicesByPID[windowPID] = currentIndex + 1
            
            if let window = parseWindowInfo(windowInfo, targetPID: windowPID, index: currentIndex) {
                if windowsByApp[windowPID] == nil {
                    windowsByApp[windowPID] = []
                }
                windowsByApp[windowPID]?.append(window)
            }
        }
        
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
        // CoreGraphics window list is always fresh, no caching needed
    }
    
    // MARK: - Private Helper Methods
    
    private func fetchWindowList(includeOffScreen: Bool) throws -> [[String: Any]] {
        let options: CGWindowListOption = includeOffScreen
            ? [.excludeDesktopElements]
            : [.excludeDesktopElements, .optionOnScreenOnly]

        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            throw WindowManagementError.systemError(NSError(
                domain: "WindowManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get window list from system"]
            ))
        }

        return windowList
    }
    
    private func extractWindowsForPID(_ pid: pid_t, from windowList: [[String: Any]]) -> [WindowData] {
        var windows: [WindowData] = []
        var windowIndex = 0

        for windowInfo in windowList {
            if let window = parseWindowInfo(windowInfo, targetPID: pid, index: windowIndex) {
                windows.append(window)
                windowIndex += 1
            }
        }

        return windows
    }
    
    private func parseWindowInfo(_ info: [String: Any], targetPID: pid_t?, index: Int) -> WindowData? {
        guard let windowPID = info[kCGWindowOwnerPID as String] as? Int32,
              let windowID = info[kCGWindowNumber as String] as? CGWindowID else {
            return nil
        }
        
        // If we're filtering by PID, check if this window belongs to the target PID
        if let targetPID = targetPID, windowPID != targetPID {
            return nil
        }

        let title = info[kCGWindowName as String] as? String ?? "Untitled"
        let bounds = extractWindowBounds(from: info)
        let isOnScreen = info[kCGWindowIsOnscreen as String] as? Bool ?? true

        return WindowData(
            windowId: windowID,
            title: title,
            bounds: bounds,
            isOnScreen: isOnScreen,
            windowIndex: index
        )
    }
    
    private func extractWindowBounds(from windowInfo: [String: Any]) -> CGRect {
        guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any] else {
            return .zero
        }

        let xCoordinate = boundsDict["X"] as? Double ?? 0
        let yCoordinate = boundsDict["Y"] as? Double ?? 0
        let width = boundsDict["Width"] as? Double ?? 0
        let height = boundsDict["Height"] as? Double ?? 0

        return CGRect(x: xCoordinate, y: yCoordinate, width: width, height: height)
    }
}

// MARK: - Extension for backward compatibility

extension macOSWindowManager {
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

