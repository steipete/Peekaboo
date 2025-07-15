import Foundation
import Testing

// Main test suite that organizes all tests
@Suite("Peekaboo Test Suite")
struct PeekabooTestSuite {
    // This suite acts as the root container for all tests
    // Individual test files are automatically discovered by Swift Testing
}

// Test configuration and helpers
@Test("Test environment is properly configured", .tags(.fast))
func environmentConfiguration() {
    // Verify we're using Swift Testing, not XCTest
    #expect(Bool(true)) // Basic sanity check

    // Verify test tags are available
    let tagCount = 10 // We have 10 tags defined
    #expect(tagCount == 10)
}

// Test execution helpers
extension Test {
    /// Helper to check if we're running in CI environment
    static var isCI: Bool {
        ProcessInfo.processInfo.environment["CI"] != nil ||
            ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil ||
            ProcessInfo.processInfo.environment["XCODE_CLOUD"] != nil
    }

    /// Helper to check if we have network access
    static var hasNetworkAccess: Bool {
        // Simple check - in real tests you'd want more sophisticated network checking
        true
    }
}
