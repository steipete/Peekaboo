import Testing

extension Tag {
    @Tag static var fast: Self
    @Tag static var permissions: Self
    @Tag static var applicationFinder: Self
    @Tag static var windowManager: Self
    @Tag static var imageCapture: Self
    @Tag static var models: Self
    @Tag static var integration: Self
    @Tag static var unit: Self
    @Tag static var jsonOutput: Self
    @Tag static var logger: Self
    @Tag static var performance: Self
    @Tag static var concurrency: Self
    @Tag static var memory: Self
    
    // Local-only test tags
    @Tag static var localOnly: Self
    @Tag static var screenshot: Self
    @Tag static var multiWindow: Self
    @Tag static var focus: Self
}
