import Foundation

struct WatchCaptureSessionStore {
    let outputRoot: URL
    let autocleanMinutes: Int
    let managedAutoclean: Bool
    let sessionId: String
    var fileManager: FileManager = .default

    func prepareOutputRoot() throws {
        try self.fileManager.createDirectory(
            at: self.outputRoot,
            withIntermediateDirectories: true)
    }

    func performAutoclean() -> WatchWarning? {
        guard self.managedAutoclean else { return nil }
        let root = self.outputRoot.deletingLastPathComponent()
        guard root.lastPathComponent == "watch-sessions" else { return nil }
        guard let contents = try? self.fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles)
        else { return nil }

        let deadline = Date().addingTimeInterval(TimeInterval(-self.autocleanMinutes) * 60)
        var removed = 0
        for url in contents {
            guard let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = attrs.contentModificationDate else { continue }
            if modified < deadline {
                if (try? self.fileManager.removeItem(at: url)) != nil {
                    removed += 1
                }
            }
        }

        guard removed > 0 else { return nil }
        return WatchWarning(
            code: .autoclean,
            message: "Autoclean removed \(removed) old watch sessions",
            details: ["session": self.sessionId])
    }

    func writeJSON(_ value: some Encodable, to url: URL) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
    }
}
