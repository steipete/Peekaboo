#if os(Linux)
import Foundation
import CoreGraphics

/// Linux-specific implementation of window management supporting both X11 and Wayland
class LinuxWindowManager: WindowManagerProtocol {
    
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
    
    func getWindowsForApp(pid: pid_t, includeOffScreen: Bool = false) throws -> [WindowData] {
        switch displayServer {
        case .x11:
            return try getWindowsForAppX11(pid: pid, includeOffScreen: includeOffScreen)
        case .wayland:
            return try getWindowsForAppWayland(pid: pid, includeOffScreen: includeOffScreen)
        case .unknown:
            throw WindowManagementError.notSupported
        }
    }
    
    func getWindowInfo(windowId: UInt32) throws -> WindowData? {
        switch displayServer {
        case .x11:
            return try getWindowInfoX11(windowId: windowId)
        case .wayland:
            return try getWindowInfoWayland(windowId: windowId)
        case .unknown:
            throw WindowManagementError.notSupported
        }
    }
    
    func getAllWindows(includeOffScreen: Bool = false) throws -> [WindowData] {
        switch displayServer {
        case .x11:
            return try getAllWindowsX11(includeOffScreen: includeOffScreen)
        case .wayland:
            return try getAllWindowsWayland(includeOffScreen: includeOffScreen)
        case .unknown:
            throw WindowManagementError.notSupported
        }
    }
    
    func getWindowsByApplication(includeOffScreen: Bool = false) throws -> [pid_t: [WindowData]] {
        let allWindows = try getAllWindows(includeOffScreen: includeOffScreen)
        var windowsByApp: [pid_t: [WindowData]] = [:]
        
        for window in allWindows {
            // Get PID for window (this is a simplified approach)
            if let pid = try? getWindowPID(windowId: window.windowId) {
                if windowsByApp[pid] == nil {
                    windowsByApp[pid] = []
                }
                windowsByApp[pid]?.append(window)
            }
        }
        
        // Sort windows within each application
        for pid in windowsByApp.keys {
            windowsByApp[pid]?.sort { $0.windowIndex < $1.windowIndex }
        }
        
        return windowsByApp
    }
    
    func isWindowManagementSupported() -> Bool {
        return displayServer != .unknown
    }
    
    func refreshWindowCache() throws {
        // Linux window information is always fresh, no caching needed
    }
    
    // MARK: - X11 Implementation
    
    private func getWindowsForAppX11(pid: pid_t, includeOffScreen: Bool) throws -> [WindowData] {
        // Get all windows and filter by PID
        let allWindows = try getAllWindowsX11(includeOffScreen: includeOffScreen)
        var appWindows: [WindowData] = []
        
        for window in allWindows {
            if let windowPid = try? getWindowPIDX11(windowId: window.windowId), windowPid == pid {
                appWindows.append(window)
            }
        }
        
        return appWindows.sorted { $0.windowIndex < $1.windowIndex }
    }
    
    private func getAllWindowsX11(includeOffScreen: Bool) throws -> [WindowData] {
        // Use wmctrl to list windows
        let result = try runCommandSync(["wmctrl", "-l", "-p", "-G"])
        
        if result.exitCode != 0 {
            // Fallback to xwininfo
            return try getAllWindowsX11Fallback(includeOffScreen: includeOffScreen)
        }
        
        var windows: [WindowData] = []
        let lines = result.stdout.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            if line.isEmpty { continue }
            
            if let windowData = parseWmctrlLine(line, index: index) {
                windows.append(windowData)
            }
        }
        
