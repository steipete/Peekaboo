#if os(Linux)
import Foundation
import SystemPackage

/// Linux implementation of screen capture using X11 and Wayland
struct LinuxScreenCapture: ScreenCaptureProtocol {
    
    private let isWayland: Bool
    
    init() {
        // Detect if we're running under Wayland
        self.isWayland = ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] != nil ||
                        ProcessInfo.processInfo.environment["XDG_SESSION_TYPE"] == "wayland"
    }
    
    func captureScreen(screenIndex: Int) async throws -> Data {
        let screens = try await getAvailableScreens()
        guard screenIndex < screens.count else {
            throw LinuxScreenCaptureError.invalidScreenIndex(screenIndex)
        }
        
        let screen = screens[screenIndex]
        
        if isWayland {
            return try await captureScreenWayland(screen: screen)
        } else {
            return try await captureScreenX11(screen: screen)
        }
    }
    
    func captureWindow(windowId: String, bounds: CGRect?) async throws -> Data {
        if isWayland {
            return try await captureWindowWayland(windowId: windowId, bounds: bounds)
        } else {
            return try await captureWindowX11(windowId: windowId, bounds: bounds)
        }
    }
    
    func getAvailableScreens() async throws -> [ScreenInfo] {
        if isWayland {
            return try await getScreensWayland()
        } else {
            return try await getScreensX11()
        }
    }
    
    static func isSupported() -> Bool {
        // Check if we have the necessary tools available
        return commandExists("xrandr") || commandExists("grim")
    }
    
    // MARK: - X11 Implementation
    
    private func captureScreenX11(screen: ScreenInfo) async throws -> Data {
        let command = [
            "import",
            "-window", "root",
            "-crop", "\\(Int(screen.bounds.width))x\\(Int(screen.bounds.height))+\\(Int(screen.bounds.minX))+\\(Int(screen.bounds.minY))",
            "png:-"
        ]
        
        return try await runCommand(command)
    }
    
    private func captureWindowX11(windowId: String, bounds: CGRect?) async throws -> Data {
        var command = ["import", "-window", windowId, "png:-"]
        
        if let bounds = bounds {
            command.insert("-crop", at: 2)
            command.insert("\\(Int(bounds.width))x\\(Int(bounds.height))+\\(Int(bounds.minX))+\\(Int(bounds.minY))", at: 3)
        }
        
        return try await runCommand(command)
    }
    
    private func getScreensX11() async throws -> [ScreenInfo] {
        let output = try await runCommandString(["xrandr", "--query"])
        return parseXrandrOutput(output)
    }
    
    // MARK: - Wayland Implementation
    
    private func captureScreenWayland(screen: ScreenInfo) async throws -> Data {
        let geometry = "\\(Int(screen.bounds.minX)),\\(Int(screen.bounds.minY)) \\(Int(screen.bounds.width))x\\(Int(screen.bounds.height))"
        let command = ["grim", "-g", geometry, "-"]
        
        return try await runCommand(command)
    }
    
    private func captureWindowWayland(windowId: String, bounds: CGRect?) async throws -> Data {
        // For Wayland, we need to use swaymsg to get window geometry
        if let bounds = bounds {
            let geometry = "\\(Int(bounds.minX)),\\(Int(bounds.minY)) \\(Int(bounds.width))x\\(Int(bounds.height))"
            return try await runCommand(["grim", "-g", geometry, "-"])
        } else {
            // Try to get window geometry from sway
            let windowInfo = try await runCommandString(["swaymsg", "-t", "get_tree"])
            // Parse window info and extract geometry
            // This is simplified - real implementation would parse JSON
            return try await runCommand(["grim", "-"])
        }
    }
    
    private func getScreensWayland() async throws -> [ScreenInfo] {
        let output = try await runCommandString(["swaymsg", "-t", "get_outputs"])
        return parseSwayOutputs(output)
    }
    
    // MARK: - Helper Methods
    
    private func runCommand(_ command: [String]) async throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw LinuxScreenCaptureError.commandFailed(command.joined(separator: " "))
        }
        
        return pipe.fileHandleForReading.readDataToEndOfFile()
    }
    
    private func runCommandString(_ command: [String]) async throws -> String {
        let data = try await runCommand(command)
        guard let output = String(data: data, encoding: .utf8) else {
            throw LinuxScreenCaptureError.invalidCommandOutput
        }
        return output
    }
    
    private func parseXrandrOutput(_ output: String) -> [ScreenInfo] {
        var screens: [ScreenInfo] = []
        let lines = output.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            if line.contains(" connected") {
                let components = line.components(separatedBy: " ")
                if let geometryIndex = components.firstIndex(where: { $0.contains("x") && $0.contains("+") }) {
                    let geometry = components[geometryIndex]
                    if let bounds = parseGeometry(geometry) {
                        let name = components[0]
                        let isPrimary = line.contains("primary")
                        
                        let screenInfo = ScreenInfo(
                            index: index,
                            bounds: bounds,
                            name: name,
                            isPrimary: isPrimary
                        )
                        screens.append(screenInfo)
                    }
                }
            }
        }
        
        return screens
    }
    
    private func parseSwayOutputs(_ output: String) -> [ScreenInfo] {
        // This would parse JSON output from swaymsg
        // Simplified implementation
        return [
            ScreenInfo(
                index: 0,
                bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                name: "Default",
                isPrimary: true
            )
        ]
    }
    
    private func parseGeometry(_ geometry: String) -> CGRect? {
        // Parse format like "1920x1080+0+0"
        let pattern = #"(\\d+)x(\\d+)\\+(\\d+)\\+(\\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: geometry, range: NSRange(geometry.startIndex..., in: geometry)) else {
            return nil
        }
        
        let width = Int(String(geometry[Range(match.range(at: 1), in: geometry)!])) ?? 0
        let height = Int(String(geometry[Range(match.range(at: 2), in: geometry)!])) ?? 0
        let x = Int(String(geometry[Range(match.range(at: 3), in: geometry)!])) ?? 0
        let y = Int(String(geometry[Range(match.range(at: 4), in: geometry)!])) ?? 0
        
        return CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
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

enum LinuxScreenCaptureError: Error, LocalizedError {
    case invalidScreenIndex(Int)
    case invalidWindowId(String)
    case commandFailed(String)
    case invalidCommandOutput
    case waylandNotSupported
    case x11NotSupported
    
    var errorDescription: String? {
        switch self {
        case .invalidScreenIndex(let index):
            return "Invalid screen index: \\(index)"
        case .invalidWindowId(let id):
            return "Invalid window ID: \\(id)"
        case .commandFailed(let command):
            return "Command failed: \\(command)"
        case .invalidCommandOutput:
            return "Invalid command output"
        case .waylandNotSupported:
            return "Wayland screen capture not supported"
        case .x11NotSupported:
            return "X11 screen capture not supported"
        }
    }
}

#endif

