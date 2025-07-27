import Testing

// MARK: - Common Test Tags

extension Tag {
    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var fast: Self
    @Tag static var manual: Self
    
    // Feature-specific tags
    @Tag static var models: Self
    @Tag static var permissions: Self
    @Tag static var windowManager: Self
    @Tag static var automation: Self
    @Tag static var agent: Self
    @Tag static var session: Self
}