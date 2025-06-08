#if os(Linux)
import Foundation

/// Linux-specific implementation of permissions management
class LinuxPermissions: PermissionsProtocol {
    
    private let displayServer: LinuxDisplayServer
    
    init() {
        // Detect display server
        if ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] != nil {
            self.displayServer = .wayland
        } else if ProcessInfo.processInfo.environment["DISPLAY"] != nil {
            self.displayServer = .x11
        } else {
            self.displayServer = .unknown
        }
    }
    
    func checkScreenCapturePermission() -> Bool {
        switch displayServer {
        case .x11:
            return checkScreenCapturePermissionX11()
        case .wayland:
            return checkScreenCapturePermissionWayland()
        case .unknown:
            return false
        }
    }
    
    func checkWindowAccessPermission() -> Bool {
        switch displayServer {
        case .x11:
            return checkWindowAccessPermissionX11()
        case .wayland:
            return checkWindowAccessPermissionWayland()
        case .unknown:
            return false
        }
    }
    
    func checkApplicationManagementPermission() -> Bool {
        // Check if we can read /proc filesystem
        return FileManager.default.isReadableFile(atPath: "/proc")
    }
    
    func requestScreenCapturePermission() async -> Bool {
        switch displayServer {
        case .wayland:
            return await requestWaylandPortalPermission()
        default:
            return checkScreenCapturePermission()
        }
    }
    
    func requestWindowAccessPermission() async -> Bool {
        return checkWindowAccessPermission()
    }
    
    func requestApplicationManagementPermission() async -> Bool {
        return checkApplicationManagementPermission()
    }
    
    func getAllPermissionStatuses() -> [PermissionType: PermissionStatus] {
        var statuses: [PermissionType: PermissionStatus] = [:]
        
        statuses[.screenCapture] = checkScreenCapturePermission() ? .granted : .denied
        statuses[.windowAccess] = checkWindowAccessPermission() ? .granted : .denied
        statuses[.applicationManagement] = checkApplicationManagementPermission() ? .granted : .denied
        
        // Linux-specific permissions
        statuses[.accessibility] = .notRequired
        statuses[.systemEvents] = .notRequired
        
        return statuses
    }
    
    func requiresExplicitPermissions() -> Bool {
        return displayServer == .wayland
    }
    
    func getPermissionInstructions() -> [PermissionInstruction] {
        var instructions: [PermissionInstruction] = []
        
        switch displayServer {
        case .x11:
            instructions.append(PermissionInstruction(
                step: 1,
                title: "X11 Display Access",
                description: "Ensure you have access to the X11 display. You may need to run 'xhost +local:' if running as a different user.",
                isAutomated: false,
                platformSpecific: true
            ))
            
            if !hasRequiredX11Tools() {
                instructions.append(PermissionInstruction(
                    step: 2,
                    title: "Install Required Tools",
                    description: "Install required X11 tools: sudo apt-get install imagemagick x11-utils wmctrl (Ubuntu/Debian) or equivalent for your distribution.",
                    isAutomated: false,
                    platformSpecific: true
                ))
            }
            
        case .wayland:
            instructions.append(PermissionInstruction(
                step: 1,
                title: "Wayland Portal Permission",
                description: "Screen capture on Wayland requires permission through the desktop portal. You'll be prompted when first attempting to capture.",
                isAutomated: true,
                platformSpecific: true
            ))
            
            if !hasRequiredWaylandTools() {
                instructions.append(PermissionInstruction(
                    step: 2,
                    title: "Install Required Tools",
                    description: "Install required Wayland tools: sudo apt-get install grim slurp (for wlroots-based compositors) or equivalent for your compositor.",
                    isAutomated: false,
                    platformSpecific: true
                ))
            }
            
        case .unknown:
            instructions.append(PermissionInstruction(
                step: 1,
                title: "Display Server Not Detected",
                description: "Could not detect X11 or Wayland display server. Ensure DISPLAY or WAYLAND_DISPLAY environment variables are set.",
                isAutomated: false,
                platformSpecific: true
            ))
        }
        
        return instructions
    }
    
    func requireScreenCapturePermission() throws {
        if !checkScreenCapturePermission() {
            throw PermissionError.screenRecordingPermissionDenied
        }
    }
    
    func requireWindowAccessPermission() throws {
        if !checkWindowAccessPermission() {
            throw PermissionError.windowAccessPermissionDenied
        }
    }
    
    func requireApplicationManagementPermission() throws {
        if !checkApplicationManagementPermission() {
            throw PermissionError.applicationManagementPermissionDenied
        }
    }
    
    // MARK: - X11 Permission Checks
    
    private func checkScreenCapturePermissionX11() -> Bool {
        // Check if we can access the X11 display
        guard ProcessInfo.processInfo.environment["DISPLAY"] != nil else {
            return false
        }
        
        // Try a simple X11 operation
        let result = try? runCommandSync(["xdpyinfo"])
        return result?.exitCode == 0
    }
    
    private func checkWindowAccessPermissionX11() -> Bool {
        // Check if we can list windows
        let result = try? runCommandSync(["xwininfo", "-root", "-tree"])
        return result?.exitCode == 0
    }
    
    private func hasRequiredX11Tools() -> Bool {
        let requiredTools = ["import", "xwininfo", "wmctrl", "xprop"]
        
        for tool in requiredTools {
            let result = try? runCommandSync(["which", tool])
            if result?.exitCode != 0 {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Wayland Permission Checks
    
    private func checkScreenCapturePermissionWayland() -> Bool {
        // Check if we have access to Wayland display
        guard ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] != nil else {
            return false
        }
        
        // Check if we can use portal or compositor-specific tools
        return hasRequiredWaylandTools()
    }
    
    private func checkWindowAccessPermissionWayland() -> Bool {
        // Wayland window access is more limited
        // Check if we have compositor-specific tools
        return hasWaylandCompositorTools()
    }
    
    private func hasRequiredWaylandTools() -> Bool {
        // Check for grim (wlroots-based compositors)
        if let result = try? runCommandSync(["which", "grim"]), result.exitCode == 0 {
            return true
        }
        
        // Check for GNOME screenshot tool
        if let result = try? runCommandSync(["which", "gnome-screenshot"]), result.exitCode == 0 {
            return true
        }
        
        // Check for KDE spectacle
        if let result = try? runCommandSync(["which", "spectacle"]), result.exitCode == 0 {
            return true
        }
        
        return false
    }
    
    private func hasWaylandCompositorTools() -> Bool {
        // Check for Sway
        if let result = try? runCommandSync(["which", "swaymsg"]), result.exitCode == 0 {
            return true
        }
        
        // Check for other compositor tools
        // This could be extended for other compositors
        
        return false
    }
    
    private func requestWaylandPortalPermission() async -> Bool {
        // Try to trigger a portal permission request
        // This is a simplified implementation
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                // Try a test screenshot to trigger permission dialog
                let result = try? self.runCommandSync(["grim", "/tmp/peekaboo_permission_test.png"])
                let success = result?.exitCode == 0
                
                // Clean up test file
                try? FileManager.default.removeItem(atPath: "/tmp/peekaboo_permission_test.png")
                
                continuation.resume(returning: success)
            }
        }
    }
    
    // MARK: - Desktop Environment Detection
    
    private func getDesktopEnvironment() -> LinuxDesktopEnvironment {
        if let de = ProcessInfo.processInfo.environment["XDG_CURRENT_DESKTOP"] {
            switch de.lowercased() {
            case "gnome":
                return .gnome
            case "kde":
                return .kde
            case "xfce":
                return .xfce
            case "sway":
                return .sway
            default:
                return .unknown
            }
        }
        
        // Fallback detection
        if ProcessInfo.processInfo.environment["GNOME_DESKTOP_SESSION_ID"] != nil {
            return .gnome
        } else if ProcessInfo.processInfo.environment["KDE_FULL_SESSION"] != nil {
            return .kde
        }
        
        return .unknown
    }
    
    private func isRunningInFlatpak() -> Bool {
        return FileManager.default.fileExists(atPath: "/.flatpak-info")
    }
    
    private func isRunningInSnap() -> Bool {
        return ProcessInfo.processInfo.environment["SNAP"] != nil
    }
    
    private func isRunningInAppImage() -> Bool {
        return ProcessInfo.processInfo.environment["APPIMAGE"] != nil
    }
    
    // MARK: - Helper Methods
    
    private func runCommandSync(_ arguments: [String]) throws -> CommandResult {
        guard !arguments.isEmpty else {
            throw PermissionError.systemError(NSError(
                domain: "LinuxPermissions",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid command arguments"]
            ))
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        try process.run()
        process.waitUntilExit()
        
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        
        return CommandResult(
            exitCode: Int(process.terminationStatus),
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }
}

// MARK: - Supporting Types

private enum LinuxDisplayServer {
    case x11
    case wayland
    case unknown
}

private enum LinuxDesktopEnvironment {
    case gnome
    case kde
    case xfce
    case sway
    case unknown
}

private struct CommandResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}
#endif

