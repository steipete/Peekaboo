import AppKit
import CoreGraphics
import Foundation

/// Manages window enumeration and information retrieval.
///
/// Provides functionality to list windows for specific applications, extract window
/// metadata, and filter windows based on visibility criteria.
final class WindowManager: Sendable {
    static func getWindowsForApp(pid: pid_t, includeOffScreen: Bool = false) throws(WindowError) -> [WindowData] {
        // Logger.shared.debug("Getting windows for PID: \(pid)")

        // In CI environment, return empty array to avoid accessing window server
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            return []
        }

        let windowList = try fetchWindowList(includeOffScreen: includeOffScreen)
        let windows = extractWindowsForPID(pid, from: windowList)

        // Logger.shared.debug("Found \(windows.count) windows for PID \(pid)")
        return windows.sorted { $0.windowIndex < $1.windowIndex }
    }

    private static func fetchWindowList(includeOffScreen: Bool) throws(WindowError) -> [[String: Any]] {
        let options: CGWindowListOption = includeOffScreen
            ? [.excludeDesktopElements]
            : [.excludeDesktopElements, .optionOnScreenOnly]

        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            throw WindowError.windowListFailed
        }

        return windowList
    }

    private static func extractWindowsForPID(_ pid: pid_t, from windowList: [[String: Any]]) -> [WindowData] {
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

    private static func parseWindowInfo(_ info: [String: Any], targetPID: pid_t, index: Int) -> WindowData? {
        guard let windowPID = info[kCGWindowOwnerPID as String] as? Int32,
              windowPID == targetPID,
              let windowID = info[kCGWindowNumber as String] as? CGWindowID else {
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

    private static func extractWindowBounds(from windowInfo: [String: Any]) -> CGRect {
        guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any] else {
            return .zero
        }

        let xCoordinate = boundsDict["X"] as? Double ?? 0
        let yCoordinate = boundsDict["Y"] as? Double ?? 0
        let width = boundsDict["Width"] as? Double ?? 0
        let height = boundsDict["Height"] as? Double ?? 0

        return CGRect(x: xCoordinate, y: yCoordinate, width: width, height: height)
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
        try WindowManager.getWindowsForApp(pid: pid)
    }
}

/// Errors that can occur during window management operations.
///
/// Covers failures in accessing the window server and scenarios where
/// no windows are found for a given application.
enum WindowError: Error, LocalizedError, Sendable {
    case windowListFailed
    case noWindowsFound

    var errorDescription: String? {
        switch self {
        case .windowListFailed:
            "Failed to get window list from system"
        case .noWindowsFound:
            "No windows found for the specified application"
        }
    }
}
