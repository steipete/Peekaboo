import Darwin
import Foundation
import PeekabooCore
import Testing
@testable import Peekaboo

@Suite(.tags(.services, .unit))
@MainActor
final class PeekabooSettingsTests {
    var settings: PeekabooSettings!

    init() {
        Task { @MainActor in
            // Create a fresh instance for each test, not using the shared instance
            self.settings = PeekabooSettings()
        }
    }

    @Test
    func `Default values are set correctly`() {
        #expect(self.settings.openAIAPIKey.isEmpty)
        #expect(self.settings.selectedModel == "gpt-4o")
        #expect(self.settings.alwaysOnTop == false)
        #expect(self.settings.showInDock == false)
        #expect(self.settings.launchAtLogin == false)
        #expect(self.settings.voiceActivationEnabled == false)
        #expect(self.settings.hapticFeedbackEnabled == true)
        #expect(self.settings.soundEffectsEnabled == true)
        #expect(self.settings.maxTokens == 16384)
        #expect(self.settings.temperature == 0.7)
    }

    @Test
    func `API key validation`() {
        // Empty key should be invalid
        #expect(!self.settings.hasValidAPIKey)

        // Set a key
        self.settings.openAIAPIKey = "sk-test123"
        #expect(self.settings.hasValidAPIKey)

        // Clear the key
        self.settings.openAIAPIKey = ""
        #expect(!self.settings.hasValidAPIKey)
    }

    @Test
    func `Model selection updates correctly`() {
        let models = ["gpt-4o", "gpt-4o-mini", "o1-preview", "o1-mini"]

        for model in models {
            self.settings.selectedModel = model
            #expect(self.settings.selectedModel == model)
        }
    }

    @Test(arguments: [
        (-1.0, 0.0), // Below minimum
        (0.0, 0.0), // Minimum
        (0.5, 0.5), // Valid middle
        (1.0, 1.0), // Maximum
        (2.0, 1.0), // Above maximum
        (2.5, 1.0) // Way above maximum
    ])
    func `Temperature bounds are enforced`(input: Double, expected: Double) {
        self.settings.temperature = input
        #expect(self.settings.temperature == expected)
    }

    @Test(arguments: [
        (0, 1), // Below minimum
        (1, 1), // Minimum
        (8192, 8192), // Valid middle
        (128_000, 128_000), // Maximum
        (200_000, 128_000) // Above maximum
    ])
    func `Max tokens bounds are enforced`(input: Int, expected: Int) {
        self.settings.maxTokens = input
        #expect(self.settings.maxTokens == expected)
    }

    @Test
    func `Toggle settings work correctly`() throws {
        // Test all boolean settings
        let toggles: [(WritableKeyPath<PeekabooSettings, Bool>, String)] = [
            (\.alwaysOnTop, "alwaysOnTop"),
            (\.showInDock, "showInDock"),
            (\.launchAtLogin, "launchAtLogin"),
            (\.voiceActivationEnabled, "voiceActivationEnabled"),
            (\.hapticFeedbackEnabled, "hapticFeedbackEnabled"),
            (\.soundEffectsEnabled, "soundEffectsEnabled"),
        ]

        for (keyPath, _) in toggles {
            let originalValue = try #require(self.settings?[keyPath: keyPath])

            // Toggle on
            self.settings?[keyPath: keyPath] = true
            #expect(self.settings?[keyPath: keyPath] == true)

            // Toggle off
            self.settings?[keyPath: keyPath] = false
            #expect(self.settings?[keyPath: keyPath] == false)

            // Restore original
            self.settings?[keyPath: keyPath] = originalValue
        }
    }
}

@Suite(.tags(.services, .integration))
@MainActor
struct PeekabooSettingsPersistenceTests {
    @Test
    func `PeekabooSettings persist across instances`() async {
        let suiteName = UUID().uuidString
        let testAPIKey = "sk-test-persistence-key"
        let testModel = "o1-preview"
        let testTemperature = 0.9

        // Set values in first instance
        do {
            let settings1 = PeekabooSettings()
            await MainActor.run {
                settings1.openAIAPIKey = testAPIKey
                settings1.selectedModel = testModel
                settings1.temperature = testTemperature
                settings1.alwaysOnTop = true
                settings1.voiceActivationEnabled = true
            }
        }

        // Create new instance and verify
        let settings2 = PeekabooSettings()

        #expect(settings2.openAIAPIKey == testAPIKey)
        #expect(settings2.selectedModel == testModel)
        #expect(settings2.temperature == testTemperature)
        #expect(settings2.alwaysOnTop == true)
        #expect(settings2.voiceActivationEnabled == true)

        // Clean up
        UserDefaults().removePersistentDomain(forName: suiteName)
    }
}

