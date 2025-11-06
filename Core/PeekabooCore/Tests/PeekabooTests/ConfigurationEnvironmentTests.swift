import Foundation
import Testing
@testable import PeekabooCore

@Suite("ConfigurationManager environment helpers")
struct ConfigurationManagerEnvironmentTests {
    private let manager = ConfigurationManager.shared

    @Test("expandEnvironmentVariables uses process environment when ConfigReader unavailable")
    func expandsEnvironmentVariables() {
        let key = "PEEKABOO_ENV_TEST"
        setenv(key, "peekaboo-success", 1)
        defer { unsetenv(key) }

        let expanded = manager.expandEnvironmentVariables(in: "${\(key)}")
        #expect(expanded == "peekaboo-success")
    }

    @Test("getValue prefers environment before defaults")
    func getValuePrefersEnvironment() {
        let key = "PEEKABOO_ENV_CHOICE"
        setenv(key, "env-choice", 1)
        defer { unsetenv(key) }

        let resolved: String = manager.getValue(
            cliValue: nil,
            envVar: key,
            configValue: nil,
            defaultValue: "fallback")
        #expect(resolved == "env-choice")
    }
}
