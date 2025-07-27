import Foundation

/// Utility for generating consistent file names for captures
public struct FileNameGenerator: Sendable {
    
    /// Generate a file name based on capture context
    public static func generateFileName(
        displayIndex: Int? = nil,
        appName: String? = nil,
        windowIndex: Int? = nil,
        windowTitle: String? = nil,
        format: ImageFormat
    ) -> String {
        let timestamp = DateFormatter.timestamp.string(from: Date())
        let ext = format.rawValue
        
        if let displayIndex {
            return "screen_\(displayIndex + 1)_\(timestamp).\(ext)"
        } else if let appName {
            let cleanAppName = sanitizeForFileName(appName)
            if let windowIndex {
                return "\(cleanAppName)_window_\(windowIndex)_\(timestamp).\(ext)"
            } else if let windowTitle {
                let cleanTitle = sanitizeForFileName(windowTitle).prefix(20)
                return "\(cleanAppName)_\(cleanTitle)_\(timestamp).\(ext)"
            } else {
                return "\(cleanAppName)_\(timestamp).\(ext)"
            }
        } else {
            return "capture_\(timestamp).\(ext)"
        }
    }
    
    /// Sanitize a string for use in file names
    private static func sanitizeForFileName(_ string: String) -> String {
        // Replace spaces and common problematic characters
        return string
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "*", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "<", with: "_")
            .replacingOccurrences(of: ">", with: "_")
            .replacingOccurrences(of: "|", with: "_")
    }
}

extension DateFormatter {
    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}