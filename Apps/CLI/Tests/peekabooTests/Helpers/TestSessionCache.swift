import Foundation
import PeekabooCore

/// Test-only session cache for compatibility with existing tests
class SessionCache {
    let sessionId: String
    private let sessionManager: SessionManager

    // Type aliases for compatibility
    typealias UIAutomationSession = PeekabooCore.UIAutomationSession
    typealias UIElement = PeekabooCore.UIElement

    init(sessionId: String? = nil, createIfNeeded: Bool = true) throws {
        self.sessionManager = SessionManager()

        if let id = sessionId {
            self.sessionId = id
        } else if createIfNeeded {
            // Generate timestamp-based ID for tests
            let timestamp = Int(Date().timeIntervalSince1970 * 1000)
            let random = Int.random(in: 1000...9999)
            self.sessionId = "\(timestamp)-\(random)"
        } else {
            // Try to get latest session
            let sessions = try sessionManager.listSessionsSync()
            guard let latest = sessions.first else {
                throw SessionError.noValidSessionFound
            }
            self.sessionId = latest
        }
    }

    func save(_ data: UIAutomationSession) async throws {
        try await self.sessionManager.saveSession(sessionId: self.sessionId, data: data)
    }

    func load() async throws -> UIAutomationSession? {
        try await self.sessionManager.loadSession(sessionId: self.sessionId)
    }

    func clear() async throws {
        try await self.sessionManager.deleteSession(sessionId: self.sessionId)
    }

    func getSessionPaths() async -> (raw: String, annotated: String, map: String) {
        let baseDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".peekaboo/session/\(self.sessionId)")

        return (
            raw: baseDir.appendingPathComponent("raw.png").path,
            annotated: baseDir.appendingPathComponent("annotated.png").path,
            map: baseDir.appendingPathComponent("map.json").path
        )
    }
}

// Extension to make SessionManager sync-compatible for tests
extension SessionManager {
    fileprivate func listSessionsSync() throws -> [String] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<[String], Error>?

        Task {
            do {
                let sessions = try await self.listSessions()
                result = .success(sessions)
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }

        semaphore.wait()

        switch result {
        case let .success(sessions):
            return sessions
        case let .failure(error):
            throw error
        case nil:
            throw SessionError.corruptedData
        }
    }
}
