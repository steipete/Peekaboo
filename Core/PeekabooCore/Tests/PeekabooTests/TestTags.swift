import Foundation
import Testing

// MARK: - Common Test Tags

extension Tag {
    // Test categories
    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var fast: Self
    @Tag static var safe: Self
    @Tag static var manual: Self
    @Tag static var regression: Self

    // Feature-specific tags
    @Tag static var models: Self
    @Tag static var permissions: Self
    @Tag static var windowManager: Self
    @Tag static var automation: Self
    @Tag static var agent: Self
    @Tag static var session: Self
    @Tag static var ui: Self

    // Performance & reliability
    @Tag static var performance: Self
    @Tag static var concurrency: Self
    @Tag static var memory: Self
    @Tag static var flaky: Self

    // Execution environment
    @Tag static var localOnly: Self
    @Tag static var ciOnly: Self
    @Tag static var requiresDisplay: Self
    @Tag static var requiresPermissions: Self
    @Tag static var requiresNetwork: Self
}

enum TestEnvironment {
    private static let env = ProcessInfo.processInfo.environment

    /// Enable automation-focused tests (input devices, hotkeys, typing).
    static var runAutomationScenarios: Bool {
        env["RUN_AUTOMATION_TESTS"] == "true" || env["RUN_LOCAL_TESTS"] == "true"
    }

    /// Enable screen capture and multi-display validation scenarios.
    static var runScreenCaptureScenarios: Bool {
        env["RUN_SCREEN_TESTS"] == "true" || runAutomationScenarios
    }
}
