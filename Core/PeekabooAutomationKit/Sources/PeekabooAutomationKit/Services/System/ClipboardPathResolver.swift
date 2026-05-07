import Foundation

public enum ClipboardPathResolver {
    public static func fileURL(from path: String) -> URL {
        URL(fileURLWithPath: self.expandedPath(path))
    }

    public static func filePath(from path: String?) -> String? {
        path.map(self.expandedPath)
    }

    private static func expandedPath(_ path: String) -> String {
        // URL(fileURLWithPath:) treats "~" as a literal directory; expand first for shell-style CLI paths.
        (path as NSString).expandingTildeInPath
    }
}
