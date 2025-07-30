import Foundation
import Observation
import ServiceManagement
import PeekabooCore

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
            self.saveAPIKeyToCredentials("OPENAI_API_KEY", openAIAPIKey)
        }
    }
    
    var anthropicAPIKey: String = "" {
        didSet { 
            self.save()
            self.saveAPIKeyToCredentials("ANTHROPIC_API_KEY", anthropicAPIKey)
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
            if temperature != clamped {
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
            if maxTokens != clamped {
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
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
                // Revert the change if it failed
                self.launchAtLogin = !launchAtLogin
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

    // Computed Properties
    var hasValidAPIKey: Bool {
        switch selectedProvider {
        case "openai":
            return !openAIAPIKey.isEmpty
        case "anthropic":
            return !anthropicAPIKey.isEmpty
        case "ollama":
            return true // Ollama doesn't require API key
        default:
            return false
        }
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
        let defaultModel: String
        if defaultProvider == "openai" {
            defaultModel = "gpt-4.1"
        } else if defaultProvider == "anthropic" {
            defaultModel = "claude-opus-4-20250514"
        } else {
            defaultModel = "llava:latest"
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
    }

    private func loadFromPeekabooConfig() {
        // Use ConfigurationManager to load from config.json
        _ = configManager.loadConfiguration()
        
        // Load API keys through ConfigurationManager (checks env vars, then credentials file)
        if let openAIKey = configManager.getOpenAIAPIKey(), !openAIKey.isEmpty {
            self.openAIAPIKey = openAIKey
        }
        
        if let anthropicKey = configManager.getAnthropicAPIKey(), !anthropicKey.isEmpty {
            self.anthropicAPIKey = anthropicKey
        }
        
        // Load provider and model from config
        let selectedProvider = configManager.getSelectedProvider()
        if !selectedProvider.isEmpty {
            self.selectedProvider = selectedProvider
        }
        
        // Load agent settings from config
        if let model = configManager.getAgentModel() {
            self.selectedModel = model
        }
        
        let configTemp = configManager.getAgentTemperature()
        if configTemp != 0.7 { // Only update if not default
            self.temperature = configTemp
        }
        
        let configTokens = configManager.getAgentMaxTokens()
        if configTokens != 16384 { // Only update if not default
            self.maxTokens = configTokens
        }
        
        // Load Ollama base URL
        let ollamaURL = configManager.getOllamaBaseURL()
        if ollamaURL != "http://localhost:11434" {
            self.ollamaBaseURL = ollamaURL
        }
    }
    
    private func migrateSettingsIfNeeded() {
        // Check if we've already migrated
        let migrationKey = "\(keyPrefix)migratedToConfigJson"
        guard !userDefaults.bool(forKey: migrationKey) else { return }
        
        // Migrate settings from UserDefaults to config.json
        do {
            try configManager.updateConfiguration { config in
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
                let providerString: String
                switch self.selectedProvider {
                case "openai":
                    providerString = "openai/\(self.selectedModel)"
                case "anthropic":
                    providerString = "anthropic/\(self.selectedModel)"
                case "ollama":
                    providerString = "ollama/\(self.selectedModel)"
                default:
                    providerString = "anthropic/claude-opus-4-20250514"
                }
                
                // Set providers string with fallbacks
                config.aiProviders?.providers = "\(providerString),ollama/llava:latest"
                
                // Set Ollama base URL if custom
                if self.ollamaBaseURL != "http://localhost:11434" {
                    config.aiProviders?.ollamaBaseUrl = self.ollamaBaseURL
                }
            }
            
            // Mark as migrated
            userDefaults.set(true, forKey: migrationKey)
            
            print("Successfully migrated settings to config.json")
        } catch {
            print("Failed to migrate settings to config.json: \(error)")
        }
    }
    
    private func updateConfigFile() {
        do {
            try configManager.updateConfiguration { config in
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
                let providerString: String
                switch self.selectedProvider {
                case "openai":
                    providerString = "openai/\(self.selectedModel)"
                case "anthropic":
                    providerString = "anthropic/\(self.selectedModel)"
                case "ollama":
                    providerString = "ollama/\(self.selectedModel)"
                default:
                    providerString = "anthropic/claude-opus-4-20250514"
                }
                
                // Update providers string
                if let currentProviders = config.aiProviders?.providers {
                    // Replace the first provider while keeping fallbacks
                    let providers = currentProviders.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                    var newProviders = [providerString]
                    
                    // Add other providers that aren't the same type
                    for provider in providers.dropFirst() {
                        let providerType = provider.split(separator: "/").first.map(String.init) ?? ""
                        if providerType != self.selectedProvider {
                            newProviders.append(provider)
                        }
                    }
                    
                    // Ensure we have a fallback
                    if newProviders.count == 1 && !providerString.starts(with: "ollama/") {
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
            try configManager.setCredential(key: key, value: value)
            
            // Refresh the agent service to pick up new API keys
            PeekabooServices.shared.refreshAgentService()
        } catch {
            print("Failed to save API key to credentials: \(error)")
        }
    }
}
