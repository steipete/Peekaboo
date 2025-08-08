import SwiftUI
import Testing
@testable import Peekaboo
@testable import PeekabooCore

@Suite("MainView Logic Tests", .tags(.ui, .unit))
@MainActor
struct MainViewLogicTests {
    @Test("Input validation")
    func inputValidation() {
        // Test various input strings
        let validInputs = [
            "Take a screenshot",
            "Click on the button",
            "Open Safari",
            "What's on my screen?",
        ]

        let emptyInputs = [
            "",
            "   ",
            "\n\n",
            "\t",
        ]

        // Valid inputs should not be empty when trimmed
        for input in validInputs {
            #expect(!input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }

        // Empty inputs should be empty when trimmed
        for input in emptyInputs {
            #expect(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

@Suite("SessionDetailView Logic Tests", .tags(.ui, .unit))
@MainActor
struct SessionDetailViewLogicTests {
    @Test("Session display formatting")
    func sessionFormatting() {
        var session = ConversationSession(title: "Test Session")

        // Add various message types
        session.messages = [
            ConversationMessage(
                role: .user,
                content: "Take a screenshot of Safari"),
            ConversationMessage(
                role: .assistant,
                content: "I'll take a screenshot of Safari for you.",
                toolCalls: [
                    ConversationToolCall(
                        name: "screenshot",
                        arguments: "{\"app\":\"Safari\"}",
                        result: "Screenshot saved"),
                ]),
            ConversationMessage(
                role: .system,
                content: "Task completed successfully"),
        ]

        // Verify message structure
        #expect(session.messages.count == 3)
        #expect(session.messages[0].role == .user)
        #expect(session.messages[1].role == .assistant)
        #expect(session.messages[1].toolCalls.count == 1)
        #expect(session.messages[2].role == .system)
    }

    @Test("Time formatting")
    func timeFormatting() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let testDate = Date()
        let formatted = formatter.string(from: testDate)

        #expect(!formatted.isEmpty)
        #expect(formatted.contains(":") || formatted.contains(".")) // Time separator
    }
}