@Suite("PeekabooSettings Config Hydration Tests", .tags(.services, .integration))
@MainActor
struct PeekabooSettingsConfigHydrationTests {
    @Test
    func `Configuration-backed state survives init`() throws {
        try withIsolatedSettingsEnvironment { configDir in
            let configPath = configDir.appendingPathComponent("config.json")
            let configJSON = """
            {
              "aiProviders": {
                "providers": "anthropic/claude-sonnet-4-5-20250929,ollama/llava:latest"
              },
              "agent": {
                "defaultModel": "claude-sonnet-4-5-20250929",
                "temperature": 0.3,
                "maxTokens": 4096
              }
            }
            """
            try configJSON.write(to: configPath, atomically: true, encoding: .utf8)

            let defaults = UserDefaults.standard
            defaults.set(true, forKey: "peekaboo.agentModeEnabled")
            defaults.set(false, forKey: "peekaboo.showInDock")

            ConfigurationManager.shared.resetForTesting()
            _ = ConfigurationManager.shared.loadConfiguration()

            let settings = PeekabooSettings()

            #expect(settings.selectedProvider == "anthropic")
            #expect(settings.selectedModel == "claude-sonnet-4-5-20250929")
            #expect(settings.temperature == 0.3)
            #expect(settings.maxTokens == 4096)
            #expect(settings.agentModeEnabled == true)
            #expect(settings.showInDock == false)

            let persistedConfig = try String(contentsOf: configPath, encoding: .utf8)
            #expect(persistedConfig == configJSON)
            #expect(defaults.bool(forKey: "peekaboo.agentModeEnabled") == true)
            #expect(defaults.bool(forKey: "peekaboo.showInDock") == false)
        }
    }

    @Test
    func `Configuration-backed provider aliases hydrate to Google and built-ins include Grok`() throws {
        try withIsolatedSettingsEnvironment { configDir in
            let configPath = configDir.appendingPathComponent("config.json")
            let configJSON = """
            {
              "aiProviders": {
                "providers": "gemini/gemini-3-flash,ollama/llava:latest"
              },
              "agent": {
                "defaultModel": "gemini-3-flash"
              }
            }
            """
            try configJSON.write(to: configPath, atomically: true, encoding: .utf8)

            ConfigurationManager.shared.resetForTesting()
            _ = ConfigurationManager.shared.loadConfiguration()

            let settings = PeekabooSettings()

            #expect(settings.selectedProvider == "google")
            #expect(settings.selectedModel == "gemini-3-flash")
            #expect(settings.allAvailableProviders.contains("google"))
            #expect(settings.allAvailableProviders.contains("grok"))
        }
    }
}

@MainActor
private func withIsolatedSettingsEnvironment(_ body: (URL) throws -> Void) throws {
    let fileManager = FileManager.default
    let configDir = fileManager.temporaryDirectory
        .appendingPathComponent("peekaboo-settings-tests-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)

    let defaults = UserDefaults.standard
    let previousConfigDir = getenv("PEEKABOO_CONFIG_DIR").map { String(cString: $0) }
    let previousDisableMigration = getenv("PEEKABOO_CONFIG_DISABLE_MIGRATION").map { String(cString: $0) }
    let previousKeys = defaults.dictionaryRepresentation().filter { $0.key.hasPrefix("peekaboo.") }

    clearPeekabooDefaults(defaults)
    setenv("PEEKABOO_CONFIG_DIR", configDir.path, 1)
    setenv("PEEKABOO_CONFIG_DISABLE_MIGRATION", "1", 1)
    ConfigurationManager.shared.resetForTesting()

    defer {
        clearPeekabooDefaults(defaults)
        for (key, value) in previousKeys {
            defaults.set(value, forKey: key)
        }
        if let previousConfigDir {
            setenv("PEEKABOO_CONFIG_DIR", previousConfigDir, 1)
        } else {
            unsetenv("PEEKABOO_CONFIG_DIR")
        }
        if let previousDisableMigration {
            setenv("PEEKABOO_CONFIG_DISABLE_MIGRATION", previousDisableMigration, 1)
        } else {
            unsetenv("PEEKABOO_CONFIG_DISABLE_MIGRATION")
        }
        ConfigurationManager.shared.resetForTesting()
        try? fileManager.removeItem(at: configDir)
    }

    try body(configDir)
}

private func clearPeekabooDefaults(_ defaults: UserDefaults) {
    for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("peekaboo.") {
        defaults.removeObject(forKey: key)
    }
}
