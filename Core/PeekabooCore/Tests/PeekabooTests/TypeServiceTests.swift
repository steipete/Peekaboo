import CoreGraphics
import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooCore

@Suite(
    "TypeService Tests",
    .tags(.ui, .automation),
    .enabled(if: TestEnvironment.runInputAutomationScenarios))
@MainActor
struct TypeServiceTests {
    @Test("Initialize TypeService")
    func initializeService() async throws {
        let service: TypeService? = TypeService()
        #expect(service != nil)
    }

    @Test("Type text")
    func typeBasicText() async throws {
        let service = TypeService()

        // Test basic text typing
        try await service.type(
            text: "Hello World",
            target: nil,
            clearExisting: false,
            typingDelay: 50,
            sessionId: nil)
    }

    @Test("Type with special characters")
    func typeSpecialCharacters() async throws {
        let service = TypeService()

        // Test typing with special characters
        let specialText = "Hello! @#$% 123 🎉"
        try await service.type(
            text: specialText,
            target: nil,
            clearExisting: false,
            typingDelay: 50,
            sessionId: nil)
    }

    @Test("Type in specific element")
    func typeInElement() async throws {
        let service = TypeService()

        // Test typing in a specific element (by query)
        // In test environment, this will attempt to find an element
        // but may not succeed - we're testing the API
        do {
            try await service.type(
                text: "test@example.com",
                target: "email",
                clearExisting: false,
                typingDelay: 50,
                sessionId: nil)
        } catch is NotFoundError {
            // Expected in test environment
        }
    }

    @Test("Clear and type")
    func clearAndType() async throws {
        let service = TypeService()

        // Test clearing before typing
        try await service.type(
            text: "New text",
            target: nil,
            clearExisting: true,
            typingDelay: 50,
            sessionId: nil)
    }

    @Test("Type actions")
    func typeActions() async throws {
        let service = TypeService()

        // Test type actions
        let actions: [TypeAction] = [
            .text("Hello"),
            .key(.space),
            .text("World"),
            .key(.return),
            .clear,
            .text("New line"),
        ]

        let result = try await service.typeActions(
            actions,
            typingDelay: 50,
            sessionId: nil)

        #expect(result.totalCharacters > 0)
        #expect(result.keyPresses > 0)
    }

    @Test("Type with fast speed")
    func typeWithFastSpeed() async throws {
        let service = TypeService()

        // Test typing with no delay
        try await service.type(
            text: "Fast typing",
            target: nil,
            clearExisting: false,
            typingDelay: 0,
            sessionId: nil)
    }

    @Test("Type with slow speed")
    func typeWithSlowSpeed() async throws {
        let service = TypeService()

        // Test typing with delay
        let startTime = Date()
        try await service.type(
            text: "Slow",
            target: nil,
            clearExisting: false,
            typingDelay: 100, // 100ms between characters
            sessionId: nil)
        let duration = Date().timeIntervalSince(startTime)

        // Should take at least 300ms for 4 characters (3 delays)
        #expect(duration >= 0.3)
    }

    @Test("Empty text handling")
    func typeEmptyText() async throws {
        let service = TypeService()

        // Should handle empty text gracefully
        try await service.type(
            text: "",
            target: nil,
            clearExisting: false,
            typingDelay: 50,
            sessionId: nil)
    }

    @Test("Unicode text")
    func typeUnicodeText() async throws {
        let service = TypeService()

        // Test various Unicode characters
        let unicodeTexts = [
            "こんにちは", // Japanese
            "你好", // Chinese
            "مرحبا", // Arabic
            "🌍🌎🌏", // Emojis
            "café", // Accented characters
            "™®©", // Symbols
        ]

        for text in unicodeTexts {
            try await service.type(
                text: text,
                target: nil,
                clearExisting: false,
                typingDelay: 50,
                sessionId: nil)
        }
    }

    @Test("Special key actions")
    func specialKeyActions() async throws {
        let service = TypeService()

        // Test special key actions
        let actions: [TypeAction] = [
            .key(.tab),
            .key(.return),
            .key(.escape),
            .key(.space),
            .key(.upArrow),
            .key(.downArrow),
            .key(.leftArrow),
            .key(.rightArrow),
        ]

        let result = try await service.typeActions(
            actions,
            typingDelay: 50,
            sessionId: nil)

        #expect(result.keyPresses == actions.count)
    }

    @Test("New special keys")
    func newSpecialKeys() async throws {
        let service = TypeService()

        // Test newly added special keys
        let newKeyActions: [TypeAction] = [
            .key(.enter), // Numeric keypad enter
            .key(.forwardDelete), // Forward delete (fn+delete)
            .key(.capsLock), // Caps lock
            .key(.clear), // Clear key
            .key(.help), // Help key
            .key(.f1), // Function keys
            .key(.f2),
            .key(.f5),
            .key(.f10),
            .key(.f12),
        ]

        let result = try await service.typeActions(
            newKeyActions,
            typingDelay: 50,
            sessionId: nil)

        #expect(result.keyPresses == newKeyActions.count)
    }

    @Test("Escape sequences in text")
    func escapeSequencesInText() async throws {
        let service = TypeService()

        // Test escape sequences converted to TypeActions
        // Note: The actual escape sequence processing happens in TypeCommand,
        // but we can test that the service handles the resulting actions correctly
        let actionsWithEscapes: [TypeAction] = [
            .text("Line 1"),
            .key(.return), // \n
            .text("Name:"),
            .key(.tab), // \t
            .text("John"),
            .key(.delete), // \b
            .text("Jane"),
            .key(.escape), // \e
            .text("Path: C:"),
            .text("\\"), // Literal backslash
            .text("data"),
        ]

        let result = try await service.typeActions(
            actionsWithEscapes,
            typingDelay: 10,
            sessionId: nil)

        #expect(result.totalCharacters > 0)
        #expect(result.keyPresses > 0)
    }

    @Test("Mixed text and special keys")
    func mixedTextAndKeys() async throws {
        let service = TypeService()

        // Test mixing text and various special keys
        let mixedActions: [TypeAction] = [
            .text("Username"),
            .key(.tab),
            .text("john.doe@example.com"),
            .key(.tab),
            .text("Password123"),
            .key(.return),
            .clear,
            .text("New session"),
            .key(.f1), // Help
            .key(.escape),
        ]

        let result = try await service.typeActions(
            mixedActions,
            typingDelay: 20,
            sessionId: nil)

        // Count expected key presses
        let expectedKeyPresses = mixedActions.count(where: { action in
            if case .key = action { return true }
            if case .clear = action { return true }
            return false
        })

        #expect(result.keyPresses >= expectedKeyPresses)
    }

    @Test("All function keys")
    func allFunctionKeys() async throws {
        let service = TypeService()

        // Test all function keys F1-F12
        let functionKeyActions: [TypeAction] = (1...12).map { num in
            .key(SpecialKey(rawValue: "f\(num)")!)
        }

        let result = try await service.typeActions(
            functionKeyActions,
            typingDelay: 30,
            sessionId: nil)

        #expect(result.keyPresses == 12)
    }
}
