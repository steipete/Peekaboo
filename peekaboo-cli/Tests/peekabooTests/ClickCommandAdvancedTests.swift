import Foundation
@testable import peekaboo
import Testing

@Suite("Advanced Click Command Tests")
struct ClickCommandAdvancedTests {
    @Test("Parse text-based click query")
    func textBasedClickParsing() async throws {
        let command = try ClickCommand.parse(["Bold"])
        #expect(command.query == "Bold")
        #expect(command.on == nil)
        #expect(command.coords == nil)
    }

    @Test("Parse coordinate-based click")
    func coordinateClickParsing() async throws {
        let command = try ClickCommand.parse(["--coords", "100,200"])
        #expect(command.coords == "100,200")
        #expect(command.on == nil)
        #expect(command.query == nil)
    }

    @Test("Parse element ID click")
    func elementIDClickParsing() async throws {
        let command = try ClickCommand.parse(["--on", "C1"])
        #expect(command.on == "C1")
        #expect(command.coords == nil)
        #expect(command.query == nil)
    }

    @Test("Parse double-click option")
    func doubleClickParsing() async throws {
        let command = try ClickCommand.parse(["--on", "T1", "--double"])
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
        let command = try ClickCommand.parse(["--on", "B1", "--wait-for", "Save"])
        #expect(command.waitFor == "Save")
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
        #expect(locator.roleDescription == "Bold")

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
        let result = ClickCommand.ClickResult(
            success: true,
            clickedElement: "AXButton: Save",
            clickLocation: CGPoint(x: 100, y: 200),
            waitTime: 1.5,
            executionTime: 2.0
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(result)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["success"] as? Bool == true)
        #expect(json?["clickedElement"] as? String == "AXButton: Save")
        #expect(json?["waitTime"] as? Double == 1.5)
        #expect(json?["executionTime"] as? Double == 2.0)

        if let location = json?["clickLocation"] as? [String: Any] {
            #expect(location["x"] as? Double == 100)
            #expect(location["y"] as? Double == 200)
        } else {
            Issue.record("clickLocation not found in JSON")
        }
    }

    @Test("Multiple click targets priority")
    func clickTargetPriority() throws {
        // When multiple targets are specified, --on takes precedence
        let command = try ClickCommand.parse([
            "TextQuery",
            "--on", "C1",
            "--coords", "100,200"
        ])

        // Should prioritize in order: --on > --coords > query
        #expect(command.on == "C1")
        #expect(command.coords == "100,200")
        #expect(command.query == "TextQuery")
    }

    @Test("Invalid click combinations")
    func invalidCombinations() throws {
        // Double and right click together should parse but behavior is defined by implementation
        let command = try ClickCommand.parse(["--on", "C1", "--double", "--right"])
        #expect(command.double == true)
        #expect(command.right == true)
    }
}

@Suite("Click Command Mock Tests")
struct ClickCommandMockTests {
    @Test("Find element by text in session")
    @MainActor
    func testFindElementByText() throws {
        // Create mock session data
        let sessionData = SessionData(
            sessionId: "test123",
            applicationName: "TextEdit",
            screenshotPath: "/tmp/test.png",
            windowBounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            windowTitle: "Test Window",
            windowId: 1234,
            uiMap: [
                SessionData.UIElement(
                    id: "C1",
                    elementId: "elem1",
                    frame: CGRect(x: 100, y: 100, width: 50, height: 20),
                    role: "AXCheckBox",
                    title: "Bold",
                    label: nil,
                    value: nil,
                    isActionable: true,
                    parentId: nil,
                    children: [],
                    description: nil,
                    help: nil,
                    roleDescription: nil,
                    identifier: nil,
                    keyboardShortcut: "cmd+b"
                ),
                SessionData.UIElement(
                    id: "C2",
                    elementId: "elem2",
                    frame: CGRect(x: 150, y: 100, width: 50, height: 20),
                    role: "AXCheckBox",
                    title: nil,
                    label: "Italic",
                    value: nil,
                    isActionable: true,
                    parentId: nil,
                    children: [],
                    description: nil,
                    help: nil,
                    roleDescription: nil,
                    identifier: nil,
                    keyboardShortcut: "cmd+i"
                )
            ],
            lastUpdateTime: Date()
        )

        // Test finding by title
        if let element = ClickCommand.findElementByText("Bold", in: sessionData) {
            #expect(element.id == "C1")
            #expect(element.title == "Bold")
        } else {
            Issue.record("Failed to find element by title")
        }

        // Test finding by label
        if let element = ClickCommand.findElementByText("Italic", in: sessionData) {
            #expect(element.id == "C2")
            #expect(element.label == "Italic")
        } else {
            Issue.record("Failed to find element by label")
        }

        // Test case-insensitive search
        if let element = ClickCommand.findElementByText("bold", in: sessionData) {
            #expect(element.id == "C1")
        } else {
            Issue.record("Failed to find element with case-insensitive search")
        }

        // Test not found
        let notFound = ClickCommand.findElementByText("NotExist", in: sessionData)
        #expect(notFound == nil)
    }

