import Foundation

/// Generates unique file names for screenshots
struct FileNameGenerator {
    
    /// Generate a unique filename with timestamp
    static func generateUniqueFileName(baseName: String = "peekaboo", extension: String = "png") -> String {
        let timestamp = DateFormatter.timestampFormatter.string(from: Date())
        return "\(baseName)_\(timestamp).\(`extension`)"
    }
    
    /// Generate a filename with custom prefix and timestamp
    static func generateFileName(prefix: String, extension: String = "png") -> String {
        let timestamp = DateFormatter.timestampFormatter.string(from: Date())
        return "\(prefix)_\(timestamp).\(`extension`)"
    }
    
    /// Generate a filename based on application name
    static func generateAppFileName(appName: String, extension: String = "png") -> String {
        let sanitizedAppName = sanitizeFileName(appName)
        return generateFileName(prefix: sanitizedAppName, extension: `extension`)
    }
    
    /// Sanitize a string to be safe for use as a filename
    private static func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }
}

extension DateFormatter {
    static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}

