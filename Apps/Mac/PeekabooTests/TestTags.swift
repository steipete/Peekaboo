import Testing

// MARK: - Test Tags

// Central location for all test tags used across the test suite

extension Tag {
    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var ui: Self
    @Tag static var services: Self
    @Tag static var models: Self
    @Tag static var tools: Self
    @Tag static var fast: Self
    @Tag static var slow: Self
    @Tag static var networking: Self
    @Tag static var ai: Self
    @Tag static var permissions: Self
}
