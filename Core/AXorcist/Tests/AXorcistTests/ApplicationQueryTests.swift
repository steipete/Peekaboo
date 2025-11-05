import AppKit
import Testing
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

@Suite("AXorcist Application Query Tests", .tags(.safe))
struct ApplicationQueryTests {
    @Test("Collect all running applications", .tags(.safe))
    func getAllApplications() async throws {
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

        #expect(result.exitCode == 0, "Command should succeed")
        #expect(result.output != nil, "Should have output")

        guard let output = result.output,
              let responseData = output.data(using: String.Encoding.utf8)
        else {
            throw TestError.generic("No output")
        }

        let response = try JSONDecoder().decode(QueryResponse.self, from: responseData)

        #expect(response.success)
        #expect(response.data != nil, "Should have data")

        if let data = response.data {
            #expect(data.attributes != nil, "Should have attributes")
        }
    }

    @Test(
        "List TextEdit windows",
        .tags(.automation),
        .enabled(if: AXTestEnvironment.runAutomationScenarios)
    )
    @MainActor
    func getWindowsOfApplication() async throws {
        await closeTextEdit()
        try await Task.sleep(for: .milliseconds(500))

        _ = try await setupTextEditAndGetInfo()
        defer {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first {
                app.terminate()
            }
        }

        try await Task.sleep(for: .seconds(1))

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
        #expect(result.exitCode == 0)

        guard let output = result.output,
              let responseData = output.data(using: String.Encoding.utf8)
        else {
            throw TestError.generic("No output")
        }

        let response = try JSONDecoder().decode(QueryResponse.self, from: responseData)

        #expect(response.success)
        if let data = response.data {
            if let roleValue = data.attributes?["AXRole"] {
                #expect(roleValue.stringValue == "AXWindow")
            }
            if let titleValue = data.attributes?["AXTitle"] {
                #expect(titleValue.stringValue != nil, "Window should have title")
            }
        }
    }

    @Test("Query non-existent application", .tags(.safe))
    func queryNonExistentApp() async throws {
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

        #expect(result.exitCode == 0, "Command should succeed even when no elements found")

        guard let output = result.output,
              let responseData = output.data(using: String.Encoding.utf8)
        else {
            throw TestError.generic("No output")
        }

        let response = try JSONDecoder().decode(SimpleSuccessResponse.self, from: responseData)

        if response.success {
            let message = response.message
            #expect(
                message.contains("No") || message.contains("not found") || message.isEmpty,
                "Message should indicate no elements found or be empty"
            )
        }
    }
}
