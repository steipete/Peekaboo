import Foundation
import Testing

@preconcurrency
enum EnvironmentFlags {
    @preconcurrency nonisolated static func isEnabled(_ key: String) -> Bool {
        ProcessInfo.processInfo.environment[key]?.lowercased() == "true"
    }

    @preconcurrency nonisolated static var runAutomationScenarios: Bool {
        isEnabled("RUN_AUTOMATION_TESTS") || isEnabled("RUN_LOCAL_TESTS")
    }

    /// Input-device automation (key/mouse) opt-in flag shared with the CLI suite.
    @preconcurrency nonisolated static var runInputAutomationScenarios: Bool {
        isEnabled("PEEKABOO_INCLUDE_AUTOMATION_TESTS")
    }

    @preconcurrency nonisolated static var runScreenCaptureScenarios: Bool {
        isEnabled("RUN_SCREEN_TESTS") || runAutomationScenarios
    }

    @preconcurrency nonisolated static var runAudioScenarios: Bool {
        isEnabled("PEEKABOO_AUDIO_TESTS")
    }
}

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

@preconcurrency
enum TestEnvironment {
    /// Enable automation-focused tests (input devices, hotkeys, typing).
    @preconcurrency nonisolated(unsafe) static var runAutomationScenarios: Bool {
        EnvironmentFlags.runAutomationScenarios
    }

    /// Enable tests that drive actual keyboard/mouse events.
    @preconcurrency nonisolated(unsafe) static var runInputAutomationScenarios: Bool {
        EnvironmentFlags.runInputAutomationScenarios
    }

    /// Enable screen capture and multi-display validation scenarios.
    @preconcurrency nonisolated(unsafe) static var runScreenCaptureScenarios: Bool {
        EnvironmentFlags.runScreenCaptureScenarios
    }
}
