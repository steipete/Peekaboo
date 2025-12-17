import Commander
import Testing
@testable import PeekabooCLI

@Suite("Commander Binder Command Binding")
struct CommanderBinderCommandBindingTests {
    @Test("Sleep command duration binding")
    func bindSleepCommand() throws {
        let parsed = ParsedValues(positional: ["2500"], options: [:], flags: [])
        let command = try CommanderCLIBinder.instantiateCommand(ofType: SleepCommand.self, parsedValues: parsed)
        #expect(command.duration == 2500)
    }

    @Test("Sleep command binding errors")
    func bindSleepCommandErrors() {
        let missing = ParsedValues(positional: [], options: [:], flags: [])
        #expect(throws: CommanderBindingError.missingArgument(label: "duration")) {
            _ = try CommanderCLIBinder.instantiateCommand(ofType: SleepCommand.self, parsedValues: missing)
        }

        let invalid = ParsedValues(positional: ["abc"], options: [:], flags: [])
        #expect(throws: CommanderBindingError.invalidArgument(
            label: "duration",
            value: "abc",
            reason: "Unable to parse Int"
        )) {
            _ = try CommanderCLIBinder.instantiateCommand(ofType: SleepCommand.self, parsedValues: invalid)
        }
    }

    @Test("Clean command option + flag binding")
    func bindCleanCommand() throws {
        let parsed = ParsedValues(
            positional: [],
            options: ["olderThan": ["48"], "snapshot": ["ignored"]],
            flags: ["dryRun"]
        )
        var command = try CommanderCLIBinder.instantiateCommand(ofType: CleanCommand.self, parsedValues: parsed)
        #expect(command.dryRun == true)
        #expect(command.olderThan == 48)
        #expect(command.snapshot == "ignored")

        let allSnapshots = ParsedValues(positional: [], options: [:], flags: ["allSnapshots"])
        command = try CommanderCLIBinder.instantiateCommand(ofType: CleanCommand.self, parsedValues: allSnapshots)
        #expect(command.allSnapshots == true)
    }

    @Test("Run command binding")
    func bindRunCommand() throws {
        let parsed = ParsedValues(
            positional: ["/tmp/demo.peekaboo.json"],
            options: ["output": ["/tmp/result.json"]],
            flags: ["noFailFast"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: RunCommand.self, parsedValues: parsed)
        #expect(command.scriptPath == "/tmp/demo.peekaboo.json")
        #expect(command.output == "/tmp/result.json")
        #expect(command.noFailFast == true)
    }

    @Test("Run command requires script path")
    func bindRunCommandErrors() {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        #expect(throws: CommanderBindingError.missingArgument(label: "scriptPath")) {
            _ = try CommanderCLIBinder.instantiateCommand(ofType: RunCommand.self, parsedValues: parsed)
        }
    }

    @Test("Image command binding")
    func bindImageCommand() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "app": ["Safari"],
                "pid": ["123"],
                "path": ["/tmp/out.jpg"],
                "mode": ["screen"],
                "windowTitle": ["Inbox"],
                "windowIndex": ["2"],
                "screenIndex": ["1"],
                "format": ["jpg"],
                "captureFocus": ["foreground"],
                "analyze": ["describe"]
            ],
            flags: []
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: ImageCommand.self, parsedValues: parsed)
        #expect(command.app == "Safari")
        #expect(command.pid == 123)
        #expect(command.path == "/tmp/out.jpg")
        #expect(command.mode == .screen)
        #expect(command.windowTitle == "Inbox")
        #expect(command.windowIndex == 2)
        #expect(command.screenIndex == 1)
        #expect(command.format == .jpg)
        #expect(command.captureFocus == .foreground)
        #expect(command.analyze == "describe")
    }

    @Test("Image command invalid mode")
    func bindImageCommandErrors() {
        let parsed = ParsedValues(positional: [], options: ["mode": ["banana"]], flags: [])
        #expect(throws: CommanderBindingError.invalidArgument(
            label: "mode",
            value: "banana",
            reason: "Unknown value for CaptureMode"
        )) {
            _ = try CommanderCLIBinder.instantiateCommand(ofType: ImageCommand.self, parsedValues: parsed)
        }
    }

    @Test("See command binding")
    func bindSeeCommand() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "app": ["Safari"],
                "pid": ["4321"],
                "windowTitle": ["Inbox"],
                "mode": ["screen"],
                "path": ["/tmp/see.png"],
                "screenIndex": ["2"],
                "analyze": ["describe"]
            ],
            flags: ["annotate"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: SeeCommand.self, parsedValues: parsed)
        #expect(command.app == "Safari")
        #expect(command.pid == 4321)
        #expect(command.windowTitle == "Inbox")
        #expect(command.mode == .screen)
        #expect(command.path == "/tmp/see.png")
        #expect(command.screenIndex == 2)
        #expect(command.annotate == true)
        #expect(command.analyze == "describe")
    }

    @Test("Tools command binding")
    func bindToolsCommand() throws {
        let parsed = ParsedValues(
            positional: [],
            options: ["mcp": ["github"]],
            flags: ["nativeOnly", "includeDisabled", "noSort", "groupByServer"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: ToolsCommand.self, parsedValues: parsed)
        #expect(command.nativeOnly == true)
        #expect(command.mcpOnly == false)
        #expect(command.includeDisabled == true)
        #expect(command.noSort == true)
        #expect(command.groupByServer == true)
        #expect(command.mcp == "github")
    }

    @Test("List menubar binding")
    func bindListMenubarCommand() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        _ = try CommanderCLIBinder.instantiateCommand(ofType: ListCommand.MenuBarSubcommand.self, parsedValues: parsed)
    }

    @Test("List windows binding")
    func bindListWindowsCommand() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "app": ["Safari"],
                "pid": ["123"],
                "includeDetails": ["bounds,ids"]
            ],
            flags: []
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: ListCommand.WindowsSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.app == "Safari")
        #expect(command.pid == 123)
        #expect(command.includeDetails == "bounds,ids")
    }

    @Test("List windows requires app")
    func bindListWindowsCommandError() {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        #expect(throws: CommanderBindingError.missingArgument(label: "app")) {
            _ = try CommanderCLIBinder.instantiateCommand(
                ofType: ListCommand.WindowsSubcommand.self,
                parsedValues: parsed
            )
        }
    }

    @Test("Permissions status binding")
    func bindPermissionsStatus() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        _ = try CommanderCLIBinder.instantiateCommand(
            ofType: PermissionsCommand.StatusSubcommand.self,
            parsedValues: parsed
        )
    }

    @Test("Permissions grant binding")
    func bindPermissionsGrant() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        _ = try CommanderCLIBinder.instantiateCommand(
            ofType: PermissionsCommand.GrantSubcommand.self,
            parsedValues: parsed
        )
    }

    @Test("Window close binding populates identification options")
    func bindWindowClose() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "app": ["Safari"],
                "pid": ["4321"],
                "windowTitle": ["Inbox"],
                "windowIndex": ["2"]
            ],
            flags: []
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: WindowCommand.CloseSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.windowOptions.app == "Safari")
        #expect(command.windowOptions.pid == 4321)
        #expect(command.windowOptions.windowTitle == "Inbox")
        #expect(command.windowOptions.windowIndex == 2)
    }

    @Test("Window move binding handles coordinates")
    func bindWindowMove() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "app": ["Safari"],
                "x": ["120"],
                "y": ["340"]
            ],
            flags: []
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: WindowCommand.MoveSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.windowOptions.app == "Safari")
        #expect(command.x == 120)
        #expect(command.y == 340)
    }

    @Test("Window move requires coordinates")
    func bindWindowMoveMissingCoordinate() {
        let parsed = ParsedValues(
            positional: [],
            options: ["app": ["Safari"], "x": ["50"]],
            flags: []
        )
        #expect(throws: CommanderBindingError.missingArgument(label: "y")) {
            _ = try CommanderCLIBinder.instantiateCommand(
                ofType: WindowCommand.MoveSubcommand.self,
                parsedValues: parsed
            )
        }
    }

    @Test("Window focus binding maps focus options")
    func bindWindowFocus() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "app": ["Terminal"],
                "focusTimeoutSeconds": ["5.5"],
                "focusRetryCountValue": ["3"]
            ],
            flags: ["noAutoFocus", "spaceSwitch", "bringToCurrentSpace"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: WindowCommand.FocusSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.windowOptions.app == "Terminal")
        #expect(command.focusOptions.noAutoFocus == true)
        #expect(command.focusOptions.spaceSwitch == true)
        #expect(command.focusOptions.bringToCurrentSpace == true)
        #expect(command.focusOptions.focusTimeoutSeconds == 5.5)
        #expect(command.focusOptions.focusRetryCountValue == 3)
    }

    @Test("Window list binding")
    func bindWindowList() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "app": ["Finder"],
                "pid": ["999"]
            ],
            flags: []
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: WindowCommand.WindowListSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.app == "Finder")
        #expect(command.pid == 999)
    }

    @Test("Click command binding")
    func bindClickCommand() throws {
        let parsed = ParsedValues(
            positional: ["Submit"],
            options: [
                "snapshot": ["abc"],
                "on": ["B1"],
                "app": ["Safari"],
                "waitFor": ["2500"]
            ],
            flags: ["double", "noAutoFocus"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: ClickCommand.self, parsedValues: parsed)
        #expect(command.query == "Submit")
        #expect(command.snapshot == "abc")
        #expect(command.on == "B1")
        #expect(command.app == "Safari")
        #expect(command.waitFor == 2500)
        #expect(command.double == true)
        #expect(command.focusOptions.noAutoFocus == true)
    }

    @Test("Type command binding")
    func bindTypeCommand() throws {
        let parsed = ParsedValues(
            positional: ["Hello"],
            options: [
                "snapshot": ["xyz"],
                "delay": ["10"],
                "wpm": ["150"],
                "tab": ["2"],
                "app": ["Notes"],
                "focusTimeoutSeconds": ["3.5"]
            ],
            flags: ["pressReturn", "escape", "delete", "clear", "spaceSwitch"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: TypeCommand.self, parsedValues: parsed)
        #expect(command.text == "Hello")
        #expect(command.snapshot == "xyz")
        #expect(command.delay == 10)
        #expect(command.profileOption?.lowercased() == "human")
        #expect(command.wordsPerMinute == 150)
        #expect(command.tab == 2)
        #expect(command.pressReturn == true)
        #expect(command.escape == true)
        #expect(command.delete == true)
        #expect(command.clear == true)
        #expect(command.app == "Notes")
        #expect(command.focusOptions.spaceSwitch == true)
        #expect(command.focusOptions.focusTimeoutSeconds == 3.5)
    }

    @Test("Type command binding with text option")
    func bindTypeCommandTextOption() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "text": ["OptionText"],
                "snapshot": ["abc"]
            ],
            flags: []
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: TypeCommand.self, parsedValues: parsed)
        #expect(command.text == nil)
        #expect(command.textOption == "OptionText")
        #expect(command.snapshot == "abc")
    }

    @Test("Press command binding")
    func bindPressCommand() throws {
        let parsed = ParsedValues(
            positional: ["cmd", "c"],
            options: [
                "count": ["3"],
                "delay": ["25"],
                "hold": ["75"],
                "snapshot": ["sess-123"]
            ],
            flags: ["noAutoFocus"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: PressCommand.self, parsedValues: parsed)
        #expect(command.keys == ["cmd", "c"])
        #expect(command.count == 3)
        #expect(command.delay == 25)
        #expect(command.hold == 75)
        #expect(command.snapshot == "sess-123")
        #expect(command.focusOptions.noAutoFocus == true)
    }

    @Test("Capture video command binding")
    func bindCaptureVideoCommand() throws {
        let parsed = ParsedValues(
            positional: ["/tmp/demo.mov"],
            options: [
                "sampleFps": ["2"],
                "startMs": ["1000"],
                "endMs": ["2000"],
                "maxFrames": ["123"],
                "maxMb": ["10"],
                "resolutionCap": ["720"],
                "diffStrategy": ["quality"],
                "diffBudgetMs": ["50"],
                "path": ["/tmp/outdir"],
                "autocleanMinutes": ["15"],
                "videoOut": ["/tmp/out.mp4"]
            ],
            flags: ["noDiff"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: CaptureVideoCommand.self,
            parsedValues: parsed
        )
        #expect(command.input == "/tmp/demo.mov")
        #expect(command.sampleFps == 2)
        #expect(command.everyMs == nil)
        #expect(command.startMs == 1000)
        #expect(command.endMs == 2000)
        #expect(command.noDiff == true)
        #expect(command.maxFrames == 123)
        #expect(command.maxMb == 10)
        #expect(command.resolutionCap == 720)
        #expect(command.diffStrategy == "quality")
        #expect(command.diffBudgetMs == 50)
        #expect(command.path == "/tmp/outdir")
        #expect(command.autocleanMinutes == 15)
        #expect(command.videoOut == "/tmp/out.mp4")
    }

    @Test("Capture video commander signature exposes required input")
    func captureVideoCommanderSignatureHasInputArgument() {
        let signature = CaptureVideoCommand.commanderSignature()
        let input = signature.arguments.first { $0.label == "input" }
        #expect(input?.isOptional == false)
        #expect(input?.help == "Input video file")
    }

    @Test("Capture video command requires input")
    func bindCaptureVideoCommandRequiresInput() {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        #expect(throws: CommanderBindingError.missingArgument(label: "input")) {
            _ = try CommanderCLIBinder.instantiateCommand(
                ofType: CaptureVideoCommand.self,
                parsedValues: parsed
            )
        }
    }

    @Test("Hotkey command binding (positional wins)")
    func bindHotkeyCommand() throws {
        let parsed = ParsedValues(
            positional: ["cmd,space"],
            options: ["keys": ["cmd,c"], "holdDuration": ["120"]],
            flags: []
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: HotkeyCommand.self, parsedValues: parsed)
        #expect(command.resolvedKeys == "cmd,space")
        #expect(command.holdDuration == 120)
    }

    @Test("Hotkey command requires keys")
    func bindHotkeyCommandMissingKeys() {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        #expect(throws: ValidationError.self) {
            _ = try CommanderCLIBinder.instantiateCommand(ofType: HotkeyCommand.self, parsedValues: parsed)
        }
    }

    @Test("See command respects capture-engine option")
    func bindSeeCommandCaptureEngine() throws {
        let parsed = ParsedValues(
            positional: [],
            options: ["captureEngine": ["classic"]],
            flags: []
        )

        let runtimeOptions = try CommanderCLIBinder.makeRuntimeOptions(from: parsed)
        #expect(runtimeOptions.captureEnginePreference == "classic")
    }

    @Test("Move command binding with coordinates")
    func bindMoveCommand() throws {
        let parsed = ParsedValues(
            positional: ["100,200"],
            options: [
                "duration": ["750"],
                "steps": ["30"],
                "profile": ["human"],
                "snapshot": ["sess-1"]
            ],
            flags: ["smooth"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: MoveCommand.self, parsedValues: parsed)
        #expect(command.coordinates == "100,200")
        #expect(command.duration == 750)
        #expect(command.steps == 30)
        #expect(command.profile == "human")
        #expect(command.snapshot == "sess-1")
        #expect(command.smooth == true)
    }

    @Test("Move command requires a target (validation)")
    func bindMoveCommandMissingTarget() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        var command = try CommanderCLIBinder.instantiateCommand(ofType: MoveCommand.self, parsedValues: parsed)
        #expect(throws: ValidationError.self) {
            try command.validate()
        }
    }

    @Test("Drag command binding")
    func bindDragCommand() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "from": ["B1"],
                "to": ["T2"],
                "duration": ["1200"],
                "steps": ["15"],
                "modifiers": ["cmd,shift"],
                "profile": ["human"],
                "snapshot": ["sess-drag"]
            ],
            flags: ["spaceSwitch"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: DragCommand.self, parsedValues: parsed)
        #expect(command.from == "B1")
        #expect(command.to == "T2")
        #expect(command.duration == 1200)
        #expect(command.steps == 15)
        #expect(command.modifiers == "cmd,shift")
        #expect(command.profile == "human")
        #expect(command.snapshot == "sess-drag")
        #expect(command.focusOptions.spaceSwitch == true)
    }

    @Test("Swipe command binding")
    func bindSwipeCommand() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "fromCoords": ["10,20"],
                "toCoords": ["30,40"],
                "duration": ["900"],
                "steps": ["25"],
                "profile": ["linear"],
                "snapshot": ["sess-swipe"]
            ],
            flags: []
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: SwipeCommand.self, parsedValues: parsed)
        #expect(command.fromCoords == "10,20")
        #expect(command.toCoords == "30,40")
        #expect(command.duration == 900)
        #expect(command.steps == 25)
        #expect(command.profile == "linear")
        #expect(command.snapshot == "sess-swipe")
    }

    @Test("Swipe command requires from/to")
    func bindSwipeCommandMissingEndpoints() async throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        var command = try CommanderCLIBinder.instantiateCommand(ofType: SwipeCommand.self, parsedValues: parsed)
        await #expect(throws: ExitCode.self) {
            try await command.run(using: CommandRuntime.makeDefault())
        }
    }
}
