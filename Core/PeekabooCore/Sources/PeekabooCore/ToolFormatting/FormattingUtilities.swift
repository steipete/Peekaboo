//
//  FormattingUtilities.swift
//  PeekabooCore
//

import Foundation

/// Shared formatting utilities for tool output
public struct FormattingUtilities {
    
    /// Format keyboard shortcut with proper symbols
    public static func formatKeyboardShortcut(_ keys: String) -> String {
        keys.replacingOccurrences(of: "cmd", with: "⌘")
            .replacingOccurrences(of: "command", with: "⌘")
            .replacingOccurrences(of: "shift", with: "⇧")
            .replacingOccurrences(of: "option", with: "⌥")
            .replacingOccurrences(of: "opt", with: "⌥")
            .replacingOccurrences(of: "alt", with: "⌥")
            .replacingOccurrences(of: "control", with: "⌃")
            .replacingOccurrences(of: "ctrl", with: "⌃")
            .replacingOccurrences(of: "return", with: "↩")
            .replacingOccurrences(of: "enter", with: "↩")
            .replacingOccurrences(of: "escape", with: "⎋")
            .replacingOccurrences(of: "esc", with: "⎋")
            .replacingOccurrences(of: "tab", with: "⇥")
            .replacingOccurrences(of: "delete", with: "⌫")
            .replacingOccurrences(of: "backspace", with: "⌫")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
    
    /// Truncate text for display
    public static func truncate(_ text: String, maxLength: Int = 50, suffix: String = "...") -> String {
        guard maxLength > 0 else { return suffix }
        if text.count <= maxLength {
            return text
        }
        let safeMaxLength = min(maxLength, text.count)
        let endIndex = text.index(text.startIndex, offsetBy: safeMaxLength)
        return String(text[..<endIndex]) + suffix
    }
    
    /// Format a file path to show only the filename
    public static func filename(from path: String) -> String {
        (path as NSString).lastPathComponent
    }
    
    /// Format plural text
    public static func pluralize(_ count: Int, singular: String, plural: String? = nil) -> String {
        if count == 1 {
            return "\(count) \(singular)"
        } else {
            return "\(count) \(plural ?? singular + "s")"
        }
    }
    
    /// Format coordinates
    public static func formatCoordinates(x: Any?, y: Any?) -> String? {
        guard let x = x, let y = y else { return nil }
        return "(\(x), \(y))"
    }
    
    /// Format size/dimensions
    public static func formatDimensions(width: Any?, height: Any?) -> String? {
        guard let width = width, let height = height else { return nil }
        return "\(width)×\(height)"
    }
    
    /// Format menu path with nice separators
    public static func formatMenuPath(_ path: String) -> String {
        let components = path.components(separatedBy: ">").map { $0.trimmingCharacters(in: .whitespaces) }
        if components.count > 1 {
            return components.joined(separator: " → ")
        }
        return path
    }
    
    /// Parse JSON arguments string to dictionary
    public static func parseArguments(_ arguments: String) -> [String: Any] {
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return args
    }
    
    /// Format JSON for pretty printing
    public static func formatJSON(_ json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
              let result = String(data: formatted, encoding: .utf8) else {
            return nil
        }
        return result
    }
    
    /// Format duration for display
    public static func formatDetailedDuration(_ seconds: TimeInterval) -> String {
        if seconds < 0.001 {
            return String(format: "%.0fµs", seconds * 1_000_000)
        } else if seconds < 1.0 {
            return String(format: "%.0fms", seconds * 1000)
        } else if seconds < 60.0 {
            return String(format: "%.1fs", seconds)
        } else {
            let minutes = Int(seconds / 60)
            let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
            return String(format: "%dmin %ds", minutes, remainingSeconds)
        }
    }

    /// Format a byte count into a human-readable string
    public static func formatFileSize(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024.0 && unitIndex < units.count - 1 {
            value /= 1024.0
            unitIndex += 1
        }

        if unitIndex == 0 {
            return String(format: "%.0f %@", value, units[unitIndex])
        } else if value < 10 {
            return String(format: "%.2f %@", value, units[unitIndex])
        } else if value < 100 {
            return String(format: "%.1f %@", value, units[unitIndex])
        } else {
            return String(format: "%.0f %@", value, units[unitIndex])
        }
    }
}