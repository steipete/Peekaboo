import Darwin
import Foundation
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

struct ConfigurationManagerEnvironmentTests {
    private let manager = ConfigurationManager.shared

    @Test
    func `expandEnvironmentVariables uses process environment when ConfigReader unavailable`() {
        let key = "PEEKABOO_ENV_TEST"
        setenv(key, "peekaboo-success", 1)
        defer { unsetenv(key) }

        let expanded = self.manager.expandEnvironmentVariables(in: "${\(key)}")
        #expect(expanded == "peekaboo-success")
    }

    @Test
    func `getValue prefers environment before defaults`() {
        let key = "PEEKABOO_ENV_CHOICE"
        setenv(key, "env-choice", 1)
        defer { unsetenv(key) }

        let resolved: String = self.manager.getValue(
            cliValue: nil,
            envVar: key,
            configValue: nil,
            defaultValue: "fallback")
        #expect(resolved == "env-choice")
    }

    @Test
    func `getGeminiAPIKey accepts compatibility aliases`() {
        let previousGeminiAPIKey = getenv("GEMINI_API_KEY").map { String(cString: $0) }
        let previousGoogleAPIKey = getenv("GOOGLE_API_KEY").map { String(cString: $0) }
        unsetenv("GEMINI_API_KEY")
        setenv("GOOGLE_API_KEY", "google-api-key", 1)
        defer {
            if let previousGeminiAPIKey {
                setenv("GEMINI_API_KEY", previousGeminiAPIKey, 1)
            } else {
                unsetenv("GEMINI_API_KEY")
            }
            if let previousGoogleAPIKey {
                setenv("GOOGLE_API_KEY", previousGoogleAPIKey, 1)
            } else {
                unsetenv("GOOGLE_API_KEY")
            }
        }

        self.manager.resetForTesting()
        #expect(self.manager.getGeminiAPIKey() == "google-api-key")
    }

    @Test
    func `getGeminiAPIKey ignores ADC credential paths`() {
        let previousGeminiAPIKey = getenv("GEMINI_API_KEY").map { String(cString: $0) }
        let previousGoogleAPIKey = getenv("GOOGLE_API_KEY").map { String(cString: $0) }
        let previousGoogleCredentials = getenv("GOOGLE_APPLICATION_CREDENTIALS").map { String(cString: $0) }
        unsetenv("GEMINI_API_KEY")
        unsetenv("GOOGLE_API_KEY")
        setenv("GOOGLE_APPLICATION_CREDENTIALS", "/tmp/service-account.json", 1)
        defer {
            if let previousGeminiAPIKey {
                setenv("GEMINI_API_KEY", previousGeminiAPIKey, 1)
            } else {
                unsetenv("GEMINI_API_KEY")
            }
            if let previousGoogleAPIKey {
                setenv("GOOGLE_API_KEY", previousGoogleAPIKey, 1)
            } else {
                unsetenv("GOOGLE_API_KEY")
            }
            if let previousGoogleCredentials {
                setenv("GOOGLE_APPLICATION_CREDENTIALS", previousGoogleCredentials, 1)
            } else {
                unsetenv("GOOGLE_APPLICATION_CREDENTIALS")
            }
        }

        self.manager.resetForTesting()
        #expect(self.manager.getGeminiAPIKey() == nil)
    }

    @Test
    func `getSelectedProvider canonicalizes Google aliases from config`() throws {
        try withIsolatedConfigurationEnvironment { configDir in
            let configPath = configDir.appendingPathComponent("config.json")
            let configJSON = """
            {
              "aiProviders": {
                "providers": "gemini/gemini-3-flash,ollama/llava:latest"
              }
            }
            """
            try configJSON.write(to: configPath, atomically: true, encoding: .utf8)

            self.manager.resetForTesting()
            _ = self.manager.loadConfiguration()
            #expect(self.manager.getSelectedProvider() == "google")
        }
    }
}

private func withIsolatedConfigurationEnvironment(_ body: (URL) throws -> Void) throws {
    let fileManager = FileManager.default
    let configDir = fileManager.temporaryDirectory
        .appendingPathComponent("peekaboo-config-tests-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)

    let previousConfigDir = getenv("PEEKABOO_CONFIG_DIR").map { String(cString: $0) }
    setenv("PEEKABOO_CONFIG_DIR", configDir.path, 1)
    ConfigurationManager.shared.resetForTesting()

    defer {
        if let previousConfigDir {
            setenv("PEEKABOO_CONFIG_DIR", previousConfigDir, 1)
        } else {
            unsetenv("PEEKABOO_CONFIG_DIR")
        }
        ConfigurationManager.shared.resetForTesting()
        try? fileManager.removeItem(at: configDir)
    }

    try body(configDir)
}
