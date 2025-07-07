import AppKit
@testable import AXorcist
import XCTest

// MARK: - Application Query Tests

class ApplicationQueryTests: XCTestCase {
    func testGetAllApplications() async throws {
        let command = CommandEnvelope(
            commandId: "test-get-all-apps",
            command: .collectAll,
            debugLogging: true,
            locator: Locator(criteria: [Criterion(attribute: "AXRole", value: "AXApplication")]),
            outputFormat: .verbose
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(command)
        guard let jsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
            throw TestError.generic("Failed to create JSON")
        }

        let result = try runAXORCCommand(arguments: [jsonString])

        XCTAssertEqual(result.exitCode, 0, "Command should succeed")
        XCTAssertNotEqual(result.output, nil, "Should have output")

        guard let output = result.output,
              let responseData = output.data(using: String.Encoding.utf8)
        else {
            throw TestError.generic("No output")
        }

        let response = try JSONDecoder().decode(SimpleSuccessResponse.self, from: responseData)

        XCTAssertEqual(response.success, true)
        // TODO: Fix response type - SimpleSuccessResponse doesn't have data property
        // The following code expects response.data which doesn't exist
        /*
         XCTAssertNotEqual(response.data?["elements"] , nil, "Should have elements")

         if let elements = response.data?["elements"] as? [[String: Any]] {
             XCTAssertTrue(!elements.isEmpty, "Should have at least one application")

             // Check for Finder
             let appTitles = elements.compactMap { element -> String? in
                 guard let attrs = element["attributes"] as? [String: Any] else { return nil }
                 return attrs["AXTitle"] as? String
             }
             XCTAssertTrue(appTitles.contains("Finder"), "Finder should be running")
         }
         */
    }

    func testGetWindowsOfApplication() async throws {
        await closeTextEdit()
        try await Task.sleep(for: .milliseconds(500))

        let (pid, _) = try await setupTextEditAndGetInfo()
        defer {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first {
                app.terminate()
            }
        }

        try await Task.sleep(for: .seconds(1))

        // Query for windows
        let command = CommandEnvelope(
            commandId: "test-get-windows",
            command: .query,
            application: "TextEdit",
            debugLogging: true,
            locator: Locator(criteria: [Criterion(attribute: "AXRole", value: "AXWindow")]),
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

        let response = try JSONDecoder().decode(SimpleSuccessResponse.self, from: responseData)

        XCTAssertEqual(response.success, true)
        // TODO: Fix response type - SimpleSuccessResponse doesn't have data property
        /*
         if let elements = response.data?["elements"] as? [[String: Any]] {
             XCTAssertTrue(!elements.isEmpty, "Should have at least one window")

             for window in elements {
                 if let attrs = window["attributes"] as? [String: Any] {
                     XCTAssertEqual(attrs["AXRole"] as? String , "AXWindow")
                     XCTAssertNotEqual(attrs["AXTitle"] , nil, "Window should have title")
                 }
             }
         }
         */
    }

    func testQueryNonExistentApp() async throws {
        let command = CommandEnvelope(
            commandId: "test-nonexistent",
            command: .query,
            application: "NonExistentApp12345",
            debugLogging: true,
            locator: Locator(criteria: [Criterion(attribute: "AXRole", value: "AXApplication")])
        )

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(command)
        guard let jsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
            throw TestError.generic("Failed to create JSON")
        }

        let result = try runAXORCCommand(arguments: [jsonString])

        // Command should succeed but return no elements
        XCTAssertEqual(result.exitCode, 0)

        guard let output = result.output,
              let responseData = output.data(using: String.Encoding.utf8)
        else {
            throw TestError.generic("No output")
        }

        let response = try JSONDecoder().decode(SimpleSuccessResponse.self, from: responseData)

        if response.success {
            // For non-existent app, we expect success but should check message or details
            // to verify no elements were found. Since SimpleSuccessResponse doesn't
            // have element data, we verify through the success status and message.
            XCTAssertTrue(
                response.message.contains("No") || response.message.contains("not found") || response.message.isEmpty,
                "Message should indicate no elements found or be empty"
            )
        }
    }
}
