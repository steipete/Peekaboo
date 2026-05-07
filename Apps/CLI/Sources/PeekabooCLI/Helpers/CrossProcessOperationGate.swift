import Darwin
import Foundation

enum CrossProcessOperationGate {
    /// Serializes same-process callers before we enter the file-lock wait loop.
    @MainActor private static var activeNames = Set<String>()

    @MainActor
    static func withExclusiveOperation<T: Sendable>(
        named name: String,
        _ operation: () async throws -> T
    ) async throws -> T {
        while self.activeNames.contains(name) {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        self.activeNames.insert(name)
        defer { self.activeNames.remove(name) }

        // `flock` coordinates independent CLI processes; this is for OS services that
        // hang when several fresh processes ask for capture/ReplayKit work at once.
        let path = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("boo.peekaboo.\(self.sanitizedName(name)).lock")
        let fd = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else {
            return try await operation()
        }
        defer { close(fd) }

        while flock(fd, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK || errno == EAGAIN || errno == EINTR else {
                // Do not turn a broken lock file into a broken command.
                return try await operation()
            }

            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        defer { flock(fd, LOCK_UN) }

        return try await operation()
    }

    private static func sanitizedName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
    }
}