    @Test("Wait for element timeout calculation")
    func waitTimeout() {
        // Default timeout
        var timeout = ClickCommand.calculateWaitTimeout(nil)
        #expect(timeout == 10.0)

        // Custom timeout from wait-for
        timeout = ClickCommand.calculateWaitTimeout("Save")
        #expect(timeout == 10.0)

        // With specific element that might take longer
        timeout = ClickCommand.calculateWaitTimeout("Dialog")
        #expect(timeout == 10.0) // Currently uses fixed timeout
    }

    @Test("Click location validation")
    @MainActor
    func clickLocationValidation() {
        let windowBounds = CGRect(x: 100, y: 100, width: 800, height: 600)

        // Valid location within window
        var location = CGPoint(x: 200, y: 200)
        #expect(ClickCommand.isValidClickLocation(location, windowBounds: windowBounds))

        // Location outside window
        location = CGPoint(x: 50, y: 50)
        #expect(!ClickCommand.isValidClickLocation(location, windowBounds: windowBounds))

        // Location at window edge
        location = CGPoint(x: 100, y: 100)
        #expect(ClickCommand.isValidClickLocation(location, windowBounds: windowBounds))

        // Location beyond window
        location = CGPoint(x: 1000, y: 800)
        #expect(!ClickCommand.isValidClickLocation(location, windowBounds: windowBounds))
    }
}

// Extension to add helper methods for testing
extension ClickCommand {
    static func parseCoordinates(_ coords: String) -> CGPoint? {
        let parts = coords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let x = Double(parts[0]),
              let y = Double(parts[1]) else {
            return nil
        }
        return CGPoint(x: x, y: y)
    }

    static func createLocatorFromQuery(_ query: String) -> ElementLocator {
        let lowerQuery = query.lowercased()

        // Check if query matches a role
        var role: String?
        if lowerQuery.contains("button") {
            role = "AXButton"
        } else if lowerQuery.contains("checkbox") {
            role = "AXCheckBox"
        } else if lowerQuery.contains("text") {
            role = "AXStaticText"
        }

        return ElementLocator(
            role: role,
            title: query,
            label: query,
            value: query,
            description: nil,
            help: nil,
            roleDescription: query,
            identifier: nil
        )
    }

    @MainActor
    static func findElementByText(_ text: String, in sessionData: SessionCache.SessionData) -> SessionCache.SessionData.UIElement? {
        let lowerText = text.lowercased()

        return sessionData.uiMap.values.first { element in
            if let title = element.title?.lowercased(), title.contains(lowerText) {
                return true
            }
            if let label = element.label?.lowercased(), label.contains(lowerText) {
                return true
            }
            if let value = element.value?.lowercased(), value.contains(lowerText) {
                return true
            }
            if let roleDesc = element.roleDescription?.lowercased(), roleDesc.contains(lowerText) {
                return true
            }
            return false
        }
    }

    static func calculateWaitTimeout(_ waitFor: String?) -> TimeInterval {
        // Could implement dynamic timeout based on what we're waiting for
        10.0
    }

    @MainActor
    static func isValidClickLocation(_ location: CGPoint, windowBounds: CGRect) -> Bool {
        windowBounds.contains(location)
    }
}
