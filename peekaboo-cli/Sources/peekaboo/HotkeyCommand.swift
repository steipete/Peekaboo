import ArgumentParser
import Foundation
import CoreGraphics
import AXorcist

/// Presses key combinations like Cmd+C, Ctrl+A, etc.
/// Supports modifier keys and special keys.
@available(macOS 14.0, *)
struct HotkeyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hotkey",
        abstract: "Press keyboard shortcuts and key combinations",
        discussion: """
            The 'hotkey' command simulates keyboard shortcuts by pressing
            multiple keys simultaneously, like Cmd+C for copy or Cmd+Shift+T.
            
            EXAMPLES:
              peekaboo hotkey --keys "cmd,c"          # Copy
              peekaboo hotkey --keys "cmd,v"          # Paste
              peekaboo hotkey --keys "cmd,shift,t"    # Reopen closed tab
              peekaboo hotkey --keys "cmd,space"      # Spotlight
              peekaboo hotkey --keys "ctrl,a"         # Select all (in terminal)
              
            KEY NAMES:
              Modifiers: cmd, shift, alt/option, ctrl, fn
              Letters: a-z
              Numbers: 0-9
              Special: space, return, tab, escape, delete, arrow_up, arrow_down, arrow_left, arrow_right
              Function: f1-f12
              
            The keys are pressed in the order given and released in reverse order.
        """
    )
    
    @Option(help: "Comma-separated list of keys to press")
    var keys: String
    
    @Option(help: "Delay between key press and release in milliseconds")
    var holdDuration: Int = 50
    
    @Flag(help: "Output in JSON format")
    var jsonOutput = false
    
    mutating func run() async throws {
        let startTime = Date()
        
        do {
            // Parse key names
            let keyNames = keys.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            
            guard !keyNames.isEmpty else {
                throw ValidationError("No keys specified")
            }
            
            // Convert to key codes
            let keyCodes = try keyNames.map { name -> CGKeyCode in
                guard let code = KeyCodeMapper.keyCode(for: name) else {
                    throw ValidationError("Unknown key: '\(name)'")
                }
                return code
            }
            
            // Determine modifier flags
            let modifierFlags = KeyCodeMapper.modifierFlags(for: keyNames)
            
            // Perform hotkey
            _ = try await performHotkey(
                keyCodes: keyCodes,
                modifierFlags: modifierFlags,
                holdDuration: holdDuration
            )
            
            // Output results
            if jsonOutput {
                let output = HotkeyResult(
                    success: true,
                    keys: keyNames,
                    keyCount: keyCodes.count,
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output)
            } else {
                print("✅ Hotkey pressed")
                print("🎹 Keys: \(keyNames.joined(separator: " + "))")
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }
            
        } catch {
            if jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .INVALID_ARGUMENT
                )
            } else {
                var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
                print("Error: \(error.localizedDescription)", to: &localStandardErrorStream)
            }
            throw ExitCode.failure
        }
    }
    
    private func performHotkey(keyCodes: [CGKeyCode],
                             modifierFlags: CGEventFlags,
                             holdDuration: Int) async throws -> InternalHotkeyResult {
        
        // Separate modifier and non-modifier keys
        let modifierCodes = keyCodes.enumerated().compactMap { index, code in
            KeyCodeMapper.isModifier(keyCodes[index]) ? code : nil
        }
        let nonModifierCodes = keyCodes.enumerated().compactMap { index, code in
            !KeyCodeMapper.isModifier(keyCodes[index]) ? code : nil
        }
        
        // Press all keys down in order (modifiers first)
        for code in modifierCodes + nonModifierCodes {
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true)
            keyDown?.flags = modifierFlags
            keyDown?.post(tap: .cghidEventTap)
            
            // Small delay between key presses
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // Hold the keys
        if holdDuration > 0 {
            try await Task.sleep(nanoseconds: UInt64(holdDuration) * 1_000_000)
        }
        
        // Release all keys in reverse order (non-modifiers first, then modifiers)
        for code in (nonModifierCodes + modifierCodes).reversed() {
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false)
            keyUp?.flags = [] // Clear all flags on key up
            keyUp?.post(tap: .cghidEventTap)
            
            // Small delay between key releases
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        return InternalHotkeyResult()
    }
}

// MARK: - Key Code Mapping

private struct KeyCodeMapper {
    // Virtual key codes for macOS
    private static let keyMap: [String: CGKeyCode] = [
        // Letters
        "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E, "f": 0x03,
        "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26, "k": 0x28, "l": 0x25,
        "m": 0x2E, "n": 0x2D, "o": 0x1F, "p": 0x23, "q": 0x0C, "r": 0x0F,
        "s": 0x01, "t": 0x11, "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07,
        "y": 0x10, "z": 0x06,
        
        // Numbers
        "0": 0x1D, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15,
        "5": 0x17, "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19,
        
        // Modifiers
        "cmd": 0x37, "command": 0x37,
        "shift": 0x38,
        "caps": 0x39, "capslock": 0x39,
        "alt": 0x3A, "option": 0x3A,
        "ctrl": 0x3B, "control": 0x3B,
        "fn": 0x3F,
        
        // Special keys
        "space": 0x31,
        "return": 0x24, "enter": 0x24,
        "tab": 0x30,
        "escape": 0x35, "esc": 0x35,
        "delete": 0x33, "backspace": 0x33,
        "forwarddelete": 0x75, "del": 0x75,
        
        // Arrow keys
        "up": 0x7E, "arrow_up": 0x7E,
        "down": 0x7D, "arrow_down": 0x7D,
        "left": 0x7B, "arrow_left": 0x7B,
        "right": 0x7C, "arrow_right": 0x7C,
        
        // Function keys
        "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76,
        "f5": 0x60, "f6": 0x61, "f7": 0x62, "f8": 0x64,
        "f9": 0x65, "f10": 0x6D, "f11": 0x67, "f12": 0x6F
    ]
    
    static func keyCode(for name: String) -> CGKeyCode? {
        return keyMap[name.lowercased()]
    }
    
    static func isModifier(_ keyCode: CGKeyCode) -> Bool {
        let modifierCodes: Set<CGKeyCode> = [0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3F]
        return modifierCodes.contains(keyCode)
    }
    
    static func modifierFlags(for keyNames: [String]) -> CGEventFlags {
        var flags: CGEventFlags = []
        
        for name in keyNames {
            switch name.lowercased() {
            case "cmd", "command":
                flags.insert(.maskCommand)
            case "shift":
                flags.insert(.maskShift)
            case "alt", "option":
                flags.insert(.maskAlternate)
            case "ctrl", "control":
                flags.insert(.maskControl)
            case "fn":
                flags.insert(.maskSecondaryFn)
            default:
                break
            }
        }
        
        return flags
    }
}

// MARK: - Supporting Types

private struct InternalHotkeyResult {
    // Empty for now, can be extended
}

// MARK: - JSON Output Structure

struct HotkeyResult: Codable {
    let success: Bool
    let keys: [String]
    let keyCount: Int
    let executionTime: TimeInterval
}