import AppKit
import AXorcist
import Foundation

// MARK: - Private API Declaration

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: inout CGWindowID) -> AXError

// MARK: - Window Identity Service

@MainActor
public final class WindowIdentityService {
    
    // MARK: - CGWindowID Extraction
    
    /// Extract CGWindowID from an AXUIElement window
    public func getWindowID(from windowElement: AXUIElement) -> CGWindowID? {
        var windowID: CGWindowID = 0
        let result = _AXUIElementGetWindow(windowElement, &windowID)
        
        guard result == .success else {
            // Failed to get CGWindowID from AXUIElement
            return nil
        }
        
        return windowID
    }
    
    /// Extract CGWindowID from an Element (AXorcist wrapper)
    public func getWindowID(from element: Element) -> CGWindowID? {
        // Get the underlying AXUIElement
        let axElement: AXUIElement = element.underlyingElement
        
        // Try to get window ID from the element
        var windowID: CGWindowID = 0
        let result = _AXUIElementGetWindow(axElement, &windowID)
        
        if result == .success {
            return windowID
        }
        
        // If not a window, try to find parent window
        // Note: AXorcist doesn't expose window property, so we try role check
        if let role = element.role(), role == "AXWindow" {
            return getWindowID(from: axElement)
        }
        
        return nil
    }
    
    // MARK: - AXUIElement Lookup
    
    /// Find AXUIElement window by CGWindowID
    public func findWindow(byID windowID: CGWindowID, in app: NSRunningApplication) -> Element? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let element = Element(appElement)
        
        // Get all windows for this application
        guard let windows = element.windows() else {
            return nil
        }
        
        // Check each window's ID
        for window in windows {
            if let currentID = getWindowID(from: window) {
                if currentID == windowID {
                    return window
                }
            }
        }
        
        return nil
    }
    
    /// Find AXUIElement window by CGWindowID across all applications
    public func findWindow(byID windowID: CGWindowID) -> (window: Element, app: NSRunningApplication)? {
        // First, use CGWindowListCopyWindowInfo to find which app owns this window
        let options: CGWindowListOption = [.optionIncludingWindow]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, windowID) as? [[String: Any]],
              let windowInfo = windowInfoList.first,
              let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t else {
            // Window not found in window list
            return nil
        }
        
        // Find the running application
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { $0.processIdentifier == ownerPID }) else {
            // Application not found for window
            return nil
        }
        
        // Find the window element
        guard let window = findWindow(byID: windowID, in: app) else {
            // AXUIElement not found for window
            return nil
        }
        
        return (window, app)
    }
    
    // MARK: - Window Information
    
    /// Get comprehensive window information using CGWindowID
    public func getWindowInfo(windowID: CGWindowID) -> WindowIdentityInfo? {
        // Get window info from CoreGraphics
        let options: CGWindowListOption = [.optionIncludingWindow]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, windowID) as? [[String: Any]],
              let windowInfo = windowInfoList.first else {
            return nil
        }
        
        // Extract information
        let title = windowInfo[kCGWindowName as String] as? String
        let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t ?? 0
        let windowLayer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
        let alpha = windowInfo[kCGWindowAlpha as String] as? CGFloat ?? 1.0
        
        // Get bounds
        var bounds: CGRect = .zero
        if let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any] {
            bounds = CGRect(
                x: boundsDict["X"] as? CGFloat ?? 0,
                y: boundsDict["Y"] as? CGFloat ?? 0,
                width: boundsDict["Width"] as? CGFloat ?? 0,
                height: boundsDict["Height"] as? CGFloat ?? 0
            )
        }
        
        // Get AX identifier if available
        var axIdentifier: String?
        if let result = findWindow(byID: windowID) {
            axIdentifier = result.window.identifier()
        }
        
        // Get application info
        let runningApps = NSWorkspace.shared.runningApplications
        let app = runningApps.first(where: { $0.processIdentifier == ownerPID })
        
        return WindowIdentityInfo(
            windowID: windowID,
            title: title,
            bounds: bounds,
            ownerPID: ownerPID,
            applicationName: app?.localizedName,
            bundleIdentifier: app?.bundleIdentifier,
            windowLayer: windowLayer,
            alpha: alpha,
            axIdentifier: axIdentifier
        )
    }
    
    // MARK: - Window State Verification
    
    /// Check if a window still exists
    public func windowExists(windowID: CGWindowID) -> Bool {
        // CGWindowListCopyWindowInfo with .optionIncludingWindow requires the window ID as the second parameter
        // and will return info only for that specific window
        let options: CGWindowListOption = [.optionIncludingWindow]
        if let windowList = CGWindowListCopyWindowInfo(options, windowID) as NSArray?,
           windowList.count > 0 {
            return true
        }
        
        // Fallback: search all windows
        let allWindowsOptions: CGWindowListOption = [.optionAll]
        guard let allWindows = CGWindowListCopyWindowInfo(allWindowsOptions, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        
        return allWindows.contains { windowInfo in
            if let id = windowInfo[kCGWindowNumber as String] as? Int {
                return CGWindowID(id) == windowID
            }
            return false
        }
    }
    
    /// Check if a window is on screen (not minimized)
    public func isWindowOnScreen(windowID: CGWindowID) -> Bool {
        let options: CGWindowListOption = [.optionIncludingWindow, .optionOnScreenOnly]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, windowID) as? [[String: Any]] else {
            return false
        }
        return !windowInfoList.isEmpty
    }
    
    /// Get all windows for a specific application
    public func getWindows(for app: NSRunningApplication) -> [WindowIdentityInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        return windowInfoList.compactMap { windowInfo in
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == app.processIdentifier,
                  let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID else {
                return nil
            }
            
            return getWindowInfo(windowID: windowID)
        }
    }
}

// MARK: - Window Identity Information

public struct WindowIdentityInfo: Sendable {
    public let windowID: CGWindowID
    public let title: String?
    public let bounds: CGRect
    public let ownerPID: pid_t
    public let applicationName: String?
    public let bundleIdentifier: String?
    public let windowLayer: Int
    public let alpha: CGFloat
    public let axIdentifier: String?
    
    /// Check if this window is likely the main/document window
    public var isMainWindow: Bool {
        // Main windows are typically on layer 0
        windowLayer == 0 && alpha == 1.0
    }
    
    /// Check if this window is likely a dialog or sheet
    public var isDialog: Bool {
        // Dialogs are often on higher layers
        windowLayer > 0 && windowLayer < 1000
    }
}