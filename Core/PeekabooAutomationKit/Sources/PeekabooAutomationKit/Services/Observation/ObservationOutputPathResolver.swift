import Foundation

public enum ObservationOutputPathResolver {
    public static func resolve(
        path: String?,
        format: ImageFormat,
        defaultFileName: @autoclosure () -> String,
        replacingExistingExtension: Bool = false) -> URL
    {
        guard let path,
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return FileManager.default.temporaryDirectory.appendingPathComponent(defaultFileName())
        }

        let expandedPath = (path as NSString).expandingTildeInPath
        if self.isDirectoryLike(expandedPath) {
            return URL(fileURLWithPath: expandedPath, isDirectory: true)
                .appendingPathComponent(defaultFileName())
        }

        let url = URL(fileURLWithPath: expandedPath)
        let expectedExtension = self.fileExtension(for: format)

        if url.pathExtension.isEmpty {
            return url.appendingPathExtension(expectedExtension)
        }

        if replacingExistingExtension, url.pathExtension.lowercased() != expectedExtension {
            return url.deletingPathExtension().appendingPathExtension(expectedExtension)
        }

        return url
    }

    public static func isDirectoryLike(_ path: String) -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath
        let lastComponent = (expandedPath as NSString).lastPathComponent
        if expandedPath.hasSuffix("/") || lastComponent == "." || lastComponent == ".." {
            return true
        }

        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private static func fileExtension(for format: ImageFormat) -> String {
        switch format {
        case .png:
            "png"
        case .jpg:
            "jpg"
        }
    }
}
