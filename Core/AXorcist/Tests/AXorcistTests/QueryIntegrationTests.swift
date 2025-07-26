import AppKit
@testable import AXorcist
import XCTest

// MARK: - Query Command Tests

class QueryIntegrationTests: XCTestCase {
    func testLaunchAndQueryTextEdit() async throws {
        await closeTextEdit()
        try await Task.sleep(for: .milliseconds(500))

        let (pid, _) = try await setupTextEditAndGetInfo()
        XCTAssertNotEqual(pid, 0, "PID should not be zero after TextEdit setup")

        let commandId = "focused_textedit_test_\(UUID().uuidString)"
        let attributesToFetch: [String] = [
            ApplicationServices.kAXRoleAttribute as String,
            ApplicationServices.kAXRoleDescriptionAttribute as String,
            ApplicationServices.kAXValueAttribute as String,
            "AXPlaceholderValue",
        ]

        let commandEnvelope = createCommandEnvelope(
            commandId: commandId,
            command: .getFocusedElement,
            application: "com.apple.TextEdit",
            attributes: attributesToFetch
        )

        let inputJSON = try encodeCommandToJSON(commandEnvelope)

        print("Input JSON for axorc:\n\(inputJSON)")

        let result = try runAXORCCommandWithStdin(
            inputJSON: inputJSON,
            arguments: ["--debug"]
        )

        print("axorc STDOUT:\n\(result.output ?? "nil")")
        print("axorc STDERR:\n\(result.errorOutput ?? "nil")")
        print("axorc Termination Status: \(result.exitCode)")

        let outputJSONString = try validateCommandExecution(
            output: result.output,
            errorOutput: result.errorOutput,
            exitCode: result.exitCode,
            commandName: "getFocusedElement"
        )

        let queryResponse = try decodeQueryResponse(from: outputJSONString, commandName: "getFocusedElement")
        validateQueryResponseBasics(queryResponse, expectedCommandId: commandId, expectedCommand: .getFocusedElement)

        guard let elementData = queryResponse.data else {
            throw TestError
                .generic(
                    "QueryResponse data is nil. Error: \(queryResponse.error?.message ?? "N/A"). " +
                        "Logs: \(queryResponse.debugLogs?.joined(separator: "\n") ?? "")"
                )
        }

        let expectedRole = ApplicationServices.kAXTextAreaRole as String
        let actualRole = elementData.attributes?[ApplicationServices.kAXRoleAttribute as String]?.value as? String
        let attributeKeys = elementData.attributes?.keys.map { Array($0) } ?? []
        XCTAssertEqual(
            actualRole, expectedRole,
            "Focused element role should be '\(expectedRole)'. Got: '\(actualRole ?? "nil")'. " +
                "Attributes: \(attributeKeys)"
        )

        XCTAssertTrue(
            elementData.attributes?.keys.contains(ApplicationServices.kAXValueAttribute as String) == true,
            "Focused element attributes should contain kAXValueAttribute as it was requested."
        )

        if let logs = queryResponse.debugLogs, !logs.isEmpty {
            print("axorc Debug Logs:")
            logs.forEach { print($0) }
        }

        await closeTextEdit()
    }

    func testGetAttributesForTextEditApplication() async throws {
        let commandId = "getattributes-textedit-app-\(UUID().uuidString)"
        let textEditBundleId = "com.apple.TextEdit"
        let requestedAttributes = ["AXRole", "AXTitle", "AXWindows", "AXFocusedWindow", "AXMainWindow", "AXIdentifier"]

        do {
            _ = try await setupTextEditAndGetInfo()
            print("TextEdit setup completed for getAttributes test.")
        } catch {
            throw TestError.generic("TextEdit setup failed for getAttributes: \(error.localizedDescription)")
        }
        defer {
            Task { await closeTextEdit() }
            print("TextEdit close process initiated for getAttributes test.")
        }

        let appLocator = Locator(criteria: [])

        let commandEnvelope = createCommandEnvelope(
            commandId: commandId,
            command: .getAttributes,
            application: textEditBundleId,
            attributes: requestedAttributes,
            locator: appLocator
        )

        let jsonString = try encodeCommandToJSON(commandEnvelope)

        print("Sending getAttributes command to axorc: \(jsonString)")
        let result = try runAXORCCommand(arguments: [jsonString])

        let outputString = try validateCommandExecution(
            output: result.output,
            errorOutput: result.errorOutput,
            exitCode: result.exitCode,
            commandName: "getAttributes"
        )

        let queryResponse = try decodeQueryResponse(from: outputString, commandName: "getAttributes")
        validateQueryResponseBasics(queryResponse, expectedCommandId: commandId, expectedCommand: .getAttributes)
        XCTAssertNotEqual(queryResponse.data?.attributes, nil, "AXElement attributes should not be nil.")

        let attributes = queryResponse.data?.attributes
        XCTAssertEqual(
            attributes?["AXRole"]?.value as? String, "AXApplication",
            "Application role should be AXApplication. Got: \(String(describing: attributes?["AXRole"]?.value))"
        )
        XCTAssertEqual(
            attributes?["AXTitle"]?.value as? String, "TextEdit",
            "Application title should be TextEdit. Got: \(String(describing: attributes?["AXTitle"]?.value))"
        )

        if let windowsAttr = attributes?["AXWindows"] {
            XCTAssertTrue(
                windowsAttr.value is [Any],
                "AXWindows should be an array. Type: \(type(of: windowsAttr.value))"
            )
            if let windowsArray = windowsAttr.value as? [AnyCodable] {
                XCTAssertTrue(!windowsArray.isEmpty, "AXWindows array should not be empty if TextEdit has windows.")
            } else if let windowsArray = windowsAttr.value as? [Any] {
                XCTAssertTrue(!windowsArray.isEmpty, "AXWindows array should not be empty (general type check).")
            }
        } else {
            XCTAssertNotEqual(attributes?["AXWindows"], nil, "AXWindows attribute should be present.")
        }

        XCTAssertNotEqual(queryResponse.debugLogs, nil, "Debug logs should be present.")
        XCTAssertTrue(
            queryResponse.debugLogs?
                .contains {
                    $0.contains("Handling getAttributes command") || $0.contains("handleGetAttributes completed")
                } ==
                true,
            "Debug logs should indicate getAttributes execution."
        )
    }

