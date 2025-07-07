import XCTest

class SimpleXCTest: XCTestCase {
    func testExample() throws {
        XCTAssertEqual(1, 1, "Simple assertion should pass")
    }

    func testAnotherExample() {
        XCTAssertTrue(true, "Another simple assertion")
    }
}
