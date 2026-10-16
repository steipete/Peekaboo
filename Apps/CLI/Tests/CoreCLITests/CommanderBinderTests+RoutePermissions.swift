import Commander
import PeekabooAutomation
import PeekabooBridge
import PeekabooBridgeTestSupport
import Testing
@testable import PeekabooCLI

extension CommanderBinderTests {
    struct PermissionRoute: Sendable {
        let name: String
        let command: any ParsableCommand.Type
        var positional: [String] = []
        var options: [String: [String]] = [:]
        var flags: Set<String> = []
        var accessibility = false
        var events = false
        var focusedReceiver = false

        func bind() throws -> CommandRuntimeOptions {
            try CommanderCLIBinder.makeRuntimeOptions(
                from: ParsedValues(positional: self.positional, options: self.options, flags: self.flags),
                commandType: self.command,
                environment: [:]
            )
        }
    }

    static let permissionRoutes: [PermissionRoute] = [
        .init(
            name: "background text",
            command: TypeCommand.self,
            positional: ["hello"],
            options: ["app": ["TextEdit"]],
            accessibility: true
        ),
        .init(
            name: "exact text",
            command: TypeCommand.self,
            positional: ["hello"],
            options: ["windowId": ["42"]],
            accessibility: true,
            focusedReceiver: true
        ),
        .init(
            name: "snapshot text",
            command: TypeCommand.self,
            positional: ["hello"],
            options: ["snapshot": ["latest"]],
            accessibility: true,
            focusedReceiver: true
        ),
        .init(
            name: "pixel text",
            command: TypeCommand.self,
            positional: ["hello"],
            options: ["at": ["20,30"], "snapshot": ["latest"]],
            accessibility: true
        ),
        .init(
            name: "foreground text",
            command: TypeCommand.self,
            positional: ["hello"],
            flags: ["foreground"],
            events: true
        ),
        .init(
            name: "focused foreground text",
            command: TypeCommand.self,
            positional: ["hello"],
            options: ["app": ["TextEdit"]],
            flags: ["foreground"],
            accessibility: true,
            events: true
        ),
        .init(
            name: "process synthesis",
            command: TypeCommand.self,
            positional: ["hello"],
            options: ["pid": ["42"], "inputStrategy": ["synthOnly"]],
            events: true
        ),
        .init(
            name: "exact synthesis",
            command: TypeCommand.self,
            positional: ["hello"],
            options: ["windowTitle": ["Document"], "inputStrategy": ["synthOnly"]],
            accessibility: true,
            events: true,
            focusedReceiver: true
        ),
        .init(
            name: "background raw chord",
            command: PressCommand.self,
            positional: ["return"],
            options: ["windowId": ["42"]],
            accessibility: true,
            events: true,
            focusedReceiver: true
        ),
        .init(
            name: "background AX select all",
            command: PressCommand.self,
            positional: ["Command+A"],
            options: ["windowTitle": ["Document"]],
            accessibility: true,
            focusedReceiver: true
        ),
        .init(
            name: "mixed chords",
            command: PressCommand.self,
            positional: ["cmd+a", "delete"],
            options: ["windowIndex": ["0"]],
            accessibility: true,
            events: true,
            focusedReceiver: true
        ),
        .init(
            name: "key option",
            command: PressCommand.self,
            options: ["key": ["return"], "windowId": ["42"]],
            accessibility: true,
            events: true,
            focusedReceiver: true
        ),
        .init(
            name: "forced select all synthesis",
            command: PressCommand.self,
            positional: ["cmd+a"],
            options: ["windowId": ["42"], "inputStrategy": ["synthFirst"]],
            accessibility: true,
            events: true,
            focusedReceiver: true
        ),
        .init(
            name: "foreground chord synthesis",
            command: PressCommand.self,
            positional: ["cmd+c"],
            flags: ["foreground"],
            events: true
        ),
        .init(
            name: "foreground forced synthesis",
            command: PressCommand.self,
            positional: ["cmd+c"],
            options: ["inputStrategy": ["synthOnly"]],
            flags: ["foreground"],
            events: true
        ),
        .init(
            name: "foreground forced action",
            command: PressCommand.self,
            positional: ["cmd+c"],
            options: ["inputStrategy": ["actionOnly"]],
            flags: ["foreground"],
            accessibility: true
        ),
        .init(
            name: "literal paste",
            command: PasteCommand.self,
            positional: ["hello"],
            options: ["app": ["TextEdit"]],
            accessibility: true
        ),
        .init(
            name: "option literal paste",
            command: PasteCommand.self,
            options: ["textOption": ["hello"], "pid": ["42"]],
            accessibility: true
        ),
        .init(
            name: "exact paste",
            command: PasteCommand.self,
            options: ["filePath": ["/synthetic/file"], "windowId": ["42"]],
            accessibility: true,
            focusedReceiver: true
        ),
        .init(
            name: "current clipboard exact paste",
            command: PasteCommand.self,
            options: ["windowId": ["42"]],
            accessibility: true,
            events: true,
            focusedReceiver: true
        ),
        .init(
            name: "unknown file paste route",
            command: PasteCommand.self,
            options: ["filePath": ["/synthetic/file"], "app": ["TextEdit"]]
        ),
        .init(
            name: "current clipboard process paste",
            command: PasteCommand.self,
            options: ["pid": ["42"]],
            events: true
        ),
        .init(
            name: "foreground paste synthesis",
            command: PasteCommand.self,
            positional: ["hello"],
            flags: ["foreground"],
            events: true
        ),
        .init(
            name: "foreground paste focus",
            command: PasteCommand.self,
            positional: ["hello"],
            options: ["app": ["TextEdit"]],
            flags: ["foreground"],
            accessibility: true,
            events: true
        ),
        .init(
            name: "foreground AX-first chord",
            command: PressCommand.self,
            positional: ["cmd+c"],
            options: ["inputStrategy": ["actionFirst"]],
            flags: ["foreground"]
        ),
        .init(
            name: "foreground AX-first paste",
            command: PasteCommand.self,
            positional: ["hello"],
            options: ["inputStrategy": ["actionFirst"]],
            flags: ["foreground"]
        ),
        .init(
            name: "encoded plain text paste",
            command: PasteCommand.self,
            options: ["dataBase64": ["aGVsbG8="], "uti": ["public.utf8-plain-text"], "app": ["TextEdit"]],
            accessibility: true
        ),
        .init(
            name: "encoded binary paste",
            command: PasteCommand.self,
            options: ["dataBase64": ["/w=="], "uti": ["public.utf8-plain-text"], "windowId": ["42"]],
            accessibility: true,
            events: true,
            focusedReceiver: true
        ),
        .init(
            name: "forced binary file paste",
            command: PasteCommand.self,
            options: ["filePath": ["/synthetic/file"], "uti": ["public.rtf"], "pid": ["42"]],
            events: true
        ),
        .init(name: "close", command: WindowCommand.CloseSubcommand.self, accessibility: true),
        .init(
            name: "foreground close permits AX success",
            command: WindowCommand.CloseSubcommand.self,
            flags: ["foreground"],
            accessibility: true
        ),
        .init(name: "minimize", command: WindowCommand.MinimizeSubcommand.self, accessibility: true),
        .init(name: "restore", command: WindowCommand.RestoreSubcommand.self, accessibility: true),
        .init(name: "maximize", command: WindowCommand.MaximizeSubcommand.self, accessibility: true),
        .init(name: "move", command: WindowCommand.MoveSubcommand.self, accessibility: true),
        .init(name: "resize", command: WindowCommand.ResizeSubcommand.self, accessibility: true),
        .init(name: "set bounds", command: WindowCommand.SetBoundsSubcommand.self, accessibility: true),
        .init(name: "window focus", command: WindowCommand.FocusSubcommand.self, accessibility: true),
        .init(name: "native window list", command: WindowCommand.WindowListSubcommand.self),
        .init(name: "menu click", command: MenuCommand.ClickSubcommand.self, accessibility: true),
        .init(name: "menu list traversal", command: MenuCommand.ListSubcommand.self, accessibility: true),
        .init(
            name: "scoped menubar AX",
            command: MenuBarCommand.ClickSubcommand.self,
            options: ["app": ["Example"]],
            flags: ["foreground"],
            accessibility: true
        ),
        .init(
            name: "indexed menubar coordinates",
            command: MenuBarCommand.ClickSubcommand.self,
            options: ["index": ["0"]],
            flags: ["foreground"],
            events: true
        ),
        .init(
            name: "named menubar coordinates",
            command: MenuBarCommand.ClickSubcommand.self,
            positional: ["Example"],
            flags: ["foreground"],
            events: true
        ),
        .init(name: "native menubar list", command: MenuBarCommand.ListSubcommand.self),
        .init(name: "native hide", command: AppCommand.HideSubcommand.self),
        .init(name: "native focus", command: AppCommand.FocusSubcommand.self, flags: ["foreground"]),
        .init(name: "clipboard write", command: ClipboardCommand.SetSubcommand.self),
    ]

