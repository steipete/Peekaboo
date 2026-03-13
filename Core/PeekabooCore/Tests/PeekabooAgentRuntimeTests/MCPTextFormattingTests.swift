import CoreGraphics
import PeekabooAutomation
import Testing
@testable import PeekabooAgentRuntime

struct MCPTextFormattingTests {
    @Test
    func `Running application formatter includes optional metadata when present`() {
        let app = ServiceApplicationInfo(
            processIdentifier: 42,
            bundleIdentifier: "com.example.Editor",
            name: "Editor",
            bundlePath: "/Applications/Editor.app",
            isActive: true,
            isHidden: true,
            windowCount: 3)

        let line = RunningApplicationTextFormatter.format(app, index: 0)

        #expect(
            line ==
                "1. Editor (com.example.Editor) [/Applications/Editor.app] - PID: 42 [ACTIVE] [HIDDEN] - Windows: 3")
    }

    @Test
    func `Running application formatter omits absent optional metadata`() {
        let app = ServiceApplicationInfo(
            processIdentifier: 7,
            bundleIdentifier: nil,
            name: "Notes")

        let line = RunningApplicationTextFormatter.format(app, index: 1)

        #expect(line == "2. Notes - PID: 7 - Windows: 0")
    }

    @Test
    func `See element formatter surfaces extra metadata`() {
        let element = UIElement(
            id: "B1",
            elementId: "B1",
            role: "button",
            title: "Continue",
            label: "Continue",
            value: "Primary",
            description: "Primary action",
            help: "Press to continue",
            identifier: "continue.button",
            frame: CGRect(x: 540, y: 320, width: 80, height: 32),
            isActionable: false,
            keyboardShortcut: "⏎")

        let line = SeeElementTextFormatter.describe(element)
        let expected = [
            #"  B1"#,
            #""Continue""#,
            "at (540, 320) size 80×32",
            #"value: "Primary""#,
            #"desc: "Primary action""#,
            #"help: "Press to continue""#,
            "shortcut: ⏎",
            "identifier: continue.button",
            "[not actionable]",
        ].joined(separator: " - ")

        #expect(line == expected)
    }

    @Test
    func `See element formatter does not duplicate value-only labels`() {
        let element = UIElement(
            id: "T1",
            elementId: "T1",
            role: "textfield",
            value: "search query",
            frame: CGRect(x: 20, y: 40, width: 180, height: 24),
            isActionable: true)

        let line = SeeElementTextFormatter.describe(element)

        #expect(line == #"  T1 - "value: search query" - at (20, 40) size 180×24"#)
    }
}
