import AppKit
import Foundation
import Testing
@testable import AXorcist

@Suite(
    "AXorcist Query Integration Tests",
    .tags(.automation),
    .enabled(if: AXTestEnvironment.runAutomationScenarios)
)
@MainActor
struct QueryIntegrationTests {
    @Test("Launch TextEdit and get focused element", .tags(.automation))
    func launchAndQueryTextEdit() async throws {
        await closeTextEdit()
        try await Task.sleep(for: .milliseconds(500))

        let (pid, _) = try await setupTextEditAndGetInfo()
        #expect(pid != 0, "PID should not be zero after TextEdit setup")

        let commandId = "focused_textedit_test_\(UUID().uuidString)"
        let attributesToFetch: [String] = [
            ApplicationServices.kAXRoleAttribute as String,
            ApplicationServices.kAXRoleDescriptionAttribute as String,
            ApplicationServices.kAXValueAttribute as String,
            "AXPlaceholderValue",
        ]

        let response = try self.executeCommand(
            envelope: createCommandEnvelope(
                commandId: commandId,
                command: .getFocusedElement,
                application: "com.apple.TextEdit",
                attributes: attributesToFetch),
            commandName: "getFocusedElement",
            viaStdin: true,
            arguments: ["--debug"])

        try self.assertFocusedElementResponse(
            response,
            expectedCommandId: commandId,
            expectedRole: ApplicationServices.kAXTextAreaRole as String,
            requestedAttributes: attributesToFetch)
        self.printDebugLogs(response.debugLogs, header: "axorc Debug Logs:")
        await closeTextEdit()
    }

    @Test("Get application attributes", .tags(.automation))
    func getAttributesForTextEditApplication() async throws {
        let commandId = "getattributes-textedit-app-\(UUID().uuidString)"
        let textEditBundleId = "com.apple.TextEdit"
        let requestedAttributes = ["AXRole", "AXTitle", "AXWindows", "AXFocusedWindow", "AXMainWindow", "AXIdentifier"]
        let appLocator = Locator(criteria: [])

        try await self.withTextEdit("getAttributes") {
            let response = try self.executeCommand(
                envelope: createCommandEnvelope(
                    commandId: commandId,
                    command: .getAttributes,
                    application: textEditBundleId,
                    attributes: requestedAttributes,
                    locator: appLocator),
                commandName: "getAttributes")

            try self.assertApplicationAttributes(
                response,
                expectedCommandId: commandId,
                expectedTitle: "TextEdit")
        }
    }

    @Test("Query TextEdit text area", .tags(.automation))
    func queryForTextEditTextArea() async throws {
        let commandId = "query-textedit-textarea-\(UUID().uuidString)"
        let textEditBundleId = "com.apple.TextEdit"
        let textAreaRole = ApplicationServices.kAXTextAreaRole as String
        let requestedAttributes = ["AXRole", "AXValue", "AXSelectedText", "AXNumberOfCharacters"]

        let textAreaLocator = Locator(
            criteria: [Criterion(attribute: "AXRole", value: textAreaRole)]
        )

        try await self.withTextEdit("query") {
            let response = try self.executeCommand(
                envelope: createCommandEnvelope(
                    commandId: commandId,
                    command: .query,
                    application: textEditBundleId,
                    attributes: requestedAttributes,
                    locator: textAreaLocator),
                commandName: "query")

            try self.assertQueryAttributes(
                response,
                expectedCommandId: commandId,
                expectedRole: textAreaRole)
        }
    }

