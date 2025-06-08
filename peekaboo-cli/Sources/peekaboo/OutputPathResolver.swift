import Foundation

struct OutputPathResolver {
    static func getOutputPath(basePath: String?, fileName: String, screenIndex: Int? = nil) -> String {
        if let basePath = basePath {
            validatePath(basePath)
            return determineOutputPath(basePath: basePath, fileName: fileName, screenIndex: screenIndex)
        } else {
            return "/tmp/\(fileName)"
        }
    }

    static func getOutputPathWithFallback(basePath: String?, fileName: String) -> String {
        if let basePath = basePath {
            validatePath(basePath)
            return determineOutputPathWithFallback(basePath: basePath, fileName: fileName)
        } else {
            return "/tmp/\(fileName)"
        }
    }

    static func determineOutputPath(basePath: String, fileName: String, screenIndex: Int? = nil) -> String {
        // Check if basePath looks like a file (has extension and doesn't end with /)
        // Exclude special directory cases like "." and ".."
        let isLikelyFile = basePath.contains(".") && !basePath.hasSuffix("/") &&
            basePath != "." && basePath != ".."

        if isLikelyFile {
            // Create parent directory if needed
            let parentDir = (basePath as NSString).deletingLastPathComponent
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

            // For multiple screens, append screen index to avoid overwriting
            if screenIndex == nil {
                // Multiple screens - modify filename to include screen info
                let pathExtension = (basePath as NSString).pathExtension
                let pathWithoutExtension = (basePath as NSString).deletingPathExtension

                // Extract screen info from fileName (e.g., "screen_1_20250608_120000.png" -> "1_20250608_120000")
                let fileNameWithoutExt = (fileName as NSString).deletingPathExtension
                let screenSuffix = fileNameWithoutExt.replacingOccurrences(of: "screen_", with: "")

                return "\(pathWithoutExtension)_\(screenSuffix).\(pathExtension)"
            }

            return basePath
        } else {
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
    }

    static func determineOutputPathWithFallback(basePath: String, fileName: String) -> String {
        // Check if basePath looks like a file (has extension and doesn't end with /)
        // Exclude special directory cases like "." and ".."
        let isLikelyFile = basePath.contains(".") && !basePath.hasSuffix("/") &&
            basePath != "." && basePath != ".."

        if isLikelyFile {
            // Create parent directory if needed
            let parentDir = (basePath as NSString).deletingLastPathComponent
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

            // For fallback mode (invalid screen index that fell back to all screens),
            // always treat as multiple screens to avoid overwriting
            let pathExtension = (basePath as NSString).pathExtension
            let pathWithoutExtension = (basePath as NSString).deletingPathExtension

            // Extract screen info from fileName (e.g., "screen_1_20250608_120000.png" -> "1_20250608_120000")
            let fileNameWithoutExt = (fileName as NSString).deletingPathExtension
            let screenSuffix = fileNameWithoutExt.replacingOccurrences(of: "screen_", with: "")

            return "\(pathWithoutExtension)_\(screenSuffix).\(pathExtension)"
        } else {
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
    }
    
    private static func validatePath(_ path: String) {
        // Check for path traversal attempts
        if path.contains("../") || path.contains("..\\") {
            Logger.shared.debug("Potential path traversal detected in path: \(path)")
        }
        
        // Check for system-sensitive paths
        let sensitivePathPrefixes = ["/etc/", "/usr/", "/bin/", "/sbin/", "/System/", "/Library/System/"]
        let normalizedPath = (path as NSString).standardizingPath
        
        for prefix in sensitivePathPrefixes {
            if normalizedPath.hasPrefix(prefix) {
                Logger.shared.debug("Path points to system directory: \(path) -> \(normalizedPath)")
                break
            }
        }
    }
}
