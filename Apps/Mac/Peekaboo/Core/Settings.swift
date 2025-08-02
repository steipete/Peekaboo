import Foundation
import Observation
import PeekabooCore
import ServiceManagement

/// Application settings and preferences manager.
///
/// Settings are automatically persisted to UserDefaults and synchronized across app launches.
/// This class uses the modern @Observable pattern for SwiftUI integration.
@Observable
final class PeekabooSettings {
    // Reference to ConfigurationManager
    private let configManager = ConfigurationManager.shared

    // API Configuration - Now synced with config.json
    var selectedProvider: String = "anthropic" {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }

    var openAIAPIKey: String = "" {
        didSet {
            self.save()
            self.saveAPIKeyToCredentials("OPENAI_API_KEY", self.openAIAPIKey)
        }
    }

    var anthropicAPIKey: String = "" {
        didSet {
            self.save()
            self.saveAPIKeyToCredentials("ANTHROPIC_API_KEY", self.anthropicAPIKey)
        }
    }

    var ollamaBaseURL: String = "http://localhost:11434" {
        didSet { self.save() }
    }

    var selectedModel: String = "claude-opus-4-20250514" {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }

    // Vision model override
    var useCustomVisionModel: Bool = false {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }

    var customVisionModel: String = "gpt-4o" {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }

    var temperature: Double = 0.7 {
        didSet {
            let clamped = max(0, min(1, temperature))
            if self.temperature != clamped {
                self.temperature = clamped
            } else {
                self.save()
                self.updateConfigFile()
            }
        }
    }

    var maxTokens: Int = 16384 {
        didSet {
            let clamped = max(1, min(128_000, maxTokens))
            if self.maxTokens != clamped {
                self.maxTokens = clamped
            } else {
                self.save()
                self.updateConfigFile()
            }
        }
    }

    // UI Preferences
    var alwaysOnTop: Bool = false {
        didSet { self.save() }
    }

    var showInDock: Bool = true {
        didSet {
            self.save()
            // Update dock visibility when preference changes
            Task { @MainActor in
                DockIconManager.shared.updateDockVisibility()
            }
        }
    }

    var launchAtLogin: Bool = false {
        didSet {
            self.save()
            // Update launch at login status
            do {
                if self.launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
                // Revert the change if it failed
                self.launchAtLogin = !self.launchAtLogin
            }
        }
    }

    var globalShortcut: String = "⌘⇧Space" {
        didSet { self.save() }
    }

    // Mac-specific UI Features
    var voiceActivationEnabled: Bool = true {
        didSet { self.save() }
    }

    var hapticFeedbackEnabled: Bool = true {
        didSet { self.save() }
    }

    var soundEffectsEnabled: Bool = true {
        didSet { self.save() }
    }
    
    // MARK: - Visualizer Settings
    
    var visualizerEnabled: Bool = true {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }
    
    var visualizerAnimationSpeed: Double = 1.0 {
        didSet {
            let clamped = max(0.1, min(2.0, visualizerAnimationSpeed))
            if self.visualizerAnimationSpeed != clamped {
                self.visualizerAnimationSpeed = clamped
            } else {
                self.save()
            }
        }
    }
    
    var visualizerEffectIntensity: Double = 1.0 {
        didSet {
            let clamped = max(0.1, min(2.0, visualizerEffectIntensity))
            if self.visualizerEffectIntensity != clamped {
                self.visualizerEffectIntensity = clamped
            } else {
                self.save()
            }
        }
    }
    
    var visualizerSoundEnabled: Bool = true {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }
    
    var visualizerKeyboardTheme: String = "modern" {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }
    
    // Individual animation toggles
    var screenshotFlashEnabled: Bool = true {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }
    
    var clickAnimationEnabled: Bool = true {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }
    
    var typeAnimationEnabled: Bool = true {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }
    
    var scrollAnimationEnabled: Bool = true {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }
    
    var mouseTrailEnabled: Bool = true {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }
    
    var swipePathEnabled: Bool = true {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }
    
    var hotkeyOverlayEnabled: Bool = true {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }
    
    var appLifecycleEnabled: Bool = true {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }
    
    var windowOperationEnabled: Bool = true {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }
    
    var menuNavigationEnabled: Bool = true {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }
    
    var dialogInteractionEnabled: Bool = true {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }
    
    var spaceTransitionEnabled: Bool = true {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }
    
    // Easter eggs
    var ghostEasterEggEnabled: Bool = true {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }
    
    var annotatedScreenshotEnabled: Bool = true {
        didSet {
            self.save()
            self.updateConfigFile()
        }
    }

