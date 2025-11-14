import Foundation
import PeekabooFoundation

/// Utility for resolving and validating file paths
public struct PathResolver: Sendable {
    // macOS filename limit is 255 bytes (not characters)
    private static let maxFilenameLength = 255
    private static let safetyBuffer = 10

    /// Expand tilde and resolve relative paths
    public static func expandPath(_ path: String) -> String {
        // Expand tilde and resolve relative paths
        (path as NSString).expandingTildeInPath
    }

    /// Validate a path for security issues
    public static func validatePath(_ path: String) throws {
        // Check for path traversal attempts
        if path.contains("../") || path.contains("..\\") {
            throw PeekabooError.invalidInput("Path traversal detected: \(path)")
        }

        // Check for system-sensitive paths
        let sensitivePathPrefixes = ["/etc/", "/usr/", "/bin/", "/sbin/", "/System/", "/Library/System/"]
        let normalizedPath = (path as NSString).standardizingPath

        for prefix in sensitivePathPrefixes where normalizedPath.hasPrefix(prefix) {
            throw PeekabooError.invalidInput("Path points to system directory: \(path)")
        }
    }

    /// Create parent directory if needed
    public static func createParentDirectoryIfNeeded(for path: String) throws {
        // Create parent directory if needed
        let parentDir = (path as NSString).deletingLastPathComponent
        if !parentDir.isEmpty, parentDir != "/" {
            try FileManager.default.createDirectory(
                atPath: parentDir,
                withIntermediateDirectories: true,
                attributes: nil)
        }
    }

    /// Create directory path
    public static func createDirectory(at path: String) throws {
        // Create directory path
        try FileManager.default.createDirectory(
            atPath: path,
            withIntermediateDirectories: true,
            attributes: nil)
    }

    /// Check if path exists
    public static func pathExists(_ path: String) -> Bool {
        // Check if path exists
        FileManager.default.fileExists(atPath: path)
    }

    /// Check if path is a directory
    public static func isDirectory(_ path: String) -> Bool {
        // Check if path is a directory
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Safely combine filename components while respecting filesystem limits
    public static func safeCombineFilename(
        directory: String,
        baseName: String,
        suffix: String,
        extension fileExtension: String) -> String
    {
        // Calculate maximum allowed length for the base name
        let suffixLength = suffix.utf8.count
        let extensionLength = fileExtension.utf8.count + 1 // +1 for the dot
        let maxBaseNameLength = self.maxFilenameLength - suffixLength - extensionLength - self.safetyBuffer

        // Ensure maxBaseNameLength is not negative
        guard maxBaseNameLength > 0 else {
            // If there's no room for the base name, use a minimal name
            let minimalName = "f"
            let finalFilename = "\(minimalName)\(suffix).\(fileExtension)"
            return "\(directory)/\(finalFilename)"
        }

        // Truncate base name if necessary
        var truncatedBaseName = baseName
        if truncatedBaseName.utf8.count > maxBaseNameLength {
            truncatedBaseName = self.truncateToValidUTF8(truncatedBaseName, maxLength: maxBaseNameLength)
        }

        // Combine the parts
        let finalFilename = "\(truncatedBaseName)\(suffix).\(fileExtension)"
        return "\(directory)/\(finalFilename)"
    }

    /// Truncate string to valid UTF-8 sequence
    private static func truncateToValidUTF8(_ string: String, maxLength: Int) -> String {
        // Truncate string to valid UTF-8 sequence
        let data = string.data(using: .utf8)!
        var truncatedData = data.prefix(maxLength)

        // Try to create a string from the truncated data
        // If it fails, reduce the size until we get a valid UTF-8 sequence
        while !truncatedData.isEmpty {
            if let validString = String(data: truncatedData, encoding: .utf8) {
                return validString
            }
            // Remove one byte and try again
            truncatedData = truncatedData.dropLast()
        }

        return ""
    }
}
