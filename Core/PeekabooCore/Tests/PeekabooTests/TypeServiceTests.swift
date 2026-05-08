import CoreGraphics
import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooAutomationKit
@testable import PeekabooCore
@testable import PeekabooVisualizer

#if PEEKABOO_INCLUDE_AUTOMATION_TESTS
@Suite(
    .tags(.ui, .automation),
    .enabled(if: TestEnvironment.runInputAutomationScenarios))
@MainActor
struct TypeServiceTests {
    @Test
    func `Initialize TypeService`() {
        let service: TypeService? = TypeService()
        #expect(service != nil)
    }

    @Test
    func `Type text`() async throws {
        let service = TypeService()

        // Test basic text typing
        try await service.type(
            text: "Hello World",
            target: nil,
            clearExisting: false,
            typingDelay: 50,
            snapshotId: nil)
    }

    @Test
    func `Type with special characters`() async throws {
        let service = TypeService()

        // Test typing with special characters
        let specialText = "Hello! @#$% 123 🎉"
        try await service.type(
            text: specialText,
            target: nil,
            clearExisting: false,
            typingDelay: 50,
            snapshotId: nil)
    }

    @Test
    func `Type in specific element`() async throws {
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
                snapshotId: nil)
        } catch is NotFoundError {
            // Expected in test environment
        } catch let error as PeekabooError {
            guard case .elementNotFound = error else {
                throw error
            }
            // Expected in test environment after NotFoundError factory migration.
        }
    }

    @Test
    func `Clear and type`() async throws {
        let service = TypeService()

        // Test clearing before typing
        try await service.type(
            text: "New text",
            target: nil,
            clearExisting: true,
            typingDelay: 50,
            snapshotId: nil)
    }

    @Test
    func `Type actions`() async throws {
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
            cadence: .fixed(milliseconds: 50),
            snapshotId: nil)

        #expect(result.totalCharacters > 0)
        #expect(result.keyPresses > 0)
    }

    @Test
    func `Type with fast speed`() async throws {
        let service = TypeService()

        // Test typing with no delay
        try await service.type(
            text: "Fast typing",
            target: nil,
            clearExisting: false,
            typingDelay: 0,
            snapshotId: nil)
    }

    @Test
    func `Type with slow speed`() async throws {
        let service = TypeService()

        // Test typing with delay
        let startTime = Date()
        try await service.type(
            text: "Slow",
            target: nil,
            clearExisting: false,
            typingDelay: 100, // 100ms between characters
            snapshotId: nil)
        let duration = Date().timeIntervalSince(startTime)

        // Should take at least 300ms for 4 characters (3 delays)
        #expect(duration >= 0.3)
    }

    @Test
    func `Empty text handling`() async throws {
        let service = TypeService()

        // Should handle empty text gracefully
        try await service.type(
            text: "",
            target: nil,
            clearExisting: false,
            typingDelay: 50,
            snapshotId: nil)
    }

    @Test
    func `Unicode text`() async throws {
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
                snapshotId: nil)
        }
    }

    @Test
    func `Special key actions`() async throws {
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
            cadence: .fixed(milliseconds: 50),
            snapshotId: nil)

        #expect(result.keyPresses == actions.count)
    }

    @Test
    func `New special keys`() async throws {
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
            cadence: .fixed(milliseconds: 50),
            snapshotId: nil)

        #expect(result.keyPresses == newKeyActions.count)
    }

    @Test
    func `Escape sequences in text`() async throws {
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
            cadence: .fixed(milliseconds: 10),
            snapshotId: nil)

        #expect(result.totalCharacters > 0)
        #expect(result.keyPresses > 0)
    }

    @Test
    func `Mixed text and special keys`() async throws {
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
            cadence: .fixed(milliseconds: 20),
            snapshotId: nil)

        // Count expected key presses
        let expectedKeyPresses = mixedActions.count(where: { action in
            if case .key = action { return true }
            if case .clear = action { return true }
            return false
        })

        #expect(result.keyPresses >= expectedKeyPresses)
    }

    @Test
    func `All function keys`() async throws {
        let service = TypeService()

        // Test all function keys F1-F12
        let functionKeyActions: [TypeAction] = (1...12).map { num in
            .key(SpecialKey(rawValue: "f\(num)")!)
        }

        let result = try await service.typeActions(
            functionKeyActions,
            cadence: .fixed(milliseconds: 30),
            snapshotId: nil)

        #expect(result.keyPresses == 12)
    }

    @Test
    func `Human cadence typing uses WPM profile`() async throws {
        let randomSource = DeterministicTypingRandomSource(values: [0.2, 0.8, 0.4, 0.6])
        let service = TypeService(randomSource: randomSource)

        let actions: [TypeAction] = [
            .text("Hi"),
            .key(.space),
            .text("there"),
        ]

        let startTime = Date()
        let result = try await service.typeActions(
            actions,
            cadence: .human(wordsPerMinute: 140),
            snapshotId: nil)

        #expect(result.totalCharacters == 7)
        #expect(result.keyPresses >= 8)
        #expect(randomSource.producedCount > 0)
        #expect(Date().timeIntervalSince(startTime) > 0)
    }
}

final class DeterministicTypingRandomSource: TypingCadenceRandomSource {
    private let values: [Double]
    private var index = 0
    var producedCount = 0

    init(values: [Double]) {
        self.values = values
    }

    func nextUnitInterval() -> Double {
        guard !self.values.isEmpty else { return 0.5 }
        let value = self.values[self.index % self.values.count]
        self.index += 1
        self.producedCount += 1
        return value
    }
}

extension DeterministicTypingRandomSource: @unchecked Sendable {}
#endif