        return windows
    }
    
    private func getAllWindowsX11Fallback(includeOffScreen: Bool) throws -> [WindowData] {
        // Use xwininfo -tree -root as fallback
        let result = try runCommandSync(["xwininfo", "-tree", "-root"])
        
        if result.exitCode != 0 {
            throw WindowManagementError.systemError(NSError(
                domain: "LinuxWindowManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get window list: \(result.stderr)"]
            ))
        }
        
        var windows: [WindowData] = []
        let lines = result.stdout.components(separatedBy: .newlines)
        var index = 0
        
        for line in lines {
            if let windowData = parseXwininfoLine(line, index: index) {
                windows.append(windowData)
                index += 1
            }
        }
        
        return windows
    }
    
    private func getWindowInfoX11(windowId: UInt32) throws -> WindowData? {
        let result = try runCommandSync(["xwininfo", "-id", String(windowId)])
        
        if result.exitCode != 0 {
            return nil
        }
        
        return parseXwininfoOutput(result.stdout, windowId: windowId, index: 0)
    }
    
    private func getWindowPIDX11(windowId: UInt32) throws -> pid_t? {
        let result = try runCommandSync(["xprop", "-id", String(windowId), "_NET_WM_PID"])
        
        if result.exitCode == 0 {
            // Parse output like "_NET_WM_PID(CARDINAL) = 1234"
            let components = result.stdout.components(separatedBy: " = ")
            if components.count >= 2, let pid = pid_t(components[1].trimmingCharacters(in: .whitespacesAndNewlines)) {
                return pid
            }
        }
        
        return nil
    }
    
    // MARK: - Wayland Implementation
    
    private func getWindowsForAppWayland(pid: pid_t, includeOffScreen: Bool) throws -> [WindowData] {
        // Wayland window management is more limited
        // Try using swaymsg if available (for Sway compositor)
        if let windows = try? getWindowsSwayWM(pid: pid) {
            return windows
        }
        
        // Fallback to generic approach
        return []
    }
    
    private func getAllWindowsWayland(includeOffScreen: Bool) throws -> [WindowData] {
        // Try swaymsg first
        if let windows = try? getAllWindowsSwayWM() {
            return windows
        }
        
        // No generic Wayland window enumeration available
        return []
    }
    
    private func getWindowInfoWayland(windowId: UInt32) throws -> WindowData? {
        // Wayland doesn't have a standard way to get window info by ID
        return nil
    }
    
    private func getWindowsSwayWM(pid: pid_t) throws -> [WindowData] {
        let result = try runCommandSync(["swaymsg", "-t", "get_tree"])
        
        if result.exitCode != 0 {
            throw WindowManagementError.systemError(NSError(
                domain: "LinuxWindowManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get Sway window tree: \(result.stderr)"]
            ))
        }
        
        // Parse JSON output (simplified)
        // A full implementation would use a JSON parser
        return []
    }
    
    private func getAllWindowsSwayWM() throws -> [WindowData] {
        let result = try runCommandSync(["swaymsg", "-t", "get_tree"])
        
        if result.exitCode != 0 {
            throw WindowManagementError.systemError(NSError(
                domain: "LinuxWindowManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get Sway window tree: \(result.stderr)"]
            ))
        }
        
        // Parse JSON output (simplified)
        // A full implementation would use a JSON parser
        return []
    }
    
    // MARK: - Helper Methods
    
    private func parseWmctrlLine(_ line: String, index: Int) -> WindowData? {
        // wmctrl output format: windowid desktop pid x y w h hostname title
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        guard components.count >= 8 else { return nil }
        
        guard let windowId = UInt32(components[0], radix: 16),
              let x = Int(components[3]),
              let y = Int(components[4]),
              let width = Int(components[5]),
              let height = Int(components[6]) else {
            return nil
        }
        
        let title = components.dropFirst(8).joined(separator: " ")
        let bounds = CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
        
        return WindowData(
            windowId: windowId,
            title: title.isEmpty ? "Untitled" : title,
            bounds: bounds,
            isOnScreen: true, // wmctrl only shows visible windows by default
            windowIndex: index
        )
    }
    
    private func parseXwininfoLine(_ line: String, index: Int) -> WindowData? {
        // Parse xwininfo -tree output
        // Format: "     0x1400001 \"Window Title\": (\"class\" \"Class\")  200x100+10+20  +10+20"
        
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("0x") else { return nil }
        
        let components = trimmed.components(separatedBy: " ")
        guard let windowIdString = components.first,
              let windowId = UInt32(String(windowIdString.dropFirst(2)), radix: 16) else {
            return nil
        }
        
        // Extract title from quotes
        var title = "Untitled"
        if let startQuote = trimmed.firstIndex(of: "\""),
           let endQuote = trimmed[trimmed.index(after: startQuote)...].firstIndex(of: "\"") {
            title = String(trimmed[trimmed.index(after: startQuote)..<endQuote])
        }
        
        // For simplicity, use default bounds
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        
        return WindowData(
            windowId: windowId,
            title: title,
            bounds: bounds,
            isOnScreen: true,
            windowIndex: index
        )
    }
    
    private func parseXwininfoOutput(_ output: String, windowId: UInt32, index: Int) -> WindowData? {
        var title = "Untitled"
        var x: CGFloat = 0, y: CGFloat = 0, width: CGFloat = 0, height: CGFloat = 0
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Window id:") && line.contains("\"") {
                let parts = line.components(separatedBy: "\"")
                if parts.count >= 2 {
                    title = parts[1]
                }
            } else if line.contains("Absolute upper-left X:") {
                x = CGFloat(extractNumber(from: line) ?? 0)
            } else if line.contains("Absolute upper-left Y:") {
                y = CGFloat(extractNumber(from: line) ?? 0)
            } else if line.contains("Width:") {
                width = CGFloat(extractNumber(from: line) ?? 0)
            } else if line.contains("Height:") {
                height = CGFloat(extractNumber(from: line) ?? 0)
            }
        }
        
        return WindowData(
            windowId: windowId,
            title: title,
            bounds: CGRect(x: x, y: y, width: width, height: height),
            isOnScreen: true,
            windowIndex: index
        )
    }
    
    private func extractNumber(from line: String) -> Int? {
        let components = line.components(separatedBy: CharacterSet.decimalDigits.inverted)
        for component in components {
            if let number = Int(component) {
                return number
            }
        }
        return nil
    }
    
    private func getWindowPID(windowId: UInt32) throws -> pid_t? {
        switch displayServer {
        case .x11:
            return try getWindowPIDX11(windowId: windowId)
        case .wayland:
            return nil // Wayland doesn't expose this easily
        case .unknown:
            return nil
        }
    }
    
    private func runCommandSync(_ arguments: [String]) throws -> CommandResult {
        guard !arguments.isEmpty else {
            throw WindowManagementError.systemError(NSError(
                domain: "LinuxWindowManager",
                code: 3,
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

// MARK: - Extension for backward compatibility

extension LinuxWindowManager {
    /// Get windows info for app in the format expected by the existing CLI
    func getWindowsInfoForApp(
        pid: pid_t,
        includeOffScreen: Bool = false,
        includeBounds: Bool = false,
        includeIDs: Bool = false
    ) throws -> [WindowInfo] {
        let windowDataArray = try getWindowsForApp(pid: pid, includeOffScreen: includeOffScreen)
        
        return windowDataArray.map { windowData in
            WindowInfo(
                window_title: windowData.title,
                window_id: includeIDs ? windowData.windowId : nil,
                window_index: windowData.windowIndex,
                bounds: includeBounds ? WindowBounds(
                    xCoordinate: Int(windowData.bounds.origin.x),
                    yCoordinate: Int(windowData.bounds.origin.y),
                    width: Int(windowData.bounds.size.width),
                    height: Int(windowData.bounds.size.height)
                ) : nil,
                is_on_screen: includeOffScreen ? windowData.isOnScreen : nil,
                application_name: nil, // Would need to look up from PID
                process_id: pid
            )
        }
    }
}

// MARK: - Supporting Types

private enum LinuxDisplayServer {
    case x11
    case wayland
    case unknown
}

private struct CommandResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}
#endif

