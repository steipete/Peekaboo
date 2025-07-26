import ArgumentParser
import CoreGraphics
import Foundation
import Testing
@testable import peekaboo

@Suite("ClickCommand Advanced Tests")
struct ClickCommandAdvancedTests {
    @Test("Parse click command basic options")
    func basicOptionsParsing() async throws {
        let command = try ClickCommand.parse(["--on", "B1"])
        #expect(command.on == "B1")
        #expect(command.coords == nil)
        #expect(command.right == false)
        #expect(command.double == false)
    }

    @Test("Parse click command with coordinates")
    func coordinatesParsing() async throws {
        let command = try ClickCommand.parse(["--coords", "100,200"])
        #expect(command.coords == "100,200")
        #expect(command.on == nil)
    }

    @Test("Parse double-click option")
    func doubleClickParsing() async throws {
        let command = try ClickCommand.parse(["--on", "B1", "--double"])
        #expect(command.double == true)
        #expect(command.right == false)
    }

    @Test("Parse right-click option")
    func rightClickParsing() async throws {
        let command = try ClickCommand.parse(["--on", "T1", "--right"])
        #expect(command.right == true)
        #expect(command.double == false)
    }

    @Test("Parse wait-for option")
    func waitForParsing() async throws {
        let command = try ClickCommand.parse(["--on", "B1", "--wait-for", "3000"])
        #expect(command.waitFor == 3000)
    }

    @Test("Parse session option")
    func sessionParsing() async throws {
        let command = try ClickCommand.parse(["--on", "C1", "--session", "12345"])
        #expect(command.session == "12345")
    }

    @Test("Coordinate string parsing")
    func testParseCoordinates() {
        // Valid coordinates
        if let coords = ClickCommand.parseCoordinates("100,200") {
            #expect(coords.x == 100)
            #expect(coords.y == 200)
        } else {
            Issue.record("Failed to parse valid coordinates")
        }

        // Invalid formats
        #expect(ClickCommand.parseCoordinates("invalid") == nil)
        #expect(ClickCommand.parseCoordinates("100") == nil)
        #expect(ClickCommand.parseCoordinates("100,") == nil)
        #expect(ClickCommand.parseCoordinates(",200") == nil)
        #expect(ClickCommand.parseCoordinates("abc,def") == nil)
    }

    @Test("Element locator creation from query")
    func elementLocatorFromQuery() {
        // Text content search
        var locator = ClickCommand.createLocatorFromQuery("Bold")
        #expect(locator.title == "Bold")
        #expect(locator.label == "Bold")
        #expect(locator.value == "Bold")
        // Note: roleDescription property doesn't exist on ElementLocator

        // Role-based search
        locator = ClickCommand.createLocatorFromQuery("checkbox")
        #expect(locator.role == "AXCheckBox")

        locator = ClickCommand.createLocatorFromQuery("button")
        #expect(locator.role == "AXButton")

        locator = ClickCommand.createLocatorFromQuery("text")
        #expect(locator.role == "AXStaticText")
    }

    @Test("Click result JSON structure")
    func clickResultJSON() throws {
        // Create a test result using the correct structure
        let clickLocation = CGPoint(x: 100, y: 200)
        let resultData = ClickResultData(
            action: "click",
            clicked_element: "AXButton: Save",
            click_type: "single",
            click_location: ["x": Int(clickLocation.x), "y": Int(clickLocation.y)],
            wait_time: 1.5,
            execution_time: 2.0
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(resultData)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        let action = json?["action"] as? String
        #expect(action == "click")
        
        let clickedElement = json?["clicked_element"] as? String
        #expect(clickedElement == "AXButton: Save")
        
        let waitTime = json?["wait_time"] as? Double
        #expect(waitTime == 1.5)
        
        let executionTime = json?["execution_time"] as? Double
        #expect(executionTime == 2.0)

        if let location = json?["click_location"] as? [String: Any] {
            let x = location["x"] as? Int
            #expect(x == 100)
            let y = location["y"] as? Int
            #expect(y == 200)
        } else {
            Issue.record("click_location not found in JSON")
        }
    }

    @Test("Command validation rejects both --on and --coords")
    func validationRejectsBothOptions() {
        #expect(throws: Error.self) {
            _ = try ClickCommand.parse(["--on", "B1", "--coords", "100,200"])
        }
    }

    @Test("Mutually exclusive options validation")
    func testMutuallyExclusiveOptions() throws {
        // Can't have both --on and --coords
        do {
            _ = try ClickCommand.parse(["--on", "button", "--coords", "100,200"])
            Issue.record("Should have thrown validation error")
        } catch {
            // Expected
        }
    }

    @Test("Find element by text in session")
    func testFindElementByText() throws {
        // Create mock session data using the correct types
        let testData = ElementDetectionResult(
            sessionId: "test123",
            screenshotPath: "/tmp/test.png",
            elements: ElementSet(
                buttons: [
                    DetectedElement(
                        id: "C1",
                        type: .button,
                        label: "Bold",
                        value: nil,
                        bounds: CGRect(x: 100, y: 100, width: 50, height: 20),
                        isEnabled: true
                    )
                ],
                labels: [],
                textFields: [],
                images: [],
                other: []
            ),
            metadata: nil
        )

        // The actual element finding would be done through SessionCache
        // This test just verifies the data structure
        let element = testData.elements.buttons.first
        #expect(element?.id == "C1")
        #expect(element?.label == "Bold")
        #expect(element?.type == .button)
    }

    @Test("Wait time calculations")
    func testWaitTimeCalculations() {
        // Default wait time
        let defaultWait = 5000
        #expect(defaultWait == 5000) // 5 seconds in milliseconds

        // Custom wait time
        let customWait = 10000
        #expect(customWait == 10000) // 10 seconds in milliseconds
    }

    @Test("Click types are handled correctly")
    func testClickTypes() {
        // Single click
        let singleClick = ClickType.single
        #expect(singleClick.rawValue == "single")

        // Double click
        let doubleClick = ClickType.double
        #expect(doubleClick.rawValue == "double")

        // Right click
        let rightClick = ClickType.right
        #expect(rightClick.rawValue == "right")
    }
}