    func testQueryForTextEditTextArea() async throws {
        let commandId = "query-textedit-textarea-\(UUID().uuidString)"
        let textEditBundleId = "com.apple.TextEdit"
        let textAreaRole = ApplicationServices.kAXTextAreaRole as String
        let requestedAttributes = ["AXRole", "AXValue", "AXSelectedText", "AXNumberOfCharacters"]

        do {
            _ = try await setupTextEditAndGetInfo()
            print("TextEdit setup completed for query test.")
        } catch {
            throw TestError.generic("TextEdit setup failed for query: \(error.localizedDescription)")
        }
        defer {
            Task { await closeTextEdit() }
            print("TextEdit close process initiated for query test.")
        }

        let textAreaLocator = Locator(
            criteria: [Criterion(attribute: "AXRole", value: textAreaRole)]
        )

        let commandEnvelope = createCommandEnvelope(
            commandId: commandId,
            command: .query,
            application: textEditBundleId,
            attributes: requestedAttributes,
            locator: textAreaLocator
        )

        let jsonString = try encodeCommandToJSON(commandEnvelope)

        print("Sending query command to axorc: \(jsonString)")
        let result = try runAXORCCommand(arguments: [jsonString])

        let outputString = try validateCommandExecution(
            output: result.output,
            errorOutput: result.errorOutput,
            exitCode: result.exitCode,
            commandName: "query"
        )

        let queryResponse = try decodeQueryResponse(from: outputString, commandName: "query")
        validateQueryResponseBasics(queryResponse, expectedCommandId: commandId, expectedCommand: .query)
        XCTAssertNotEqual(queryResponse.data?.attributes, nil, "AXElement attributes should not be nil.")

        let attributes = queryResponse.data?.attributes
        XCTAssertEqual(
            attributes?["AXRole"]?.value as? String, textAreaRole,
            "Element role should be \(textAreaRole). Got: \(String(describing: attributes?["AXRole"]?.value))"
        )

        XCTAssertTrue(attributes?["AXValue"]?.value is String, "AXValue should exist and be a string.")
        XCTAssertTrue(attributes?["AXNumberOfCharacters"]?.value is Int, "AXNumberOfCharacters should exist and be an Int.")

        XCTAssertNotEqual(queryResponse.debugLogs, nil, "Debug logs should be present.")
        XCTAssertTrue(
            queryResponse.debugLogs?
                .contains { $0.contains("Handling query command") || $0.contains("handleQuery completed") } == true,
            "Debug logs should indicate query execution."
        )
    }

