import AppKit
import ApplicationServices

/// Window-specific accessibility operations
public extension Element {
    
    // MARK: - Window Identification
    
    /// Whether this element is a window
    @MainActor var isWindow: Bool {
        role() == kAXWindowRole
    }
    
    /// Whether this element is the application element
    @MainActor var isApplication: Bool {
        role() == kAXApplicationRole
    }
    
    // MARK: - Window State
    
    /// Whether the window is minimized
    @MainActor func isWindowMinimized() -> Bool {
        guard isWindow else { return false }
        return isMinimized() ?? false
    }
    
    /// Whether the window is hidden (its app is hidden)
    @MainActor func isWindowHidden() -> Bool {
        guard isWindow else { return false }
        
        // Check if the window's app is hidden by getting the PID and checking the running app
        if let pid = pid(),
           let app = NSRunningApplication(processIdentifier: pid) {
            return app.isHidden
        }
        
        return false
    }
    
    /// Whether the window is visible on any screen
    @MainActor func isWindowVisible() -> Bool {
        guard isWindow else { return false }
        
        // Can't be visible if minimized or hidden
        if isWindowMinimized() || isWindowHidden() {
            return false
        }
        
        // Check if window is on any screen
        return isOnAnyScreen()
    }
    
    // MARK: - Window Actions
    
    /// Minimize a window using the most appropriate method
    @MainActor func minimizeWindow() -> Bool {
        guard isWindow else { return false }
        
        // First try using the minimize button
        if let minimizeButton = minimizeButton() {
            do {
                try minimizeButton.performAction(.press)
                return true
            } catch {
                axDebugLog("Failed to press minimize button: \(error)")
            }
        }
        
        // Fall back to setting minimized attribute
        let error = setMinimized(true)
        if error == .success {
            return true
        }
        
        axWarningLog("Failed to minimize window")
        return false
    }
    
    /// Unminimize a window
    @MainActor func unminimizeWindow() -> Bool {
        guard isWindow else { return false }
        
        let error = setMinimized(false)
        if error == .success {
            return true
        }
        
        axWarningLog("Failed to unminimize window")
        return false
    }
    
    /// Maximize a window using the most appropriate method
    @MainActor func maximizeWindow() -> Bool {
        guard isWindow else { return false }
        
        // First try using the zoom button (green button)
        if let zoomButton = zoomButton() {
            do {
                try zoomButton.performAction(.press)
                return true
            } catch {
                axDebugLog("Failed to press zoom button: \(error)")
            }
        }
        
        // Try full screen button if available
        if let fullScreenButton = fullScreenButton() {
            do {
                try fullScreenButton.performAction(.press)
                return true
            } catch {
                axDebugLog("Failed to press full screen button: \(error)")
            }
        }
        
        // Try setting full screen attribute
        let error = setFullScreen(true)
        if error == .success {
            return true
        }
        
        // As a last resort, try to manually set window to screen size
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            setFrame(screenFrame)
            return true
        }
        
        axWarningLog("Failed to maximize window")
        return false
    }
    
    /// Close a window using the most appropriate method
    @MainActor func closeWindow() -> Bool {
        guard isWindow else { return false }
        
        // First try using the close button
        if let closeButton = closeButton() {
            do {
                try closeButton.performAction(.press)
                return true
            } catch {
                axDebugLog("Failed to press close button: \(error)")
            }
        }
        
        // Try the close action
        do {
            try performAction("AXClose")
            return true
        } catch {
            axDebugLog("Failed to perform close action: \(error)")
        }
        
        axWarningLog("Failed to close window")
        return false
    }
    
    /// Raise window to front
    @MainActor func raiseWindow() -> Bool {
        guard isWindow else { return false }
        
        do {
            try performAction(.raise)
            return true
        } catch {
            axWarningLog("Failed to raise window: \(error)")
            return false
        }
    }
    
    /// Show a window (unminimize, unhide app, and raise)
    @MainActor func showWindow() -> Bool {
        guard isWindow else { return false }
        
        // Unminimize if needed
        if isWindowMinimized() {
            _ = unminimizeWindow()
        }
        
        // Unhide app if needed
        if let pid = pid(), 
           let app = NSRunningApplication(processIdentifier: pid),
           app.isHidden {
            app.unhide()
        }
        
        // Raise to front
        return raiseWindow()
    }
    
    /// Focus a window (activate app and raise window)
    @MainActor func focusWindow() -> Bool {
        guard isWindow else { return false }
        
        // First activate the application
        if let pid = pid() {
            let axApp = AXUIElementCreateApplication(pid)
            let appElement = Element(axApp)
            _ = appElement.activateApplication()
        }
        
        // Then raise the window
        return raiseWindow()
    }
    
    // MARK: - Window Geometry
    
    /// Move window to a new position
    @MainActor func moveWindow(to position: CGPoint) -> Bool {
        guard isWindow else { return false }
        return setPosition(position) == .success
    }
    
    /// Resize window to a new size
    @MainActor func resizeWindow(to size: CGSize) -> Bool {
        guard isWindow else { return false }
        return setSize(size) == .success
    }
    
    /// Set window bounds (position and size)
    @MainActor func setWindowBounds(_ bounds: CGRect) -> Bool {
        guard isWindow else { return false }
        setFrame(bounds)
        return true
    }
    
    // MARK: - Screen Detection
    
    /// Get the screen containing the window
    @MainActor func windowScreen() -> NSScreen? {
        guard isWindow, let frame = frame() else { return nil }
        
        // Find screen containing window center
        let center = CGPoint(x: frame.midX, y: frame.midY)
        
        for screen in NSScreen.screens {
            if screen.frame.contains(center) {
                return screen
            }
        }
        
        // Fall back to screen containing any part of window
        for screen in NSScreen.screens {
            if screen.frame.intersects(frame) {
                return screen
            }
        }
        
        return nil
    }
    
    /// Whether the window is on any screen
    @MainActor func isOnAnyScreen() -> Bool {
        guard isWindow, let frame = frame() else { return false }
        
        return NSScreen.screens.contains { screen in
            screen.frame.intersects(frame)
        }
    }
    
    /// Whether the window is fully on screen
    @MainActor func isFullyOnScreen() -> Bool {
        guard isWindow, let frame = frame() else { return false }
        
        return NSScreen.screens.contains { screen in
            screen.frame.contains(frame)
        }
    }
    
    // MARK: - Application Actions
    
    /// Activate the application (bring to front)
    @MainActor func activateApplication() -> Bool {
        guard isApplication else { return false }
        
        // Get the application's process ID
        guard let pid = pid() else { return false }
        
        // Use NSRunningApplication to activate
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return false
        }
        
        return app.activate(options: [.activateIgnoringOtherApps])
    }
}

// MARK: - Convenience Functions

public extension Element {
    /// Find all windows for this application
    @MainActor func applicationWindows() -> [Element]? {
        guard isApplication else { return nil }
        return windows()
    }
    
    /// Find the main/key window for this application
    @MainActor func applicationMainWindow() -> Element? {
        guard let windows = applicationWindows() else { return nil }
        return windows.first { $0.isMain() ?? false }
    }
    
    /// Find the focused window for this application
    @MainActor func applicationFocusedWindow() -> Element? {
        guard isApplication else { return nil }
        return focusedWindow()
    }
}