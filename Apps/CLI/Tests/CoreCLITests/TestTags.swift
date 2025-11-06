import Foundation
import Testing

extension Tag {
    // Test categories
    @Tag static var fast: Self
    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var safe: Self
    @Tag static var automation: Self
    @Tag static var regression: Self

    // Feature areas
    @Tag static var permissions: Self
    @Tag static var applicationFinder: Self
    @Tag static var windowManager: Self
    @Tag static var imageCapture: Self
    @Tag static var models: Self
    @Tag static var jsonOutput: Self
    @Tag static var logger: Self
    @Tag static var browserFiltering: Self
    @Tag static var screenshot: Self
    @Tag static var multiWindow: Self
    @Tag static var focus: Self
    @Tag static var imageAnalysis: Self
    @Tag static var formats: Self
    @Tag static var multiDisplay: Self

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

enum CLITestEnvironment {
    private static let env = ProcessInfo.processInfo.environment

    static var runAutomationScenarios: Bool {
        env["RUN_AUTOMATION_TESTS"] == "true" || env["RUN_LOCAL_TESTS"] == "true"
    }
}
