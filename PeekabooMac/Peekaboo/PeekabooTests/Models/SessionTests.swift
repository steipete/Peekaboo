import Foundation
import Testing
@testable import Peekaboo

@Suite("Session Model Tests", .tags(.models, .unit))
struct SessionTests {
    @Test("Session initializes with correct defaults")
    func sessionInitialization() {
        let session = Session(title: "Test Session")

        #expect(!session.id.isEmpty)
        #expect(session.id.hasPrefix("session_"))
        #expect(session.title == "Test Session")
        #expect(session.messages.isEmpty)
        #expect(session.startTime <= Date())
        #expect(session.summary.isEmpty)
    }

    @Test("Session IDs are unique")
    func uniqueSessionIDs() {
        let sessions = (0..<100).map { _ in Session(title: "Test") }
        let uniqueIDs = Set(sessions.map(\.id))

        #expect(uniqueIDs.count == sessions.count)
    }

    @Test("Session codable roundtrip")
    func sessionCodable() throws {
        // Create a session with messages
        var session = Session(title: "Codable Test")
        session.messages = [
            SessionMessage(
                role: .user,
                content: "Hello"),
            SessionMessage(
                role: .assistant,
                content: "Hi there!",
                toolCalls: [
                    ToolCall(
                        id: "call_123",
                        name: "screenshot",
                        arguments: ["app": AnyCodable("Safari")],
                        result: "Screenshot taken"),
                ]),
        ]
        session.summary = "A friendly greeting"

        // Encode
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)

        // Decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedSession = try decoder.decode(Session.self, from: data)

        // Verify
        #expect(decodedSession.id == session.id)
        #expect(decodedSession.title == session.title)
        #expect(decodedSession.messages.count == 2)
        #expect(decodedSession.messages[0].content == "Hello")
        #expect(decodedSession.messages[1].content == "Hi there!")
        #expect(decodedSession.messages[1].toolCalls.count == 1)
        #expect(decodedSession.summary == session.summary)
    }
}

@Suite("SessionMessage Model Tests", .tags(.models, .unit))
struct SessionMessageTests {
    @Test("Message role types")
    func messageRoles() {
        let userMessage = SessionMessage(
            role: .user,
            content: "User content")

        let assistantMessage = SessionMessage(
            role: .assistant,
            content: "Assistant content")

        let systemMessage = SessionMessage(
            role: .system,
            content: "System content")

        #expect(userMessage.role == .user)
        #expect(assistantMessage.role == .assistant)
        #expect(systemMessage.role == .system)
    }

    @Test("Message with tool calls")
    func messageWithToolCalls() {
        let toolCalls = [
            ToolCall(
                id: "call_1",
                name: "screenshot",
                arguments: ["app": AnyCodable("Finder")],
                result: "Success"),
            ToolCall(
                id: "call_2",
                name: "click",
                arguments: ["x": AnyCodable(100), "y": AnyCodable(200)],
                result: "Clicked"),
        ]

        let message = SessionMessage(
            role: .assistant,
            content: "I'll take a screenshot and click",
            toolCalls: toolCalls)

        #expect(message.toolCalls.count == 2)
        #expect(message.toolCalls[0].name == "screenshot")
        #expect(message.toolCalls[1].name == "click")
    }
}

@Suite("ToolCall Model Tests", .tags(.models, .unit))
struct ToolCallTests {
    @Test("Tool call initialization")
    func toolCallInit() {
        let arguments: [String: AnyCodable] = [
            "app": AnyCodable("Safari"),
            "window": AnyCodable(1),
            "includeDesktop": AnyCodable(true),
        ]

        let toolCall = ToolCall(
            id: "call_abc123",
            name: "screenshot",
            arguments: arguments,
            result: "Screenshot saved to /tmp/screenshot.png")

        #expect(toolCall.id == "call_abc123")
        #expect(toolCall.name == "screenshot")
        #expect((toolCall.arguments["app"]?.value as? String) == "Safari")
        #expect((toolCall.arguments["window"]?.value as? Int) == 1)
        #expect((toolCall.arguments["includeDesktop"]?.value as? Bool) == true)
        #expect(toolCall.result == "Screenshot saved to /tmp/screenshot.png")
    }

    @Test("Tool call codable with various argument types")
    func toolCallCodable() throws {
        let toolCall = ToolCall(
            id: "test_call",
            name: "complex_tool",
            arguments: [
                "string": AnyCodable("value"),
                "number": AnyCodable(42),
                "float": AnyCodable(3.14),
                "bool": AnyCodable(true),
                "array": AnyCodable([1, 2, 3]),
                "nested": AnyCodable(["key": "value"]),
            ],
            result: "Done")

        // Encode
        let data = try JSONEncoder().encode(toolCall)

        // Decode
        let decoded = try JSONDecoder().decode(ToolCall.self, from: data)

        // Verify
        #expect(decoded.id == toolCall.id)
        #expect(decoded.name == toolCall.name)
        #expect(decoded.result == toolCall.result)

        // Check arguments
        #expect((decoded.arguments["string"]?.value as? String) == "value")
        #expect((decoded.arguments["number"]?.value as? Int) == 42)
        #expect((decoded.arguments["bool"]?.value as? Bool) == true)
    }
}
