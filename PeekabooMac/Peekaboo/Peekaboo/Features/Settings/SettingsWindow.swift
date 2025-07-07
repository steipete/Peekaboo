import Observation
import SwiftUI

struct SettingsWindow: View {
    @Environment(Settings.self) private var settings
    @Environment(Permissions.self) private var permissions

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AISettingsView()
                .tabItem {
                    Label("AI", systemImage: "brain")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Environment(Settings.self) private var settings

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.launchAtLogin = $0 }
                ))
                Toggle("Show in Dock", isOn: Binding(
                    get: { settings.showInDock },
                    set: { settings.showInDock = $0 }
                ))
                Toggle("Keep window on top", isOn: Binding(
                    get: { settings.alwaysOnTop },
                    set: { settings.alwaysOnTop = $0 }
                ))
            }

            Section("Features") {
                Toggle("Enable voice activation", isOn: Binding(
                    get: { settings.voiceActivationEnabled },
                    set: { settings.voiceActivationEnabled = $0 }
                ))
                Toggle("Enable haptic feedback", isOn: Binding(
                    get: { settings.hapticFeedbackEnabled },
                    set: { settings.hapticFeedbackEnabled = $0 }
                ))
                Toggle("Enable sound effects", isOn: Binding(
                    get: { settings.soundEffectsEnabled },
                    set: { settings.soundEffectsEnabled = $0 }
                ))
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - AI Settings

struct AISettingsView: View {
    @Environment(Settings.self) private var settings
    @State private var showingAPIKey = false

    var body: some View {
        Form {
            Section("OpenAI Configuration") {
                // API Key
                HStack {
                    Text("API Key")
                        .frame(width: 80, alignment: .trailing)

                    if self.showingAPIKey {
                        TextField("sk-...", text: Binding(
                            get: { settings.openAIAPIKey },
                            set: { settings.openAIAPIKey = $0 }
                        ))
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("sk-...", text: Binding(
                            get: { settings.openAIAPIKey },
                            set: { settings.openAIAPIKey = $0 }
                        ))
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        self.showingAPIKey.toggle()
                    } label: {
                        Image(systemName: self.showingAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }

                // Model selection
                HStack {
                    Text("Model")
                        .frame(width: 80, alignment: .trailing)

                    Picker("", selection: Binding(
                        get: { settings.selectedModel },
                        set: { settings.selectedModel = $0 }
                    )) {
                        Text("GPT-4o").tag("gpt-4o")
                        Text("GPT-4o mini").tag("gpt-4o-mini")
                        Text("o1-preview").tag("o1-preview")
                        Text("o1-mini").tag("o1-mini")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
            }

            Section("Parameters") {
                // Temperature
                HStack {
                    Text("Temperature")
                        .frame(width: 80, alignment: .trailing)

                    Slider(value: Binding(
                        get: { settings.temperature },
                        set: { settings.temperature = $0 }
                    ), in: 0...1, step: 0.1)

                    Text(String(format: "%.1f", self.settings.temperature))
                        .monospacedDigit()
                        .frame(width: 30)
                }

                // Max tokens
                HStack {
                    Text("Max Tokens")
                        .frame(width: 80, alignment: .trailing)

                    TextField("", value: Binding(
                        get: { settings.maxTokens },
                        set: { settings.maxTokens = $0 }
                    ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)

                    Text("(1 - 128,000)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // API usage info
            if self.settings.hasValidAPIKey {
                Section {
                    HStack {
                        Spacer()
                        Link("View API Usage", destination: URL(string: "https://platform.openai.com/usage")!)
                        Spacer()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    @Environment(Settings.self) private var settings
    @State private var recordingShortcut = false

    var body: some View {
        Form {
            Section("Global Shortcuts") {
                HStack {
                    Text("Toggle Peekaboo")
                        .frame(width: 120, alignment: .trailing)

                    Text(self.settings.globalShortcut)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)

                    Button(self.recordingShortcut ? "Recording..." : "Record") {
                        self.recordingShortcut.toggle()
                        // TODO: Implement shortcut recording
                    }
                    .disabled(self.recordingShortcut)
                }

                Text("Default shortcuts:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 4) {
                    self.shortcutInfo("⌘⇧Space", "Toggle Peekaboo window")
                    self.shortcutInfo("⌘⇧P", "Open Peekaboo")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func shortcutInfo(_ keys: String, _ description: String) -> some View {
        HStack(spacing: 8) {
            Text(keys)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)

            Text(description)
        }
    }
}
