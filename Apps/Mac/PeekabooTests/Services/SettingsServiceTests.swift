import Darwin
import Foundation
import PeekabooCore
import Testing
@testable import Peekaboo

@Suite(.tags(.services, .unit), .serialized)
@MainActor
struct PeekabooSettingsTests {
    @Test
    func `Default values are set correctly`() throws {
        try withIsolatedSettingsEnvironment { _ in
            let settings = PeekabooSettings()
            #expect(settings.openAIAPIKey.isEmpty)
            #expect(settings.selectedProvider == "anthropic")
            #expect(settings.selectedModel == "claude-sonnet-4-5-20250929")
            #expect(settings.alwaysOnTop == false)
            #expect(settings.showInDock == true)
            #expect(settings.launchAtLogin == false)
            #expect(settings.voiceActivationEnabled == true)
            #expect(settings.hapticFeedbackEnabled == true)
            #expect(settings.soundEffectsEnabled == true)
            #expect(settings.maxTokens == 16384)
            #expect(settings.temperature == 0.7)
        }
    }

    @Test
    func `API key validation`() throws {
        try withIsolatedSettingsEnvironment { _ in
            let settings = PeekabooSettings()
            settings.selectedProvider = "openai"

            // Empty key should be invalid
            #expect(!settings.hasValidAPIKey)

            // Set a key
            settings.openAIAPIKey = "sk-test123"
            #expect(settings.hasValidAPIKey)

            // Clear the key
            settings.openAIAPIKey = ""
            #expect(!settings.hasValidAPIKey)
        }
    }

    @Test
    func `Model selection updates correctly`() throws {
        try withIsolatedSettingsEnvironment { _ in
            let settings = PeekabooSettings()
            let models = ["gpt-4o", "gpt-4o-mini", "o1-preview", "o1-mini"]

            for model in models {
                settings.selectedModel = model
                #expect(settings.selectedModel == model)
            }
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
    func `Temperature bounds are enforced`(input: Double, expected: Double) throws {
        try withIsolatedSettingsEnvironment { _ in
            let settings = PeekabooSettings()
            settings.temperature = input
            #expect(settings.temperature == expected)
        }
    }

    @Test(arguments: [
        (0, 1), // Below minimum
        (1, 1), // Minimum
        (8192, 8192), // Valid middle
        (128_000, 128_000), // Maximum
        (200_000, 128_000) // Above maximum
    ])
    func `Max tokens bounds are enforced`(input: Int, expected: Int) throws {
        try withIsolatedSettingsEnvironment { _ in
            let settings = PeekabooSettings()
            settings.maxTokens = input
            #expect(settings.maxTokens == expected)
        }
    }

    @Test
    func `Toggle settings work correctly`() throws {
        try withIsolatedSettingsEnvironment { _ in
            var settings = PeekabooSettings()
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
                let originalValue = settings[keyPath: keyPath]

                // Toggle on
                settings[keyPath: keyPath] = true
                #expect(settings[keyPath: keyPath] == true)

                // Toggle off
                settings[keyPath: keyPath] = false
                #expect(settings[keyPath: keyPath] == false)

                // Restore original
                settings[keyPath: keyPath] = originalValue
            }
        }
    }
}

@Suite(.tags(.services, .integration), .serialized)
@MainActor
struct PeekabooSettingsPersistenceTests {
    @Test
    func `PeekabooSettings persist across instances`() throws {
        try withIsolatedSettingsEnvironment { _ in
            let testAPIKey = "sk-test-persistence-key"
            let testModel = "o1-preview"
            let testTemperature = 0.9

            let settings1 = PeekabooSettings()
            settings1.openAIAPIKey = testAPIKey
            settings1.selectedModel = testModel
            settings1.temperature = testTemperature
            settings1.alwaysOnTop = true
            settings1.voiceActivationEnabled = true

            // Create new instance and verify
            let settings2 = PeekabooSettings()

            #expect(settings2.openAIAPIKey == testAPIKey)
            #expect(settings2.selectedModel == testModel)
            #expect(settings2.temperature == testTemperature)
            #expect(settings2.alwaysOnTop == true)
            #expect(settings2.voiceActivationEnabled == true)
        }
    }
}

@Suite(.tags(.services, .integration), .serialized)
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
    let credentialEnvironmentKeys = [
        "OPENAI_API_KEY",
        "OPENAI_ACCESS_TOKEN",
        "ANTHROPIC_API_KEY",
        "ANTHROPIC_ACCESS_TOKEN",
        "X_AI_API_KEY",
        "XAI_API_KEY",
        "GROK_API_KEY",
        "GEMINI_API_KEY",
        "GOOGLE_API_KEY",
    ]
    let previousCredentialEnvironment = credentialEnvironmentKeys.reduce(into: [String: String]()) { values, key in
        if let value = getenv(key).map({ String(cString: $0) }) {
            values[key] = value
        }
    }
    let previousKeys = defaults.dictionaryRepresentation().filter { $0.key.hasPrefix("peekaboo.") }

    clearPeekabooDefaults(defaults)
    defaults.set(true, forKey: "peekaboo.migratedToConfigJson")
    setenv("PEEKABOO_CONFIG_DIR", configDir.path, 1)
    setenv("PEEKABOO_CONFIG_DISABLE_MIGRATION", "1", 1)
    for key in credentialEnvironmentKeys {
        unsetenv(key)
    }
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
        for key in credentialEnvironmentKeys {
            if let value = previousCredentialEnvironment[key] {
                setenv(key, value, 1)
            } else {
                unsetenv(key)
            }
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
