import AppKit
import Darwin
import Foundation

/// AppKit can lose the PID after an in-place exec while retaining valid application metadata.
enum RunningApplicationProcessIdentity {
    struct Metadata: Equatable, Sendable {
        let bundleIdentifier: String?
        let bundleURL: URL?
        let executableURL: URL?

        init(bundleIdentifier: String?, bundleURL: URL?, executableURL: URL?) {
            self.bundleIdentifier = bundleIdentifier
            self.bundleURL = bundleURL?.standardizedFileURL.resolvingSymlinksInPath()
            self.executableURL = executableURL?.standardizedFileURL.resolvingSymlinksInPath()
        }

        init(_ application: NSRunningApplication) {
            self.init(
                bundleIdentifier: application.bundleIdentifier,
                bundleURL: application.bundleURL,
                executableURL: application.executableURL)
        }
    }

    struct Readers: Sendable {
        var processIdentifiers: @Sendable () -> [pid_t]?
        var executablePath: @Sendable (pid_t) -> String?
        var metadata: @Sendable (pid_t) -> Metadata?
        var startIdentity: @Sendable (pid_t) -> UInt64?

        static let system = Self(
            processIdentifiers: RunningApplicationProcessIdentity.processIdentifiers,
            executablePath: RunningApplicationProcessIdentity.executablePath,
            metadata: { NSRunningApplication(processIdentifier: $0).map(Metadata.init) },
            startIdentity: SystemIdentityResolver.processStartIdentity)
    }

    static func resolve(_ application: NSRunningApplication) -> pid_t? {
        let pid = application.processIdentifier
        guard pid <= 0 else { return pid }
        return self.resolve(processIdentifier: pid, metadata: Metadata(application), readers: .system)
    }

    static func resolve(processIdentifier: pid_t, metadata: Metadata, readers: Readers) -> pid_t? {
        guard processIdentifier <= 0 else { return processIdentifier }
        guard let executableURL = metadata.executableURL, executableURL.isFileURL,
              let candidates = readers.processIdentifiers()
        else { return nil }

        var recovered: pid_t?
        var recoveredGeneration: UInt64?
        for candidate in Set(candidates) where candidate > 0 {
            let before = readers.startIdentity(candidate)
            guard let path = readers.executablePath(candidate),
                  URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path == executableURL.path,
                  readers.metadata(candidate) == metadata
            else { continue }
            // An otherwise matching process without a stable generation cannot be safely excluded.
            guard let before, readers.startIdentity(candidate) == before else { return nil }
            guard recovered == nil else { return nil }
            recovered = candidate
            recoveredGeneration = before
        }
        // A match found early must still be the same process after the rest of the table was checked.
        guard let recovered, readers.startIdentity(recovered) == recoveredGeneration else { return nil }
        return recovered
    }

    private static func processIdentifiers() -> [pid_t]? {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return nil }
        var capacity = Int(estimate) + 64
        for _ in 0..<3 {
            var pids = [pid_t](repeating: 0, count: capacity)
            let count = pids.withUnsafeMutableBytes { buffer in
                proc_listallpids(buffer.baseAddress, Int32(buffer.count))
            }
            guard count >= 0 else { return nil }
            if count < capacity {
                return Array(pids.prefix(Int(count)))
            }
            capacity *= 2
        }
        return nil
    }

    private static func executablePath(_ processIdentifier: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let count = proc_pidpath(processIdentifier, &buffer, UInt32(buffer.count))
        guard count > 0 else { return nil }
        return String(
            bytes: buffer.prefix(Int(count)).prefix { $0 != 0 }.map { UInt8(bitPattern: $0) },
            encoding: .utf8)
    }
}
