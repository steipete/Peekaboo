import AppKit
@testable import AXorcist
import Foundation
import XCTest

// MARK: - Action Command Tests

class ActionIntegrationTests: XCTestCase {
    // MARK: Internal

    func testPerformActionSetTextEditTextAreaValue() async throws {
        let actionCommandId = "performaction-setvalue-\(UUID().uuidString)"
        let queryCommandId = "query-verify-setvalue-\(UUID().uuidString)"
        let textEditBundleId = "com.apple.TextEdit"
        let textAreaRole = ApplicationServices.kAXTextAreaRole as String
        let textToSet = "Hello from AXORC performAction test! Time: \(Date())"

        // Setup
        _ = try await setupTextEditAndGetInfo()
        defer { Task { await closeTextEdit() } }

        let textAreaLocator = Locator(criteria: [Criterion(attribute: "AXRole", value: textAreaRole)])

        // Perform action
        try await performSetValueAction(
            actionCommandId: actionCommandId,
            textEditBundleId: textEditBundleId,
            textAreaLocator: textAreaLocator,
            textToSet: textToSet
        )

        // Verify the value was set
        try await verifyTextValue(
            queryCommandId: queryCommandId,
            textEditBundleId: textEditBundleId,
            textAreaLocator: textAreaLocator,
            expectedText: textToSet
        )
    }

    func testExtractTextFromTextEditTextArea() async throws {
        let setValueCommandId = "setvalue-for-extract-\(UUID().uuidString)"
        let extractTextCommandId = "extracttext-textedit-textarea-\(UUID().uuidString)"
        let textEditBundleId = "com.apple.TextEdit"
        let textAreaRole = ApplicationServices.kAXTextAreaRole as String
        let textToSetAndExtract = "Text to be extracted by AXORC. Unique: \(UUID().uuidString)"

        // Setup
        _ = try await setupTextEditAndGetInfo()
        defer { Task { await closeTextEdit() } }

        let textAreaLocator = Locator(criteria: [Criterion(attribute: "AXRole", value: textAreaRole)])

        // Set text value
        try await performSetValueAction(
            actionCommandId: setValueCommandId,
            textEditBundleId: textEditBundleId,
            textAreaLocator: textAreaLocator,
            textToSet: textToSetAndExtract
        )

        // Extract and verify text
        try await extractAndVerifyText(
            extractTextCommandId: extractTextCommandId,
            textEditBundleId: textEditBundleId,
            textAreaLocator: textAreaLocator,
            expectedText: textToSetAndExtract
        )
    }

    // MARK: Private

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
            actionValue: AnyCodable(textToSet)
        )

        let response = try await executeCommand(performActionEnvelope)

        XCTAssertEqual(response.commandId, actionCommandId)
        XCTAssertEqual(
            response.success, true,
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

        XCTAssertEqual(response.commandId, queryCommandId)
        XCTAssertEqual(
            response.success, true,
            "Query (verify) command failed. Error: \(response.error?.message ?? "N/A")"
        )

        guard let attributes = response.data?.attributes else {
            throw TestError.generic("Attributes nil in query (verify) response.")
        }

        let retrievedValue = attributes["AXValue"]?.value as? String
        XCTAssertEqual(
            retrievedValue, expectedText,
            "AXValue did not match. Expected: '\(expectedText)'. Got: '\(retrievedValue ?? "nil")'"
        )

        XCTAssertNotEqual(response.debugLogs, nil)
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

        XCTAssertEqual(response.commandId, extractTextCommandId)
        XCTAssertEqual(
            response.success, true,
            "extractText command failed. Error: \(response.error?.message ?? "N/A")"
        )
        XCTAssertEqual(response.command, CommandType.extractText.rawValue)

        guard let attributes = response.data?.attributes else {
            throw TestError.generic("Attributes nil in extractText response.")
        }

        let extractedValue = attributes["AXValue"]?.value as? String
        XCTAssertEqual(
            extractedValue, expectedText,
            "Extracted text did not match. Expected: '\(expectedText)'. Got: '\(extractedValue ?? "nil")'"
        )

        XCTAssertNotEqual(response.debugLogs, nil)
        XCTAssertTrue(
            response.debugLogs?
                .contains { log in
                    log.contains("Handling extractText command") ||
                        log.contains("handleExtractText completed")
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

        XCTAssertEqual(exitCode, 0, "Command failed. Error: \(errorOutput ?? "N/A")")
        XCTAssertTrue(
            (errorOutput == nil || errorOutput!.isEmpty),
            "STDERR should be empty. Got: \(errorOutput ?? "")"
        )

        guard let outputString = output, !outputString.isEmpty else {
            throw TestError.generic("Output was nil/empty.")
        }

        print("Received output: \(outputString)")

        guard let responseData = outputString.data(using: String.Encoding.utf8) else {
            throw TestError.generic("Could not convert output to data.")
        }

        do {
            return try JSONDecoder().decode(QueryResponse.self, from: responseData)
        } catch {
            throw TestError.generic("Failed to decode response: \(error.localizedDescription). JSON: \(outputString)")
        }
    }
}
