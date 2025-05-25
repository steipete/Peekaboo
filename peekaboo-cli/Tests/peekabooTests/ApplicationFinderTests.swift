@testable import peekaboo
import XCTest

final class ApplicationFinderTests: XCTestCase {
    var applicationFinder: ApplicationFinder!

    override func setUp() {
        super.setUp()
        applicationFinder = ApplicationFinder()
    }

    override func tearDown() {
        applicationFinder = nil
        super.tearDown()
    }

    // MARK: - findRunningApplication Tests

    func testFindRunningApplicationExactMatch() throws {
        // Test finding an app that should always be running on macOS
        let result = try applicationFinder.findRunningApplication(named: "Finder")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.localizedName, "Finder")
        XCTAssertEqual(result?.bundleIdentifier, "com.apple.finder")
    }

    func testFindRunningApplicationCaseInsensitive() throws {
        // Test case-insensitive matching
        let result = try applicationFinder.findRunningApplication(named: "finder")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.localizedName, "Finder")
    }

    func testFindRunningApplicationByBundleIdentifier() throws {
        // Test finding by bundle identifier
        let result = try applicationFinder.findRunningApplication(named: "com.apple.finder")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.bundleIdentifier, "com.apple.finder")
    }

    func testFindRunningApplicationNotFound() {
        // Test app not found error
        XCTAssertThrowsError(try applicationFinder.findRunningApplication(named: "NonExistentApp12345")) { error in
            guard let captureError = error as? CaptureError else {
                XCTFail("Expected CaptureError")
                return
            }
            XCTAssertEqual(captureError, .appNotFound)
        }
    }

    func testFindRunningApplicationPartialMatch() throws {
        // Test partial name matching
        let result = try applicationFinder.findRunningApplication(named: "Find")

        // Should find Finder as closest match
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.localizedName, "Finder")
    }

    // MARK: - Fuzzy Matching Tests

    func testFuzzyMatchingScore() {
        // Test the fuzzy matching algorithm
        let finder = "Finder"

        // Exact match should have highest score
        XCTAssertEqual(applicationFinder.fuzzyMatch("Finder", with: finder), 1.0)

        // Case differences should still score high
        XCTAssertGreaterThan(applicationFinder.fuzzyMatch("finder", with: finder), 0.8)

        // Partial matches should score lower but still match
        XCTAssertGreaterThan(applicationFinder.fuzzyMatch("Find", with: finder), 0.5)
        XCTAssertLessThan(applicationFinder.fuzzyMatch("Find", with: finder), 0.9)

        // Completely different should score very low
        XCTAssertLessThan(applicationFinder.fuzzyMatch("Safari", with: finder), 0.3)
    }

    func testFuzzyMatchingWithSpaces() {
        // Test matching with spaces and special characters
        let appName = "Google Chrome"

        // Various ways users might type Chrome
        XCTAssertGreaterThan(applicationFinder.fuzzyMatch("chrome", with: appName), 0.5)
        XCTAssertGreaterThan(applicationFinder.fuzzyMatch("google", with: appName), 0.5)
        XCTAssertGreaterThan(applicationFinder.fuzzyMatch("googlechrome", with: appName), 0.7)
    }

    // MARK: - Performance Tests

    func testFindApplicationPerformance() throws {
        // Test that finding an app completes in reasonable time
        measure {
            _ = try? applicationFinder.findRunningApplication(named: "Finder")
        }
    }
}
