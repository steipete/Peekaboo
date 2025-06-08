#if os(Linux)
import Foundation
import SystemPackage

/// Linux implementation of permissions checking
struct LinuxPermissions: PermissionsProtocol {
    
    private let isWayland: Bool
    
    init() {
        // Detect if we're running under Wayland
        self.isWayland = ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] != nil ||
                        ProcessInfo.processInfo.environment["XDG_SESSION_TYPE"] == "wayland"
    }
    
    func hasScreenRecordingPermission() async -> Bool {
        if isWayland {
            return await hasWaylandScreenRecordingPermission()
        } else {
            return await hasX11ScreenRecordingPermission()
        }
    }
    
    func requestScreenRecordingPermission() async -> Bool {
        // On Linux, permissions are typically handled by the desktop environment
        // We can't programmatically request permissions, but we can check if they're available
        return await hasScreenRecordingPermission()
    }
    
    func hasAccessibilityPermission() async -> Bool {
        if isWayland {
            return await hasWaylandAccessibilityPermission()
        } else {
            return await hasX11AccessibilityPermission()
        }
    }
    
    func requestAccessibilityPermission() async -> Bool {
        // Similar to screen recording, we can't programmatically request permissions
        return await hasAccessibilityPermission()
    }
    
    func getPermissionInstructions() -> String {
        if isWayland {
            return getWaylandInstructions()
        } else {
            return getX11Instructions()
        }
    }
    
    static func isSupported() -> Bool {
        return true // Linux always supports permission checking
    }
    
    // MARK: - X11 Permission Checking
    
    private func hasX11ScreenRecordingPermission() async -> Bool {
        // Check if we can access the X11 display
        guard ProcessInfo.processInfo.environment["DISPLAY"] != nil else {
            return false
        }
        
        // Test if we can capture a screenshot using import or scrot
        if commandExists("import") {
            return testImageMagickCapture()
        } else if commandExists("scrot") {
            return testScrotCapture()
        }
        
        return false
    }
    
    private func hasX11AccessibilityPermission() async -> Bool {
        // Check if we can enumerate windows using wmctrl or xwininfo
        if commandExists("wmctrl") {
            return testWmctrlAccess()
        } else if commandExists("xwininfo") {
            return testXwininfoAccess()
        }
        
        return false
    }
    
    private func testImageMagickCapture() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["import", "-window", "root", "-resize", "1x1", "/dev/null"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    private func testScrotCapture() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["scrot", "--silent", "/dev/null"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    private func testWmctrlAccess() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["wmctrl", "-l"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    private func testXwininfoAccess() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["xwininfo", "-root", "-tree"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    // MARK: - Wayland Permission Checking
    
    private func hasWaylandScreenRecordingPermission() async -> Bool {
        // Check if we have access to screen capture tools
        if commandExists("grim") {
            return testGrimCapture()
        } else if commandExists("gnome-screenshot") {
            return testGnomeScreenshotCapture()
        }
        
        return false
    }
    
    private func hasWaylandAccessibilityPermission() async -> Bool {
        // Check if we can access window information
        if commandExists("swaymsg") {
            return testSwaymsgAccess()
        }
        
        // For other Wayland compositors, this might be more limited
        return false
    }
    
    private func testGrimCapture() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["grim", "-g", "1,1 1x1", "/dev/null"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    private func testGnomeScreenshotCapture() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gnome-screenshot", "--file=/dev/null"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    private func testSwaymsgAccess() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swaymsg", "-t", "get_outputs"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    // MARK: - Instructions
    
    private func getX11Instructions() -> String {
        return \"\"\"
        To use Peekaboo on X11 Linux, you need the following tools installed:
        
        For screen capture:
        - ImageMagick (import command): sudo apt install imagemagick
        - OR scrot: sudo apt install scrot
        
        For window management:
        - wmctrl: sudo apt install wmctrl
        - OR xwininfo (usually pre-installed with X11)
        
        Make sure your DISPLAY environment variable is set correctly.
        
        If you're using a display manager or desktop environment with additional
        security restrictions, you may need to adjust your settings.
        \"\"\"
    }
    
    private func getWaylandInstructions() -> String {
        return \"\"\"
        To use Peekaboo on Wayland Linux, you need the following tools installed:
        
        For screen capture:
        - grim: sudo apt install grim (for wlroots-based compositors like Sway)
        - OR gnome-screenshot: sudo apt install gnome-screenshot (for GNOME)
        
        For window management:
        - swaymsg (for Sway): usually included with Sway
        
        Note: Wayland has stricter security policies. Some desktop environments
        may require additional permissions or may not support all features.
        
        For GNOME Wayland, you may need to use the built-in screenshot portal
        or grant additional permissions through your desktop environment settings.
        \"\"\"
    }
    
    // MARK: - Helper Methods
    
    private func commandExists(_ command: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

#endif

