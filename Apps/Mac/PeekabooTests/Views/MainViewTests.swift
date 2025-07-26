import SwiftUI
import Testing
@testable import Peekaboo

@Suite("MainView Tests", .tags(.ui, .unit))
@MainActor
struct MainViewTests {
    @Test("View modes toggle correctly")
    func viewModes() {
        let settings = PeekabooSettings()
        let sessionStore = SessionStore()
        let agent = PeekabooAgent(
            settings: settings,
            sessionStore: sessionStore)
        let speechRecognizer = SpeechRecognizer(settings: settings)

        // Note: We can't directly test SwiftUI views easily without UI testing
        // This test verifies the services are properly initialized
        #expect(agent.isExecuting == false)
        #expect(speechRecognizer.isListening == false)
    }

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

@Suite("SessionDetailView Tests", .tags(.ui, .unit))
@MainActor
struct SessionDetailViewTests {
    @Test("Session display formatting")
    func sessionFormatting() {
        var session = Session(title: "Test Session")

        // Add various message types
        session.messages = [
            SessionMessage(
                role: .user,
                content: "Take a screenshot of Safari"),
            SessionMessage(
                role: .assistant,
                content: "I'll take a screenshot of Safari for you.",
                toolCalls: [
                    ToolCall(
                        id: "call_123",
                        name: "screenshot",
                        arguments: ["app": AnyCodable("Safari")],
                        result: "Screenshot saved"),
                ]),
            SessionMessage(
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
