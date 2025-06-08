#if os(Linux)
import Foundation

/// Linux-specific implementation of application discovery and management
class LinuxApplicationFinder: ApplicationFinderProtocol {
    
    func findApplication(identifier: String) throws -> RunningApplication {
        let runningApps = getRunningApplications(includeBackground: true)
        
        // Try to find by PID first
        if let pid = pid_t(identifier) {
            if let app = runningApps.first(where: { $0.processIdentifier == pid }) {
                return app
            }
        }
        
        // Try exact matches first
        var matches = runningApps.filter { app in
            return app.localizedName?.lowercased() == identifier.lowercased() ||
                   app.executablePath?.lastPathComponent.lowercased() == identifier.lowercased()
        }
        
        // If no exact matches, try fuzzy matching
        if matches.isEmpty {
            matches = runningApps.filter { app in
                return app.localizedName?.localizedCaseInsensitiveContains(identifier) == true ||
                       app.executablePath?.lastPathComponent.localizedCaseInsensitiveContains(identifier) == true
            }
        }
        
        if matches.isEmpty {
            throw ApplicationError.notFound(identifier)
        } else if matches.count > 1 {
            throw ApplicationError.ambiguous(identifier, matches)
        }
        
        return matches[0]
    }
    
    func getRunningApplications(includeBackground: Bool = false) -> [RunningApplication] {
        var applications: [RunningApplication] = []
        
        // Read from /proc filesystem
        guard let procContents = try? FileManager.default.contentsOfDirectory(atPath: "/proc") else {
            return applications
        }
        
        for item in procContents {
            guard let pid = pid_t(item) else { continue }
            
            if let appInfo = getProcessInfo(pid: pid, includeBackground: includeBackground) {
                applications.append(appInfo)
            }
        }
        
        return applications
    }
    
