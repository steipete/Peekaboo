import Foundation

enum Version {
    private static let values = VersionMetadata.resolve()

    static let current = values.current
    static let gitCommit = values.gitCommit
    static let gitCommitDate = values.gitCommitDate
    static let gitBranch = values.gitBranch
    static let buildDate = values.buildDate

    static var fullVersion: String {
        "\(current) (\(gitBranch)/\(gitCommit), built: \(buildDate))"
    }
}

private enum VersionMetadata {
    struct Values {
        let current: String
        let gitCommit: String
        let gitCommitDate: String
        let gitBranch: String
        let buildDate: String
    }

    static func resolve() -> Values {
        if let workingCopy = valuesFromWorkingCopy() {
            return workingCopy
        }
        if let info = valuesFromInfoDictionary() {
            return info
        }

        return Values(
            current: "Peekaboo 0.0.0",
            gitCommit: "unknown",
            gitCommitDate: "unknown",
            gitBranch: "unknown",
            buildDate: self.iso8601Now()
        )
    }

    private static func valuesFromInfoDictionary() -> Values? {
        guard let info = Bundle.main.infoDictionary else { return nil }

        guard let shortVersion = info["CFBundleShortVersionString"] as? String else {
            return nil
        }

        let display = info["PeekabooVersionDisplayString"] as? String ?? "Peekaboo \(shortVersion)"
        let commit = info["PeekabooGitCommit"] as? String ?? "unknown"
        let commitDate = info["PeekabooGitCommitDate"] as? String ?? "unknown"
        let branch = info["PeekabooGitBranch"] as? String ?? "unknown"
        let buildDate = info["PeekabooBuildDate"] as? String ?? self.iso8601Now()

        return Values(
            current: display,
            gitCommit: commit,
            gitCommitDate: commitDate,
            gitBranch: branch,
            buildDate: buildDate
        )
    }

    private static func valuesFromWorkingCopy() -> Values? {
        let root = self.repositoryRoot()
        guard FileManager.default.fileExists(atPath: root.path) else { return nil }

        let versionString = self.workingCopyVersion(root: root) ?? "0.0.0"
        var commit = self.git(["rev-parse", "--short", "HEAD"], root: root) ?? "unknown"
        let diffStatus = self.git(["status", "--porcelain"], root: root) ?? ""
        if !diffStatus.isEmpty {
            commit += "-dirty"
        }

        let commitDate = self.git(["show", "-s", "--format=%ci", "HEAD"], root: root) ?? "unknown"
        let branch = self.git(["rev-parse", "--abbrev-ref", "HEAD"], root: root) ?? "unknown"

        return Values(
            current: "Peekaboo \(versionString)",
            gitCommit: commit,
            gitCommitDate: commitDate,
            gitBranch: branch,
            buildDate: self.iso8601Now()
        )
    }

    private static func repositoryRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 {
            url.deleteLastPathComponent()
        }
        return url
    }

    private static func workingCopyVersion(root: URL) -> String? {
        let url = root.appendingPathComponent("version.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        struct VersionFile: Decodable { let version: String }
        return try? JSONDecoder().decode(VersionFile.self, from: data).version
    }

    private static func git(_ arguments: [String], root: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = root

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func iso8601Now() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }
}
