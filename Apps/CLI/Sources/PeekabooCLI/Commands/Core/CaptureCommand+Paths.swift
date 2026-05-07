import Foundation

enum CaptureCommandPathResolver {
    static func outputDirectory(from path: String?) -> URL {
        if let path {
            return URL(fileURLWithPath: self.expandedPath(path), isDirectory: true)
        }
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("peekaboo")
            .appendingPathComponent("capture-sessions", isDirectory: true)
            .appendingPathComponent("capture-\(UUID().uuidString)", isDirectory: true)
    }

    static func fileURL(from path: String) -> URL {
        URL(fileURLWithPath: self.expandedPath(path))
    }

    private static func expandedPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }
}
