import Foundation
import Observation

@Observable
final class Settings {
    // API Configuration
    var openAIAPIKey: String = "" {
        didSet { self.save() }
    }

    var selectedModel: String = "gpt-4o" {
        didSet { self.save() }
    }

    var temperature: Double = 0.7 {
        didSet {
            let clamped = max(0, min(1, temperature))
            if temperature != clamped {
                self.temperature = clamped
            } else {
                self.save()
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
            }
        }
    }

    // UI Preferences
    var alwaysOnTop: Bool = false {
        didSet { self.save() }
    }

    var showInDock: Bool = false {
        didSet { self.save() }
    }

    var launchAtLogin: Bool = false {
        didSet { self.save() }
    }

    var globalShortcut: String = "⌘⇧Space" {
        didSet { self.save() }
    }

    // Features
    var voiceActivationEnabled: Bool = false {
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
        !self.openAIAPIKey.isEmpty
    }

    // Storage
    private let userDefaults = UserDefaults.standard
    private let keyPrefix = "peekaboo."

    init() {
        self.load()
        self.loadFromPeekabooConfig()
    }

    private func load() {
        self.openAIAPIKey = self.userDefaults.string(forKey: "\(self.keyPrefix)openAIAPIKey") ?? ""
        self.selectedModel = self.userDefaults.string(forKey: "\(self.keyPrefix)selectedModel") ?? "gpt-4o"
        self.temperature = self.userDefaults.double(forKey: "\(self.keyPrefix)temperature")
        if self.temperature == 0 { self.temperature = 0.7 } // Default if not set
        self.maxTokens = self.userDefaults.integer(forKey: "\(self.keyPrefix)maxTokens")
        if self.maxTokens == 0 { self.maxTokens = 16384 } // Default if not set

        self.alwaysOnTop = self.userDefaults.bool(forKey: "\(self.keyPrefix)alwaysOnTop")
        self.showInDock = self.userDefaults.bool(forKey: "\(self.keyPrefix)showInDock")
        self.launchAtLogin = self.userDefaults.bool(forKey: "\(self.keyPrefix)launchAtLogin")
        self.globalShortcut = self.userDefaults.string(forKey: "\(self.keyPrefix)globalShortcut") ?? "⌘⇧Space"

        self.voiceActivationEnabled = self.userDefaults.bool(forKey: "\(self.keyPrefix)voiceActivationEnabled")
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
        self.userDefaults.set(self.openAIAPIKey, forKey: "\(self.keyPrefix)openAIAPIKey")
        self.userDefaults.set(self.selectedModel, forKey: "\(self.keyPrefix)selectedModel")
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
        // First check environment variable for OpenAI API key
        if self.openAIAPIKey.isEmpty {
            if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
                self.openAIAPIKey = envKey
            }
        }
        
        // Load from Peekaboo config file if exists
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/peekaboo/config.json")
        
        guard FileManager.default.fileExists(atPath: configPath.path) else { return }
        
        do {
            let data = try Data(contentsOf: configPath)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Load AI provider settings
                if let aiProviders = json["aiProviders"] as? [String: Any] {
                    // Only override if we don't have a key yet
                    if self.openAIAPIKey.isEmpty {
                        if let apiKey = aiProviders["openaiApiKey"] as? String {
                            // Handle environment variable expansion
                            if apiKey.hasPrefix("${") && apiKey.hasSuffix("}") {
                                let envVar = String(apiKey.dropFirst(2).dropLast(1))
                                if let envValue = ProcessInfo.processInfo.environment[envVar] {
                                    self.openAIAPIKey = envValue
                                }
                            } else {
                                self.openAIAPIKey = apiKey
                            }
                        }
                    }
                    
                    // Load preferred model from providers list
                    if let providers = aiProviders["providers"] as? String {
                        let providerList = providers.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                        for provider in providerList {
                            if provider.starts(with: "openai/") {
                                let model = String(provider.dropFirst("openai/".count))
                                // Only override if it's a valid model
                                if ["gpt-4o", "gpt-4o-mini", "o1-preview", "o1-mini"].contains(model) {
                                    self.selectedModel = model
                                    break
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            // Silently ignore config loading errors
            print("Failed to load Peekaboo config: \(error)")
        }
    }
}