    // Custom Providers
    @ObservationIgnored
    var customProviders: [String: Configuration.CustomProvider] {
        configManager.listCustomProviders()
    }
    
    // Computed Properties
    var hasValidAPIKey: Bool {
        switch self.selectedProvider {
        case "openai":
            !self.openAIAPIKey.isEmpty
        case "anthropic":
            !self.anthropicAPIKey.isEmpty
        case "ollama":
            true // Ollama doesn't require API key
        default:
            // Check if it's a custom provider
            if let customProvider = customProviders[selectedProvider] {
                return !customProvider.options.apiKey.isEmpty
            }
            return false
        }
    }
    
    var allAvailableProviders: [String] {
        let builtIn = ["openai", "anthropic", "ollama"]
        let custom = Array(customProviders.keys)
        return builtIn + custom.sorted()
    }

    // Storage
    private let userDefaults = UserDefaults.standard
    private let keyPrefix = "peekaboo."

    init() {
        self.load()
        self.loadFromPeekabooConfig()
        self.migrateSettingsIfNeeded()
    }

    private func load() {
        self.selectedProvider = self.userDefaults.string(forKey: "\(self.keyPrefix)selectedProvider") ?? "anthropic"
        self.openAIAPIKey = self.userDefaults.string(forKey: "\(self.keyPrefix)openAIAPIKey") ?? ""
        self.anthropicAPIKey = self.userDefaults.string(forKey: "\(self.keyPrefix)anthropicAPIKey") ?? ""
        self.ollamaBaseURL = self.userDefaults.string(forKey: "\(self.keyPrefix)ollamaBaseURL") ?? "http://localhost:11434"

        // Set default model based on provider
        let defaultProvider = self.selectedProvider
        let defaultModel = if defaultProvider == "openai" {
            "gpt-4.1"
        } else if defaultProvider == "anthropic" {
            "claude-opus-4-20250514"
        } else {
            "llava:latest"
        }
        self.selectedModel = self.userDefaults.string(forKey: "\(self.keyPrefix)selectedModel") ?? defaultModel
        self.useCustomVisionModel = self.userDefaults.bool(forKey: "\(self.keyPrefix)useCustomVisionModel")
        self.customVisionModel = self.userDefaults.string(forKey: "\(self.keyPrefix)customVisionModel") ?? "gpt-4o"
        self.temperature = self.userDefaults.double(forKey: "\(self.keyPrefix)temperature")
        if self.temperature == 0 { self.temperature = 0.7 } // Default if not set
        self.maxTokens = self.userDefaults.integer(forKey: "\(self.keyPrefix)maxTokens")
        if self.maxTokens == 0 { self.maxTokens = 16384 } // Default if not set

        self.alwaysOnTop = self.userDefaults.bool(forKey: "\(self.keyPrefix)alwaysOnTop")
        // Default showInDock to true if not previously set
        if self.userDefaults.object(forKey: "\(self.keyPrefix)showInDock") == nil {
            self.showInDock = true
            self.userDefaults.set(true, forKey: "\(self.keyPrefix)showInDock")
        } else {
            self.showInDock = self.userDefaults.bool(forKey: "\(self.keyPrefix)showInDock")
        }
        // Check actual launch at login status
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        self.userDefaults.set(self.launchAtLogin, forKey: "\(self.keyPrefix)launchAtLogin")
        self.globalShortcut = self.userDefaults.string(forKey: "\(self.keyPrefix)globalShortcut") ?? "⌘⇧Space"

        // Default voiceActivationEnabled to true if not previously set
        if self.userDefaults.object(forKey: "\(self.keyPrefix)voiceActivationEnabled") == nil {
            self.voiceActivationEnabled = true
            self.userDefaults.set(true, forKey: "\(self.keyPrefix)voiceActivationEnabled")
        } else {
            self.voiceActivationEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)voiceActivationEnabled")
        }
        self.hapticFeedbackEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)hapticFeedbackEnabled")
        self.soundEffectsEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)soundEffectsEnabled")

        // Set defaults for bools that should be true by default
        if !self.userDefaults.bool(forKey: "\(self.keyPrefix)hapticFeedbackEnabledSet") {
            self.hapticFeedbackEnabled = true
            self.userDefaults.set(true, forKey: "\(self.keyPrefix)hapticFeedbackEnabledSet")
        }
        if !self.userDefaults.bool(forKey: "\(self.keyPrefix)soundEffectsEnabledSet") {
            self.soundEffectsEnabled = true
            self.userDefaults.set(true, forKey: "\(self.keyPrefix)soundEffectsEnabledSet")
        }
        
        // Load visualizer settings
        if self.userDefaults.object(forKey: "\(self.keyPrefix)visualizerEnabled") == nil {
            self.visualizerEnabled = true
        } else {
            self.visualizerEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)visualizerEnabled")
        }
        
        self.visualizerAnimationSpeed = self.userDefaults.double(forKey: "\(self.keyPrefix)visualizerAnimationSpeed")
        if self.visualizerAnimationSpeed == 0 { self.visualizerAnimationSpeed = 1.0 }
        
        self.visualizerEffectIntensity = self.userDefaults.double(forKey: "\(self.keyPrefix)visualizerEffectIntensity")
        if self.visualizerEffectIntensity == 0 { self.visualizerEffectIntensity = 1.0 }
        
        if self.userDefaults.object(forKey: "\(self.keyPrefix)visualizerSoundEnabled") == nil {
            self.visualizerSoundEnabled = true
        } else {
            self.visualizerSoundEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)visualizerSoundEnabled")
        }
        
        self.visualizerKeyboardTheme = self.userDefaults.string(forKey: "\(self.keyPrefix)visualizerKeyboardTheme") ?? "modern"
        
        // Load individual animation toggles with defaults to true
        let animationKeys = [
            "screenshotFlashEnabled", "clickAnimationEnabled", "typeAnimationEnabled",
            "scrollAnimationEnabled", "mouseTrailEnabled", "swipePathEnabled",
            "hotkeyOverlayEnabled", "appLifecycleEnabled", "windowOperationEnabled",
            "menuNavigationEnabled", "dialogInteractionEnabled", "spaceTransitionEnabled",
            "ghostEasterEggEnabled"
        ]
        
        for key in animationKeys {
            let fullKey = "\(self.keyPrefix)\(key)"
            if self.userDefaults.object(forKey: fullKey) == nil {
                self.userDefaults.set(true, forKey: fullKey)
            }
        }
        
        self.screenshotFlashEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)screenshotFlashEnabled")
        self.clickAnimationEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)clickAnimationEnabled")
        self.typeAnimationEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)typeAnimationEnabled")
        self.scrollAnimationEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)scrollAnimationEnabled")
        self.mouseTrailEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)mouseTrailEnabled")
        self.swipePathEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)swipePathEnabled")
        self.hotkeyOverlayEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)hotkeyOverlayEnabled")
        self.appLifecycleEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)appLifecycleEnabled")
        self.windowOperationEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)windowOperationEnabled")
        self.menuNavigationEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)menuNavigationEnabled")
        self.dialogInteractionEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)dialogInteractionEnabled")
        self.spaceTransitionEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)spaceTransitionEnabled")
        self.ghostEasterEggEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)ghostEasterEggEnabled")
    }

    private func save() {
        self.userDefaults.set(self.selectedProvider, forKey: "\(self.keyPrefix)selectedProvider")
        self.userDefaults.set(self.openAIAPIKey, forKey: "\(self.keyPrefix)openAIAPIKey")
        self.userDefaults.set(self.anthropicAPIKey, forKey: "\(self.keyPrefix)anthropicAPIKey")
        self.userDefaults.set(self.ollamaBaseURL, forKey: "\(self.keyPrefix)ollamaBaseURL")
        self.userDefaults.set(self.selectedModel, forKey: "\(self.keyPrefix)selectedModel")
        self.userDefaults.set(self.useCustomVisionModel, forKey: "\(self.keyPrefix)useCustomVisionModel")
        self.userDefaults.set(self.customVisionModel, forKey: "\(self.keyPrefix)customVisionModel")
        self.userDefaults.set(self.temperature, forKey: "\(self.keyPrefix)temperature")
        self.userDefaults.set(self.maxTokens, forKey: "\(self.keyPrefix)maxTokens")

        self.userDefaults.set(self.alwaysOnTop, forKey: "\(self.keyPrefix)alwaysOnTop")
        self.userDefaults.set(self.showInDock, forKey: "\(self.keyPrefix)showInDock")
        self.userDefaults.set(self.launchAtLogin, forKey: "\(self.keyPrefix)launchAtLogin")
        self.userDefaults.set(self.globalShortcut, forKey: "\(self.keyPrefix)globalShortcut")

        self.userDefaults.set(self.voiceActivationEnabled, forKey: "\(self.keyPrefix)voiceActivationEnabled")
        self.userDefaults.set(self.hapticFeedbackEnabled, forKey: "\(self.keyPrefix)hapticFeedbackEnabled")
        self.userDefaults.set(self.soundEffectsEnabled, forKey: "\(self.keyPrefix)soundEffectsEnabled")
        
        // Save visualizer settings
        self.userDefaults.set(self.visualizerEnabled, forKey: "\(self.keyPrefix)visualizerEnabled")
        self.userDefaults.set(self.visualizerAnimationSpeed, forKey: "\(self.keyPrefix)visualizerAnimationSpeed")
        self.userDefaults.set(self.visualizerEffectIntensity, forKey: "\(self.keyPrefix)visualizerEffectIntensity")
        self.userDefaults.set(self.visualizerSoundEnabled, forKey: "\(self.keyPrefix)visualizerSoundEnabled")
        self.userDefaults.set(self.visualizerKeyboardTheme, forKey: "\(self.keyPrefix)visualizerKeyboardTheme")
        
        // Save individual animation toggles
        self.userDefaults.set(self.screenshotFlashEnabled, forKey: "\(self.keyPrefix)screenshotFlashEnabled")
        self.userDefaults.set(self.clickAnimationEnabled, forKey: "\(self.keyPrefix)clickAnimationEnabled")
        self.userDefaults.set(self.typeAnimationEnabled, forKey: "\(self.keyPrefix)typeAnimationEnabled")
        self.userDefaults.set(self.scrollAnimationEnabled, forKey: "\(self.keyPrefix)scrollAnimationEnabled")
        self.userDefaults.set(self.mouseTrailEnabled, forKey: "\(self.keyPrefix)mouseTrailEnabled")
        self.userDefaults.set(self.swipePathEnabled, forKey: "\(self.keyPrefix)swipePathEnabled")
        self.userDefaults.set(self.hotkeyOverlayEnabled, forKey: "\(self.keyPrefix)hotkeyOverlayEnabled")
        self.userDefaults.set(self.appLifecycleEnabled, forKey: "\(self.keyPrefix)appLifecycleEnabled")
        self.userDefaults.set(self.windowOperationEnabled, forKey: "\(self.keyPrefix)windowOperationEnabled")
        self.userDefaults.set(self.menuNavigationEnabled, forKey: "\(self.keyPrefix)menuNavigationEnabled")
        self.userDefaults.set(self.dialogInteractionEnabled, forKey: "\(self.keyPrefix)dialogInteractionEnabled")
        self.userDefaults.set(self.spaceTransitionEnabled, forKey: "\(self.keyPrefix)spaceTransitionEnabled")
        self.userDefaults.set(self.ghostEasterEggEnabled, forKey: "\(self.keyPrefix)ghostEasterEggEnabled")
    }

    private func loadFromPeekabooConfig() {
        // Use ConfigurationManager to load from config.json
        _ = self.configManager.loadConfiguration()

        // Load API keys through ConfigurationManager (checks env vars, then credentials file)
        if let openAIKey = configManager.getOpenAIAPIKey(), !openAIKey.isEmpty {
            self.openAIAPIKey = openAIKey
        }

        if let anthropicKey = configManager.getAnthropicAPIKey(), !anthropicKey.isEmpty {
            self.anthropicAPIKey = anthropicKey
        }

        // Load provider and model from config
        let selectedProvider = self.configManager.getSelectedProvider()
        if !selectedProvider.isEmpty {
            self.selectedProvider = selectedProvider
        }

        // Load agent settings from config
        if let model = configManager.getAgentModel() {
            self.selectedModel = model
        }

        let configTemp = self.configManager.getAgentTemperature()
        if configTemp != 0.7 { // Only update if not default
            self.temperature = configTemp
        }

        let configTokens = self.configManager.getAgentMaxTokens()
        if configTokens != 16384 { // Only update if not default
            self.maxTokens = configTokens
        }

        // Load Ollama base URL
        let ollamaURL = self.configManager.getOllamaBaseURL()
        if ollamaURL != "http://localhost:11434" {
            self.ollamaBaseURL = ollamaURL
        }
    }

    private func migrateSettingsIfNeeded() {
        // Check if we've already migrated
        let migrationKey = "\(keyPrefix)migratedToConfigJson"
        guard !self.userDefaults.bool(forKey: migrationKey) else { return }

        // Migrate settings from UserDefaults to config.json
        do {
            try self.configManager.updateConfiguration { config in
                // Ensure structures exist
                if config.agent == nil {
                    config.agent = Configuration.AgentConfig()
                }

                // Migrate agent settings
                config.agent?.defaultModel = self.selectedModel
                config.agent?.temperature = self.temperature
                config.agent?.maxTokens = self.maxTokens

                // Update AI providers if needed
                if config.aiProviders == nil {
                    config.aiProviders = Configuration.AIProviderConfig()
                }

                // Build providers string based on selected provider and model
                let providerString = switch self.selectedProvider {
                case "openai":
                    "openai/\(self.selectedModel)"
                case "anthropic":
                    "anthropic/\(self.selectedModel)"
                case "ollama":
                    "ollama/\(self.selectedModel)"
                default:
                    "anthropic/claude-opus-4-20250514"
                }

                // Set providers string with fallbacks
                config.aiProviders?.providers = "\(providerString),ollama/llava:latest"

                // Set Ollama base URL if custom
                if self.ollamaBaseURL != "http://localhost:11434" {
                    config.aiProviders?.ollamaBaseUrl = self.ollamaBaseURL
                }
            }

            // Mark as migrated
            self.userDefaults.set(true, forKey: migrationKey)

            print("Successfully migrated settings to config.json")
        } catch {
            print("Failed to migrate settings to config.json: \(error)")
        }
    }

    private func updateConfigFile() {
        do {
            try self.configManager.updateConfiguration { config in
                // Ensure structures exist
                if config.agent == nil {
                    config.agent = Configuration.AgentConfig()
                }

                // Update agent settings
                config.agent?.defaultModel = self.selectedModel
                config.agent?.temperature = self.temperature
                config.agent?.maxTokens = self.maxTokens

                // Update AI providers
                if config.aiProviders == nil {
                    config.aiProviders = Configuration.AIProviderConfig()
                }

                // Build providers string based on selected provider and model
                let providerString = switch self.selectedProvider {
                case "openai":
                    "openai/\(self.selectedModel)"
                case "anthropic":
                    "anthropic/\(self.selectedModel)"
                case "ollama":
                    "ollama/\(self.selectedModel)"
                default:
                    // Check if it's a custom provider
                    if self.customProviders[self.selectedProvider] != nil {
                        "\(self.selectedProvider)/\(self.selectedModel)"
                    } else {
                        "anthropic/claude-opus-4-20250514"
                    }
                }

                // Update providers string
                if let currentProviders = config.aiProviders?.providers {
                    // Replace the first provider while keeping fallbacks
                    let providers = currentProviders.split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespaces) }
                    var newProviders = [providerString]

                    // Add other providers that aren't the same type
                    for provider in providers.dropFirst() {
                        let providerType = provider.split(separator: "/").first.map(String.init) ?? ""
                        if providerType != self.selectedProvider {
                            newProviders.append(provider)
                        }
                    }

                    // Ensure we have a fallback
                    if newProviders.count == 1, !providerString.starts(with: "ollama/") {
                        newProviders.append("ollama/llava:latest")
                    }

                    config.aiProviders?.providers = newProviders.joined(separator: ",")
                } else {
                    config.aiProviders?.providers = "\(providerString),ollama/llava:latest"
                }

                // Update Ollama base URL if custom
                if self.ollamaBaseURL != "http://localhost:11434" {
                    config.aiProviders?.ollamaBaseUrl = self.ollamaBaseURL
                }
            }
        } catch {
            print("Failed to update config.json: \(error)")
        }
    }

    @MainActor
    private func saveAPIKeyToCredentials(_ key: String, _ value: String) {
        do {
            if value.isEmpty {
                // Don't save empty keys
                return
            }
            try self.configManager.setCredential(key: key, value: value)

            // Refresh the agent service to pick up new API keys
            PeekabooServices.shared.refreshAgentService()
        } catch {
            print("Failed to save API key to credentials: \(error)")
        }
    }
    
    // MARK: - Custom Provider Management
    
    func addCustomProvider(_ provider: Configuration.CustomProvider, id: String) throws {
        try configManager.addCustomProvider(provider, id: id)
        // Trigger UI update
        objectWillChange.send()
    }
    
    func removeCustomProvider(id: String) throws {
        try configManager.removeCustomProvider(id: id)
        // If we were using this provider, switch to a built-in one
        if selectedProvider == id {
            selectedProvider = "anthropic"
        }
        // Trigger UI update
        objectWillChange.send()
    }
    
    func getCustomProvider(id: String) -> Configuration.CustomProvider? {
        return configManager.getCustomProvider(id: id)
    }
    
    func testCustomProvider(id: String) async -> (success: Bool, error: String?) {
        return await configManager.testCustomProvider(id: id)
    }
    
    func discoverModelsForCustomProvider(id: String) async -> (models: [String], error: String?) {
        return await configManager.discoverModelsForCustomProvider(id: id)
    }
}
