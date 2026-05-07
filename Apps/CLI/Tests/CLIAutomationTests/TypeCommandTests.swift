import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooCLI

@Suite(.tags(.safe))
struct TypeCommandTests {
    @Test
    func `Type command with text argument`() throws {
        let command = try TypeCommand.parse(["Hello World", "--json"])

        #expect(command.text == "Hello World")
        #expect(command.jsonOutput == true)
        #expect(command.delay == 2) // default delay
        #expect(command.pressReturn == false)
        #expect(command.clear == false)
    }

    @Test
    func `Type command with --text option`() throws {
        let command = try TypeCommand.parse(["--text", "Option Text", "--json"])

        #expect(command.text == nil)
        #expect(command.textOption == "Option Text")
    }

    @Test
    func `Type command with special keys`() throws {
        let command = try TypeCommand.parse(["--tab", "2", "--return", "--json"])

        #expect(command.text == nil)
        #expect(command.tab == 2)
        #expect(command.pressReturn == true)
        #expect(command.escape == false)
        #expect(command.delete == false)
    }

    @Test
    func `Type command with clear flag`() throws {
        let command = try TypeCommand.parse(["New Text", "--clear", "--json"])

        #expect(command.text == "New Text")
        #expect(command.clear == true)
        #expect(command.delay == 2) // default delay
    }

    @Test
    func `Type command with custom delay`() throws {
        let command = try TypeCommand.parse(["Fast", "--delay", "0", "--json"])

        #expect(command.text == "Fast")
        #expect(command.delay == 0)
    }

    @Test
    func `Type command with human typing speed`() throws {
        var command = try TypeCommand.parse(["Message", "--wpm", "140", "--json"])
        #expect(command.wordsPerMinute == 140)
        #expect(command.delay == 2)
        // Validation should allow the selected range
        try command.validate()
    }

    @Test
    func `Type command with linear profile`() throws {
        var command = try TypeCommand.parse(["Hello", "--profile", "linear", "--delay", "15"])
        #expect(command.profileOption?.lowercased() == "linear")
        #expect(command.delay == 15)
        #expect(command.wordsPerMinute == nil)
        try command.validate()
    }

    @Test
    func `Type command rejects invalid WPM`() throws {
        var command = try TypeCommand.parse(["Hello", "--wpm", "20"])
        do {
            try command.validate()
            Issue.record("Expected validation failure for WPM outside allowed range")
        } catch {
            let description = String(describing: error)
            #expect(description.contains("--wpm must be between 80 and 220"))
        }
    }

    @Test
    func `Type command rejects WPM with linear profile`() throws {
        var command = try TypeCommand.parse(["Hello", "--profile", "linear", "--wpm", "140"])
        do {
            try command.validate()
            Issue.record("Expected validation failure for linear profile with WPM")
        } catch {
            let description = String(describing: error)
            #expect(description.contains("--wpm is only valid when --profile human"))
        }
    }

    @Test
    func `Type execution defaults to human cadence`() async throws {
        let context = await self.makeContext()
        let result = try await self.runType(arguments: ["Hello"], context: context)

        #expect(result.exitStatus == 0)
        let call = try #require(await self.automationState(context) { $0.typeActionsCalls.first })
        if case let .human(wordsPerMinute) = call.cadence {
            #expect(wordsPerMinute == 140)
        } else {
            Issue.record("Expected human cadence")
        }
    }

    @Test
    func `Type execution honors linear profile and delay`() async throws {
        let context = await self.makeContext()
        let result = try await self.runType(
            arguments: ["Hello", "--profile", "linear", "--delay", "15"],
            context: context
        )

        #expect(result.exitStatus == 0)
        let call = try #require(await self.automationState(context) { $0.typeActionsCalls.first })
        if case let .fixed(milliseconds) = call.cadence {
            #expect(milliseconds == 15)
        } else {
            Issue.record("Expected linear cadence")
        }
    }

    @Test
    func `Type execution reuses latest snapshot when target is implicit`() async throws {
        let context = await self.makeContext()
        let snapshotId = try await context.snapshots.createSnapshot()

        let result = try await self.runType(arguments: ["Hello", "--no-auto-focus"], context: context)

        #expect(result.exitStatus == 0)
        let call = try #require(await self.automationState(context) { $0.typeActionsCalls.first })
        #expect(call.snapshotId == snapshotId)
    }

    @Test
    func `Type execution does not reuse latest snapshot with explicit app target`() async throws {
        let context = await self.makeContext()
        _ = try await context.snapshots.createSnapshot()

        let result = try await self.runType(
            arguments: ["Hello", "--app", "TextEdit", "--no-auto-focus"],
            context: context
        )

        #expect(result.exitStatus == 0)
        let call = try #require(await self.automationState(context) { $0.typeActionsCalls.first })
        #expect(call.snapshotId == nil)
    }

    @Test
    func `Type command argument parsing`() throws {
        let command = try TypeCommand.parse(["Hello World", "--delay", "10", "--return"])

        #expect(command.text == "Hello World")
        #expect(command.delay == 10)
        #expect(command.pressReturn == true)
    }

    @Test
    func `Type command with all special keys`() throws {
        let command = try TypeCommand.parse([
            "Test",
            "--clear",
            "--tab",
            "1",
            "--return",
            "--escape",
            "--delete",
            "--json"
        ])

        #expect(command.text == "Test")
        #expect(command.clear == true)
        #expect(command.tab == 1)
        #expect(command.pressReturn == true)
        #expect(command.escape == true)
        #expect(command.delete == true)
    }

