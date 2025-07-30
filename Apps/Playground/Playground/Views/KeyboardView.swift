import Combine
import SwiftUI

struct KeyboardView: View {
    @EnvironmentObject var actionLogger: ActionLogger
    @State private var lastKeyPressed = ""
    @State private var modifierKeys: Set<String> = []
    @State private var keySequence: [String] = []
    @State private var isRecordingSequence = false
    @State private var hotkeyTestText = "Press hotkeys here..."
    @FocusState private var isHotkeyFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SectionHeader(title: "Keyboard Testing", icon: "keyboard")

                // Key press detection
                GroupBox("Key Press Detection") {
                    VStack(spacing: 15) {
                        Text("Click the field below and press any key:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Press keys here...", text: .constant(""))
                            .textFieldStyle(.roundedBorder)
                            .frame(height: 60)
                            .accessibilityIdentifier("key-detection-field")
                            .onKeyPress { press in
                                self.handleKeyPress(press)
                                return .handled
                            }
                            .focused(self.$isHotkeyFieldFocused)

                        if !self.lastKeyPressed.isEmpty {
                            HStack {
                                Label("Last key:", systemImage: "keyboard")
                                Text(self.lastKeyPressed)
                                    .font(.system(.title3, design: .monospaced))
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding()
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }

                // Modifier keys
                GroupBox("Modifier Keys") {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Hold modifier keys and click the buttons:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 20) {
                            ForEach(["⌘ Cmd", "⇧ Shift", "⌥ Option", "⌃ Control"], id: \.self) { modifier in
                                Button(modifier) {
                                    let flags = NSEvent.modifierFlags
                                    var activeModifiers: [String] = []

                                    if flags.contains(.command) { activeModifiers.append("Cmd") }
                                    if flags.contains(.shift) { activeModifiers.append("Shift") }
                                    if flags.contains(.option) { activeModifiers.append("Option") }
                                    if flags.contains(.control) { activeModifiers.append("Control") }

                                    let modifierString = activeModifiers.isEmpty ? "None" : activeModifiers
                                        .joined(separator: "+")
                                    self.actionLogger.log(
                                        .keyboard,
                                        "Button clicked with modifiers",
                                        details: "Modifiers: \(modifierString)")
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("modifier-test-\(modifier)")
                            }
                        }

                        // Current modifier display
                        ModifierStatusView()
                    }
                }

                // Hotkey combinations
                GroupBox("Hotkey Combinations") {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Common hotkeys to test:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: 10) {
                            HotkeyButton(key: "C", modifiers: [.command], label: "Copy (⌘C)")
                            HotkeyButton(key: "V", modifiers: [.command], label: "Paste (⌘V)")
                            HotkeyButton(key: "Z", modifiers: [.command], label: "Undo (⌘Z)")
                            HotkeyButton(key: "Z", modifiers: [.command, .shift], label: "Redo (⌘⇧Z)")
                            HotkeyButton(key: "S", modifiers: [.command], label: "Save (⌘S)")
                            HotkeyButton(key: "A", modifiers: [.command], label: "Select All (⌘A)")
                        }

                        Divider()

                        TextField("Test hotkeys here", text: self.$hotkeyTestText)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("hotkey-test-field")
                            .onKeyPress { press in
                                if press.modifiers.contains(.command) {
                                    var hotkeyParts = ["Cmd"]
                                    if press.modifiers.contains(.shift) { hotkeyParts.append("Shift") }
                                    if press.modifiers.contains(.option) { hotkeyParts.append("Option") }
                                    if press.modifiers.contains(.control) { hotkeyParts.append("Control") }

                                    let keyChar = press.characters
                                    hotkeyParts.append(keyChar.uppercased())

                                    let hotkey = hotkeyParts.joined(separator: "+")
                                    self.actionLogger.log(.keyboard, "Hotkey pressed", details: hotkey)
                                }
                                return .ignored
                            }
                    }
                }

