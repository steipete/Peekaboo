import Foundation
import CoreGraphics

#if os(macOS)
import AppKit
#endif

// Legacy WindowManager class for backward compatibility
// New code should use PlatformFactory.createWindowManager()
final class WindowManager: Sendable {
    #if os(macOS)
    static func getWindowsForApp(pid: pid_t, includeOffScreen: Bool = false) throws(WindowError) -> [WindowData] {
        // In CI environment, return empty array to avoid accessing window server
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            return []
        }

        let windowList = try fetchWindowList(includeOffScreen: includeOffScreen)
        let windows = extractWindowsForPID(pid, from: windowList)

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

    private static func extractWindowsForPID(_ targetPID: pid_t, from windowList: [[String: Any]]) -> [WindowData] {
        var windows: [WindowData] = []
        var windowIndex = 0

        for windowInfo in windowList {
            guard let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  pid == targetPID else {
                continue
            }

            guard let windowID = windowInfo[kCGWindowNumber as String] as? UInt32 else {
                continue
            }

            let title = windowInfo[kCGWindowName as String] as? String ?? ""
            
            // Skip windows without titles (usually system windows)
            guard !title.isEmpty else {
                continue
            }

            let bounds = extractWindowBounds(from: windowInfo)
            let isOnScreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool ?? false

            let windowData = WindowData(
                windowId: windowID,
                title: title,
                bounds: bounds,
                isOnScreen: isOnScreen,
                windowIndex: windowIndex
            )

            windows.append(windowData)
            windowIndex += 1
        }

        return windows
    }

    private static func extractWindowBounds(from windowInfo: [String: Any]) -> CGRect {
        guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let width = boundsDict["Width"] as? CGFloat,
              let height = boundsDict["Height"] as? CGFloat else {
            return CGRect.zero
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }
    #else
    // Non-macOS platforms - use platform factory
    static func getWindowsForApp(pid: pid_t, includeOffScreen: Bool = false) async throws -> [WindowData] {
        let windowManager = PlatformFactory.createWindowManager()
        let windows = try await windowManager.getWindows(for: String(pid))
        
        return windows.enumerated().map { index, window in
            WindowData(
                windowId: UInt32(window.id) ?? 0,
                title: window.title,
                bounds: window.bounds,
                isOnScreen: window.isVisible,
                windowIndex: index
            )
        }
    }
    #endif
}

// Window-related errors
enum WindowError: Error, LocalizedError, Sendable {
    case windowListFailed
    case invalidWindowID
    case windowNotFound

    var errorDescription: String? {
        switch self {
        case .windowListFailed:
            return "Failed to retrieve window list from the system."
        case .invalidWindowID:
            return "Invalid window ID provided."
        case .windowNotFound:
            return "The specified window could not be found."
        }
    }
}

