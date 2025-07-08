import AppKit
import CoreGraphics

/// Detects and provides information about menu bar items
struct MenuBarDetector {
    
    /// Information about a menu bar item
    struct MenuBarItemInfo {
        let title: String
        let appName: String
        let bundleIdentifier: String?
        let frame: CGRect
        let windowID: CGWindowID
        let processID: pid_t
        
        /// Display name suitable for users
        var displayName: String {
            // Handle special system items
            if bundleIdentifier == "com.apple.controlcenter" {
                switch title {
                case "WiFi": return "Wi-Fi"
                case "BentoBox": return "Control Center"
                case "FocusModes": return "Focus"
                case "NowPlaying": return "Now Playing"
                case "ScreenMirroring": return "Screen Mirroring"
                case "UserSwitcher": return "Fast User Switching"
                case "AccessibilityShortcuts": return "Accessibility Shortcuts"
                case "KeyboardBrightness": return "Keyboard Brightness"
                default: return title.isEmpty ? appName : title
                }
            } else if bundleIdentifier == "com.apple.systemuiserver" {
                switch title {
                case "TimeMachine.TMMenuExtraHost", "TimeMachineMenuExtra.TMMenuExtraHost": 
                    return "Time Machine"
                default: 
                    return title.isEmpty ? appName : title
                }
            } else if bundleIdentifier == "com.apple.Spotlight" {
                return "Spotlight"
            } else if bundleIdentifier == "com.apple.Siri" {
                return "Siri"
            }
            
            // For regular apps, use app name
            return appName
        }
    }
    
    /// Gets all menu bar items currently visible
    @MainActor
    static func getMenuBarItems() -> [MenuBarItemInfo] {
        var items: [MenuBarItemInfo] = []
        
        // Get all windows - don't filter by on-screen only as menu bar items might be reported differently
        let windowList = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        
        // Get menu bar height
        let menuBarHeight: CGFloat = 38.0 // Actual menu bar area including some padding
        
        // Debug: print total windows found
        if ProcessInfo.processInfo.environment["PEEKABOO_DEBUG"] != nil {
            print("DEBUG: Found \(windowList.count) total windows")
        }
        
        for windowInfo in windowList {
            // Get window layer - menu bar items are typically at layer 25
            let windowLayer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            
            // Check if window is in menu bar area
            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat else {
                continue
            }
            
            let frame = CGRect(x: x, y: y, width: width, height: height)
            
            // Debug potential menu bar items
            if ProcessInfo.processInfo.environment["PEEKABOO_DEBUG"] != nil {
                let ownerName = windowInfo[kCGWindowOwnerName as String] as? String ?? "Unknown"
                let windowTitle = windowInfo[kCGWindowName as String] as? String ?? ""
                if y < 50 && height < 50 && width < 500 {
                    print("DEBUG: Potential menu bar window - Owner: \(ownerName), Title: '\(windowTitle)', Layer: \(windowLayer), Frame: \(frame)")
                }
            }
            
            // Menu bar items criteria:
            // 1. At layer 25 (standard menu bar layer)
            // 2. Y position is 0 or very close to top
            // 3. Height is around 43 pixels (modern macOS menu bar height)
            // 4. Reasonable width (not too wide, not zero)
            // 5. Not a negative X position (off-screen items)
            guard windowLayer == 25 &&
                  y >= 0 && y < 10 &&
                  height > 30 && height <= 50 &&
                  width > 0 && width < 400 &&
                  x >= 0 else {
                continue
            }
            
            // Get window details
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t else {
                continue
            }
            
            // Get app info
            let ownerName = windowInfo[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let windowTitle = windowInfo[kCGWindowName as String] as? String ?? ""
            
            // Get bundle identifier if possible
            var bundleID: String?
            if let app = NSRunningApplication(processIdentifier: ownerPID) {
                bundleID = app.bundleIdentifier
            }
            
            // Skip certain system windows that aren't menu bar items
            if bundleID == "com.apple.finder" && windowTitle.isEmpty {
                continue  // Skip Finder's desktop window
            }
            
            // Don't skip any menu bar items - they're all valid
            
            let item = MenuBarItemInfo(
                title: windowTitle,
                appName: ownerName,
                bundleIdentifier: bundleID,
                frame: frame,
                windowID: windowID,
                processID: ownerPID
            )
            
            items.append(item)
        }
        
        // Sort by X position (left to right)
        items.sort { $0.frame.minX < $1.frame.minX }
        
        // Special handling: Check if we have the main menu bar extras
        if items.isEmpty {
            // Try alternative approach using NSStatusBar if needed
            items.append(contentsOf: getSystemMenuBarItems())
        }
        
        return items
    }
    
    /// Gets system menu bar items using NSStatusBar (fallback method)
    private static func getSystemMenuBarItems() -> [MenuBarItemInfo] {
        let items: [MenuBarItemInfo] = []
        
        // This is a simplified fallback - in reality, we'd need more sophisticated detection
        // For now, we'll return an empty array and rely on the window-based detection
        
        return items
    }
    
    /// Checks if a point is within any menu bar item
    @MainActor
    static func menuBarItem(at point: CGPoint) -> MenuBarItemInfo? {
        let items = getMenuBarItems()
        return items.first { $0.frame.contains(point) }
    }
}