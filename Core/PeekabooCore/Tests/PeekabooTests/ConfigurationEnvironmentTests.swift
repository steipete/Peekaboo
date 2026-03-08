import Darwin
import Foundation
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@Suite("ConfigurationManager environment helpers")
struct ConfigurationManagerEnvironmentTests {
    private let manager = ConfigurationManager.shared

    @Test("expandEnvironmentVariables uses process environment when ConfigReader unavailable")
    func expandsEnvironmentVariables() {
        let key = "PEEKABOO_ENV_TEST"
        setenv(key, "peekaboo-success", 1)
        defer { unsetenv(key) }

        let expanded = self.manager.expandEnvironmentVariables(in: "${\(key)}")
        #expect(expanded == "peekaboo-success")
    }

    @Test("getValue prefers environment before defaults")
    func getValuePrefersEnvironment() {
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

    @Test("getSelectedProvider canonicalizes Google aliases from config")
    func getSelectedProviderCanonicalizesGoogleAlias() throws {
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
