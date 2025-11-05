import Foundation
import PeekabooCore
import Testing
@testable import Peekaboo

@Suite("ConversationSession Model Tests", .tags(.models, .unit))
struct ConversationSessionTests {
    @Test("Session initializes with correct defaults")
    func sessionInitialization() {
        let session = ConversationSession(title: "Test Session")

        #expect(!session.id.isEmpty)
        #expect(session.id.hasPrefix("session_"))
        #expect(session.title == "Test Session")
        #expect(session.messages.isEmpty)
        #expect(session.startTime <= Date())
        #expect(session.summary.isEmpty)
    }

    @Test("Session IDs are unique")
    func uniqueSessionIDs() {
        let sessions = (0..<100).map { _ in ConversationSession(title: "Test") }
        let uniqueIDs = Set(sessions.map(\.id))

        #expect(uniqueIDs.count == sessions.count)
    }

    @Test("Session codable roundtrip")
    func sessionCodable() throws {
        // Create a session with messages
        var session = ConversationSession(title: "Codable Test")
        session.messages = [
            ConversationMessage(
                role: .user,
                content: "Hello"),
            ConversationMessage(
                role: .assistant,
                content: "Hi there!",
                toolCalls: [
                    ConversationToolCall(
                        name: "screenshot",
                        arguments: "{\"app\":\"Safari\"}",
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
        let decodedSession = try decoder.decode(ConversationSession.self, from: data)

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

@Suite("ConversationMessage Model Tests", .tags(.models, .unit))
struct ConversationMessageTests {
    @Test("Message role types")
    func messageRoles() {
        let userMessage = ConversationMessage(
            role: .user,
            content: "User content")

        let assistantMessage = ConversationMessage(
            role: .assistant,
            content: "Assistant content")

        let systemMessage = ConversationMessage(
            role: .system,
            content: "System content")

        #expect(userMessage.role == .user)
        #expect(assistantMessage.role == .assistant)
        #expect(systemMessage.role == .system)
    }

    @Test("Message with tool calls")
    func messageWithToolCalls() {
        let toolCalls = [
            ConversationToolCall(
                name: "screenshot",
                arguments: "{\"app\":\"Finder\"}",
                result: "Success"),
            ConversationToolCall(
                name: "click",
                arguments: "{\"x\":100,\"y\":200}",
                result: "Clicked"),
        ]

        let message = ConversationMessage(
            role: .assistant,
            content: "I'll take a screenshot and click",
            toolCalls: toolCalls)

        #expect(message.toolCalls.count == 2)
        #expect(message.toolCalls[0].name == "screenshot")
        #expect(message.toolCalls[1].name == "click")
    }
}

@Suite("ConversationToolCall Model Tests", .tags(.models, .unit))
struct ConversationToolCallTests {
    @Test("Tool call initialization")
    func toolCallInit() {
        let arguments = "{\"app\":\"Safari\",\"window\":1,\"includeDesktop\":true}"

        let toolCall = ConversationToolCall(
            id: "call_abc123",
            name: "screenshot",
            arguments: arguments,
            result: "Screenshot saved to /tmp/screenshot.png")

        #expect(toolCall.id == "call_abc123")
        #expect(toolCall.name == "screenshot")
        #expect(toolCall.arguments == arguments)
        #expect(toolCall.result == "Screenshot saved to /tmp/screenshot.png")
    }

    @Test("Tool call codable with complex arguments")
    func toolCallCodable() throws {
        let arguments = "{\"string\":\"value\",\"number\":42,\"float\":3.14,\"bool\":true,\"array\":[1,2,3],\"nested\":{\"key\":\"value\"}}"
        let toolCall = ConversationToolCall(
            id: "test_call",
            name: "complex_tool",
            arguments: arguments,
            result: "Done")

        // Encode
        let data = try JSONEncoder().encode(toolCall)

        // Decode
        let decoded = try JSONDecoder().decode(ConversationToolCall.self, from: data)

        // Verify
        #expect(decoded.id == toolCall.id)
        #expect(decoded.name == toolCall.name)
        #expect(decoded.result == toolCall.result)
        #expect(decoded.arguments == arguments)
    }
}
