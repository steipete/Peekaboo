import Foundation

#if os(Linux)

/// Linux-specific implementation of permission checking
class LinuxPermissionChecker: PermissionCheckerProtocol {
    
    func hasScreenCapturePermission() -> Bool {
        // On Linux, screen capture permissions depend on the display server and user session
        return canAccessDisplay() && hasDisplayServerAccess()
    }
    
    func canRequestPermission() -> Bool {
        // Linux permission model varies by desktop environment
        // Some environments support permission requests, others don't
        return detectDesktopEnvironment() != .unknown
    }
    
    func requestScreenCapturePermission() throws {
        // Check if we already have permission
        if hasScreenCapturePermission() {
            return
        }
        
        // Try to request permission based on the desktop environment
        let desktop = detectDesktopEnvironment()
        
        switch desktop {
        case .gnome, .kde, .xfce:
            // These environments might support permission dialogs
            try requestPermissionThroughDesktopEnvironment(desktop)
        case .wayland:
            // Wayland has its own permission model
            try requestWaylandPermission()
        case .x11:
            // X11 typically doesn't require explicit permissions
            guard canAccessDisplay() else {
                throw ScreenCaptureError.permissionDenied
            }
        case .unknown:
            // For unknown environments, just check basic access
            guard canAccessDisplay() else {
                throw ScreenCaptureError.permissionDenied
            }
        }
    }
    
    func requireScreenCapturePermission() throws {
        guard hasScreenCapturePermission() else {
            throw ScreenCaptureError.permissionDenied
        }
    }
    
    func hasAccessibilityPermission() -> Bool {
        // Linux accessibility permissions are typically handled through AT-SPI
        return canAccessATSPI()
    }
    
    func canRequestAccessibilityPermission() -> Bool {
        return true
    }
    
    func requestAccessibilityPermission() throws {
        guard canAccessATSPI() else {
            throw ScreenCaptureError.permissionDenied
        }
    }
    
    func requireAccessibilityPermission() throws {
        guard hasAccessibilityPermission() else {
            throw ScreenCaptureError.permissionDenied
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func canAccessDisplay() -> Bool {
        // Check if we can access the display server
        if let display = ProcessInfo.processInfo.environment["DISPLAY"] {
            // X11 display
            return !display.isEmpty && canConnectToX11()
        } else if let waylandDisplay = ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] {
            // Wayland display
            return !waylandDisplay.isEmpty && canConnectToWayland()
        }
        return false
    }
    
    private func hasDisplayServerAccess() -> Bool {
        let desktop = detectDesktopEnvironment()
        
        switch desktop {
        case .wayland:
            return hasWaylandScreenCaptureAccess()
        case .x11:
            return hasX11ScreenCaptureAccess()
        default:
            // For other environments, assume access if we can connect to display
            return canAccessDisplay()
        }
    }
    
    private func canConnectToX11() -> Bool {
        // Try to connect to X11 display
        // This is a simplified check - in practice, you'd use Xlib
        guard let display = ProcessInfo.processInfo.environment["DISPLAY"] else {
            return false
        }
        
        // Basic format check for DISPLAY variable
        return display.contains(":") && !display.isEmpty
    }
    
    private func canConnectToWayland() -> Bool {
        // Try to connect to Wayland display
        guard let waylandDisplay = ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] else {
            return false
        }
        
        // Check if the Wayland socket exists
        let socketPath = "/run/user/\(getuid())/\(waylandDisplay)"
        return FileManager.default.fileExists(atPath: socketPath)
    }
    
    private func hasX11ScreenCaptureAccess() -> Bool {
        // For X11, check if we can access the root window
        // This would typically use Xlib functions
        return canConnectToX11()
    }
    
    private func hasWaylandScreenCaptureAccess() -> Bool {
        // For Wayland, screen capture requires specific protocols
        // Check if we have access to screen capture protocols
        return canConnectToWayland() && hasWaylandScreenCaptureProtocol()
    }
    
    private func hasWaylandScreenCaptureProtocol() -> Bool {
        // Check if the Wayland compositor supports screen capture protocols
        // This would typically check for wlr-screencopy or similar protocols
        return true // Simplified for now
    }
    
