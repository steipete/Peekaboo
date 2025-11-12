import Commander
import Testing
@testable import PeekabooCLI

@Suite("Commander Binder Program Resolution (Space + Dialog)")
struct CommanderBinderSpaceDialogTests {
    @Test("Commander program resolves space list options")
    @MainActor
    func commanderResolvesSpaceList() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "space",
            "list",
            "--detailed"
        ])
        let values = invocation.parsedValues
        #expect(values.flags.contains("detailed"))
    }

    @Test("Commander program resolves space switch options")
    @MainActor
    func commanderResolvesSpaceSwitch() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "space",
            "switch",
            "--to", "3"
        ])
        let values = invocation.parsedValues
        #expect(values.options["to"] == ["3"])
    }

    @Test("Commander program resolves space move-window options")
    @MainActor
    func commanderResolvesSpaceMoveWindow() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "space",
            "move-window",
            "--app", "Safari",
            "--window-title", "Inbox",
            "--window-index", "2",
            "--to", "4",
            "--follow"
        ])
        let values = invocation.parsedValues
        #expect(values.options["app"] == ["Safari"])
        #expect(values.options["windowTitle"] == ["Inbox"])
        #expect(values.options["windowIndex"] == ["2"])
        #expect(values.options["to"] == ["4"])
        #expect(values.flags.contains("follow"))
    }

    @Test("Commander program resolves dialog click options")
    @MainActor
    func commanderResolvesDialogClick() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "dialog",
            "click",
            "--button", "OK",
            "--window", "Save"
        ])
        let values = invocation.parsedValues
        #expect(values.options["button"] == ["OK"])
        #expect(values.options["window"] == ["Save"])
    }

    @Test("Commander program resolves dialog input options")
    @MainActor
    func commanderResolvesDialogInput() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "dialog",
            "input",
            "--text", "Report generated",
            "--window", "Export"
        ])
        let values = invocation.parsedValues
        #expect(values.options["text"] == ["Report generated"])
        #expect(values.options["window"] == ["Export"])
    }
}
