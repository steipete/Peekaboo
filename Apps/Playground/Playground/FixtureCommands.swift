import SwiftUI

struct FixtureCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Fixtures") {
            Button("Open Click Fixture") { self.openWindow(id: "fixture-click") }
                .keyboardShortcut("1", modifiers: [.command, .control])

            Button("Open Text Fixture") { self.openWindow(id: "fixture-text") }
                .keyboardShortcut("2", modifiers: [.command, .control])

            Button("Open Controls Fixture") { self.openWindow(id: "fixture-controls") }
                .keyboardShortcut("3", modifiers: [.command, .control])

            Button("Open Scroll Fixture") { self.openWindow(id: "fixture-scroll") }
                .keyboardShortcut("4", modifiers: [.command, .control])

            Button("Open Window Fixture") { self.openWindow(id: "fixture-window") }
                .keyboardShortcut("5", modifiers: [.command, .control])

            Button("Open Drag Fixture") { self.openWindow(id: "fixture-drag") }
                .keyboardShortcut("6", modifiers: [.command, .control])

            Button("Open Keyboard Fixture") { self.openWindow(id: "fixture-keyboard") }
                .keyboardShortcut("7", modifiers: [.command, .control])

            Button("Open Dialog Fixture") { self.openWindow(id: "fixture-dialog") }
                .keyboardShortcut("8", modifiers: [.command, .control])
        }
    }
}