    @Test("Describe TextEdit text area", .tags(.automation))
    func describeTextEditTextArea() async throws {
        let commandId = "describe-textedit-textarea-\(UUID().uuidString)"
        let textEditBundleId = "com.apple.TextEdit"
        let textAreaRole = ApplicationServices.kAXTextAreaRole as String

        let textAreaLocator = Locator(
            criteria: [Criterion(attribute: "AXRole", value: textAreaRole)]
        )

        try await self.withTextEdit("describeElement") {
            let response = try self.executeCommand(
                envelope: createCommandEnvelope(
                    commandId: commandId,
                    command: .describeElement,
                    application: textEditBundleId,
                    locator: textAreaLocator),
                commandName: "describeElement")

            try self.assertDescribeAttributes(
                response,
                expectedCommandId: commandId,
                expectedRole: textAreaRole)
        }
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
            let message = "Could not convert output string to data for \(commandName). " +
                "Output: \(outputString)"
            throw TestError.generic(message)
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(QueryResponse.self, from: responseData)
        } catch {
            let message = "Failed to decode QueryResponse for \(commandName): " +
                "\(error.localizedDescription). Original JSON: \(outputString)"
            throw TestError.generic(message)
        }
    }

    private func validateCommandExecution(
        output: String?,
        errorOutput: String?,
        exitCode: Int32,
        commandName: String
    ) throws -> String {
        #expect(exitCode == 0, "axorc process should exit with 0 for \(commandName). Error: \(errorOutput ?? "N/A")")
        #expect(
            errorOutput?.isEmpty ?? true,
            "STDERR should be empty on success. Got: \(errorOutput ?? "")"
        )

        guard let outputString = output, !outputString.isEmpty else {
            throw TestError.generic("Output string was nil or empty for \(commandName).")
        }

        print("Received output from axorc (\(commandName)): \(outputString)")
        return outputString
    }

    private func executeCommand(
        envelope: CommandEnvelope,
        commandName: String,
        viaStdin: Bool = false,
        arguments: [String] = []) throws -> QueryResponse
    {
        let jsonString = try encodeCommandToJSON(envelope)
        print("Sending \(commandName) command to axorc: \(jsonString)")
        let result: (output: String?, errorOutput: String?, exitCode: Int32)
        if viaStdin {
            result = try runAXORCCommandWithStdin(inputJSON: jsonString, arguments: arguments)
        } else {
            let cliArgs = [jsonString] + arguments
            result = try runAXORCCommand(arguments: cliArgs)
        }
        let outputString = try validateCommandExecution(
            output: result.output,
            errorOutput: result.errorOutput,
            exitCode: result.exitCode,
            commandName: commandName)
        return try decodeQueryResponse(from: outputString, commandName: commandName)
    }

    private func withTextEdit(_ context: String, action: () async throws -> Void) async throws {
        do {
            _ = try await setupTextEditAndGetInfo()
            print("TextEdit setup completed for \(context) test.")
        } catch {
            throw TestError.generic("TextEdit setup failed for \(context): \(error.localizedDescription)")
        }
        defer {
            Task { await closeTextEdit() }
            print("TextEdit close process initiated for \(context) test.")
        }
        try await action()
    }

    private func printDebugLogs(_ logs: [String]?, header: String) {
        guard let logs, !logs.isEmpty else { return }
        print(header)
        logs.forEach { print($0) }
    }

    private func assertFocusedElementResponse(
        _ response: QueryResponse,
        expectedCommandId: String,
        expectedRole: String,
        requestedAttributes: [String]) throws
    {
        validateQueryResponseBasics(response, expectedCommandId: expectedCommandId, expectedCommand: .getFocusedElement)
        guard let elementData = response.data else {
            throw TestError.generic("QueryResponse data is nil for getFocusedElement.")
        }
        let actualRole = elementData.attributes?[ApplicationServices.kAXRoleAttribute as String]?.anyValue as? String
        let attributeKeys = Array(elementData.attributes?.keys ?? [])
        let roleMessage = "Focused element role should be '\(expectedRole)'. " +
            "Got: '\(actualRole ?? "nil")'. Attributes: \(attributeKeys)"
        #expect(actualRole == expectedRole, roleMessage)
        #expect(
            elementData.attributes?.keys.contains(ApplicationServices.kAXValueAttribute as String) == true,
            "Focused element attributes should contain kAXValueAttribute as it was requested."
        )
        #expect(
            requestedAttributes.allSatisfy { elementData.attributes?.keys.contains($0) == true },
            "Focused element should include all requested attributes."
        )
    }

    private func assertApplicationAttributes(
        _ response: QueryResponse,
        expectedCommandId: String,
        expectedTitle: String) throws
    {
        validateQueryResponseBasics(response, expectedCommandId: expectedCommandId, expectedCommand: .getAttributes)
        guard let attributes = response.data?.attributes else {
            throw TestError.generic("AXElement attributes should not be nil for getAttributes.")
        }
        #expect(attributes["AXRole"]?.stringValue == "AXApplication")
        #expect(attributes["AXTitle"]?.stringValue == expectedTitle)
        if let windowsAttr = attributes["AXWindows"] {
            #expect(windowsAttr.arrayValue != nil, "AXWindows should be an array.")
        }
        self.printDebugLogs(response.debugLogs, header: "getAttributes debug logs")
    }

    private func assertQueryAttributes(
        _ response: QueryResponse,
        expectedCommandId: String,
        expectedRole: String) throws
    {
        validateQueryResponseBasics(response, expectedCommandId: expectedCommandId, expectedCommand: .query)
        guard let attributes = response.data?.attributes else {
            throw TestError.generic("AXElement attributes should not be nil for query.")
        }
        #expect(attributes["AXRole"]?.anyValue as? String == expectedRole)
        #expect(attributes["AXValue"]?.anyValue is String)
        #expect(attributes["AXNumberOfCharacters"]?.anyValue is Int)
        #expect(
            response.debugLogs?
                .contains { $0.contains("Handling query command") || $0.contains("handleQuery completed") } == true,
            "Debug logs should indicate query execution.")
    }

    private func assertDescribeAttributes(
        _ response: QueryResponse,
        expectedCommandId: String,
        expectedRole: String) throws
    {
        validateQueryResponseBasics(response, expectedCommandId: expectedCommandId, expectedCommand: .describeElement)
        guard let attributes = response.data?.attributes else {
            throw TestError.generic("Attributes dictionary is nil in describeElement response.")
        }
        #expect(attributes["AXRole"]?.anyValue as? String == expectedRole)
        #expect(attributes["AXRoleDescription"]?.anyValue is String)
        #expect(attributes["AXEnabled"]?.anyValue is Bool)
        #expect(attributes["AXPosition"] != nil)
        #expect(attributes["AXSize"] != nil)
        #expect(attributes.count > 10, "Expected describeElement to return many attributes (e.g., > 10).")
        #expect(
            response.debugLogs?
                .contains {
                    $0.contains("Handling describeElement command") || $0.contains("handleDescribeElement completed")
                } == true,
            "Debug logs should indicate describeElement execution.")
    }

    private func validateQueryResponseBasics(
        _ queryResponse: QueryResponse,
        expectedCommandId: String,
        expectedCommand: CommandType
    ) {
        #expect(queryResponse.commandId == expectedCommandId)
        #expect(
            queryResponse.success,
            "Command should succeed. Error: \(queryResponse.error?.message ?? "None")"
        )
        #expect(queryResponse.command == expectedCommand.rawValue)
        #expect(
            queryResponse.error == nil,
            "Error field should be nil. Got: \(queryResponse.error?.message ?? "N/A")"
        )
        #expect(queryResponse.data != nil, "Data field should not be nil.")
    }
}
