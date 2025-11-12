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
        try await withFreshTextEdit { encoder in
            try await self.setText("Hello from AXorcist tests!", encoder: encoder)
            let response = try await self.queryTextArea(encoder: encoder)
            #expect(response.success)
            if let data = response.data,
               let value = data.attributes?["AXValue"]?.anyValue as? String
            {
                #expect(value.contains("Hello from AXorcist tests!"), "Should find the text we set")
            }
        }
    }

    @Test("Extract text from TextEdit window", .tags(.automation))
    func extractText() async throws {
        try await withFreshTextEdit { encoder in
            try await self.setText(
                "This is test content.\nIt has multiple lines.\nExtract this text.",
                encoder: encoder
            )
            let response = try await self.extractWindowText(encoder: encoder)
            #expect(response.success)
            self.assertExtractedText(response)
        }
    }
}

// MARK: - Helper Extensions

extension ElementSearchTests {
    private func withFreshTextEdit(_ action: (JSONEncoder) async throws -> Void) async throws {
        await closeTextEdit()
        try await Task.sleep(for: .milliseconds(500))
        _ = try await setupTextEditAndGetInfo()
        defer {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first {
                app.terminate()
            }
        }
        try await Task.sleep(for: .seconds(1))
        let encoder = JSONEncoder()
        try await action(encoder)
    }

    private func setText(_ text: String, encoder: JSONEncoder) async throws {
        let command = CommandEnvelope(
            commandId: "set-text",
            command: .performAction,
            application: "TextEdit",
            debugLogging: true,
            locator: Locator(criteria: [Criterion(attribute: "AXRole", value: "AXTextArea")]),
            actionName: "AXSetValue",
            actionValue: .string(text)
        )

        try await execute(command: command, encoder: encoder)
    }

    private func queryTextArea(encoder: JSONEncoder) async throws -> QueryResponse {
        let command = CommandEnvelope(
            commandId: "query-text",
            command: .query,
            application: "TextEdit",
            debugLogging: true,
            locator: Locator(criteria: [Criterion(attribute: "AXRole", value: "AXTextArea")]),
            outputFormat: .verbose
        )
        return try await runQuery(command: command, encoder: encoder)
    }

    private func extractWindowText(encoder: JSONEncoder) async throws -> QueryResponse {
        let command = CommandEnvelope(
            commandId: "extract-text-window",
            command: .extractText,
            application: "TextEdit",
            debugLogging: true,
            locator: Locator(criteria: [Criterion(attribute: "AXRole", value: "AXWindow")]),
            outputFormat: .textContent
        )
        return try await runQuery(command: command, encoder: encoder)
    }

    private func execute(command: CommandEnvelope, encoder: JSONEncoder) async throws {
        let data = try encoder.encode(command)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw TestError.generic("Failed to create JSON")
        }
        let result = try runAXORCCommand(arguments: [jsonString])
        #expect(result.exitCode == 0)
    }

    private func runQuery(command: CommandEnvelope, encoder: JSONEncoder) async throws -> QueryResponse {
        let data = try encoder.encode(command)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw TestError.generic("Failed to create JSON")
        }
        let result = try runAXORCCommand(arguments: [jsonString])
        #expect(result.exitCode == 0)
        guard let output = result.output,
              let responseData = output.data(using: .utf8)
        else {
            throw TestError.generic("No output")
        }
        return try JSONDecoder().decode(QueryResponse.self, from: responseData)
    }

    private func assertExtractedText(_ response: QueryResponse) {
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
