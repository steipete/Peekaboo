@testable import peekaboo
import XCTest

final class ApplicationFinderTests: XCTestCase {

    // MARK: - findRunningApplication Tests

    func testFindApplicationExactMatch() throws {
        // Test finding an app that should always be running on macOS
        let result = try ApplicationFinder.findApplication(identifier: "Finder")

        XCTAssertNotNil(result)
        XCTAssertEqual(result.localizedName, "Finder")
        XCTAssertEqual(result.bundleIdentifier, "com.apple.finder")
    }

    func testFindApplicationCaseInsensitive() throws {
        // Test case-insensitive matching
        let result = try ApplicationFinder.findApplication(identifier: "finder")

        XCTAssertNotNil(result)
        XCTAssertEqual(result.localizedName, "Finder")
    }

    func testFindApplicationByBundleIdentifier() throws {
        // Test finding by bundle identifier
        let result = try ApplicationFinder.findApplication(identifier: "com.apple.finder")

        XCTAssertNotNil(result)
        XCTAssertEqual(result.bundleIdentifier, "com.apple.finder")
    }

    func testFindApplicationNotFound() throws {
        // Test app not found error - ApplicationError is thrown
        XCTAssertThrowsError(try ApplicationFinder.findApplication(identifier: "NonExistentApp12345")) { error in
            // ApplicationError.applicationNotFound would be the expected error
            XCTAssertNotNil(error)
        }
    }

    func testFindApplicationPartialMatch() throws {
        // Test partial name matching
        let result = try ApplicationFinder.findApplication(identifier: "Find")

        // Should find Finder as closest match
        XCTAssertNotNil(result)
        XCTAssertEqual(result.localizedName, "Finder")
    }

    // MARK: - Static Method Tests
    
    func testGetAllRunningApplications() {
        // Test getting all running applications
        let apps = ApplicationFinder.getAllRunningApplications()
        
        // Should have at least some apps running
        XCTAssertGreaterThan(apps.count, 0)
        
        // Should include Finder
        let hasFinder = apps.contains { $0.name == "Finder" }
        XCTAssertTrue(hasFinder, "Finder should always be running")
    }

    // MARK: - Performance Tests

    func testFindApplicationPerformance() throws {
        // Test that finding an app completes in reasonable time
        measure {
            _ = try? ApplicationFinder.findApplication(identifier: "Finder")
        }
    }
}
