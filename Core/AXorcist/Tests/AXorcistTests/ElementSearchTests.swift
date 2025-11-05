import AppKit
import Testing
@testable import AXorcist

@Suite(
    "AXorcist Element Search Tests",
    .tags(.automation),
    .enabled(if: AXTestEnvironment.runAutomationScenarios)
)
@MainActor
struct ElementSearchTests {
    @Test("Search elements by role", .tags(.automation))
    func searchElementsByRole() async throws {
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
        #expect(result.exitCode == 0)

        guard let output = result.output,
              let responseData = output.data(using: String.Encoding.utf8)
        else {
            throw TestError.generic("No output")
        }

        let response = try JSONDecoder().decode(QueryResponse.self, from: responseData)

        #expect(response.success)

        if let data = response.data, let attributes = data.attributes {
            if let role = attributes["AXRole"]?.anyValue as? String {
                #expect(role == "AXButton", "Should find button elements")
            }
        }
    }

    @Test("Describe element hierarchy", .tags(.automation))
    func describeElementHierarchy() async throws {
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
        #expect(result.exitCode == 0)

        guard let output = result.output,
              let responseData = output.data(using: String.Encoding.utf8)
        else {
            throw TestError.generic("No output")
        }

        let response = try JSONDecoder().decode(QueryResponse.self, from: responseData)

        #expect(response.success)
        #expect(response.data != nil)

        if let data = response.data, let attributes = data.attributes {
            if let role = attributes["AXRole"]?.anyValue as? String {
                #expect(role == "AXApplication", "Should find application element")
            }
        }
    }

    @Test("Set and verify text in TextEdit", .tags(.automation))
    func setAndVerifyText() async throws {
        await closeTextEdit()
        try await Task.sleep(for: .milliseconds(500))

        _ = try await setupTextEditAndGetInfo()
        defer {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first {
                app.terminate()
            }
        }

        try await Task.sleep(for: .seconds(1))

        let setText = CommandEnvelope(
            commandId: "test-set-text",
            command: .performAction,
            application: "TextEdit",
            debugLogging: true,
            locator: Locator(criteria: [Criterion(attribute: "AXRole", value: "AXTextArea")]),
            actionName: "AXSetValue",
            actionValue: .string("Hello from AXorcist tests!")
        )

        let encoder = JSONEncoder()
        var jsonData = try encoder.encode(setText)
        guard let setJsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
            throw TestError.generic("Failed to create JSON")
        }

        var result = try runAXORCCommand(arguments: [setJsonString])
        #expect(result.exitCode == 0)

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
        #expect(result.exitCode == 0)

        guard let output = result.output,
              let responseData = output.data(using: String.Encoding.utf8)
        else {
            throw TestError.generic("No output")
        }

        let response = try JSONDecoder().decode(QueryResponse.self, from: responseData)

        #expect(response.success)

        if let data = response.data, let attributes = data.attributes {
            if let value = attributes["AXValue"]?.anyValue as? String {
                #expect(value.contains("Hello from AXorcist tests!"), "Should find the text we set")
            }
        }
    }

    @Test("Extract text from TextEdit window", .tags(.automation))
    func extractText() async throws {
        await closeTextEdit()
        try await Task.sleep(for: .milliseconds(500))

        _ = try await setupTextEditAndGetInfo()
        defer {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first {
                app.terminate()
            }
        }

        try await Task.sleep(for: .seconds(1))

        let setText = CommandEnvelope(
            commandId: "test-set-for-extract",
            command: .performAction,
            application: "TextEdit",
            debugLogging: true,
            locator: Locator(criteria: [Criterion(attribute: "AXRole", value: "AXTextArea")]),
            actionName: "AXSetValue",
            actionValue: .string("This is test content.\nIt has multiple lines.\nExtract this text.")
        )

        let encoder = JSONEncoder()
        var jsonData = try encoder.encode(setText)
        guard let setJsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
            throw TestError.generic("Failed to create JSON")
        }

        _ = try runAXORCCommand(arguments: [setJsonString])

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
        #expect(result.exitCode == 0)

        guard let output = result.output,
              let responseData = output.data(using: String.Encoding.utf8)
        else {
            throw TestError.generic("No output")
        }

        let response = try JSONDecoder().decode(QueryResponse.self, from: responseData)

        #expect(response.success)

        if let data = response.data, let attributes = data.attributes {
            if let extractedText = attributes["extractedText"]?.anyValue as? String {
                #expect(extractedText.contains("This is test content"), "Should extract the test content")
                #expect(extractedText.contains("multiple lines"), "Should extract multiple lines")
            } else if let value = attributes["AXValue"]?.anyValue as? String {
                #expect(value.contains("This is test content"), "Should extract the test content")
                #expect(value.contains("multiple lines"), "Should extract multiple lines")
            }
        }
    }
}

