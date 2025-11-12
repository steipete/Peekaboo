import Foundation
import Testing
@testable import AXorcist

@Suite("AXorcist Ping Integration Tests", .tags(.safe))
struct PingIntegrationTests {
    @Test("Ping via stdin", .tags(.safe))
    func pingViaStdin() async throws {
        let inputJSON = """
        {
            "command_id": "test_ping_stdin",
            "command": "ping",
            "payload": {
                "message": "Hello from testPingViaStdin"
            }
        }
        """
        let result = try runAXORCCommandWithStdin(
            inputJSON: inputJSON,
            arguments: ["--stdin"]
        )

        let stdinFailureMessage = """
        axorc command failed with status \(result.exitCode).
        Error: \(result.errorOutput ?? "N/A")
        """
        #expect(result.exitCode == 0, stdinFailureMessage)
        let stdinErrorMessage = "Expected no error output, but got: \(result.errorOutput ?? "N/A")"
        #expect(result.errorOutput?.isEmpty ?? true, stdinErrorMessage)

        guard let outputString = result.output else {
            Issue.record("Output was nil for ping via STDIN")
            return
        }

        guard let responseData = outputString.data(using: .utf8) else {
            Issue.record("Failed to convert output to Data for ping via STDIN. Output: \(outputString)")
            return
        }

        let decodedResponse = try JSONDecoder().decode(SimpleSuccessResponse.self, from: responseData)
        #expect(decodedResponse.success)
        #expect(
            decodedResponse.message == "Ping handled by AXORCCommand. Input source: STDIN",
            "Unexpected success message: \(decodedResponse.message)"
        )
        #expect(decodedResponse.details == "Hello from testPingViaStdin")
    }

    @Test("Ping via file input", .tags(.safe))
    func pingViaFile() async throws {
        let payloadMessage = "Hello from testPingViaFile"
        let inputJSON = """
        {
            "command_id": "test_ping_file",
            "command": "ping",
            "payload": { "message": "\(payloadMessage)" }
        }
        """
        let tempFilePath = try createTempFile(content: inputJSON)
        defer { try? FileManager.default.removeItem(atPath: tempFilePath) }

        let result = try runAXORCCommand(arguments: ["--file", tempFilePath])

        let fileFailureMessage = """
        axorc command failed with status \(result.exitCode).
        Error: \(result.errorOutput ?? "N/A")
        """
        #expect(result.exitCode == 0, fileFailureMessage)
        let fileErrorMessage = "Expected no error output, but got: \(result.errorOutput ?? "N/A")"
        #expect(result.errorOutput?.isEmpty ?? true, fileErrorMessage)

        guard let outputString = result.output else {
            Issue.record("Output was nil for ping via file")
            return
        }
        guard let responseData = outputString.data(using: .utf8) else {
            Issue.record("Failed to convert output to Data for ping via file. Output: \(outputString)")
            return
        }
        let decodedResponse = try JSONDecoder().decode(SimpleSuccessResponse.self, from: responseData)
        #expect(decodedResponse.success)
        #expect(
            decodedResponse.message.lowercased().contains("file: \(tempFilePath.lowercased())"),
            "Message should contain file path. Got: \(decodedResponse.message)"
        )
        #expect(decodedResponse.details == payloadMessage)
    }

    @Test("Ping via direct payload argument", .tags(.safe))
    func pingViaDirectPayload() async throws {
        let payloadMessage = "Hello from testPingViaDirectPayload"
        let inputJSON = """
        {"command_id":"test_ping_direct","command":"ping","payload":{"message":"\(payloadMessage)"}}
        """

        let result = try runAXORCCommand(arguments: [inputJSON])

        let directFailureMessage = """
        axorc command failed with status \(result.exitCode).
        Error: \(result.errorOutput ?? "N/A")
        """
        #expect(result.exitCode == 0, directFailureMessage)
        let directErrorMessage = "Expected no error output, but got: \(result.errorOutput ?? "N/A")"
        #expect(result.errorOutput?.isEmpty ?? true, directErrorMessage)

        guard let outputString = result.output else {
            Issue.record("Output was nil for ping via direct payload")
            return
        }
        guard let responseData = outputString.data(using: .utf8) else {
            Issue.record("Failed to convert output to Data for ping via direct payload. Output: \(outputString)")
            return
        }
        let decodedResponse = try JSONDecoder().decode(SimpleSuccessResponse.self, from: responseData)
        #expect(decodedResponse.success)
        #expect(
            decodedResponse.message.contains("Direct Argument Payload"),
            "Unexpected success message: \(decodedResponse.message)"
        )
        #expect(decodedResponse.details == payloadMessage)
    }

    @Test("Reject multiple input sources", .tags(.safe))
    func errorMultipleInputMethods() async throws {
        let inputJSON = """
        {
            "command_id": "test_error_multiple_inputs",
            "command": "ping",
            "payload": { "message": "This should not be processed" }
        }
        """
        let tempFilePath = try createTempFile(content: "{}")
        defer { try? FileManager.default.removeItem(atPath: tempFilePath) }

        let result = try runAXORCCommandWithStdin(
            inputJSON: inputJSON,
            arguments: ["--file", tempFilePath]
        )

        let multiInputMessage = """
        axorc command should return 0 with error on stdout.
        Status: \(result.exitCode). Error STDOUT: \(result.output ?? "nil").
        Error STDERR: \(result.errorOutput ?? "nil")
        """
        #expect(result.exitCode == 0, multiInputMessage)

        guard let outputString = result.output, !outputString.isEmpty else {
            Issue.record("Output was nil or empty for multiple input methods error test")
            return
        }
        guard let responseData = outputString.data(using: .utf8) else {
            Issue.record("Failed to convert output to Data for multiple input methods error. Output: \(outputString)")
            return
        }
        let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: responseData)
        #expect(errorResponse.success == false)
        #expect(
            errorResponse.error.message.contains("Multiple input flags specified"),
            "Unexpected error message: \(errorResponse.error.message)"
        )
    }

    @Test("Reject ping without input", .tags(.safe))
    func errorNoInputProvidedForPing() async throws {
        let result = try runAXORCCommand(arguments: [])

        let noInputMessage = """
        axorc should return 0 with error on stdout. Status: \(result.exitCode).
        Error STDOUT: \(result.output ?? "nil"). Error STDERR: \(result.errorOutput ?? "nil")
        """
        #expect(result.exitCode == 0, noInputMessage)

        guard let outputString = result.output, !outputString.isEmpty else {
            Issue.record("Output was nil or empty for no input test.")
            return
        }
        guard let responseData = outputString.data(using: .utf8) else {
            Issue.record("Failed to convert output to Data for no input error. Output: \(outputString)")
            return
        }
        let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: responseData)
        #expect(errorResponse.success == false)
        let commandIdMessage = "Expected commandId to be input_error, got \(errorResponse.commandId)"
        #expect(errorResponse.commandId == "input_error", commandIdMessage)
    }
}
