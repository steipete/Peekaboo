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
            
            VisualizerSettingsView(settings: settings)
                .tabItem {
                    Label("Visualizer", systemImage: "sparkles")
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
                    get: { self.settings.launchAtLogin },
                    set: { self.settings.launchAtLogin = $0 }))
                Toggle("Show in Dock", isOn: Binding(
                    get: { self.settings.showInDock },
                    set: { self.settings.showInDock = $0 }))
                Toggle("Keep window on top", isOn: Binding(
                    get: { self.settings.alwaysOnTop },
                    set: { self.settings.alwaysOnTop = $0 }))
            }

            Section("Features") {
                Toggle("Enable voice activation", isOn: Binding(
                    get: { self.settings.voiceActivationEnabled },
                    set: { self.settings.voiceActivationEnabled = $0 }))
                Toggle("Enable haptic feedback", isOn: Binding(
                    get: { self.settings.hapticFeedbackEnabled },
                    set: { self.settings.hapticFeedbackEnabled = $0 }))
                Toggle("Enable sound effects", isOn: Binding(
                    get: { self.settings.soundEffectsEnabled },
                    set: { self.settings.soundEffectsEnabled = $0 }))
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - AI Settings

struct AISettingsView: View {
    @Environment(PeekabooSettings.self) private var settings
    @State private var showingOpenAIKey = false
    @State private var showingAnthropicKey = false

    private var allModels: [(provider: String, models: [(id: String, name: String)])] {
        [
            ("openai", [
                ("gpt-4.1", "GPT-4.1"),
                ("gpt-4.1-mini", "GPT-4.1 mini"),
                ("gpt-4o", "GPT-4o"),
                ("gpt-4o-mini", "GPT-4o mini"),
                ("o3", "o3"),
                ("o3-pro", "o3 pro"),
                ("o4-mini", "o4-mini"),
            ]),
            ("anthropic", [
                ("claude-opus-4-20250514", "Claude Opus 4"),
                ("claude-sonnet-4-20250514", "Claude Sonnet 4"),
                ("claude-3-5-haiku", "Claude 3.5 Haiku"),
                ("claude-3-5-sonnet", "Claude 3.5 Sonnet"),
            ]),
            ("ollama", [
                ("llava:latest", "LLaVA"),
                ("llama3.2-vision:latest", "Llama 3.2 Vision"),
            ]),
        ]
    }

    private var modelDescriptions: [String: String] {
        [
            // OpenAI models
            "gpt-4o": "Flagship multimodal model with strong performance across text, vision, and audio. Excellent for general-purpose tasks with 128K context window.",
            "gpt-4o-mini": "Fast and cost-effective multimodal model. Great for high-volume tasks while maintaining vision capabilities.",
            "gpt-4.1": "Latest generation with superior coding and instruction following. Supports up to 1M tokens context window.",
            "gpt-4.1-mini": "Small but powerful model that outperforms GPT-4o in many benchmarks. Perfect for fast, efficient multimodal tasks.",
            "o3": "Advanced reasoning model with integrated vision analysis. Can combine tools and analyze visual inputs in its reasoning chain.",
            "o3-pro": "Same as o3 but with extended reasoning time for complex tasks. Best for challenging problems requiring deep analysis.",
            "o4-mini": "Optimized for fast, cost-efficient reasoning with strong performance in math, coding, and visual tasks.",
            // Anthropic models
            "claude-opus-4-20250514": "World's best coding model. Leads on SWE-bench (72.5%) and Terminal-bench (43.2%). Can work continuously for several hours on complex tasks.",
            "claude-sonnet-4-20250514": "Cost-optimized general-purpose model with excellent performance across various tasks.",
            "claude-3-5-haiku": "Fast and efficient model perfect for simple tasks and high-volume usage.",
            "claude-3-5-sonnet": "Balanced model with computer use capabilities for automation tasks.",
            // Ollama models
            "llava:latest": "Open-source multimodal model that runs locally. Good for privacy-conscious users and offline usage.",
            "llama3.2-vision:latest": "Meta's latest vision-capable model with strong performance on visual understanding tasks.",
        ]
    }

    var body: some View {
        Form {
            // Model Selection
            Section("Model Selection") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Model")
                            .frame(width: 80, alignment: .trailing)

                        Picker("", selection: Binding(
                            get: { self.settings.selectedModel },
                            set: { newModel in
                                self.settings.selectedModel = newModel
                                // Update provider based on model selection
                                for (provider, models) in self.allModels {
                                    if models.contains(where: { $0.id == newModel }) {
                                        self.settings.selectedProvider = provider
                                        break
                                    }
                                }
                            })) {
                                ForEach(self.allModels, id: \.provider) { provider, models in
                                    Section(header: Text(provider.capitalized)) {
                                        ForEach(models, id: \.id) { model in
                                            Text(model.name).tag(model.id)
                                        }
                                    }
                                }
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

            // Provider-specific configuration - Always show all blocks
            Section("OpenAI Configuration") {
                // API Key
                HStack {
                    Text("API Key")
                        .frame(width: 80, alignment: .trailing)

                    if self.showingOpenAIKey {
                        TextField("sk-...", text: Binding(
                            get: { self.settings.openAIAPIKey },
                            set: { self.settings.openAIAPIKey = $0 }))
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("sk-...", text: Binding(
                            get: { self.settings.openAIAPIKey },
                            set: { self.settings.openAIAPIKey = $0 }))
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        self.showingOpenAIKey.toggle()
                    } label: {
                        Image(systemName: self.showingOpenAIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Anthropic Configuration") {
                // API Key
                HStack {
                    Text("API Key")
                        .frame(width: 80, alignment: .trailing)

                    if self.showingAnthropicKey {
                        TextField("sk-ant-...", text: Binding(
                            get: { self.settings.anthropicAPIKey },
                            set: { self.settings.anthropicAPIKey = $0 }))
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("sk-ant-...", text: Binding(
                            get: { self.settings.anthropicAPIKey },
                            set: { self.settings.anthropicAPIKey = $0 }))
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        self.showingAnthropicKey.toggle()
                    } label: {
                        Image(systemName: self.showingAnthropicKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Ollama Configuration") {
                // Base URL
                HStack {
                    Text("Base URL")
                        .frame(width: 80, alignment: .trailing)

                    TextField("http://localhost:11434", text: Binding(
                        get: { self.settings.ollamaBaseURL },
                        set: { self.settings.ollamaBaseURL = $0 }))
                        .textFieldStyle(.roundedBorder)
                }

                // Connection status
                HStack {
                    Spacer()
                    Text("Ensure Ollama is running locally")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            Section("Parameters") {
                // Temperature
                HStack {
                    Text("Temperature")
                        .frame(width: 80, alignment: .trailing)

                    Slider(value: Binding(
                        get: { self.settings.temperature },
                        set: { self.settings.temperature = $0 }), in: 0...1, step: 0.1)

                    Text(String(format: "%.1f", self.settings.temperature))
                        .monospacedDigit()
                        .frame(width: 30)
                }

                // Max tokens
                HStack {
                    Text("Max Tokens")
                        .frame(width: 80, alignment: .trailing)

                    TextField("", value: Binding(
                        get: { self.settings.maxTokens },
                        set: { self.settings.maxTokens = $0 }), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)

                    Text("(1 - 128,000)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Vision Model Override
            Section("Vision Model Override") {
                Toggle(isOn: Binding(
                    get: { self.settings.useCustomVisionModel },
                    set: { self.settings.useCustomVisionModel = $0 }))
                {
                    Text("Use custom model for vision tasks")
                }

                if self.settings.useCustomVisionModel {
                    HStack {
                        Text("Vision Model")
                            .frame(width: 80, alignment: .trailing)

                        Picker("", selection: Binding(
                            get: { self.settings.customVisionModel },
                            set: { self.settings.customVisionModel = $0 }))
                        {
                            ForEach(self.allModels, id: \.provider) { provider, models in
                                Section(header: Text(provider.capitalized)) {
                                    ForEach(models, id: \.id) { model in
                                        Text(model.name).tag(model.id)
                                    }
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }

                    Text(
                        "When enabled, this model will be used for all vision-related tasks like screenshots and image analysis, regardless of the primary model selection.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 88)
                }
            }

            // API usage info
            if self.settings.hasValidAPIKey {
                Section {
                    HStack {
                        Spacer()
                        if self.settings.selectedProvider == "openai" {
                            Link("View API Usage", destination: URL(string: "https://platform.openai.com/usage")!)
                        } else if self.settings.selectedProvider == "anthropic" {
                            Link("View API Usage", destination: URL(string: "https://console.anthropic.com/usage")!)
                        }
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
                            if !modifiers.isEmpty, event.charactersIgnoringModifiers != nil {
                                // Convert NSEvent.ModifierFlags to string representation
                                var shortcutParts: [String] = []
                                if modifiers.contains(.command) { shortcutParts.append("⌘") }
                                if modifiers.contains(.control) { shortcutParts.append("⌃") }
                                if modifiers.contains(.option) { shortcutParts.append("⌥") }
                                if modifiers.contains(.shift) { shortcutParts.append("⇧") }
                                shortcutParts.append(event.charactersIgnoringModifiers!.uppercased())

                                // Update the shortcut in settings
                                self.settings.globalShortcut = shortcutParts.joined()

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