    func testDescribeTextEditTextArea() async throws {
        let commandId = "describe-textedit-textarea-\(UUID().uuidString)"
        let textEditBundleId = "com.apple.TextEdit"
        let textAreaRole = ApplicationServices.kAXTextAreaRole as String

        do {
            _ = try await setupTextEditAndGetInfo()
            print("TextEdit setup completed for describeElement test.")
        } catch {
            throw TestError.generic("TextEdit setup failed for describeElement: \(error.localizedDescription)")
        }
        defer {
            Task { await closeTextEdit() }
            print("TextEdit close process initiated for describeElement test.")
        }

        let textAreaLocator = Locator(
            criteria: [Criterion(attribute: "AXRole", value: textAreaRole)]
        )

        let commandEnvelope = createCommandEnvelope(
            commandId: commandId,
            command: .describeElement,
            application: textEditBundleId,
            locator: textAreaLocator
        )

        let jsonString = try encodeCommandToJSON(commandEnvelope)

        print("Sending describeElement command to axorc: \(jsonString)")
        let result = try runAXORCCommand(arguments: [jsonString])

        let outputString = try validateCommandExecution(
            output: result.output,
            errorOutput: result.errorOutput,
            exitCode: result.exitCode,
            commandName: "describeElement"
        )

        let queryResponse = try decodeQueryResponse(from: outputString, commandName: "describeElement")
        validateQueryResponseBasics(queryResponse, expectedCommandId: commandId, expectedCommand: .describeElement)

        guard let attributes = queryResponse.data?.attributes else {
            throw TestError.generic("Attributes dictionary is nil in describeElement response.")
        }

        XCTAssertEqual(
            attributes["AXRole"]?.value as? String, textAreaRole,
            "Element role should be \(textAreaRole). Got: \(String(describing: attributes["AXRole"]?.value))"
        )

        XCTAssertTrue(attributes["AXRoleDescription"]?.value is String, "AXRoleDescription should exist.")
        XCTAssertTrue(attributes["AXEnabled"]?.value is Bool, "AXEnabled should exist.")
        XCTAssertNotNil(attributes["AXPosition"]?.value, "AXPosition should exist.")
        XCTAssertNotNil(attributes["AXSize"]?.value, "AXSize should exist.")
        XCTAssertTrue(
            attributes.count > 10,
            "Expected describeElement to return many attributes (e.g., > 10). Got \(attributes.count)"
        )

        XCTAssertNotEqual(queryResponse.debugLogs, nil, "Debug logs should be present.")
        XCTAssertTrue(
            queryResponse.debugLogs?
                .contains {
                    $0.contains("Handling describeElement command") || $0.contains("handleDescribeElement completed")
                } ==
                true,
            "Debug logs should indicate describeElement execution."
        )
    }

    // MARK: - Helper Functions

    private func createCommandEnvelope(
        commandId: String,
        command: CommandType,
        application: String,
        attributes: [String]? = nil,
        locator: Locator? = nil,
        debugLogging: Bool = true
    ) -> CommandEnvelope {
        CommandEnvelope(
            commandId: commandId,
            command: command,
            application: application,
            attributes: attributes,
            debugLogging: debugLogging,
            locator: locator,
            payload: nil
        )
    }

    private func encodeCommandToJSON(_ commandEnvelope: CommandEnvelope) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let jsonData = try encoder.encode(commandEnvelope)
        guard let jsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
            throw TestError.generic("Failed to create JSON string for command.")
        }
        return jsonString
    }

    private func decodeQueryResponse(from outputString: String, commandName: String) throws -> QueryResponse {
        guard let responseData = outputString.data(using: String.Encoding.utf8) else {
            throw TestError.generic("Could not convert output string to data for \(commandName). Output: \(outputString)")
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(QueryResponse.self, from: responseData)
        } catch {
            throw TestError.generic(
                "Failed to decode QueryResponse for \(commandName): \(error.localizedDescription). " +
                    "Original JSON: \(outputString)"
            )
        }
    }

    private func validateCommandExecution(
        output: String?,
        errorOutput: String?,
        exitCode: Int32,
        commandName: String
    ) throws -> String {
        XCTAssertEqual(
            exitCode, 0,
            "axorc process should exit with 0 for \(commandName). Error: \(errorOutput ?? "N/A")"
        )
        XCTAssertTrue(
            (errorOutput == nil || errorOutput!.isEmpty),
            "STDERR should be empty on success. Got: \(errorOutput ?? "")"
        )

        guard let outputString = output, !outputString.isEmpty else {
            throw TestError.generic("Output string was nil or empty for \(commandName).")
        }

        print("Received output from axorc (\(commandName)): \(outputString)")
        return outputString
    }

    private func validateQueryResponseBasics(
        _ queryResponse: QueryResponse,
        expectedCommandId: String,
        expectedCommand: CommandType
    ) {
        XCTAssertEqual(queryResponse.commandId, expectedCommandId)
        XCTAssertEqual(
            queryResponse.success, true,
            "Command should succeed. Error: \(queryResponse.error?.message ?? "None")"
        )
        XCTAssertEqual(queryResponse.command, expectedCommand.rawValue)
        XCTAssertNil(
            queryResponse.error,
            "Error field should be nil. Got: \(queryResponse.error?.message ?? "N/A")"
        )
        XCTAssertNotNil(queryResponse.data, "Data field should not be nil.")
    }

}
