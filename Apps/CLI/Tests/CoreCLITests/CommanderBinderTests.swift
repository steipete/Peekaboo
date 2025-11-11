import Commander
import Testing
@testable import PeekabooCLI

@Suite("Commander Binder")
struct CommanderBinderTests {
    @Test("Runtime options map verbose flag")
    func runtimeOptionVerbose() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: ["verbose"])
        let options = try CommanderCLIBinder.makeRuntimeOptions(from: parsed)
        #expect(options.verbose == true)
        #expect(options.jsonOutput == false)
    }

    @Test("Runtime options map json flag")
    func runtimeOptionJson() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: ["jsonOutput"])
        let options = try CommanderCLIBinder.makeRuntimeOptions(from: parsed)
        #expect(options.verbose == false)
        #expect(options.jsonOutput == true)
    }

    @Test("Runtime options map log level option")
    func runtimeOptionLogLevel() throws {
        let parsed = ParsedValues(positional: [], options: ["logLevel": ["error"]], flags: [])
        let options = try CommanderCLIBinder.makeRuntimeOptions(from: parsed)
        #expect(options.logLevel == .error)
    }

    @Test("Runtime options validate log level")
    func runtimeOptionInvalidLogLevel() {
        let parsed = ParsedValues(positional: [], options: ["logLevel": ["nope"]], flags: [])
        #expect(throws: CommanderBindingError.invalidArgument(
            label: "logLevel",
            value: "nope",
            reason: "Unable to parse LogLevel"
        )) {
            _ = try CommanderCLIBinder.makeRuntimeOptions(from: parsed)
        }
    }

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
            options: ["olderThan": ["48"], "session": ["ignored"]],
            flags: ["dryRun"]
        )
        var command = try CommanderCLIBinder.instantiateCommand(ofType: CleanCommand.self, parsedValues: parsed)
        #expect(command.dryRun == true)
        #expect(command.olderThan == 48)
        #expect(command.session == "ignored")

        let allSessions = ParsedValues(positional: [], options: [:], flags: ["allSessions"])
        command = try CommanderCLIBinder.instantiateCommand(ofType: CleanCommand.self, parsedValues: allSessions)
        #expect(command.allSessions == true)
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
                "path": ["/tmp/out.png"],
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
        #expect(command.path == "/tmp/out.png")
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
                "session": ["abc"],
                "on": ["B1"],
                "app": ["Safari"],
                "waitFor": ["2500"]
            ],
            flags: ["double", "noAutoFocus"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: ClickCommand.self, parsedValues: parsed)
        #expect(command.query == "Submit")
        #expect(command.session == "abc")
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
                "session": ["xyz"],
                "delay": ["10"],
                "tab": ["2"],
                "app": ["Notes"],
                "focusTimeoutSeconds": ["3.5"]
            ],
            flags: ["pressReturn", "escape", "delete", "clear", "spaceSwitch"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: TypeCommand.self, parsedValues: parsed)
        #expect(command.text == "Hello")
        #expect(command.session == "xyz")
        #expect(command.delay == 10)
        #expect(command.tab == 2)
        #expect(command.pressReturn == true)
        #expect(command.escape == true)
        #expect(command.delete == true)
        #expect(command.clear == true)
        #expect(command.app == "Notes")
        #expect(command.focusOptions.spaceSwitch == true)
        #expect(command.focusOptions.focusTimeoutSeconds == 3.5)
    }

    @Test("Press command binding")
    func bindPressCommand() throws {
        let parsed = ParsedValues(
            positional: ["cmd", "c"],
            options: [
                "count": ["3"],
                "delay": ["25"],
                "hold": ["75"],
                "session": ["sess-123"]
            ],
            flags: ["noAutoFocus"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: PressCommand.self, parsedValues: parsed)
        #expect(command.keys == ["cmd", "c"])
        #expect(command.count == 3)
        #expect(command.delay == 25)
        #expect(command.hold == 75)
        #expect(command.session == "sess-123")
        #expect(command.focusOptions.noAutoFocus == true)
    }

    @Test("Scroll command binding")
    func bindScrollCommand() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "direction": ["down"],
                "amount": ["7"],
                "on": ["B4"],
                "session": ["sess-5"],
                "delay": ["5"],
                "app": ["Mail"]
            ],
            flags: ["smooth", "spaceSwitch"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: ScrollCommand.self, parsedValues: parsed)
        #expect(command.direction == "down")
        #expect(command.amount == 7)
        #expect(command.on == "B4")
        #expect(command.session == "sess-5")
        #expect(command.delay == 5)
        #expect(command.app == "Mail")
        #expect(command.smooth == true)
        #expect(command.focusOptions.spaceSwitch == true)
    }

    @Test("Drag command binding")
    func bindDragCommand() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "fromCoords": ["10,20"],
                "toCoords": ["30,40"],
                "session": ["sess-9"],
                "duration": ["900"],
                "steps": ["15"],
                "modifiers": ["cmd,shift"]
            ],
            flags: ["bringToCurrentSpace"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: DragCommand.self, parsedValues: parsed)
        #expect(command.fromCoords == "10,20")
        #expect(command.toCoords == "30,40")
        #expect(command.session == "sess-9")
        #expect(command.duration == 900)
        #expect(command.steps == 15)
        #expect(command.modifiers == "cmd,shift")
        #expect(command.focusOptions.bringToCurrentSpace == true)
    }

    @Test("Hotkey command binding")
    func bindHotkeyCommand() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "keys": ["cmd,c"],
                "holdDuration": ["120"],
                "session": ["sess-11"]
            ],
            flags: ["noAutoFocus"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: HotkeyCommand.self, parsedValues: parsed)
        #expect(command.keys == "cmd,c")
        #expect(command.holdDuration == 120)
        #expect(command.session == "sess-11")
        #expect(command.focusOptions.noAutoFocus == true)
    }

    @Test("Swipe command binding")
    func bindSwipeCommand() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "from": ["A1"],
                "toCoords": ["400,500"],
                "session": ["sess-15"],
                "duration": ["600"],
                "steps": ["12"]
            ],
            flags: ["rightButton"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: SwipeCommand.self, parsedValues: parsed)
        #expect(command.from == "A1")
        #expect(command.toCoords == "400,500")
        #expect(command.session == "sess-15")
        #expect(command.duration == 600)
        #expect(command.steps == 12)
        #expect(command.rightButton == true)
    }

    @Test("Move command binding")
    func bindMoveCommand() throws {
        let parsed = ParsedValues(
            positional: ["120,240"],
            options: [
                "to": ["Submit"],
                "id": ["B2"],
                "duration": ["750"],
                "steps": ["30"],
                "session": ["sess-20"]
            ],
            flags: ["center", "smooth"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: MoveCommand.self, parsedValues: parsed)
        #expect(command.coordinates == "120,240")
        #expect(command.to == "Submit")
        #expect(command.id == "B2")
        #expect(command.center == true)
        #expect(command.smooth == true)
        #expect(command.duration == 750)
        #expect(command.steps == 30)
        #expect(command.session == "sess-20")
    }

    @Test("Menu click binding")
    func bindMenuClick() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "app": ["Safari"],
                "pid": ["999"],
                "path": ["File > New"],
                "item": ["ignored"]
            ],
            flags: ["spaceSwitch"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: MenuCommand.ClickSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.app == "Safari")
        #expect(command.pid == 999)
        #expect(command.path == "File > New")
        #expect(command.focusOptions.spaceSwitch == true)
    }

    @Test("Menu click extra binding")
    func bindMenuClickExtra() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "title": ["WiFi"],
                "item": ["Turn Wi-Fi Off"]
            ],
            flags: []
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: MenuCommand.ClickExtraSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.title == "WiFi")
        #expect(command.item == "Turn Wi-Fi Off")
    }

    @Test("Menu list binding")
    func bindMenuList() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "app": ["Finder"],
                "pid": ["321"]
            ],
            flags: ["includeDisabled", "noAutoFocus"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: MenuCommand.ListSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.app == "Finder")
        #expect(command.pid == 321)
        #expect(command.includeDisabled == true)
        #expect(command.focusOptions.noAutoFocus == true)
    }

    @Test("Menu list-all binding")
    func bindMenuListAll() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [:],
            flags: ["includeDisabled", "includeFrames"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: MenuCommand.ListAllSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.includeDisabled == true)
        #expect(command.includeFrames == true)
    }

    @Test("Dock launch binding")
    func bindDockLaunch() throws {
        let parsed = ParsedValues(
            positional: ["Safari"],
            options: [:],
            flags: []
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: DockCommand.LaunchSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.app == "Safari")
    }

    @Test("Dock right-click binding")
    func bindDockRightClick() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "app": ["Finder"],
                "select": ["New Window"]
            ],
            flags: []
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: DockCommand.RightClickSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.app == "Finder")
        #expect(command.select == "New Window")
    }

    @Test("Dock list binding")
    func bindDockList() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [:],
            flags: ["includeAll"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: DockCommand.ListSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.includeAll == true)
    }

    @Test("Dialog click binding")
    func bindDialogClick() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "button": ["OK"],
                "window": ["Save"]
            ],
            flags: []
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: DialogCommand.ClickSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.button == "OK")
        #expect(command.window == "Save")
    }

    @Test("Dialog input binding")
    func bindDialogInput() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "text": ["secret"],
                "field": ["Password"],
                "index": ["2"]
            ],
            flags: ["clear"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: DialogCommand.InputSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.text == "secret")
        #expect(command.field == "Password")
        #expect(command.index == 2)
        #expect(command.clear == true)
    }

    @Test("Dialog file binding")
    func bindDialogFile() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "path": ["/tmp"],
                "name": ["report.pdf"],
                "select": ["Open"]
            ],
            flags: []
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: DialogCommand.FileSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.path == "/tmp")
        #expect(command.name == "report.pdf")
        #expect(command.select == "Open")
    }

    @Test("Dialog dismiss binding")
    func bindDialogDismiss() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "window": ["Confirm"]
            ],
            flags: ["force"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: DialogCommand.DismissSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.force == true)
        #expect(command.window == "Confirm")
    }

    @Test("Dialog list binding")
    func bindDialogList() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        _ = try CommanderCLIBinder.instantiateCommand(ofType: DialogCommand.ListSubcommand.self, parsedValues: parsed)
    }

    @Test("App launch binding")
    func bindAppLaunch() throws {
        let parsed = ParsedValues(
            positional: ["Visual Studio Code"],
            options: [
                "bundleId": ["com.microsoft.VSCode"]
            ],
            flags: ["waitUntilReady"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: AppCommand.LaunchSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.app == "Visual Studio Code")
        #expect(command.bundleId == "com.microsoft.VSCode")
        #expect(command.waitUntilReady == true)
    }

    @Test("App quit binding")
    func bindAppQuit() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "app": ["Safari"],
                "pid": ["123"],
                "except": ["Finder,Terminal"]
            ],
            flags: ["all", "force"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: AppCommand.QuitSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.app == "Safari")
        #expect(command.pid == 123)
        #expect(command.all == true)
        #expect(command.except == "Finder,Terminal")
        #expect(command.force == true)
    }

    @Test("App switch binding")
    func bindAppSwitch() throws {
        let parsed = ParsedValues(
            positional: [],
            options: ["to": ["Slack"]],
            flags: ["cycle"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: AppCommand.SwitchSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.to == "Slack")
        #expect(command.cycle == true)
    }

    @Test("App list binding")
    func bindAppList() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [:],
            flags: ["includeHidden", "includeBackground"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: AppCommand.ListSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.includeHidden == true)
        #expect(command.includeBackground == true)
    }

    @Test("App relaunch binding")
    func bindAppRelaunch() throws {
        let parsed = ParsedValues(
            positional: ["Safari"],
            options: [
                "pid": ["456"],
                "wait": ["3.5"]
            ],
            flags: ["force", "waitUntilReady"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: AppCommand.RelaunchSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.app == "Safari")
        #expect(command.pid == 456)
        #expect(command.wait == 3.5)
        #expect(command.force == true)
        #expect(command.waitUntilReady == true)
    }

    @Test("Config init binding")
    func bindConfigInit() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: ["force"])
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: ConfigCommand.InitCommand.self,
            parsedValues: parsed
        )
        #expect(command.force == true)
    }

    @Test("Config show binding")
    func bindConfigShow() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: ["effective"])
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: ConfigCommand.ShowCommand.self,
            parsedValues: parsed
        )
        #expect(command.effective == true)
    }

    @Test("Config set credential binding")
    func bindConfigSetCredential() throws {
        let parsed = ParsedValues(positional: ["OPENAI_API_KEY", "sk-123"], options: [:], flags: [])
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: ConfigCommand.SetCredentialCommand.self,
            parsedValues: parsed
        )
        #expect(command.key == "OPENAI_API_KEY")
        #expect(command.value == "sk-123")
    }

    @Test("Config add provider binding")
    func bindConfigAddProvider() throws {
        let parsed = ParsedValues(
            positional: ["openrouter"],
            options: [
                "type": ["openai"],
                "name": ["OpenRouter"],
                "baseUrl": ["https://openrouter.ai"],
                "apiKey": ["{env:OPENROUTER_API_KEY}"],
                "description": ["Multi-provider"],
                "headers": ["x-demo:yes"]
            ],
            flags: ["force"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: ConfigCommand.AddProviderCommand.self,
            parsedValues: parsed
        )
        #expect(command.providerId == "openrouter")
        #expect(command.type == "openai")
        #expect(command.name == "OpenRouter")
        #expect(command.baseUrl == "https://openrouter.ai")
        #expect(command.apiKey == "{env:OPENROUTER_API_KEY}")
        #expect(command.description == "Multi-provider")
        #expect(command.headers == "x-demo:yes")
        #expect(command.force == true)
    }

    @Test("Config remove provider binding")
    func bindConfigRemoveProvider() throws {
        let parsed = ParsedValues(positional: ["openrouter"], options: [:], flags: ["force"])
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: ConfigCommand.RemoveProviderCommand.self,
            parsedValues: parsed
        )
        #expect(command.providerId == "openrouter")
        #expect(command.force == true)
    }

    @Test("Config models provider binding")
    func bindConfigModelsProvider() throws {
        let parsed = ParsedValues(positional: ["openrouter"], options: [:], flags: ["discover"])
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: ConfigCommand.ModelsProviderCommand.self,
            parsedValues: parsed
        )
        #expect(command.providerId == "openrouter")
        #expect(command.discover == true)
    }

    @Test("Space list binding")
    func bindSpaceList() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: ["detailed"])
        let command = try CommanderCLIBinder.instantiateCommand(ofType: ListSubcommand.self, parsedValues: parsed)
        #expect(command.detailed == true)
    }

    @Test("Space switch binding")
    func bindSpaceSwitch() throws {
        let parsed = ParsedValues(positional: [], options: ["to": ["3"]], flags: [])
        let command = try CommanderCLIBinder.instantiateCommand(ofType: SwitchSubcommand.self, parsedValues: parsed)
        #expect(command.to == 3)
    }

    @Test("Space move-window binding")
    func bindSpaceMoveWindow() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "app": ["Safari"],
                "pid": ["123"],
                "windowTitle": ["Inbox"],
                "windowIndex": ["456"],
                "to": ["2"]
            ],
            flags: ["toCurrent", "follow"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: MoveWindowSubcommand.self, parsedValues: parsed)
        #expect(command.app == "Safari")
        #expect(command.pid == 123)
        #expect(command.windowTitle == "Inbox")
        #expect(command.windowIndex == 456)
        #expect(command.to == 2)
        #expect(command.toCurrent == true)
        #expect(command.follow == true)
    }

    @Test("Agent command binding")
    func bindAgentCommand() throws {
        let parsed = ParsedValues(
            positional: ["Open Notes and write summary"],
            options: [
                "maxSteps": ["7"],
                "model": ["gpt-5"],
                "resumeSession": ["sess-42"],
                "audioFile": ["/tmp/input.wav"]
            ],
            flags: [
                "debugTerminal",
                "quiet",
                "dryRun",
                "resume",
                "listSessions",
                "noCache",
                "audio",
                "realtime",
                "simple",
                "noColor"
            ]
        )
        let command = try CommanderCLIBinder.instantiateCommand(ofType: AgentCommand.self, parsedValues: parsed)
        #expect(command.task == "Open Notes and write summary")
        #expect(command.debugTerminal == true)
        #expect(command.quiet == true)
        #expect(command.dryRun == true)
        #expect(command.maxSteps == 7)
        #expect(command.model == "gpt-5")
        #expect(command.resume == true)
        #expect(command.resumeSession == "sess-42")
        #expect(command.listSessions == true)
        #expect(command.noCache == true)
        #expect(command.audio == true)
        #expect(command.audioFile == "/tmp/input.wav")
        #expect(command.realtime == true)
        #expect(command.simple == true)
        #expect(command.noColor == true)
    }

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
            "--text", "password123",
            "--field", "Password",
            "--index", "1",
            "--clear"
        ])
        let values = invocation.parsedValues
        #expect(values.options["text"] == ["password123"])
        #expect(values.options["field"] == ["Password"])
        #expect(values.options["index"] == ["1"])
        #expect(values.flags.contains("clear"))
    }

    @Test("Commander program resolves dialog file options")
    @MainActor
    func commanderResolvesDialogFile() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "dialog",
            "file",
            "--path", "/tmp/report",
            "--name", "report.pdf",
            "--select", "Save"
        ])
        let values = invocation.parsedValues
        #expect(values.options["path"] == ["/tmp/report"])
        #expect(values.options["name"] == ["report.pdf"])
        #expect(values.options["select"] == ["Save"])
    }

    @Test("Commander program resolves dialog dismiss options")
    @MainActor
    func commanderResolvesDialogDismiss() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "dialog",
            "dismiss",
            "--force",
            "--window", "Confirm"
        ])
        let values = invocation.parsedValues
        #expect(values.flags.contains("force"))
        #expect(values.options["window"] == ["Confirm"])
    }

    @Test("Commander program resolves MCP serve options")
    @MainActor
    func commanderResolvesMcpServe() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "mcp",
            "serve",
            "--transport", "http",
            "--port", "9090"
        ])
        let values = invocation.parsedValues
        #expect(values.options["transport"] == ["http"])
        #expect(values.options["port"] == ["9090"])
    }

    @Test("Commander program resolves MCP call options")
    @MainActor
    func commanderResolvesMcpCall() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "mcp",
            "call",
            "claude-code",
            "--tool", "edit_file",
            "--args", #"{"path":"main.swift"}"#
        ])
        let values = invocation.parsedValues
        #expect(values.positional == ["claude-code"])
        #expect(values.options["tool"] == ["edit_file"])
        #expect(values.options["args"] == [#"{"path":"main.swift"}"#])
    }

    @Test("Commander program resolves MCP add options")
    @MainActor
    func commanderResolvesMcpAdd() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "mcp",
            "add",
            "github",
            "-e", "API_KEY=xyz",
            "--transport", "stdio",
            "--description", "GitHub tools",
            "--disabled",
            "--",
            "npx",
            "-y",
            "@modelcontextprotocol/server-github"
        ])
        let values = invocation.parsedValues
        #expect(values.positional == ["github", "npx", "-y", "@modelcontextprotocol/server-github"])
        #expect(values.options["env"] == ["API_KEY=xyz"])
        #expect(values.options["transport"] == ["stdio"])
        #expect(values.options["description"] == ["GitHub tools"])
        #expect(values.flags.contains("disabled"))
    }

    @Test("Commander program resolves MCP list flag")
    @MainActor
    func commanderResolvesMcpList() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "mcp",
            "list",
            "--skip-health-check"
        ])
        let values = invocation.parsedValues
        #expect(values.flags.contains("skipHealthCheck"))
    }

    @Test("Commander program resolves window close options")
    @MainActor
    func commanderResolvesWindowClose() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "window",
            "close",
            "--app", "Safari",
            "--window-title", "Inbox"
        ])
        let values = invocation.parsedValues
        #expect(values.options["app"] == ["Safari"])
        #expect(values.options["windowTitle"] == ["Inbox"])
    }

    @Test("Commander program resolves window move options")
    @MainActor
    func commanderResolvesWindowMove() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "window",
            "move",
            "--app", "Notes",
            "--x", "120",
            "--y", "240"
        ])
        let values = invocation.parsedValues
        #expect(values.options["app"] == ["Notes"])
        #expect(values.options["x"] == ["120"])
        #expect(values.options["y"] == ["240"])
    }

    @Test("Commander program resolves window focus options")
    @MainActor
    func commanderResolvesWindowFocus() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "window",
            "focus",
            "--app", "Safari",
            "--window-title", "Inbox",
            "--space-switch",
            "--bring-to-current-space"
        ])
        let values = invocation.parsedValues
        #expect(values.options["app"] == ["Safari"])
        #expect(values.options["windowTitle"] == ["Inbox"])
        #expect(values.flags.contains("spaceSwitch"))
        #expect(values.flags.contains("bringToCurrentSpace"))
    }

    @Test("Commander program resolves app launch options")
    @MainActor
    func commanderResolvesAppLaunch() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "app",
            "launch",
            "\"Visual Studio Code\"",
            "--bundle-id", "com.microsoft.VSCode",
            "--wait-until-ready"
        ])
        let values = invocation.parsedValues
        #expect(values.positional == ["\"Visual Studio Code\""])
        #expect(values.options["bundleId"] == ["com.microsoft.VSCode"])
        #expect(values.flags.contains("waitUntilReady"))
    }

    @Test("Commander program resolves app quit options")
    @MainActor
    func commanderResolvesAppQuit() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "app",
            "quit",
            "--all",
            "--except", "Finder,Terminal",
            "--force"
        ])
        let values = invocation.parsedValues
        #expect(values.flags.contains("all"))
        #expect(values.options["except"] == ["Finder,Terminal"])
        #expect(values.flags.contains("force"))
    }

    @Test("Commander program resolves menu click options")
    @MainActor
    func commanderResolvesMenuClick() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "menu",
            "click",
            "--app", "Safari",
            "--path", "File > New",
            "--no-auto-focus"
        ])
        let values = invocation.parsedValues
        #expect(values.options["app"] == ["Safari"])
        #expect(values.options["path"] == ["File > New"])
        #expect(values.flags.contains("noAutoFocus"))
    }

    @Test("Commander program resolves permissions default subcommand")
    @MainActor
    func commanderResolvesPermissionsDefault() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "permissions",
            "--json-output"
        ])
        #expect(invocation.path == ["permissions", "status"])
        #expect(invocation.parsedValues.flags.contains("jsonOutput"))
    }

    @Test("Commander program resolves tools command options")
    @MainActor
    func commanderResolvesToolsCommand() throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: [
            "peekaboo",
            "tools",
            "--native-only",
            "--include-disabled",
            "--no-sort",
            "--group-by-server",
            "--mcp",
            "github"
        ])
        let values = invocation.parsedValues
        #expect(values.flags.contains("nativeOnly"))
        #expect(values.flags.contains("includeDisabled"))
        #expect(values.flags.contains("noSort"))
        #expect(values.flags.contains("groupByServer"))
        #expect(values.options["mcp"] == ["github"])
    }
}
