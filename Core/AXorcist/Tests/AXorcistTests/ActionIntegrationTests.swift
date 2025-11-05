import AppKit
import Foundation
import Testing
@testable import AXorcist

@Suite(
    "AXorcist Action Integration Tests",
    .tags(.automation),
    .enabled(if: AXTestEnvironment.runAutomationScenarios)
)
@MainActor
struct ActionIntegrationTests {
    @Test("Perform AXSetValue on TextEdit", .tags(.automation))
    func performActionSetTextEditTextAreaValue() async throws {
        let actionCommandId = "performaction-setvalue-\(UUID().uuidString)"
        let queryCommandId = "query-verify-setvalue-\(UUID().uuidString)"
        let textEditBundleId = "com.apple.TextEdit"
        let textAreaRole = ApplicationServices.kAXTextAreaRole as String
        let textToSet = "Hello from AXORC performAction test! Time: \(Date())"

        _ = try await setupTextEditAndGetInfo()
        defer { Task { await closeTextEdit() } }

        let textAreaLocator = Locator(criteria: [Criterion(attribute: "AXRole", value: textAreaRole)])

        try await performSetValueAction(
            actionCommandId: actionCommandId,
            textEditBundleId: textEditBundleId,
            textAreaLocator: textAreaLocator,
            textToSet: textToSet
        )

        try await verifyTextValue(
            queryCommandId: queryCommandId,
            textEditBundleId: textEditBundleId,
            textAreaLocator: textAreaLocator,
            expectedText: textToSet
        )
    }

    @Test("Extract text after setting value", .tags(.automation))
    func extractTextFromTextEditTextArea() async throws {
        let setValueCommandId = "setvalue-for-extract-\(UUID().uuidString)"
        let extractTextCommandId = "extracttext-textedit-textarea-\(UUID().uuidString)"
        let textEditBundleId = "com.apple.TextEdit"
        let textAreaRole = ApplicationServices.kAXTextAreaRole as String
        let textToSetAndExtract = "Text to be extracted by AXORC. Unique: \(UUID().uuidString)"

        _ = try await setupTextEditAndGetInfo()
        defer { Task { await closeTextEdit() } }

        let textAreaLocator = Locator(criteria: [Criterion(attribute: "AXRole", value: textAreaRole)])

        try await performSetValueAction(
            actionCommandId: setValueCommandId,
            textEditBundleId: textEditBundleId,
            textAreaLocator: textAreaLocator,
            textToSet: textToSetAndExtract
        )

        try await extractAndVerifyText(
            extractTextCommandId: extractTextCommandId,
            textEditBundleId: textEditBundleId,
            textAreaLocator: textAreaLocator,
            expectedText: textToSetAndExtract
        )
    }

    // MARK: - Helper Functions

    private func performSetValueAction(
        actionCommandId: String,
        textEditBundleId: String,
        textAreaLocator: Locator,
        textToSet: String
    ) async throws {
        let performActionEnvelope = CommandEnvelope(
            commandId: actionCommandId,
            command: .performAction,
            application: textEditBundleId,
            debugLogging: true,
            locator: textAreaLocator,
            actionName: "AXSetValue",
            actionValue: .string(textToSet)
        )

        let response = try await executeCommand(performActionEnvelope)

        #expect(response.commandId == actionCommandId)
        #expect(
            response.success,
            "performAction command was not successful. Error: \(response.error?.message ?? "N/A")"
        )

        try await Task.sleep(for: .milliseconds(100))
    }

    private func verifyTextValue(
        queryCommandId: String,
        textEditBundleId: String,
        textAreaLocator: Locator,
        expectedText: String
    ) async throws {
        let queryEnvelope = CommandEnvelope(
            commandId: queryCommandId,
            command: .query,
            application: textEditBundleId,
            attributes: ["AXValue"],
            debugLogging: true,
            locator: textAreaLocator
        )

        let response = try await executeCommand(queryEnvelope)

        #expect(response.commandId == queryCommandId)
        #expect(
            response.success,
            "Query (verify) command failed. Error: \(response.error?.message ?? "N/A")"
        )

        guard let attributes = response.data?.attributes else {
            throw TestError.generic("Attributes nil in query (verify) response.")
        }

        let retrievedValue = attributes["AXValue"]?.anyValue as? String
        #expect(
            retrievedValue == expectedText,
            "AXValue did not match. Expected: '\(expectedText)'. Got: '\(retrievedValue ?? "nil")'"
        )

        #expect(response.debugLogs != nil)
    }

    private func extractAndVerifyText(
        extractTextCommandId: String,
        textEditBundleId: String,
        textAreaLocator: Locator,
        expectedText: String
    ) async throws {
        let extractTextEnvelope = CommandEnvelope(
            commandId: extractTextCommandId,
            command: .extractText,
            application: textEditBundleId,
            debugLogging: true,
            locator: textAreaLocator
        )

        let response = try await executeCommand(extractTextEnvelope)

        #expect(response.commandId == extractTextCommandId)
        #expect(
            response.success,
            "extractText command failed. Error: \(response.error?.message ?? "N/A")"
        )
        #expect(response.command == CommandType.extractText.rawValue)

        guard let attributes = response.data?.attributes else {
            throw TestError.generic("Attributes nil in extractText response.")
        }

        let extractedValue = attributes["AXValue"]?.anyValue as? String
        #expect(
            extractedValue == expectedText,
            "Extracted text did not match. Expected: '\(expectedText)'. Got: '\(extractedValue ?? "nil")'"
        )

        #expect(response.debugLogs != nil)
        #expect(
            response.debugLogs?.contains { log in
                log.contains("Handling extractText command") || log.contains("handleExtractText completed")
            } == true,
            "Debug logs should indicate extractText execution."
        )
    }

    private func executeCommand(_ command: CommandEnvelope) async throws -> QueryResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let jsonData = try encoder.encode(command)
        guard let jsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
            throw TestError.generic("Failed to create JSON for command.")
        }

        print("Sending command: \(jsonString)")
        let result = try runAXORCCommand(arguments: [jsonString])
        let (output, errorOutput, exitCode) = (result.output, result.errorOutput, result.exitCode)

        #expect(exitCode == 0, "Command failed. Error: \(errorOutput ?? "N/A")")
        #expect(
            errorOutput?.isEmpty ?? true,
            "STDERR should be empty. Got: \(errorOutput ?? "")"
        )

        guard let outputString = output, !outputString.isEmpty else {
            throw TestError.generic("Output string was nil or empty for command: \(command.commandId)")
        }
        guard let responseData = outputString.data(using: String.Encoding.utf8) else {
            throw TestError.generic("Failed to convert output string to data for command: \(command.commandId)")
        }

        return try JSONDecoder().decode(QueryResponse.self, from: responseData)
    }
}

