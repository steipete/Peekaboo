import Foundation

struct OutputPathResolver: Sendable {
    // macOS filename limit is 255 bytes (not characters)
    private static let maxFilenameLength = 255
    private static let safetyBuffer = 10
    static func getOutputPath(
        basePath: String?,
        fileName: String,
        screenIndex: Int? = nil,
        isSingleCapture: Bool = false
    ) -> String {
        if let basePath {
            validatePath(basePath)
            return determineOutputPath(
                basePath: basePath,
                fileName: fileName,
                screenIndex: screenIndex,
                isSingleCapture: isSingleCapture
            )
        } else {
            let defaultPath = ConfigurationManager.shared.getDefaultSavePath(cliValue: nil)
            return handleDirectoryBasePath(basePath: defaultPath, fileName: fileName)
        }
    }

    static func getOutputPathWithFallback(
        basePath: String?,
        fileName: String,
        isSingleCapture: Bool = false
    ) -> String {
        if let basePath {
            validatePath(basePath)
            return determineOutputPathWithFallback(
                basePath: basePath,
                fileName: fileName,
                isSingleCapture: isSingleCapture
            )
        } else {
            let defaultPath = ConfigurationManager.shared.getDefaultSavePath(cliValue: nil)
            return handleDirectoryBasePath(basePath: defaultPath, fileName: fileName)
        }
    }

    static func determineOutputPath(
        basePath: String,
        fileName: String,
        screenIndex: Int? = nil,
        isSingleCapture: Bool = false
    ) -> String {
        // Check if basePath looks like a file (has extension and doesn't end with /)
        // Exclude special directory cases like "." and ".."
        let isLikelyFile = basePath.contains(".") && !basePath.hasSuffix("/") &&
            basePath != "." && basePath != ".."

        if isLikelyFile {
            return handleFileBasePath(
                basePath: basePath,
                fileName: fileName,
                isSingleCapture: isSingleCapture
            )
        } else {
            return handleDirectoryBasePath(basePath: basePath, fileName: fileName)
        }
    }

    private static func handleFileBasePath(
        basePath: String,
        fileName: String,
        isSingleCapture: Bool
    ) -> String {
        // Create parent directory if needed
        createParentDirectoryIfNeeded(for: basePath)

        // If this is a single capture, use the file path as-is without appending metadata
        if isSingleCapture {
            return basePath
        }

        // When a file path is provided and we're capturing multiple items, append metadata
        let pathExtension = (basePath as NSString).pathExtension

        // Check what type of capture this is based on the fileName pattern
        let isScreenCapture = fileName.hasPrefix("screen_")
        let isWindowCapture = fileName.contains("_window_")

        if isWindowCapture {
            // Extract the metadata suffix from the generated fileName
            // e.g., "Finder_window_0_20250610_052730.png" -> "_Finder_window_0_20250610_052730"
            let fileNameWithoutExt = (fileName as NSString).deletingPathExtension
            let suffix = "_" + fileNameWithoutExt
            return safeCombineFilename(basePath: basePath, suffix: suffix, extension: pathExtension)
        } else if isScreenCapture {
            // Screen capture - modify filename to include screen info
            // Extract screen info from fileName (e.g., "screen_1_20250608_120000.png" -> "1_20250608_120000")
            let fileNameWithoutExt = (fileName as NSString).deletingPathExtension
            let replacedText = fileNameWithoutExt.replacingOccurrences(of: "screen_", with: "")
            let screenSuffix = "_" + replacedText
            return safeCombineFilename(basePath: basePath, suffix: screenSuffix, extension: pathExtension)
        }

        return basePath
    }

