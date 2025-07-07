import Foundation
import Observation

// MARK: - Session Management

@Observable
final class SessionStore {
    var sessions: [Session] = []
    var currentSession: Session?

    private let storageURL: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let peekabooPath = documentsPath.appendingPathComponent("Peekaboo")
        try? FileManager.default.createDirectory(at: peekabooPath, withIntermediateDirectories: true)
        return peekabooPath.appendingPathComponent("sessions.json")
    }()

    init() {
        self.loadSessions()
    }

    func createSession(title: String = "") -> Session {
        let session = Session(title: title.isEmpty ? "New Session" : title)
        self.sessions.insert(session, at: 0)
        self.currentSession = session
        self.saveSessions()
        return session
    }

    func addMessage(_ message: SessionMessage, to session: Session) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        self.sessions[index].messages.append(message)
        self.saveSessions()
    }

    func updateSummary(_ summary: String, for session: Session) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        self.sessions[index].summary = summary
        self.saveSessions()
    }

    private func loadSessions() {
        guard FileManager.default.fileExists(atPath: self.storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.sessions = try decoder.decode([Session].self, from: data)
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }

    private func saveSessions() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self.sessions)
            try data.write(to: self.storageURL)
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }
}

// MARK: - Models

struct Session: Identifiable, Codable {
    let id: String
    var title: String
    var messages: [SessionMessage] = []
    let startTime: Date
    var summary: String = ""

    init(title: String) {
        self.id = "session_\(UUID().uuidString)"
        self.title = title
        self.startTime = Date()
    }
}

struct SessionMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let toolCalls: [ToolCall]

    init(role: MessageRole, content: String, toolCalls: [ToolCall] = []) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.toolCalls = toolCalls
    }
}

enum MessageRole: String, Codable {
    case system
    case user
    case assistant
}

struct ToolCall: Identifiable, Codable {
    let id: String
    let name: String
    let arguments: [String: AnyCodable]
    let result: String
}

// Helper for encoding/decoding heterogeneous dictionaries
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            self.value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self.value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
