import Foundation

/// Manages agent session persistence for resume functionality
@available(macOS 14.0, *)
actor AgentSessionManager {
    
    // MARK: - Session Data Models
    
    struct AgentSession: Codable {
        let id: String
        let task: String
        let threadId: String
        let steps: [AgentStep]
        let lastQuestion: String?
        let createdAt: Date
        let lastActivityAt: Date
        
        struct AgentStep: Codable {
            let description: String
            let command: String?
            let output: String?
            let timestamp: Date
        }
    }
    
    // MARK: - Properties
    
    private let sessionsDirectory: URL
    private var activeSessions: [String: AgentSession] = [:]
    
    // MARK: - Initialization
    
    init() {
        // Store sessions in ~/.peekaboo/sessions/
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        self.sessionsDirectory = homeDir.appendingPathComponent(".peekaboo/sessions")
        
        // Create sessions directory if it doesn't exist
        try? FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        
        // Load existing sessions on startup
        Task { 
            await loadExistingSessions()
        }
    }
    
    // MARK: - Session Management
    
    func createSession(task: String, threadId: String) -> String {
        let sessionId = UUID().uuidString
        let session = AgentSession(
            id: sessionId,
            task: task,
            threadId: threadId,
            steps: [],
            lastQuestion: nil,
            createdAt: Date(),
            lastActivityAt: Date()
        )
        
        activeSessions[sessionId] = session
        saveSession(session)
        return sessionId
    }
    
    func addStep(sessionId: String, description: String, command: String?, output: String?) {
        guard var session = activeSessions[sessionId] else { return }
        
        let step = AgentSession.AgentStep(
            description: description,
            command: command,
            output: output,
            timestamp: Date()
        )
        
        session = AgentSession(
            id: session.id,
            task: session.task,
            threadId: session.threadId,
            steps: session.steps + [step],
            lastQuestion: session.lastQuestion,
            createdAt: session.createdAt,
            lastActivityAt: Date()
        )
        
        activeSessions[sessionId] = session
        saveSession(session)
    }
    
    func setLastQuestion(sessionId: String, question: String?) {
        guard var session = activeSessions[sessionId] else { return }
        
        session = AgentSession(
            id: session.id,
            task: session.task,
            threadId: session.threadId,
            steps: session.steps,
            lastQuestion: question,
            createdAt: session.createdAt,
            lastActivityAt: Date()
        )
        
        activeSessions[sessionId] = session
        saveSession(session)
    }
    
    func getSession(id: String) -> AgentSession? {
        if let session = activeSessions[id] {
            return session
        }
        
        // Try loading from disk if not in memory
        return loadSession(id: id)
    }
    
    func getRecentSessions(limit: Int = 20) -> [AgentSession] {
        let allSessions = activeSessions.values + loadAllSessions().filter { session in
            !activeSessions.keys.contains(session.id)
        }
        
        return Array(allSessions.sorted { $0.lastActivityAt > $1.lastActivityAt }.prefix(limit))
    }
    
    func deleteSession(id: String) {
        activeSessions.removeValue(forKey: id)
        
        let sessionFile = sessionsDirectory.appendingPathComponent("\(id).json")
        try? FileManager.default.removeItem(at: sessionFile)
    }
    
    // MARK: - Persistence
    
    private func saveSession(_ session: AgentSession) {
        let sessionFile = sessionsDirectory.appendingPathComponent("\(session.id).json")
        
        do {
            let data = try JSONEncoder().encode(session)
            try data.write(to: sessionFile)
        } catch {
            print("Failed to save session \(session.id): \(error)")
        }
    }
    
    private func loadSession(id: String) -> AgentSession? {
        let sessionFile = sessionsDirectory.appendingPathComponent("\(id).json")
        
        do {
            let data = try Data(contentsOf: sessionFile)
            let session = try JSONDecoder().decode(AgentSession.self, from: data)
            activeSessions[id] = session
            return session
        } catch {
            return nil
        }
    }
    
    private func loadExistingSessions() async {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: nil)
            
            for file in files where file.pathExtension == "json" {
                do {
                    let data = try Data(contentsOf: file)
                    let session = try JSONDecoder().decode(AgentSession.self, from: data)
                    activeSessions[session.id] = session
                } catch {
                    print("Failed to load session from \(file.lastPathComponent): \(error)")
                }
            }
        } catch {
            // Directory doesn't exist or can't be read - that's ok
        }
    }
    
    private func loadAllSessions() -> [AgentSession] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: nil)
            var sessions: [AgentSession] = []
            
            for file in files where file.pathExtension == "json" {
                do {
                    let data = try Data(contentsOf: file)
                    let session = try JSONDecoder().decode(AgentSession.self, from: data)
                    sessions.append(session)
                } catch {
                    continue
                }
            }
            
            return sessions
        } catch {
            return []
        }
    }
    
    // MARK: - Cleanup
    
    func cleanupOldSessions(olderThan days: Int = 7) {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
        
        let sessionsToDelete = activeSessions.values.filter { $0.lastActivityAt < cutoffDate }
        
        for session in sessionsToDelete {
            deleteSession(id: session.id)
        }
    }
}

// MARK: - Global Instance

@available(macOS 14.0, *)
private let sharedSessionManager = AgentSessionManager()

@available(macOS 14.0, *)
extension AgentSessionManager {
    static var shared: AgentSessionManager {
        return sharedSessionManager
    }
}