                // Key sequence recording
                GroupBox("Key Sequence Recording") {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Button(self.isRecordingSequence ? "Stop Recording" : "Start Recording") {
                                self.isRecordingSequence.toggle()
                                if self.isRecordingSequence {
                                    self.keySequence.removeAll()
                                    self.actionLogger.log(.keyboard, "Started recording key sequence")
                                } else {
                                    let sequence = self.keySequence.joined(separator: " → ")
                                    self.actionLogger.log(
                                        .keyboard,
                                        "Key sequence recorded",
                                        details: sequence.isEmpty ? "Empty" : sequence)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(self.isRecordingSequence ? .red : .accentColor)
                            .accessibilityIdentifier("sequence-record-button")

                            Button("Clear") {
                                self.keySequence.removeAll()
                                self.actionLogger.log(.keyboard, "Key sequence cleared")
                            }
                            .disabled(self.keySequence.isEmpty)
                            .accessibilityIdentifier("sequence-clear-button")

                            Spacer()
                        }

                        if !self.keySequence.isEmpty {
                            ScrollView(.horizontal) {
                                HStack(spacing: 10) {
                                    ForEach(Array(self.keySequence.enumerated()), id: \.offset) { index, key in
                                        Text(key)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.accentColor.opacity(0.2))
                                            .cornerRadius(6)
                                            .font(.system(.body, design: .monospaced))

                                        if index < self.keySequence.count - 1 {
                                            Image(systemName: "arrow.right")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 5)
                            }
                        }

                        TextField("Type to record sequence...", text: .constant(""))
                            .textFieldStyle(.roundedBorder)
                            .disabled(!self.isRecordingSequence)
                            .accessibilityIdentifier("sequence-input-field")
                            .onKeyPress { press in
                                if self.isRecordingSequence {
                                    self.recordKeyInSequence(press)
                                }
                                return .handled
                            }
                    }
                }

                // Special keys
                GroupBox("Special Keys") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Test special key handling:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: 10) {
                            SpecialKeyButton(key: "Escape", code: .escape)
                            SpecialKeyButton(key: "Tab", code: .tab)
                            SpecialKeyButton(key: "Return", code: .return)
                            SpecialKeyButton(key: "Delete", code: .delete)
                            SpecialKeyButton(key: "Space", code: .space)
                            SpecialKeyButton(key: "←", code: .leftArrow)
                            SpecialKeyButton(key: "→", code: .rightArrow)
                            SpecialKeyButton(key: "↑", code: .upArrow)
                            SpecialKeyButton(key: "↓", code: .downArrow)
                            SpecialKeyButton(key: "Home", code: .home)
                            SpecialKeyButton(key: "End", code: .end)
                            SpecialKeyButton(key: "F1", code: .f1)
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            self.isHotkeyFieldFocused = true
        }
    }

    private func handleKeyPress(_ press: KeyPress) {
        var keyDescription = ""

        // Add modifiers
        var modifiers: [String] = []
        if press.modifiers.contains(.command) { modifiers.append("⌘") }
        if press.modifiers.contains(.shift) { modifiers.append("⇧") }
        if press.modifiers.contains(.option) { modifiers.append("⌥") }
        if press.modifiers.contains(.control) { modifiers.append("⌃") }

        if !modifiers.isEmpty {
            keyDescription = modifiers.joined() + " + "
        }

        // Add key
        keyDescription += press.characters.isEmpty ? "Special Key" : press.characters.uppercased()

        self.lastKeyPressed = keyDescription
        self.actionLogger.log(.keyboard, "Key pressed", details: keyDescription)
    }

    private func recordKeyInSequence(_ press: KeyPress) {
        var keyDescription = ""

        if press.modifiers.contains(.command) { keyDescription += "⌘" }
        if press.modifiers.contains(.shift) { keyDescription += "⇧" }
        if press.modifiers.contains(.option) { keyDescription += "⌥" }
        if press.modifiers.contains(.control) { keyDescription += "⌃" }

        if !keyDescription.isEmpty, !press.characters.isEmpty {
            keyDescription += "+"
        }

        keyDescription += press.characters.isEmpty ? "?" : press.characters.uppercased()

        self.keySequence.append(keyDescription)
    }
}

struct ModifierStatusView: View {
    @State private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @State private var activeModifiers: Set<String> = []

    var body: some View {
        HStack(spacing: 15) {
            Label("Active:", systemImage: "command")
                .foregroundColor(.secondary)

            ForEach(["⌘", "⇧", "⌥", "⌃"], id: \.self) { modifier in
                Text(modifier)
                    .font(.system(size: 20))
                    .padding(6)
                    .background(self.isModifierActive(modifier) ? Color.accentColor : Color.gray.opacity(0.2))
                    .foregroundColor(self.isModifierActive(modifier) ? .white : .primary)
                    .cornerRadius(6)
            }
        }
        .onReceive(self.timer) { _ in
            self.updateModifierStatus()
        }
    }

    private func isModifierActive(_ modifier: String) -> Bool {
        switch modifier {
        case "⌘": self.activeModifiers.contains("command")
        case "⇧": self.activeModifiers.contains("shift")
        case "⌥": self.activeModifiers.contains("option")
        case "⌃": self.activeModifiers.contains("control")
        default: false
        }
    }

    private func updateModifierStatus() {
        let flags = NSEvent.modifierFlags
        var newModifiers: Set<String> = []

        if flags.contains(.command) { newModifiers.insert("command") }
        if flags.contains(.shift) { newModifiers.insert("shift") }
        if flags.contains(.option) { newModifiers.insert("option") }
        if flags.contains(.control) { newModifiers.insert("control") }

        self.activeModifiers = newModifiers
    }
}

struct HotkeyButton: View {
    let key: String
    let modifiers: NSEvent.ModifierFlags
    let label: String
    @EnvironmentObject var actionLogger: ActionLogger

    var body: some View {
        Button(self.label) {
            var modifierList: [String] = []
            if self.modifiers.contains(.command) { modifierList.append("Cmd") }
            if self.modifiers.contains(.shift) { modifierList.append("Shift") }
            if self.modifiers.contains(.option) { modifierList.append("Option") }
            if self.modifiers.contains(.control) { modifierList.append("Control") }

            let combo = modifierList.joined(separator: "+") + "+" + self.key
            self.actionLogger.log(.keyboard, "Hotkey button clicked", details: combo)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityIdentifier("hotkey-\(self.label)")
    }
}

struct SpecialKeyButton: View {
    let key: String
    let code: KeyCode
    @EnvironmentObject var actionLogger: ActionLogger

    var body: some View {
        Button(self.key) {
            self.actionLogger.log(.keyboard, "Special key pressed", details: self.key)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityIdentifier("special-key-\(self.key)")
    }
}

enum KeyCode {
    case escape, tab, `return`, delete, space
    case leftArrow, rightArrow, upArrow, downArrow
    case home, end, f1
}