    func activateApplication(pid: pid_t) throws {
        // Try to find and activate the main window for the process
        let windowManager = LinuxWindowManager()
        let windows = try windowManager.getWindowsForApp(pid: pid, includeOffScreen: false)
        
        guard let mainWindow = windows.first else {
            throw ApplicationError.activationFailed(pid)
        }
        
        // Try different activation methods based on display server
        if ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] != nil {
            try activateWindowWayland(windowId: mainWindow.windowId)
        } else if ProcessInfo.processInfo.environment["DISPLAY"] != nil {
            try activateWindowX11(windowId: mainWindow.windowId)
        } else {
            throw ApplicationError.activationFailed(pid)
        }
    }
    
    func isApplicationRunning(identifier: String) -> Bool {
        do {
            _ = try findApplication(identifier: identifier)
            return true
        } catch {
            return false
        }
    }
    
    func getApplicationInfo(pid: pid_t) throws -> ApplicationInfo {
        guard let basicInfo = getProcessInfo(pid: pid, includeBackground: true) else {
            throw ApplicationError.notFound("PID \(pid)")
        }
        
        // Get additional detailed information
        let memoryUsage = getProcessMemoryUsage(pid: pid)
        let cpuUsage = getProcessCPUUsage(pid: pid)
        let windowCount = getWindowCount(pid: pid)
        let version = getProcessVersion(executablePath: basicInfo.executablePath)
        
        return ApplicationInfo(
            processIdentifier: pid,
            bundleIdentifier: nil, // Linux doesn't have bundle identifiers like macOS
            localizedName: basicInfo.localizedName,
            executablePath: basicInfo.executablePath,
            bundlePath: basicInfo.executablePath?.deletingLastPathComponent,
            version: version,
            isActive: basicInfo.isActive,
            activationPolicy: basicInfo.activationPolicy,
            launchDate: basicInfo.launchDate,
            memoryUsage: memoryUsage,
            cpuUsage: cpuUsage,
            windowCount: windowCount,
            icon: basicInfo.icon,
            architecture: getProcessArchitecture(pid: pid)
        )
    }
    
    func isApplicationManagementSupported() -> Bool {
        return true
    }
    
    func refreshApplicationCache() throws {
        // Linux process list is always fresh from /proc, no caching needed
    }
    
    // MARK: - Private Helper Methods
    
    private func getProcessInfo(pid: pid_t, includeBackground: Bool) -> RunningApplication? {
        let procPath = "/proc/\(pid)"
        
        // Check if process directory exists
        guard FileManager.default.fileExists(atPath: procPath) else {
            return nil
        }
        
        // Get command line
        let cmdlinePath = "\(procPath)/cmdline"
        var executablePath: String? = nil
        var processName: String? = nil
        
        if let cmdlineData = try? Data(contentsOf: URL(fileURLWithPath: cmdlinePath)) {
            let cmdline = String(data: cmdlineData, encoding: .utf8)?.replacingOccurrences(of: "\0", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if let cmdline = cmdline, !cmdline.isEmpty {
                let components = cmdline.components(separatedBy: " ")
                executablePath = components.first
                processName = executablePath?.lastPathComponent
            }
        }
        
        // Fallback to comm file for process name
        if processName == nil {
            let commPath = "\(procPath)/comm"
            if let commData = try? Data(contentsOf: URL(fileURLWithPath: commPath)) {
                processName = String(data: commData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Skip kernel threads (usually in brackets)
        if let name = processName, name.hasPrefix("[") && name.hasSuffix("]") {
            return nil
        }
        
        // Determine if this is a background process
        let hasWindows = getWindowCount(pid: pid) > 0
        let activationPolicy: ApplicationActivationPolicy = hasWindows ? .regular : .prohibited
        
        if !includeBackground && activationPolicy != .regular {
            return nil
        }
        
        // Check if process is active (simplified check)
        let isActive = isProcessActive(pid: pid)
        
        // Get process start time
        let launchDate = getProcessStartTime(pid: pid)
        
        // Get process icon (basic implementation)
        let icon = getProcessIcon(executablePath: executablePath)
        
        return RunningApplication(
            processIdentifier: pid,
            bundleIdentifier: nil,
            localizedName: processName,
            executablePath: executablePath,
            isActive: isActive,
            activationPolicy: activationPolicy,
            launchDate: launchDate,
            icon: icon
        )
    }
    
    private func getWindowCount(pid: pid_t) -> Int {
        do {
            let windowManager = LinuxWindowManager()
            let windows = try windowManager.getWindowsForApp(pid: pid, includeOffScreen: false)
            return windows.count
        } catch {
            return 0
        }
    }
    
    private func isProcessActive(pid: pid_t) -> Bool {
        // Check if any window of this process is focused
        // This is a simplified implementation
        do {
            let windowManager = LinuxWindowManager()
            let windows = try windowManager.getWindowsForApp(pid: pid, includeOffScreen: false)
            
            // For X11, we could check _NET_ACTIVE_WINDOW
            if ProcessInfo.processInfo.environment["DISPLAY"] != nil {
                return try isProcessActiveX11(pid: pid, windows: windows)
            }
            
            // For Wayland, this is more complex
            return false
        } catch {
            return false
        }
    }
    
    private func isProcessActiveX11(pid: pid_t, windows: [WindowData]) -> Bool {
        // Get the active window
        let result = try? runCommandSync(["xprop", "-root", "_NET_ACTIVE_WINDOW"])
        
        guard let output = result?.stdout,
              result?.exitCode == 0 else {
            return false
        }
        
        // Parse output like "_NET_ACTIVE_WINDOW(WINDOW): window id # 0x1400001"
        let components = output.components(separatedBy: " ")
        for component in components {
            if component.hasPrefix("0x"), let activeWindowId = UInt32(String(component.dropFirst(2)), radix: 16) {
                return windows.contains { $0.windowId == activeWindowId }
            }
        }
        
        return false
    }
    
    private func getProcessStartTime(pid: pid_t) -> Date? {
        let statPath = "/proc/\(pid)/stat"
        
        guard let statData = try? Data(contentsOf: URL(fileURLWithPath: statPath)),
              let statString = String(data: statData, encoding: .utf8) else {
            return nil
        }
        
        let components = statString.components(separatedBy: " ")
        guard components.count > 21,
              let starttime = UInt64(components[21]) else {
            return nil
        }
        
        // Get system boot time
        guard let uptimeData = try? Data(contentsOf: URL(fileURLWithPath: "/proc/uptime")),
              let uptimeString = String(data: uptimeData, encoding: .utf8) else {
            return nil
        }
        
        let uptimeComponents = uptimeString.components(separatedBy: " ")
        guard let uptime = Double(uptimeComponents[0]) else {
            return nil
        }
        
        // Calculate process start time
        let clockTicks = 100.0 // Usually 100 Hz on Linux
        let processStartSeconds = Double(starttime) / clockTicks
        let bootTime = Date().timeIntervalSince1970 - uptime
        
        return Date(timeIntervalSince1970: bootTime + processStartSeconds)
    }
    
    private func getProcessIcon(executablePath: String?) -> Data? {
        // Try to find icon from .desktop files
        guard let execPath = executablePath else { return nil }
        
        let execName = execPath.lastPathComponent
        let desktopDirs = [
            "/usr/share/applications",
            "/usr/local/share/applications",
            "\(NSHomeDirectory())/.local/share/applications"
        ]
        
        for dir in desktopDirs {
            let desktopFile = "\(dir)/\(execName).desktop"
            if let iconPath = getIconFromDesktopFile(desktopFile) {
                return try? Data(contentsOf: URL(fileURLWithPath: iconPath))
            }
        }
        
        return nil
    }
    
    private func getIconFromDesktopFile(_ path: String) -> String? {
        guard let content = try? String(contentsOfFile: path) else { return nil }
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("Icon=") {
                let iconName = String(line.dropFirst(5))
                // Try to resolve icon path
                return resolveIconPath(iconName)
            }
        }
        
        return nil
    }
    
    private func resolveIconPath(_ iconName: String) -> String? {
        // Try common icon directories
        let iconDirs = [
            "/usr/share/icons/hicolor/48x48/apps",
            "/usr/share/icons/hicolor/32x32/apps",
            "/usr/share/pixmaps"
        ]
        
        for dir in iconDirs {
            let iconPath = "\(dir)/\(iconName).png"
            if FileManager.default.fileExists(atPath: iconPath) {
                return iconPath
            }
        }
        
        return nil
    }
    
    private func getProcessMemoryUsage(pid: pid_t) -> UInt64? {
        let statusPath = "/proc/\(pid)/status"
        
        guard let statusData = try? Data(contentsOf: URL(fileURLWithPath: statusPath)),
              let statusString = String(data: statusData, encoding: .utf8) else {
            return nil
        }
        
        let lines = statusString.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("VmRSS:") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if components.count >= 2, let kb = UInt64(components[1]) {
                    return kb * 1024 // Convert KB to bytes
                }
            }
        }
        
        return nil
    }
    
    private func getProcessCPUUsage(pid: pid_t) -> Double? {
        // CPU usage calculation would require sampling over time
        // This is a placeholder for now
        return nil
    }
    
    private func getProcessVersion(executablePath: String?) -> String? {
        guard let path = executablePath else { return nil }
        
        // Try to get version from the executable
        let result = try? runCommandSync([path, "--version"])
        if let output = result?.stdout, result?.exitCode == 0 {
            // Extract version from output (simplified)
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                if line.contains("version") || line.contains("Version") {
                    return line.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return nil
    }
    
    private func getProcessArchitecture(pid: pid_t) -> ProcessArchitecture {
        let exePath = "/proc/\(pid)/exe"
        
        // Try to determine architecture from the executable
        let result = try? runCommandSync(["file", exePath])
        
        if let output = result?.stdout, result?.exitCode == 0 {
            if output.contains("x86-64") || output.contains("x86_64") {
                return .x86_64
            } else if output.contains("aarch64") || output.contains("ARM64") {
                return .arm64
            } else if output.contains("i386") || output.contains("x86") {
                return .x86
            }
        }
        
        return .unknown
    }
    
    private func activateWindowX11(windowId: UInt32) throws {
        // Try wmctrl first
        var result = try? runCommandSync(["wmctrl", "-i", "-a", String(windowId)])
        
        if result?.exitCode != 0 {
            // Fallback to xdotool
            result = try? runCommandSync(["xdotool", "windowactivate", String(windowId)])
            
            if result?.exitCode != 0 {
                throw ApplicationError.activationFailed(0) // Don't have PID here
            }
        }
    }
    
    private func activateWindowWayland(windowId: UInt32) throws {
        // Wayland window activation is compositor-specific
        // Try swaymsg for Sway
        let result = try? runCommandSync(["swaymsg", "[con_id=\(windowId)]", "focus"])
        
        if result?.exitCode != 0 {
            throw ApplicationError.activationFailed(0) // Don't have PID here
        }
    }
    
    private func runCommandSync(_ arguments: [String]) throws -> CommandResult {
        guard !arguments.isEmpty else {
            throw ApplicationError.systemError(NSError(
                domain: "LinuxApplicationFinder",
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

// MARK: - String Extensions

private extension String {
    var lastPathComponent: String {
        return (self as NSString).lastPathComponent
    }
    
    var deletingLastPathComponent: String {
        return (self as NSString).deletingLastPathComponent
    }
}

// MARK: - Supporting Types

private struct CommandResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}
#endif

