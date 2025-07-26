@testable import AXorcist
import Foundation
import XCTest

// MARK: - Ping Command Tests

class PingIntegrationTests: XCTestCase {
    func testPingViaStdin() async throws {
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

        XCTAssertEqual(
            result.exitCode, 0,
            "axorc command failed with status \(result.exitCode). Error: \(result.errorOutput ?? "N/A")"
        )
        XCTAssertTrue(
            (result.errorOutput == nil || result.errorOutput!.isEmpty),
            "Expected no error output, but got: \(result.errorOutput!)"
        )

        guard let outputString = result.output else {
            XCTAssertTrue(Bool(false), "Output was nil for ping via STDIN")
            return
        }

        guard let responseData = outputString.data(using: String.Encoding.utf8) else {
            XCTAssertTrue(
                Bool(false),
                "Failed to convert output to Data for ping via STDIN. Output: \(outputString)"
            )
            return
        }
        let decodedResponse = try JSONDecoder().decode(SimpleSuccessResponse.self, from: responseData)
        XCTAssertEqual(decodedResponse.success, true)
        XCTAssertEqual(
            decodedResponse.message, "Ping handled by AXORCCommand. Input source: STDIN",
            "Unexpected success message: \(decodedResponse.message)"
        )
        XCTAssertEqual(decodedResponse.details, "Hello from testPingViaStdin")
    }

    func testPingViaFile() async throws {
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

        XCTAssertEqual(
            result.exitCode, 0,
            "axorc command failed with status \(result.exitCode). Error: \(result.errorOutput ?? "N/A")"
        )
        XCTAssertTrue(
            (result.errorOutput == nil || result.errorOutput!.isEmpty),
            "Expected no error output, but got: \(result.errorOutput ?? "N/A")"
        )

        guard let outputString = result.output else {
            XCTAssertTrue(Bool(false), "Output was nil for ping via file")
            return
        }
        guard let responseData = outputString.data(using: String.Encoding.utf8) else {
            XCTAssertTrue(
                Bool(false),
                "Failed to convert output to Data for ping via file. Output: \(outputString)"
            )
            return
        }
        let decodedResponse = try JSONDecoder().decode(SimpleSuccessResponse.self, from: responseData)
        XCTAssertEqual(decodedResponse.success, true)
        XCTAssertTrue(
            decodedResponse.message.lowercased().contains("file: \(tempFilePath.lowercased())"),
            "Message should contain file path. Got: \(decodedResponse.message)"
        )
        XCTAssertEqual(decodedResponse.details, payloadMessage)
    }

    func testPingViaDirectPayload() async throws {
        let payloadMessage = "Hello from testPingViaDirectPayload"
        let inputJSON =
            "{\"command_id\":\"test_ping_direct\",\"command\":\"ping\",\"payload\":{\"message\":\"\(payloadMessage)\"}}"

        let result = try runAXORCCommand(arguments: [inputJSON])

        XCTAssertEqual(
            result.exitCode, 0,
            "axorc command failed with status \(result.exitCode). Error: \(result.errorOutput ?? "N/A")"
        )
        XCTAssertTrue(
            (result.errorOutput == nil || result.errorOutput!.isEmpty),
            "Expected no error output, but got: \(result.errorOutput ?? "N/A")"
        )

        guard let outputString = result.output else {
            XCTAssertTrue(Bool(false), "Output was nil for ping via direct payload")
            return
        }
        guard let responseData = outputString.data(using: String.Encoding.utf8) else {
            XCTAssertTrue(
                Bool(false),
                "Failed to convert output to Data for ping via direct payload. Output: \(outputString)"
            )
            return
        }
        let decodedResponse = try JSONDecoder().decode(SimpleSuccessResponse.self, from: responseData)
        XCTAssertEqual(decodedResponse.success, true)
        XCTAssertTrue(
            decodedResponse.message.contains("Direct Argument Payload"),
            "Unexpected success message: \(decodedResponse.message)"
        )
        XCTAssertEqual(decodedResponse.details, payloadMessage)
    }

    func testErrorMultipleInputMethods() async throws {
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

        XCTAssertEqual(
            result.exitCode, 0,
            "axorc command should return 0 with error on stdout. Status: \(result.exitCode). " +
                "Error STDOUT: \(result.output ?? "nil"). Error STDERR: \(result.errorOutput ?? "nil")"
        )

        guard let outputString = result.output, !outputString.isEmpty else {
            XCTAssertTrue(
                Bool(false),
                "Output was nil or empty for multiple input methods error test"
            )
            return
        }
        guard let responseData = outputString.data(using: String.Encoding.utf8) else {
            XCTAssertTrue(
                Bool(false),
                "Failed to convert output to Data for multiple input methods error. Output: \(outputString)"
            )
            return
        }
        let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: responseData)
        XCTAssertEqual(errorResponse.success, false)
        XCTAssertTrue(
            errorResponse.error.message.contains("Multiple input flags specified"),
            "Unexpected error message: \(errorResponse.error.message)"
        )
    }

    func testErrorNoInputProvidedForPing() async throws {
        let result = try runAXORCCommand(arguments: [])

        XCTAssertEqual(
            result.exitCode, 0,
            "axorc should return 0 with error on stdout. Status: \(result.exitCode). " +
                "Error STDOUT: \(result.output ?? "nil"). Error STDERR: \(result.errorOutput ?? "nil")"
        )

        guard let outputString = result.output, !outputString.isEmpty else {
            XCTAssertTrue(Bool(false), "Output was nil or empty for no input test.")
            return
        }
        guard let responseData = outputString.data(using: String.Encoding.utf8) else {
            XCTAssertTrue(
                Bool(false),
                "Failed to convert output to Data for no input error. Output: \(outputString)"
            )
            return
        }
        let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: responseData)
        XCTAssertEqual(errorResponse.success, false)
        XCTAssertEqual(
            errorResponse.commandId, "input_error",
            "Expected commandId to be input_error, got \(errorResponse.commandId)"
        )
        XCTAssertTrue(
            errorResponse.error.message.contains("No JSON input method specified"),
            "Unexpected error message for no input: \(errorResponse.error.message)"
        )
    }
}
