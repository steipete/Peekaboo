import AppKit
import Observation
import PeekabooCore
import SwiftUI

struct SettingsWindow: View {
    let updater: any UpdaterProviding

    @Environment(PeekabooSettings.self) private var settings
    @Environment(Permissions.self) private var permissions
    @State private var selectedTab: PeekabooSettingsTab = .general
    @State private var monitoringPermissions = false

    init(updater: any UpdaterProviding = DisabledUpdaterController()) {
        self.updater = updater
    }

    var body: some View {
        TabView(selection: self.$selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(PeekabooSettingsTab.general)

            if self.settings.agentModeEnabled {
                AISettingsView()
                    .tabItem {
                        Label("AI", systemImage: "brain")
                    }
                    .tag(PeekabooSettingsTab.ai)
            }

            VisualizerSettingsTabView()
                .tabItem {
                    Label("Visualizer", systemImage: "sparkles")
                }
                .tag(PeekabooSettingsTab.visualizer)

            ShortcutSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag(PeekabooSettingsTab.shortcuts)

            PermissionsSettingsView()
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
                .tag(PeekabooSettingsTab.permissions)

            AboutSettingsView(updater: self.updater)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(PeekabooSettingsTab.about)
        }
        .frame(width: 550, height: 700)
        .onReceive(NotificationCenter.default.publisher(for: .peekabooSelectSettingsTab)) { note in
            if let tab = note.object as? PeekabooSettingsTab {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    self.selectedTab = self.sanitizedTabSelection(tab)
                }
            }
        }
        .onAppear {
            if let pending = SettingsTabRouter.consumePending() {
                self.selectedTab = self.sanitizedTabSelection(pending)
            }
            if !self.settings.agentModeEnabled, self.selectedTab == .ai {
                self.selectedTab = .general
            }
            self.updatePermissionMonitoring(for: self.selectedTab)
        }
        .onChange(of: self.selectedTab) { _, newValue in
            self.updatePermissionMonitoring(for: newValue)
        }
        .onChange(of: self.settings.agentModeEnabled) { _, enabled in
            if !enabled, self.selectedTab == .ai {
                self.selectedTab = .general
            }
        }
        .onDisappear {
            self.stopPermissionMonitoring()
        }
    }

    private func sanitizedTabSelection(_ tab: PeekabooSettingsTab) -> PeekabooSettingsTab {
        if tab == .ai, !self.settings.agentModeEnabled {
            return .general
        }
        return tab
    }

    private func updatePermissionMonitoring(for tab: PeekabooSettingsTab) {
        let shouldMonitor = tab == .permissions
        if shouldMonitor, !self.monitoringPermissions {
            self.monitoringPermissions = true
            self.permissions.registerMonitoring()
        } else if !shouldMonitor, self.monitoringPermissions {
            self.monitoringPermissions = false
            self.permissions.unregisterMonitoring()
        }
    }

    private func stopPermissionMonitoring() {
        guard self.monitoringPermissions else { return }
        self.monitoringPermissions = false
        self.permissions.unregisterMonitoring()
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
                Toggle("Enable agent mode", isOn: Binding(
                    get: { self.settings.agentModeEnabled },
                    set: { self.settings.agentModeEnabled = $0 }))
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
    @State private var detectedOllamaModelOptions: [(id: String, name: String)] = []
    @State private var hasAttemptedOllamaDetection = false

    private var allModels: [(provider: String, models: [(id: String, name: String)])] {
        var models: [(provider: String, models: [(id: String, name: String)])] = [
            ("openai", [
                ("gpt-5.1", "GPT-5.1"),
                ("gpt-5.1-mini", "GPT-5.1 mini"),
                ("gpt-5.1-nano", "GPT-5.1 nano"),
                ("gpt-5", "GPT-5"),
                ("gpt-5-mini", "GPT-5 mini"),
            ]),
            ("anthropic", [
                ("claude-sonnet-4-5-20250929", "Claude Sonnet 4.5"),
                ("claude-haiku-4.5", "Claude Haiku 4.5"),
            ]),
            ("ollama", self.ollamaModelOptions),
        ]

        // Add custom providers
        for (id, provider) in self.settings.customProviders.sorted(by: { $0.key < $1.key }) {
            let providerModels = provider.models?.map { (id: $0.key, name: $0.value.name) } ?? [
                (id: "custom-model", name: "Default Model"),
            ]
            models.append((id, providerModels))
        }

        return models
    }

    private var modelDescriptions: [String: String] {
        [
            // OpenAI models
            "gpt-5.1": "Flagship GPT-5.1 model with 400K context and upgraded tool " +
                "usage + reasoning.",
            "gpt-5.1-mini": "Cost-optimized GPT-5.1 Mini with identical tools + 400K context " +
                "at a friendlier price.",
            "gpt-5.1-nano": "Ultra-low latency GPT-5.1 Nano tuned for snappy agent runs and " +
                "tool calling.",
            "gpt-5": "Flagship GPT-5 model with 400K context and best-in-class " +
                "coding + automation skills.",
            "gpt-5-mini": "Cost-optimized GPT-5 Mini with the same tools + 400K context " +
                "at a friendlier price.",
            // Anthropic models
            "claude-sonnet-4-5-20250929": "Claude Sonnet 4.5 with new tools + computer use, " +
                "tuned for long-running automation tasks.",
            "claude-haiku-4.5": "Claude Haiku 4.5 for ultra-low latency assistant tasks with " +
                "the updated reasoning stack.",
            // Ollama models
            "llava:latest": "Open-source multimodal model that runs locally. Good for " +
                "privacy-conscious users and offline usage.",
            "llama3.2-vision:latest": "Meta's latest vision-capable model with strong " +
                "performance on visual understanding tasks.",
        ]
    }

    private func provider(for modelId: String) -> String? {
        for (provider, models) in self.allModels
            where models.contains(where: { $0.id == modelId })
        {
            return provider
        }
        return nil
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
                                if let provider = self.provider(for: newModel) {
                                    self.settings.selectedProvider = provider
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

            // Provider-specific configuration
            Section("OpenAI Configuration") {
                APIKeyField(
                    provider: .openai,
                    apiKey: Binding(
                        get: { self.settings.openAIAPIKey },
                        set: { self.settings.openAIAPIKey = $0 }))
            }

            Section("Anthropic Configuration") {
                APIKeyField(
                    provider: .anthropic,
                    apiKey: Binding(
                        get: { self.settings.anthropicAPIKey },
                        set: { self.settings.anthropicAPIKey = $0 }))
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

                    Slider(
                        value: Binding(
                            get: { self.settings.temperature },
                            set: { self.settings.temperature = $0 }),
                        in: 0...1,
                        step: 0.1)

                    Text(String(format: "%.1f", self.settings.temperature))
                        .monospacedDigit()
                        .frame(width: 30)
                }

                // Max tokens
                HStack {
                    Text("Max Tokens")
                        .frame(width: 80, alignment: .trailing)

                    TextField(
                        "",
                        value: Binding(
                            get: { self.settings.maxTokens },
                            set: { self.settings.maxTokens = $0 }),
                        format: .number)
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
                        "When enabled, this model will be used for all vision-related tasks " +
                            "like screenshots and image analysis, regardless of the primary " +
                            "model selection.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 88)
                }
            }

            // Custom Providers
            Section("Custom Providers") {
                CustomProviderView()
            }

            // API usage info
        }
        .formStyle(.grouped)
        .padding()
        .task(id: self.settings.ollamaBaseURL) {
            await self.refreshOllamaModels()
        }
    }

    private var ollamaModelOptions: [(id: String, name: String)] {
        if !self.detectedOllamaModelOptions.isEmpty {
            return self.detectedOllamaModelOptions
        }
        return Self.defaultOllamaModels
    }

    private static let defaultOllamaModels: [(id: String, name: String)] = [
        ("llava:latest", "LLaVA"),
        ("llama3.2-vision:latest", "Llama 3.2 Vision"),
    ]

    @MainActor
    private func refreshOllamaModels() async {
        if self.hasAttemptedOllamaDetection {
            return
        }
        self.hasAttemptedOllamaDetection = true

        guard let url = URL(string: "\(self.settings.ollamaBaseURL)/api/tags") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return
            }

            let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            let models = decoded.models.map { model in
                (id: model.name, name: model.displayName)
            }

            if !models.isEmpty {
                self.detectedOllamaModelOptions = models
            }
        } catch {
            // Silently ignore detection failures; defaults remain.
        }
    }
}

private struct OllamaTagsResponse: Decodable {
    struct OllamaModel: Decodable {
        struct Details: Decodable {
            let parameter_size: String?
        }

        let name: String
        let details: Details?

        var displayName: String {
            if let parameterSize = self.details?.parameter_size {
                return "\(self.name) (\(parameterSize))"
            }
            return self.name
        }
    }

    let models: [OllamaModel]
}

// MARK: - Visualizer Settings Tab Wrapper

struct VisualizerSettingsTabView: View {
    @Environment(PeekabooSettings.self) private var settings
    @Environment(VisualizerCoordinator.self) private var visualizerCoordinator

    var body: some View {
        VisualizerSettingsView(settings: self.settings)
            .environment(self.visualizerCoordinator)
    }
}

// MARK: - Shortcuts Settings (Wrapper)

// ShortcutsSettingsView is now in its own file