    private func canAccessATSPI() -> Bool {
        // Check if we can access AT-SPI (Assistive Technology Service Provider Interface)
        let atspiBusAddress = ProcessInfo.processInfo.environment["AT_SPI_BUS_ADDRESS"]
        return atspiBusAddress != nil || canAccessDBus()
    }
    
    private func canAccessDBus() -> Bool {
        // Check if we can access D-Bus for AT-SPI communication
        let sessionBusAddress = ProcessInfo.processInfo.environment["DBUS_SESSION_BUS_ADDRESS"]
        return sessionBusAddress != nil
    }
    
    private func detectDesktopEnvironment() -> DesktopEnvironment {
        // Check environment variables to detect desktop environment
        if let xdgCurrentDesktop = ProcessInfo.processInfo.environment["XDG_CURRENT_DESKTOP"] {
            let desktop = xdgCurrentDesktop.lowercased()
            if desktop.contains("gnome") {
                return .gnome
            } else if desktop.contains("kde") {
                return .kde
            } else if desktop.contains("xfce") {
                return .xfce
            }
        }
        
        if let desktopSession = ProcessInfo.processInfo.environment["DESKTOP_SESSION"] {
            let session = desktopSession.lowercased()
            if session.contains("gnome") {
                return .gnome
            } else if session.contains("kde") {
                return .kde
            } else if session.contains("xfce") {
                return .xfce
            }
        }
        
        // Check display server
        if ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] != nil {
            return .wayland
        } else if ProcessInfo.processInfo.environment["DISPLAY"] != nil {
            return .x11
        }
        
        return .unknown
    }
    
    private func requestPermissionThroughDesktopEnvironment(_ desktop: DesktopEnvironment) throws {
        // This would typically use desktop-specific APIs or D-Bus calls
        // For now, just check if we have basic access
        guard canAccessDisplay() else {
            throw ScreenCaptureError.permissionDenied
        }
    }
    
    private func requestWaylandPermission() throws {
        // Wayland permission requests would typically go through the compositor
        // or use portals (xdg-desktop-portal)
        guard hasWaylandScreenCaptureAccess() else {
            throw ScreenCaptureError.permissionDenied
        }
    }
    
    private func checkPortalAccess() -> Bool {
        // Check if we can access xdg-desktop-portal for screen capture
        // This would typically involve D-Bus communication
        return canAccessDBus()
    }
}

// MARK: - Supporting Types

enum DesktopEnvironment {
    case gnome
    case kde
    case xfce
    case wayland
    case x11
    case unknown
}

// MARK: - Linux System Integration

extension LinuxPermissionChecker {
    
    /// Check if the current user has the necessary group memberships for screen capture
    func hasRequiredGroupMemberships() -> Bool {
        // Check for common groups that might be required for screen capture
        let requiredGroups = ["video", "render", "input"]
        
        for group in requiredGroups {
            if isMemberOfGroup(group) {
                return true
            }
        }
        
        return false
    }
    
    private func isMemberOfGroup(_ groupName: String) -> Bool {
        // Check if the current user is a member of the specified group
        // This would typically use getgrnam() and getgroups() system calls
        
        // For now, return true as a simplified implementation
        // In practice, you'd check the actual group membership
        return true
    }
    
    /// Check if running in a sandboxed environment (like Flatpak or Snap)
    func isRunningInSandbox() -> Bool {
        // Check for common sandbox indicators
        let sandboxIndicators = [
            "FLATPAK_ID",
            "SNAP",
            "SNAP_NAME",
            "APPIMAGE"
        ]
        
        for indicator in sandboxIndicators {
            if ProcessInfo.processInfo.environment[indicator] != nil {
                return true
            }
        }
        
        return false
    }
    
    /// Get the current session type (X11, Wayland, etc.)
    func getSessionType() -> String {
        if let sessionType = ProcessInfo.processInfo.environment["XDG_SESSION_TYPE"] {
            return sessionType
        } else if ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] != nil {
            return "wayland"
        } else if ProcessInfo.processInfo.environment["DISPLAY"] != nil {
            return "x11"
        } else {
            return "unknown"
        }
    }
}

#endif

