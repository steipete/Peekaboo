import AppKit
import Foundation

// MARK: - Window State Operations

@MainActor
public extension Element {
    /// Checks if the window is minimized
    /// - Returns: true if minimized, false if not, nil if the attribute is not available
    func isWindowMinimized() -> Bool? {
        isMinimized()
    }

    /// Checks if the window is hidden (different from minimized - this is when the app is hidden with Cmd+H)
    /// - Returns: true if hidden, false if not, nil if cannot be determined
    func isWindowHidden() -> Bool? {
        // Get the application element by walking up the parent hierarchy
        var current: Element? = self
        while let element = current {
            if element.role() == kAXApplicationRole {
                return element.attribute(Attribute<Bool>("AXHidden"))
            }
            current = element.parent()
        }

        // Alternative: If we have the PID, we can create the application element directly
        if let windowPid = self.pid() {
            if let app = Element.application(for: windowPid) {
                return app.attribute(Attribute<Bool>("AXHidden"))
            }
        }

        return nil
    }

    /// Minimizes the window
    /// - Returns: AXError indicating success or failure
    func minimizeWindow() -> AXError {
        // Try to set the minimized attribute directly
        let error = setMinimized(true)
        if error == .success {
            return .success
        }

        // Fallback: Try to press the minimize button
        if let minimizeBtn = minimizeButton() {
            do {
                _ = try minimizeBtn.performAction(.press)
                return .success
            } catch {
                return .actionUnsupported
            }
        }

        return error
    }

    /// Unminimizes the window
    /// - Returns: AXError indicating success or failure
    func unminimizeWindow() -> AXError {
        setMinimized(false)
    }

    /// Closes the window
    /// - Returns: AXError indicating success or failure
    func closeWindow() -> AXError {
        // Try to press the close button
        if let closeBtn = closeButton() {
            do {
                _ = try closeBtn.performAction(.press)
                return .success
            } catch {
                return .actionUnsupported
            }
        }

        // Fallback: Try the close action if available
        if let supportedActions = supportedActions(), supportedActions.contains("AXClose") {
            do {
                _ = try performAction("AXClose")
                return .success
            } catch {
                return .actionUnsupported
            }
        }

        return .actionUnsupported
    }

    /// Brings the window to front
    /// - Returns: AXError indicating success or failure
    func raiseWindow() -> AXError {
        do {
            _ = try performAction(.raise)
            return .success
        } catch {
            return .actionUnsupported
        }
    }
}

// MARK: - Screen Information

@MainActor
public extension Element {
    /// Gets the screen that contains this window
    /// - Returns: The NSScreen that contains the window, or nil if the window is minimized or cannot be determined
    func windowScreen() -> NSScreen? {
        // If window is minimized, it doesn't belong to any screen
        if isMinimized() == true {
            return nil
        }

        // Get window frame
        guard let windowFrame = frame() else {
            return nil
        }

        // Handle case where window might be hidden
        if isWindowHidden() == true {
            // Hidden windows maintain their position, so we can still determine the screen
            return screenContainingRect(windowFrame)
        }

        return screenContainingRect(windowFrame)
    }

    /// Gets the screen number (1-based) that contains this window
    /// - Returns: The screen number, or nil if the window is minimized or cannot be determined
    func windowScreenNumber() -> Int? {
        guard let screen = windowScreen() else {
            return nil
        }

        let screens = NSScreen.screens
        for (index, s) in screens.enumerated() {
            if s == screen {
                return index + 1 // 1-based numbering
            }
        }

        return nil
    }

    /// Determines which screen contains the largest portion of the given rect
    /// - Parameter rect: The rect to check
    /// - Returns: The screen containing the largest portion of the rect, or nil if no intersection
    private func screenContainingRect(_ rect: CGRect) -> NSScreen? {
        var bestScreen: NSScreen?
        var bestArea: CGFloat = 0

        for screen in NSScreen.screens {
            let screenFrame = screen.frame
            let intersection = screenFrame.intersection(rect)

            if !intersection.isNull {
                let area = intersection.width * intersection.height
                if area > bestArea {
                    bestArea = area
                    bestScreen = screen
                }
            }
        }

        // If no intersection found, check by window center point
        if bestScreen == nil {
            let centerPoint = CGPoint(x: rect.midX, y: rect.midY)
            for screen in NSScreen.screens {
                if screen.frame.contains(centerPoint) {
                    return screen
                }
            }
        }

        return bestScreen
    }

    /// Gets detailed screen information for the window
    /// - Returns: A dictionary containing screen information, or nil if cannot be determined
    func windowScreenInfo() -> [String: Any]? {
        guard let screen = windowScreen() else {
            // Check if minimized or hidden
            let isMin = isMinimized() ?? false
            let isHid = isWindowHidden() ?? false

            return [
                "screenNumber": NSNull(),
                "isMinimized": isMin,
                "isHidden": isHid,
                "hasScreen": false,
            ]
        }

        let screenNumber = windowScreenNumber() ?? 0
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        return [
            "screenNumber": screenNumber,
            "screenFrame": NSStringFromRect(screenFrame),
            "visibleFrame": NSStringFromRect(visibleFrame),
            "backingScaleFactor": screen.backingScaleFactor,
            "isMinimized": isMinimized() ?? false,
            "isHidden": isWindowHidden() ?? false,
            "hasScreen": true,
            "deviceDescription": screen.deviceDescription,
        ]
    }
}

// MARK: - Window Visibility

@MainActor
public extension Element {
    /// Checks if the window is visible (not minimized, not hidden, and on screen)
    /// - Returns: true if visible, false otherwise, nil if cannot be determined
    func isWindowVisible() -> Bool? {
        // Check if minimized
        if let minimized = isMinimized(), minimized {
            return false
        }

        // Check if hidden
        if let hidden = isWindowHidden(), hidden {
            return false
        }

        // Check if it has a valid frame on a screen
        if let _ = windowScreen() {
            return true
        }

        return nil
    }

    /// Shows a hidden window (unhides the application if needed)
    /// - Returns: AXError indicating success or failure
    func showWindow() -> AXError {
        // First unminimize if needed
        if isMinimized() == true {
            let error = unminimizeWindow()
            if error != AXError.success {
                return error
            }
        }

        // Then unhide the app if needed
        // Get the application element by walking up the parent hierarchy or using PID
        var appElement: Element? = nil

        // Try parent hierarchy first
        var current: Element? = self
        while let element = current {
            if element.role() == kAXApplicationRole {
                appElement = element
                break
            }
            current = element.parent()
        }

        // If not found, try using PID
        if appElement == nil, let windowPid = self.pid() {
            appElement = Element.application(for: windowPid)
        }

        if let app = appElement, app.attribute(Attribute<Bool>("AXHidden")) == true {
            let error = AXUIElementSetAttributeValue(app.underlyingElement, "AXHidden" as CFString, false as CFBoolean)
            if error != AXError.success {
                return error
            }
        }

        // Finally raise the window
        return raiseWindow()
    }
}
