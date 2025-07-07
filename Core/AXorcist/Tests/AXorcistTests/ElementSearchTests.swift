import AppKit
@testable import AXorcist
import XCTest

// MARK: - Element Search and Navigation Tests

class ElementSearchTests: XCTestCase {
    func testSearchElementsByRole() async throws {
        await closeTextEdit()
        try await Task.sleep(for: .milliseconds(500))

        _ = try await setupTextEditAndGetInfo()
        defer {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first {
                app.terminate()
            }
        }

        try await Task.sleep(for: .seconds(1))

        // Search for buttons
        let command = CommandEnvelope(
            commandId: "test-search-buttons",
            command: .query,
            application: "TextEdit",
            debugLogging: true,
            locator: Locator(criteria: [Criterion(attribute: "AXRole", value: "AXButton")]),
            outputFormat: .verbose
        )

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(command)
        guard let jsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
            throw TestError.generic("Failed to create JSON")
        }

        let result = try runAXORCCommand(arguments: [jsonString])

        XCTAssertEqual(result.exitCode, 0)

        guard let output = result.output,
              let responseData = output.data(using: String.Encoding.utf8)
        else {
            throw TestError.generic("No output")
        }

        let response = try JSONDecoder().decode(QueryResponse.self, from: responseData)

        XCTAssertEqual(response.success, true)

        if let data = response.data, let attributes = data.attributes {
            // For a query response, we should find button elements
            if let role = attributes["AXRole"]?.value as? String {
                XCTAssertEqual(role, "AXButton", "Should find button elements")
            }
        }
    }

    func testDescribeElementHierarchy() async throws {
        await closeTextEdit()
        try await Task.sleep(for: .milliseconds(500))

        _ = try await setupTextEditAndGetInfo()
        defer {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first {
                app.terminate()
            }
        }

        try await Task.sleep(for: .seconds(1))

        // Describe the application element
        let command = CommandEnvelope(
            commandId: "test-describe",
            command: .describeElement,
            application: "TextEdit",
            debugLogging: true,
            locator: Locator(criteria: [Criterion(attribute: "AXRole", value: "AXApplication")]),
            maxElements: 3,
            outputFormat: .verbose
        )

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(command)
        guard let jsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
            throw TestError.generic("Failed to create JSON")
        }

        let result = try runAXORCCommand(arguments: [jsonString])

        XCTAssertEqual(result.exitCode, 0)

        guard let output = result.output,
              let responseData = output.data(using: String.Encoding.utf8)
        else {
            throw TestError.generic("No output")
        }

        let response = try JSONDecoder().decode(QueryResponse.self, from: responseData)

        XCTAssertEqual(response.success, true)
        XCTAssertNotNil(response.data)

        // Check hierarchy
        if let data = response.data, let attributes = data.attributes {
            if let role = attributes["AXRole"]?.value as? String {
                XCTAssertEqual(role, "AXApplication", "Should find application element")
            }
        }
    }

    func testSetAndVerifyText() async throws {
        await closeTextEdit()
        try await Task.sleep(for: .milliseconds(500))

        _ = try await setupTextEditAndGetInfo()
        defer {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first {
                app.terminate()
            }
        }

        try await Task.sleep(for: .seconds(1))

        // Set text
        let setText = CommandEnvelope(
            commandId: "test-set-text",
            command: .performAction,
            application: "TextEdit",
            debugLogging: true,
            locator: Locator(criteria: [Criterion(attribute: "AXRole", value: "AXTextArea")]),
            actionName: "AXSetValue",
            actionValue: AnyCodable("Hello from AXorcist tests!")
        )

        let encoder = JSONEncoder()
        var jsonData = try encoder.encode(setText)
        guard let setJsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
            throw TestError.generic("Failed to create JSON")
        }

        var result = try runAXORCCommand(arguments: [setJsonString])
        XCTAssertEqual(result.exitCode, 0)

        // Query to verify
        let queryText = CommandEnvelope(
            commandId: "test-query-text",
            command: .query,
            application: "TextEdit",
            debugLogging: true,
            locator: Locator(criteria: [Criterion(attribute: "AXRole", value: "AXTextArea")]),
            outputFormat: .verbose
        )

        jsonData = try encoder.encode(queryText)
        guard let queryJsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
            throw TestError.generic("Failed to create JSON")
        }

        result = try runAXORCCommand(arguments: [queryJsonString])
        XCTAssertEqual(result.exitCode, 0)

        guard let output = result.output,
              let responseData = output.data(using: String.Encoding.utf8)
        else {
            throw TestError.generic("No output")
        }

        let response = try JSONDecoder().decode(QueryResponse.self, from: responseData)

        XCTAssertEqual(response.success, true)

        if let data = response.data, let attributes = data.attributes {
            if let value = attributes["AXValue"]?.value as? String {
                XCTAssertTrue(value.contains("Hello from AXorcist tests!"), "Should find the text we set")
            }
        }
    }

    func testExtractText() async throws {
        await closeTextEdit()
        try await Task.sleep(for: .milliseconds(500))

        _ = try await setupTextEditAndGetInfo()
        defer {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first {
                app.terminate()
            }
        }

        try await Task.sleep(for: .seconds(1))

        // Set some text first
        let setText = CommandEnvelope(
            commandId: "test-set-for-extract",
            command: .performAction,
            application: "TextEdit",
            debugLogging: true,
            locator: Locator(criteria: [Criterion(attribute: "AXRole", value: "AXTextArea")]),
            actionName: "AXSetValue",
            actionValue: AnyCodable("This is test content.\nIt has multiple lines.\nExtract this text.")
        )

        let encoder = JSONEncoder()
        var jsonData = try encoder.encode(setText)
        guard let setJsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
            throw TestError.generic("Failed to create JSON")
        }

        _ = try runAXORCCommand(arguments: [setJsonString])

        // Extract text
        let extractCommand = CommandEnvelope(
            commandId: "test-extract",
            command: .extractText,
            application: "TextEdit",
            debugLogging: true,
            locator: Locator(criteria: [Criterion(attribute: "AXRole", value: "AXWindow")]),
            outputFormat: .textContent
        )

        jsonData = try encoder.encode(extractCommand)
        guard let extractJsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
            throw TestError.generic("Failed to create JSON")
        }

        let result = try runAXORCCommand(arguments: [extractJsonString])
        XCTAssertEqual(result.exitCode, 0)

        guard let output = result.output,
              let responseData = output.data(using: String.Encoding.utf8)
        else {
            throw TestError.generic("No output")
        }

        let response = try JSONDecoder().decode(QueryResponse.self, from: responseData)

        XCTAssertEqual(response.success, true)

        if let data = response.data, let attributes = data.attributes {
            // For extract text commands, check for extracted text in attributes
            if let extractedText = attributes["extractedText"]?.value as? String {
                XCTAssertTrue(extractedText.contains("This is test content"), "Should extract the test content")
                XCTAssertTrue(extractedText.contains("multiple lines"), "Should extract multiple lines")
            } else if let value = attributes["AXValue"]?.value as? String {
                XCTAssertTrue(value.contains("This is test content"), "Should extract the test content")
                XCTAssertTrue(value.contains("multiple lines"), "Should extract multiple lines")
            }
        }
    }
}