    private static func handleDirectoryBasePath(basePath: String, fileName: String) -> String {
        // Treat as directory - ensure it exists
        do {
            try FileManager.default.createDirectory(
                atPath: basePath,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            // Log but don't fail - maybe directory already exists
            // Logger.debug("Could not create directory \(basePath): \(error)")
        }
        return "\(basePath)/\(fileName)"
    }

    private static func createParentDirectoryIfNeeded(for path: String) {
        let parentDir = (path as NSString).deletingLastPathComponent
        if !parentDir.isEmpty && parentDir != "/" {
            do {
                try FileManager.default.createDirectory(
                    atPath: parentDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                // Log but don't fail - maybe directory already exists
                // Logger.debug("Could not create parent directory \(parentDir): \(error)")
            }
        }
    }

    static func determineOutputPathWithFallback(
        basePath: String,
        fileName: String,
        isSingleCapture: Bool = false
    ) -> String {
        // Check if basePath looks like a file (has extension and doesn't end with /)
        // Exclude special directory cases like "." and ".."
        let isLikelyFile = basePath.contains(".") && !basePath.hasSuffix("/") &&
            basePath != "." && basePath != ".."

        if isLikelyFile {
            // Create parent directory if needed
            createParentDirectoryIfNeeded(for: basePath)

            // If this is a single capture, use the file path as-is
            if isSingleCapture {
                return basePath
            }

            // For fallback mode (invalid screen index that fell back to all screens),
            // always treat as multiple screens to avoid overwriting
            let pathExtension = (basePath as NSString).pathExtension

            // Extract screen info from fileName (e.g., "screen_1_20250608_120000.png" -> "1_20250608_120000")
            let fileNameWithoutExt = (fileName as NSString).deletingPathExtension
            let screenSuffix = "_" + fileNameWithoutExt.replacingOccurrences(of: "screen_", with: "")

            return safeCombineFilename(basePath: basePath, suffix: screenSuffix, extension: pathExtension)
        } else {
            return handleDirectoryBasePath(basePath: basePath, fileName: fileName)
        }
    }

    private static func validatePath(_ path: String) {
        // Check for path traversal attempts
        if path.contains("../") || path.contains("..\\") {
            // Logger.shared.debug("Potential path traversal detected in path: \(path)")
        }

        // Check for system-sensitive paths
        let sensitivePathPrefixes = ["/etc/", "/usr/", "/bin/", "/sbin/", "/System/", "/Library/System/"]
        let normalizedPath = (path as NSString).standardizingPath

        for prefix in sensitivePathPrefixes where normalizedPath.hasPrefix(prefix) {
            // Logger.shared.debug("Path points to system directory: \(path) -> \(normalizedPath)")
            break
        }
    }

    /// Safely combines a base filename with a suffix, ensuring the total length doesn't exceed filesystem limits
    private static func safeCombineFilename(
        basePath: String,
        suffix: String,
        extension pathExtension: String
    ) -> String {
        let directory = (basePath as NSString).deletingLastPathComponent
        let pathWithoutExt = (basePath as NSString).deletingPathExtension
        let baseNameWithoutExt = pathWithoutExt.components(separatedBy: "/").last ?? "capture"

        // Debug logging
        // print("safeCombineFilename - basePath: \(basePath)")
        // print("safeCombineFilename - baseNameWithoutExt: \(baseNameWithoutExt) (\(baseNameWithoutExt.utf8.count)
        // bytes)")
        // print("safeCombineFilename - suffix: \(suffix) (\(suffix.utf8.count) bytes)")
        // print("safeCombineFilename - extension: \(pathExtension)")

        // Calculate maximum allowed length for the base name
        // Account for: suffix + extension + dot before extension + safety buffer
        let suffixLength = suffix.utf8.count
        let extensionLength = pathExtension.utf8.count + 1 // +1 for the dot
        let maxBaseNameLength = maxFilenameLength - suffixLength - extensionLength - safetyBuffer

        // Ensure maxBaseNameLength is not negative
        guard maxBaseNameLength > 0 else {
            // If there's no room for the base name, use a minimal name
            let minimalName = "f"
            let finalFilename = "\(minimalName)\(suffix).\(pathExtension)"
            return "\(directory)/\(finalFilename)"
        }

        // Truncate base name if necessary
        var truncatedBaseName = baseNameWithoutExt
        if truncatedBaseName.utf8.count > maxBaseNameLength {
            // Truncate by UTF-8 bytes, ensuring we don't cut in the middle of a character
            let data = truncatedBaseName.data(using: .utf8)!
            var truncatedData = data.prefix(maxBaseNameLength)

            // Try to create a string from the truncated data
            // If it fails, reduce the size until we get a valid UTF-8 sequence
            while !truncatedData.isEmpty {
                if let validString = String(data: truncatedData, encoding: .utf8) {
                    truncatedBaseName = validString
                    break
                }
                // Remove one byte and try again
                truncatedData = truncatedData.dropLast()
            }
        }

        // Combine the parts
        let finalFilename = "\(truncatedBaseName)\(suffix).\(pathExtension)"
        return "\(directory)/\(finalFilename)"
    }
}
