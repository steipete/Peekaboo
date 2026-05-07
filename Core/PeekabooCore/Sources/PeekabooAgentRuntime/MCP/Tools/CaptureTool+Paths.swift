import Foundation

enum CaptureToolPathResolver {
    static func outputDirectory(from path: String) -> URL {
        URL(fileURLWithPath: self.expandedPath(path), isDirectory: true)
    }

    static func fileURL(from path: String) -> URL {
        URL(fileURLWithPath: self.expandedPath(path))
    }

    static func filePath(from path: String?) -> String? {
        path.map(self.expandedPath)
    }

    private static func expandedPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }
}
