import Foundation
import Observation
import ServiceManagement

/// Application settings and preferences manager.
///
/// `PeekabooSettings` manages all user-configurable settings for the Peekaboo application,
/// including API configuration, UI preferences, and behavior options. Settings are automatically
/// persisted to UserDefaults and synchronized across app launches.
///
/// ## Overview
///
/// The settings manager handles:
/// - OpenAI API configuration for agent functionality
/// - Model selection and generation parameters
/// - UI preferences like window behavior and shortcuts
/// - Application behavior settings
///
/// All properties are observable and automatically save changes to UserDefaults.
///
/// ## Topics
///
/// ### API Configuration
///
/// - ``openAIAPIKey``
/// - ``selectedModel``
/// - ``temperature``
/// - ``maxTokens``
/// - ``hasValidAPIKey``
///
/// ### UI Preferences
///
/// - ``alwaysOnTop``
/// - ``showInDock``
/// - ``launchAtLogin``
/// - ``globalShortcut``
///
/// ### Persistence
///
/// - ``load()``
/// - ``save()``
@Observable
final class PeekabooSettings {
    // API Configuration
    var openAIAPIKey: String = "" {
        didSet { self.save() }
    }

    var selectedModel: String = "gpt-4.1" {
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

    // Features
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
        self.selectedModel = self.userDefaults.string(forKey: "\(self.keyPrefix)selectedModel") ?? "gpt-4.1"
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
                                if ["gpt-4o", "gpt-4o-mini", "gpt-4.1", "gpt-4.1-mini", "o3", "o3-pro", "o4-mini"].contains(model) {
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
