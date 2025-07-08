import Observation
import SwiftUI

struct SettingsWindow: View {
    @Environment(PeekabooSettings.self) private var settings
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
    @Environment(PeekabooSettings.self) private var settings

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
    @Environment(PeekabooSettings.self) private var settings
    @State private var showingAPIKey = false

    private var modelDescriptions: [String: String] {
        [
            "gpt-4o": "Flagship multimodal model with strong performance across text, vision, and audio. Excellent for general-purpose tasks with 128K context window.",
            "gpt-4o-mini": "Fast and cost-effective multimodal model. Great for high-volume tasks while maintaining vision capabilities.",
            "gpt-4.1": "Latest generation with superior coding and instruction following. Supports up to 1M tokens context window.",
            "gpt-4.1-mini": "Small but powerful model that outperforms GPT-4o in many benchmarks. Perfect for fast, efficient multimodal tasks.",
            "o3": "Advanced reasoning model with integrated vision analysis. Can combine tools and analyze visual inputs in its reasoning chain.",
            "o3-pro": "Same as o3 but with extended reasoning time for complex tasks. Best for challenging problems requiring deep analysis.",
            "o4-mini": "Optimized for fast, cost-efficient reasoning with strong performance in math, coding, and visual tasks."
        ]
    }

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
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Model")
                            .frame(width: 80, alignment: .trailing)

                        Picker("", selection: Binding(
                            get: { settings.selectedModel },
                            set: { settings.selectedModel = $0 }
                        )) {
                            Text("GPT-4o").tag("gpt-4o")
                            Text("GPT-4o mini").tag("gpt-4o-mini")
                            Text("GPT-4.1").tag("gpt-4.1")
                            Text("GPT-4.1 mini").tag("gpt-4.1-mini")
                            Divider()
                            Text("o3").tag("o3")
                            Text("o3 pro").tag("o3-pro")
                            Text("o4-mini").tag("o4-mini")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }
                    
                    // Model description
                    if let description = modelDescriptions[settings.selectedModel] {
                        HStack {
                            Spacer()
                                .frame(width: 88)
                            
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: 300, alignment: .leading)
                        }
                    }
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
    @Environment(PeekabooSettings.self) private var settings
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
                        self.recordingShortcut = true
                        
                        // Set up event monitor for shortcut recording
                        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                            guard self.recordingShortcut else { return event }
                            
                            // Capture the key combination
                            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
                            if !modifiers.isEmpty && event.charactersIgnoringModifiers != nil {
                                // Update the shortcut
                                self.currentShortcut = KeyboardShortcut(
                                    key: KeyEquivalent(Character(event.charactersIgnoringModifiers!)),
                                    modifiers: EventModifiers(modifiers)
                                )
                                
                                self.recordingShortcut = false
                                return nil // Consume the event
                            }
                            
                            return event
                        }
                        
                        // Stop recording after 5 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            self.recordingShortcut = false
                        }
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
