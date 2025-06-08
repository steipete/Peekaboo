#if os(Linux)
import Foundation
import SystemPackage

/// Linux implementation of window management using X11 and Wayland tools
struct LinuxWindowManager: WindowManagerProtocol {
    
    private let isWayland: Bool
    
    init() {
        // Detect if we're running under Wayland
        self.isWayland = ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] != nil ||
                        ProcessInfo.processInfo.environment["XDG_SESSION_TYPE"] == "wayland"
    }
    
    func getWindows(for applicationId: String) async throws -> [WindowInfo] {
        let allWindows = try await getAllWindows()
        return allWindows.filter { $0.applicationId == applicationId }
    }
    
    func getAllWindows() async throws -> [WindowInfo] {
        if isWayland {
            return try await getWindowsWayland()
        } else {
            return try await getWindowsX11()
        }
    }
    
    func getWindow(by windowId: String) async throws -> WindowInfo? {
        let allWindows = try await getAllWindows()
        return allWindows.first { $0.id == windowId }
    }
    
    static func isSupported() -> Bool {
        // Check if we have the necessary tools available
        return commandExists("wmctrl") || commandExists("swaymsg")
    }
    
    // MARK: - X11 Implementation
    
    private func getWindowsX11() async throws -> [WindowInfo] {
        // Use wmctrl to get window list
        let output = try await runCommandString(["wmctrl", "-l", "-G"])
        return parseWmctrlOutput(output)
    }
    
    private func parseWmctrlOutput(_ output: String) -> [WindowInfo] {
        var windows: [WindowInfo] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            guard !line.isEmpty else { continue }
            
            let components = line.components(separatedBy: " ").filter { !$0.isEmpty }
            guard components.count >= 7 else { continue }
            
            let windowId = components[0]
            let desktop = components[1]
            let x = Int(components[2]) ?? 0
            let y = Int(components[3]) ?? 0
            let width = Int(components[4]) ?? 0
            let height = Int(components[5]) ?? 0
            let machine = components[6]
            let title = components.dropFirst(7).joined(separator: " ")
            
            // Skip windows with empty titles or very small dimensions
            guard !title.isEmpty, width > 50, height > 50 else { continue }
            
            let bounds = CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
            
            // Get process information for this window
            let (processId, applicationName) = getProcessInfoForWindow(windowId: windowId)
            
            let windowInfo = WindowInfo(
                id: windowId,
                title: title,
                bounds: bounds,
                applicationName: applicationName,
                applicationId: String(processId),
                isVisible: desktop != "-1", // -1 means window is not visible
                isMinimized: false, // wmctrl doesn't easily provide this info
                level: 0
            )
            
            windows.append(windowInfo)
        }
        
        return windows
    }
    
    private func getProcessInfoForWindow(windowId: String) -> (Int, String) {
        // Use xprop to get process ID for the window
        do {
            let output = try runCommandStringSync(["xprop", "-id", windowId, "_NET_WM_PID"])
            if let pidRange = output.range(of: #"_NET_WM_PID\\(CARDINAL\\) = (\\d+)"#, options: .regularExpression) {
                let pidString = String(output[pidRange]).components(separatedBy: " = ").last ?? "0"
                if let pid = Int(pidString) {
                    let appName = getApplicationName(processId: pid)
                    return (pid, appName)
                }
            }
        } catch {
            // Fallback if xprop fails
        }
        
        return (0, "Unknown")
    }
    
    private func getApplicationName(processId: Int) -> String {
        do {
            let commPath = "/proc/\\(processId)/comm"
            let comm = try String(contentsOfFile: commPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            return comm
        } catch {
            return "Unknown"
        }
    }
    
    // MARK: - Wayland Implementation
    
    private func getWindowsWayland() async throws -> [WindowInfo] {
        // Use swaymsg to get window tree
        let output = try await runCommandString(["swaymsg", "-t", "get_tree"])
        return parseSwayTree(output)
    }
    
    private func parseSwayTree(_ output: String) -> [WindowInfo] {
        // This would parse JSON output from swaymsg
        // Simplified implementation for now
        var windows: [WindowInfo] = []
        
        // In a real implementation, we would parse the JSON tree structure
        // and extract window information from each node
        
        return windows
    }
    
    // MARK: - Helper Methods
    
    private func runCommandString(_ command: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw LinuxWindowManagerError.commandFailed(command.joined(separator: " "))
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw LinuxWindowManagerError.invalidCommandOutput
        }
        
        return output
    }
    
    private func runCommandStringSync(_ command: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw LinuxWindowManagerError.commandFailed(command.joined(separator: " "))
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw LinuxWindowManagerError.invalidCommandOutput
        }
        
        return output
    }
    
    private static func commandExists(_ command: String) -> Bool {
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

// MARK: - Error Types

enum LinuxWindowManagerError: Error, LocalizedError {
    case commandFailed(String)
    case invalidCommandOutput
    case waylandNotSupported
    case x11NotSupported
    
    var errorDescription: String? {
        switch self {
        case .commandFailed(let command):
            return "Command failed: \\(command)"
        case .invalidCommandOutput:
            return "Invalid command output"
        case .waylandNotSupported:
            return "Wayland window management not fully supported"
        case .x11NotSupported:
            return "X11 window management not supported"
        }
    }
}

#endif

