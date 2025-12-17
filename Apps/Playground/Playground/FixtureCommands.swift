import SwiftUI

struct FixtureCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Fixtures") {
            Button("Open Click Fixture") { self.openWindow(id: "fixture-click") }
                .keyboardShortcut("1", modifiers: [.command, .shift])

            Button("Open Text Fixture") { self.openWindow(id: "fixture-text") }
                .keyboardShortcut("2", modifiers: [.command, .shift])

            Button("Open Controls Fixture") { self.openWindow(id: "fixture-controls") }
                .keyboardShortcut("3", modifiers: [.command, .shift])

            Button("Open Scroll Fixture") { self.openWindow(id: "fixture-scroll") }
                .keyboardShortcut("4", modifiers: [.command, .shift])

            Button("Open Window Fixture") { self.openWindow(id: "fixture-window") }
                .keyboardShortcut("5", modifiers: [.command, .shift])

            Button("Open Drag Fixture") { self.openWindow(id: "fixture-drag") }
                .keyboardShortcut("6", modifiers: [.command, .shift])

            Button("Open Keyboard Fixture") { self.openWindow(id: "fixture-keyboard") }
                .keyboardShortcut("7", modifiers: [.command, .shift])
        }
    }
}