    @Test
    func `Process text with escape sequences`() {
        // Test newline escape
        let newlineActions = TypeCommand.processTextWithEscapes("Line 1\\nLine 2")
        #expect(newlineActions.count == 3)
        if case .text("Line 1") = newlineActions[0] { } else { Issue.record("Expected text 'Line 1'") }
        if case .key(.return) = newlineActions[1] { } else { Issue.record("Expected return key") }
        if case .text("Line 2") = newlineActions[2] { } else { Issue.record("Expected text 'Line 2'") }

        // Test tab escape
        let tabActions = TypeCommand.processTextWithEscapes("Name:\\tJohn")
        #expect(tabActions.count == 3)
        if case .text("Name:") = tabActions[0] { } else { Issue.record("Expected text 'Name:'") }
        if case .key(.tab) = tabActions[1] { } else { Issue.record("Expected tab key") }
        if case .text("John") = tabActions[2] { } else { Issue.record("Expected text 'John'") }

        // Test backspace escape
        let backspaceActions = TypeCommand.processTextWithEscapes("ABC\\b")
        #expect(backspaceActions.count == 2)
        if case .text("ABC") = backspaceActions[0] { } else { Issue.record("Expected text 'ABC'") }
        if case .key(.delete) = backspaceActions[1] { } else { Issue.record("Expected delete key") }

        // Test escape key
        let escapeActions = TypeCommand.processTextWithEscapes("Cancel\\e")
        #expect(escapeActions.count == 2)
        if case .text("Cancel") = escapeActions[0] { } else { Issue.record("Expected text 'Cancel'") }
        if case .key(.escape) = escapeActions[1] { } else { Issue.record("Expected escape key") }

        // Test literal backslash
        let backslashActions = TypeCommand.processTextWithEscapes("Path: C\\\\data")
        #expect(backslashActions.count == 1)
        if case let .text(value) = backslashActions[0] {
            #expect(value == "Path: C\\data", "Value was: \(value)")
        } else {
            Issue.record("Expected text with backslash")
        }
    }

    @Test
    func `Complex escape sequence combinations`() {
        // Test multiple escape sequences
        let complexActions = TypeCommand.processTextWithEscapes("Line 1\\nLine 2\\tTabbed\\bFixed\\eEsc\\\\Path")
        #expect(complexActions.count == 9)

        // Verify the sequence
        if case .text("Line 1") = complexActions[0] { } else { Issue.record("Expected 'Line 1'") }
        if case .key(.return) = complexActions[1] { } else { Issue.record("Expected return") }
        if case .text("Line 2") = complexActions[2] { } else { Issue.record("Expected 'Line 2'") }
        if case .key(.tab) = complexActions[3] { } else { Issue.record("Expected tab") }
        if case .text("Tabbed") = complexActions[4] { } else { Issue.record("Expected 'Tabbed'") }
        if case .key(.delete) = complexActions[5] { } else { Issue.record("Expected delete") }
        if case .text("Fixed") = complexActions[6] { } else { Issue.record("Expected 'Fixed'") }
        if case .key(.escape) = complexActions[7] { } else { Issue.record("Expected escape") }
        if case .text("Esc\\Path") = complexActions[8] { } else { Issue.record("Expected 'Esc\\Path'") }
    }

    @Test
    func `Empty and edge case escape sequences`() {
        // Empty text
        let emptyActions = TypeCommand.processTextWithEscapes("")
        #expect(emptyActions.isEmpty)

        // Only escape sequences
        let onlyEscapes = TypeCommand.processTextWithEscapes("\\n\\t\\b\\e")
        #expect(onlyEscapes.count == 4)

        // Text ending with incomplete escape
        let incompleteEscape = TypeCommand.processTextWithEscapes("Text\\\\")
        #expect(incompleteEscape.count == 1)
        if case .text("Text\\") = incompleteEscape[0] { } else { Issue.record("Expected 'Text\\'") }

        // Multiple consecutive escapes
        let consecutiveEscapes = TypeCommand.processTextWithEscapes("Text\\n\\n\\t\\t")
        #expect(consecutiveEscapes.count == 5)
        if case .text("Text") = consecutiveEscapes[0] { } else { Issue.record("Expected 'Text'") }
        if case .key(.return) = consecutiveEscapes[1] { } else { Issue.record("Expected return") }
        if case .key(.return) = consecutiveEscapes[2] { } else { Issue.record("Expected return") }
        if case .key(.tab) = consecutiveEscapes[3] { } else { Issue.record("Expected tab") }
        if case .key(.tab) = consecutiveEscapes[4] { } else { Issue.record("Expected tab") }
    }

    @Test
    func `Parse type command with escape sequences`() throws {
        // Test parsing text with escape sequences
        // Note: The escape sequences are processed at runtime, not during parsing
        let command = try TypeCommand.parse(["Line 1\\nLine 2", "--delay", "50"])

        #expect(command.text == "Line 1\\nLine 2")
        #expect(command.delay == 50)
    }

    // MARK: - Helpers

    private func runType(
        arguments: [String],
        context: TestServicesFactory.AutomationTestContext
    ) async throws -> CommandRunResult {
        try await InProcessCommandRunner.run(["type"] + arguments, services: context.services)
    }

    @MainActor
    private func makeContext(
        configure: ((StubAutomationService, StubSnapshotManager) -> Void)? = nil
    ) async -> TestServicesFactory.AutomationTestContext {
        await MainActor.run {
            let context = TestServicesFactory.makeAutomationTestContext()
            configure?(context.automation, context.snapshots)
            return context
        }
    }

    @MainActor
    private func automationState<T: Sendable>(
        _ context: TestServicesFactory.AutomationTestContext,
        _ operation: (StubAutomationService) -> T
    ) async -> T {
        await MainActor.run {
            operation(context.automation)
        }
    }
}