    @Test(arguments: await permissionRoutes)
    func `routes declare only guaranteed permissions`(route: PermissionRoute) throws {
        let options = try route.bind()
        #expect(options.routeRequiresAccessibilityPermission == route.accessibility, "\(route.name)")
        #expect(options.routeRequiresPostEventPermission == route.events, "\(route.name)")
        #expect(!options.requiresAccessibilityPermission, "\(route.name)")
        #expect(!options.requiresPostEventPermission, "\(route.name)")
        #expect(options.requiresTargetedFocusedElement == route.focusedReceiver, "\(route.name)")
        #expect(!options.requiresExactWindowTargetedKeyboard, "\(route.name)")
        #expect(!options.requiresScreenCapturePermission, "\(route.name)")
        var expected: Set<PeekabooBridgePermissionKind> = []
        if route.accessibility {
            expected.insert(.accessibility)
        }
        if route.events {
            expected.insert(.postEvent)
        }
        let handshake = BridgeTestFixtures.handshake(
            negotiatedVersion: PeekabooBridgeConstants.protocolVersion,
            supportedOperations: [],
            permissions: .init(screenRecording: false, accessibility: false, postEvent: false)
        )
        #expect(
            BridgeCapabilityPolicy.explicitlyMissingRemotePermissions(for: handshake, options: options) == expected,
            "\(route.name)"
        )
    }
}
