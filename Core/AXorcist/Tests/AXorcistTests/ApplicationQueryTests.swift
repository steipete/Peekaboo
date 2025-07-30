import AppKit
import XCTest
@testable import AXorcist

// Helper type for decoding arbitrary JSON values
struct AnyDecodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyDecodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyDecodable].self) {
            var result: [String: Any] = [:]
            for (key, val) in dict {
                result[key] = val.value
            }
            value = result
        } else {
            value = NSNull()
        }
    }
}

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

        // Define a proper response type that includes data
        struct ApplicationQueryResponse: Decodable {
            let success: Bool
            let data: [String: [[String: Any]]]

            enum CodingKeys: String, CodingKey {
                case success
                case data
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                success = try container.decode(Bool.self, forKey: .success)

                // Decode data as dictionary with array of dictionaries
                let dataContainer = try container.decode([String: [[String: AnyDecodable]]].self, forKey: .data)
                var dataDict: [String: [[String: Any]]] = [:]
                for (key, value) in dataContainer {
                    dataDict[key] = value.map { dict in
                        var result: [String: Any] = [:]
                        for (k, v) in dict {
                            result[k] = v.value
                        }
                        return result
                    }
                }
                data = dataDict
            }
        }

        let response = try JSONDecoder().decode(ApplicationQueryResponse.self, from: responseData)

        XCTAssertEqual(response.success, true)
        XCTAssertNotNil(response.data["elements"], "Should have elements")

        if let elements = response.data["elements"] {
            XCTAssertTrue(!elements.isEmpty, "Should have at least one application")

            // Check for Finder
            let appTitles = elements.compactMap { element -> String? in
                guard let attrs = element["attributes"] as? [String: Any] else { return nil }
                return attrs["AXTitle"] as? String
            }
            XCTAssertTrue(appTitles.contains("Finder"), "Finder should be running")
        }
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

        let response = try JSONDecoder().decode(ApplicationQueryResponse.self, from: responseData)

        XCTAssertEqual(response.success, true)
        if let elements = response.data["elements"] {
            XCTAssertTrue(!elements.isEmpty, "Should have at least one window")

            for window in elements {
                if let attrs = window["attributes"] as? [String: Any] {
                    XCTAssertEqual(attrs["AXRole"] as? String, "AXWindow")
                    XCTAssertNotNil(attrs["AXTitle"], "Window should have title")
                }
            }
        }
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
