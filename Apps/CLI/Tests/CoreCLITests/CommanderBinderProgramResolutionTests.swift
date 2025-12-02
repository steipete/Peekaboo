import Commander
import Testing
@testable import PeekabooCLI

@Suite("Commander Binder Program Resolution")
struct CommanderBinderProgramResolutionTests {
    @Test("Commander program resolves image command options")
    @MainActor
    func commanderResolvesImageOptions() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "image",
            "--app", "Safari",
            "--window-title", "Inbox",
            "--mode", "screen",
            "--path", "/tmp/sample.png"
        ])
        let values = invocation.parsedValues
        #expect(values.options["app"] == ["Safari"])
        #expect(values.options["windowTitle"] == ["Inbox"])
        #expect(values.options["mode"] == ["screen"])
        #expect(values.options["path"] == ["/tmp/sample.png"])
    }

    @Test("Commander program resolves see command flags")
    @MainActor
    func commanderResolvesSeeCommand() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "see",
            "--app", "Mail",
            "--annotate",
            "--screen-index", "1",
            "--analyze", "describe"
        ])
        let values = invocation.parsedValues
        #expect(values.options["app"] == ["Mail"])
        #expect(values.options["screenIndex"] == ["1"])
        #expect(values.options["analyze"] == ["describe"])
        #expect(values.flags.contains("annotate"))
    }

    @Test("Commander program resolves list windows options")
    @MainActor
    func commanderResolvesListWindows() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "list",
            "windows",
            "--app", "Safari",
            "--include-details", "ids,bounds"
        ])
        let values = invocation.parsedValues
        #expect(values.options["app"] == ["Safari"])
        #expect(values.options["includeDetails"] == ["ids,bounds"])
    }

    @Test("Commander program resolves click options and focus flags")
    @MainActor
    func commanderResolvesClickCommand() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "click",
            "\"Submit\"",
            "--session", "abc",
            "--on", "B1",
            "--app", "Safari",
            "--wait-for", "2500",
            "--no-auto-focus",
            "--space-switch"
        ])
        let values = invocation.parsedValues
        #expect(values.positional == ["\"Submit\""])
        #expect(values.options["session"] == ["abc"])
        #expect(values.options["on"] == ["B1"])
        #expect(values.options["app"] == ["Safari"])
        #expect(values.options["waitFor"] == ["2500"])
        #expect(values.flags.contains("noAutoFocus"))
        #expect(values.flags.contains("spaceSwitch"))
    }

    @Test("Commander program resolves type command options")
    @MainActor
    func commanderResolvesTypeCommand() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "type",
            "Hello",
            "--session", "xyz",
            "--delay", "10",
            "--tab", "2",
            "--return",
            "--escape",
            "--delete",
            "--clear",
            "--app", "Notes",
            "--focus-timeout-seconds", "3.5",
            "--space-switch"
        ])
        let values = invocation.parsedValues
        #expect(values.positional == ["Hello"])
        #expect(values.options["session"] == ["xyz"])
        #expect(values.options["delay"] == ["10"])
        #expect(values.options["tab"] == ["2"])
        #expect(values.options["app"] == ["Notes"])
        #expect(values.flags.contains("pressReturn"))
        #expect(values.flags.contains("escape"))
        #expect(values.flags.contains("delete"))
        #expect(values.flags.contains("clear"))
        #expect(values.options["focusTimeoutSeconds"] == ["3.5"])
        #expect(values.flags.contains("spaceSwitch"))
    }

    @Test("Commander program resolves press command options")
    @MainActor
    func commanderResolvesPressCommand() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "press",
            "cmd",
            "c",
            "--count", "3",
            "--delay", "25",
            "--hold", "75",
            "--session", "sess-1",
            "--no-auto-focus"
        ])
        let values = invocation.parsedValues
        #expect(values.positional == ["cmd", "c"])
        #expect(values.options["count"] == ["3"])
        #expect(values.options["delay"] == ["25"])
        #expect(values.options["hold"] == ["75"])
        #expect(values.options["session"] == ["sess-1"])
        #expect(values.flags.contains("noAutoFocus"))
    }

    @Test("Commander program resolves capture video input positional")
    @MainActor
    func commanderResolvesCaptureVideoInput() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "capture",
            "video",
            "/tmp/demo.mov",
            "--sample-fps", "3"
        ])
        let values = invocation.parsedValues
        #expect(values.positional == ["/tmp/demo.mov"])
        #expect(values.options["sampleFps"] == ["3"])
    }

    @Test("Commander program resolves list default to apps")
    @MainActor
    func commanderResolvesListDefaultApps() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "list",
            "--json-output"
        ])
        #expect(invocation.path == ["list", "apps"])
        #expect(invocation.parsedValues.flags.contains("jsonOutput"))
    }

    @Test("Commander program resolves list menubar")
    @MainActor
    func commanderResolvesListMenubar() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "list",
            "menubar"
        ])
        #expect(invocation.path == ["list", "menubar"])
    }

    @Test("Commander program resolves list screens")
    @MainActor
    func commanderResolvesListScreens() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "list",
            "screens"
        ])
        #expect(invocation.path == ["list", "screens"])
    }

    @Test("Commander program resolves scroll command options")
    @MainActor
    func commanderResolvesScrollCommand() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "scroll",
            "--direction", "down",
            "--amount", "7",
            "--on", "B4",
            "--session", "sess-5",
            "--delay", "5",
            "--smooth",
            "--app", "Mail",
            "--bring-to-current-space"
        ])
        let values = invocation.parsedValues
        #expect(values.options["direction"] == ["down"])
        #expect(values.options["amount"] == ["7"])
        #expect(values.options["on"] == ["B4"])
        #expect(values.options["session"] == ["sess-5"])
        #expect(values.options["delay"] == ["5"])
        #expect(values.flags.contains("smooth"))
        #expect(values.options["app"] == ["Mail"])
        #expect(values.flags.contains("bringToCurrentSpace"))
    }

    @Test("Commander program resolves hotkey command options")
    @MainActor
    func commanderResolvesHotkeyCommand() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "hotkey",
            "--keys", "cmd,c",
            "--hold-duration", "120",
            "--session", "sess-11",
            "--no-auto-focus"
        ])
        let values = invocation.parsedValues
        #expect(values.options["keys"] == ["cmd,c"])
        #expect(values.options["holdDuration"] == ["120"])
        #expect(values.options["session"] == ["sess-11"])
        #expect(values.flags.contains("noAutoFocus"))
    }

    @Test("Commander program resolves move command options")
    @MainActor
    func commanderResolvesMoveCommand() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "move",
            "120,240",
            "--to", "Submit",
            "--id", "B2",
            "--duration", "750",
            "--steps", "30",
            "--session", "sess-20",
            "--center",
            "--smooth"
        ])
        let values = invocation.parsedValues
        #expect(values.positional == ["120,240"])
        #expect(values.options["to"] == ["Submit"])
        #expect(values.options["id"] == ["B2"])
        #expect(values.options["duration"] == ["750"])
        #expect(values.options["steps"] == ["30"])
        #expect(values.options["session"] == ["sess-20"])
        #expect(values.flags.contains("center"))
        #expect(values.flags.contains("smooth"))
    }

    @Test("Commander program resolves drag command options")
    @MainActor
    func commanderResolvesDragCommand() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "drag",
            "--from", "A1",
            "--to-coords", "300,400",
            "--session", "sess-9",
            "--duration", "900",
            "--steps", "15",
            "--modifiers", "cmd,shift",
            "--bring-to-current-space"
        ])
        let values = invocation.parsedValues
        #expect(values.options["from"] == ["A1"])
        #expect(values.options["toCoords"] == ["300,400"])
        #expect(values.options["session"] == ["sess-9"])
        #expect(values.options["duration"] == ["900"])
        #expect(values.options["steps"] == ["15"])
        #expect(values.options["modifiers"] == ["cmd,shift"])
        #expect(values.flags.contains("bringToCurrentSpace"))
    }

    @Test("Commander program resolves swipe command options")
    @MainActor
    func commanderResolvesSwipeCommand() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "swipe",
            "--from-coords", "10,20",
            "--to", "B1",
            "--session", "sess-8",
            "--duration", "600",
            "--steps", "12",
            "--right-button"
        ])
        let values = invocation.parsedValues
        #expect(values.options["fromCoords"] == ["10,20"])
        #expect(values.options["to"] == ["B1"])
        #expect(values.options["session"] == ["sess-8"])
        #expect(values.options["duration"] == ["600"])
        #expect(values.options["steps"] == ["12"])
        #expect(values.flags.contains("rightButton"))
    }
}
