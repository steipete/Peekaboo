import Foundation
import Testing
@testable import Peekaboo

@Suite("PeekabooSettings Tests", .tags(.services, .unit))
@MainActor
final class PeekabooSettingsTests {
    var settings: PeekabooSettings!

    init() {
        Task { @MainActor in
            // Create a fresh instance for each test, not using the shared instance
            self.settings = PeekabooSettings()
        }
    }

    @Test("Default values are set correctly")
    func defaultValues() {
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

    @Test("API key validation")
    func aPIKeyValidation() {
        // Empty key should be invalid
        #expect(!self.settings.hasValidAPIKey)

        // Set a key
        self.settings.openAIAPIKey = "sk-test123"
        #expect(self.settings.hasValidAPIKey)

        // Clear the key
        self.settings.openAIAPIKey = ""
        #expect(!self.settings.hasValidAPIKey)
    }

    @Test("Model selection updates correctly")
    func modelSelection() {
        let models = ["gpt-4o", "gpt-4o-mini", "o1-preview", "o1-mini"]

        for model in models {
            self.settings.selectedModel = model
            #expect(self.settings.selectedModel == model)
        }
    }

    @Test("Temperature bounds are enforced", arguments: [
        (-1.0, 0.0), // Below minimum
        (0.0, 0.0), // Minimum
        (0.5, 0.5), // Valid middle
        (1.0, 1.0), // Maximum
        (2.0, 1.0), // Above maximum
        (2.5, 1.0) // Way above maximum
    ])
    func temperatureBounds(input: Double, expected: Double) {
        self.settings.temperature = input
        #expect(self.settings.temperature == expected)
    }

    @Test("Max tokens bounds are enforced", arguments: [
        (0, 1), // Below minimum
        (1, 1), // Minimum
        (8192, 8192), // Valid middle
        (128_000, 128_000), // Maximum
        (200_000, 128_000) // Above maximum
    ])
    func maxTokensBounds(input: Int, expected: Int) {
        self.settings.maxTokens = input
        #expect(self.settings.maxTokens == expected)
    }

    @Test("Toggle settings work correctly")
    func togglePeekabooSettings() {
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
            let originalValue = self.settings![keyPath: keyPath]

            // Toggle on
            self.settings![keyPath: keyPath] = true
            #expect(self.settings![keyPath: keyPath] == true)

            // Toggle off
            self.settings![keyPath: keyPath] = false
            #expect(self.settings![keyPath: keyPath] == false)

            // Restore original
            self.settings![keyPath: keyPath] = originalValue
        }
    }
}

@Suite("PeekabooSettings Persistence Tests", .tags(.services, .integration))
@MainActor
struct PeekabooSettingsPersistenceTests {
    @Test("PeekabooSettings persist across instances")
    func settingsPersistence() async throws {
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
