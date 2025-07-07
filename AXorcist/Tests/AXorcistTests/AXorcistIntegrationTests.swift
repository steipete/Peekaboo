import AppKit
@testable import AXorcistLib
import Testing
import XCTest

// Refactored TextEdit setup logic into an @MainActor async function
@MainActor
private func setupTextEditAndGetInfo() async throws -> (pid: pid_t, axAppElement: AXUIElement?) {
    let textEditBundleId = "com.apple.TextEdit"
    var app: NSRunningApplication? = NSRunningApplication.runningApplications(withBundleIdentifier: textEditBundleId)
        .first

    if app == nil {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: textEditBundleId) else {
            throw TestError.generic("Could not find URL for TextEdit application.")
        }

        print("Attempting to launch TextEdit from URL: \(url.path)")
        // Use the older launchApplication API which sometimes is more robust in test environments
        // despite deprecation. Configure for async and no activation initially.
        let configuration: [NSWorkspace.LaunchConfigurationKey: Any] = [:] // Empty config for older API
        do {
            app = try NSWorkspace.shared.launchApplication(at: url,
                                                           options: [.async, .withoutActivation],
                                                           configuration: configuration)
            print("launchApplication call completed. App PID if returned: \(app?.processIdentifier ?? -1)")
        } catch {
            throw TestError
                .appNotRunning(
                    "Failed to launch TextEdit using launchApplication(at:options:configuration:): \(error.localizedDescription)"
                )
        }

        // Wait for the app to appear in running applications list
        var launchedApp: NSRunningApplication?
        for attempt in 1...10 { // Retry for up to 10 * 0.5s = 5 seconds
            launchedApp = NSRunningApplication.runningApplications(withBundleIdentifier: textEditBundleId).first
            if launchedApp != nil {
                print("TextEdit found running after launch, attempt \(attempt).")
                break
            }
            try await Task.sleep(for: .milliseconds(500))
            print("Waiting for TextEdit to appear in running list... attempt \(attempt)")
        }

        guard let runningAppAfterLaunch = launchedApp else {
            throw TestError.appNotRunning("TextEdit did not appear in running applications list after launch attempt.")
        }
        app = runningAppAfterLaunch // Assign the found app
    }

    guard let runningApp = app else {
        // This should be redundant now due to the guard above, but as a final safety.
        throw TestError.appNotRunning("TextEdit is unexpectedly nil before activation checks.")
    }

    let pid = runningApp.processIdentifier
    let axAppElement = AXUIElementCreateApplication(pid)

    // Activate and ensure a window
    if !runningApp.isActive {
        runningApp.activate(options: [.activateAllWindows])
        try await Task.sleep(for: .seconds(1.5)) // Wait for activation
    }

    var window: AnyObject?
    let resultCopyAttribute = AXUIElementCopyAttributeValue(
        axAppElement,
        ApplicationServices.kAXWindowsAttribute as CFString,
        &window
    )
    if resultCopyAttribute != AXError.success || (window as? [AXUIElement])?.isEmpty ?? true {
        let appleScript = """
        tell application "System Events"
            tell process "TextEdit"
                set frontmost to true
                keystroke "n" using command down
            end tell
        end tell
        """
        var errorDict: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
            scriptObject.executeAndReturnError(&errorDict)
            if let error = errorDict {
                throw TestError.appleScriptError("Failed to create new document in TextEdit: \(error)")
            }
            try await Task.sleep(for: .seconds(2)) // Wait for new document window
        }
    }

    // Re-check activation
    if !runningApp.isActive {
        runningApp.activate(options: [.activateAllWindows])
        try await Task.sleep(for: .seconds(1))
    }

    // Optional: Confirm focused element directly (for debugging setup)
    var cfFocusedElement: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(
        axAppElement,
        ApplicationServices.kAXFocusedUIElementAttribute as CFString,
        &cfFocusedElement
    )
    if status == AXError.success, cfFocusedElement != nil {
        print("AX API successfully got a focused element during setup.")
    } else {
        print("AX API did not get a focused element during setup. Status: \(status.rawValue). This might be okay.")
    }

    return (pid, axAppElement)
}

@MainActor
private func closeTextEdit() async {
    let textEditBundleId = "com.apple.TextEdit"
    guard let textEdit = NSRunningApplication.runningApplications(withBundleIdentifier: textEditBundleId).first else {
        return // Not running
    }

    textEdit.terminate()
    // Give it a moment to terminate gracefully
    for _ in 0..<5 { // Check for up to 2.5 seconds
        if textEdit.isTerminated { break }
        try? await Task.sleep(for: .milliseconds(500))
    }

    if !textEdit.isTerminated {
        textEdit.forceTerminate()
        try? await Task.sleep(for: .milliseconds(500)) // Brief pause after force terminate
    }
}

private func runAXORCCommand(arguments: [String]) throws -> (String?, String?, Int32) {
    let axorcUrl = productsDirectory.appendingPathComponent("axorc")

    let process = Process()
    process.executableURL = axorcUrl
    process.arguments = arguments

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

    let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

    // Strip the AXORC_JSON_OUTPUT_PREFIX if present
    let cleanOutput = stripJSONPrefix(from: output)

    return (cleanOutput, errorOutput, process.terminationStatus)
}

// Helper to create a temporary file with content
private func createTempFile(content: String) throws -> String {
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = UUID().uuidString + ".json"
    let fileURL = tempDir.appendingPathComponent(fileName)
    try content.write(to: fileURL, atomically: true, encoding: .utf8)
    return fileURL.path
}

// Helper to strip the JSON output prefix from axorc output
private func stripJSONPrefix(from output: String?) -> String? {
    guard let output = output else { return nil }
    let prefix = "AXORC_JSON_OUTPUT_PREFIX:::"
    if output.hasPrefix(prefix) {
        return String(output.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return output
}

// Function to run axorc with STDIN input
private func runAXORCCommandWithStdin(inputJSON: String, arguments: [String]) throws -> (String?, String?, Int32) {
    let axorcUrl = productsDirectory.appendingPathComponent("axorc")

    let process = Process()
    process.executableURL = axorcUrl
    // Ensure --stdin is included if not already present, as axorc.swift now uses it as a flag
    var effectiveArguments = arguments
    if !effectiveArguments.contains("--stdin") {
        effectiveArguments.append("--stdin")
    }
    process.arguments = effectiveArguments

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    let inputPipe = Pipe()

    process.standardOutput = outputPipe
    process.standardError = errorPipe
    process.standardInput = inputPipe

    try process.run()

    // Write to STDIN
    if let inputData = inputJSON.data(using: .utf8) {
        try inputPipe.fileHandleForWriting.write(contentsOf: inputData)
        inputPipe.fileHandleForWriting.closeFile() // Close STDIN to signal EOF
    } else {
        // Handle error: inputJSON could not be converted to Data
        inputPipe.fileHandleForWriting.closeFile() // Still close it
        // Consider throwing an error or logging
        print("Warning: Could not convert inputJSON to Data for STDIN.")
    }

    process.waitUntilExit()

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

    let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

    let cleanOutput = stripJSONPrefix(from: output)

    return (cleanOutput, errorOutput, process.terminationStatus)
}

// MARK: - Codable Structs for Testing

// Based on axorc.swift and AXorcist.swift
enum CommandType: String, Codable {
    case ping
    case getFocusedElement
    // Add other command types as they are implemented in axorc
    case collectAll, query, describeElement, getAttributes, performAction, extractText, batch
}

// Local test model for Locator, mirroring AXorcist.Locator from Models.swift
struct Locator: Codable {
    var match_all: Bool?
    var criteria: [String: String]
    var root_element_path_hint: [String]?
    var requireAction: String? // Snake case for JSON: require_action
    var computed_name_contains: String?

    enum CodingKeys: String, CodingKey {
        case match_all
        case criteria
        case root_element_path_hint
        case requireAction = "require_action"
        case computed_name_contains
    }

    init(match_all: Bool? = nil, criteria: [String: String] = [:], root_element_path_hint: [String]? = nil,
         requireAction: String? = nil, computed_name_contains: String? = nil) {
        self.match_all = match_all
        self.criteria = criteria
        self.root_element_path_hint = root_element_path_hint
        self.requireAction = requireAction
        self.computed_name_contains = computed_name_contains
    }
}

struct CommandEnvelope: Codable {
    let command_id: String
    let command: CommandType
    let application: String?
    let attributes: [String]?
    let debug_logging: Bool?

    // Use the locally defined Locator struct that mirrors AXorcist.Locator
    let locator: Locator?
    let path_hint: [String]? // Changed from String? to [String]? to align with AXorcist.CommandEnvelope
    let max_elements: Int?
    let output_format: OutputFormat? // Use directly from AXorcist module (OutputFormat, not AXorcist.OutputFormat)
    let action_name: String?
    let action_value: AnyCodable? // Use directly from AXorcist module (AnyCodable, not AXorcist.AnyCodable)

    let payload: [String: AnyCodable]? // Use directly from AXorcist module
    let sub_commands: [CommandEnvelope]? // Recursive for batch command

    init(command_id: String,
         command: CommandType,
         application: String? = nil,
         attributes: [String]? = nil,
         debug_logging: Bool? = nil,
         locator: Locator? = nil, // Use local Locator type
         path_hint: [String]? = nil, // Aligned to [String]?
         max_elements: Int? = nil,
         output_format: OutputFormat? = nil, // Use direct OutputFormat
         action_name: String? = nil,
         action_value: AnyCodable? = nil, // Use direct AnyCodable
         payload: [String: AnyCodable]? = nil, // Use direct AnyCodable
         sub_commands: [CommandEnvelope]? = nil) {
        self.command_id = command_id
        self.command = command
        self.application = application
        self.attributes = attributes
        self.debug_logging = debug_logging
        self.locator = locator
        self.path_hint = path_hint
        self.max_elements = max_elements
        self.output_format = output_format
        self.action_name = action_name
        self.action_value = action_value
        self.payload = payload
        self.sub_commands = sub_commands
    }
}

// Matches SimpleSuccessResponse implicitly defined in axorc.swift for ping
struct SimpleSuccessResponse: Codable {
    let command_id: String
    let success: Bool // Assuming true for success responses
    let status: String? // e.g., "pong"
    let message: String
    let details: String?
    let debug_logs: [String]?

    // Adding an explicit init to match how it might be constructed if `success` is always true for this type
    init(command_id: String, success: Bool = true, status: String?, message: String, details: String?,
         debug_logs: [String]?) {
        self.command_id = command_id
        self.success = success
        self.status = status
        self.message = message
        self.details = details
        self.debug_logs = debug_logs
    }
}

// Matches ErrorResponse implicitly defined in axorc.swift
struct ErrorResponse: Codable {
    let command_id: String
    let success: Bool // Assuming false for error responses
    let error: ErrorDetail // Changed from String to ErrorDetail struct

    struct ErrorDetail: Codable { // Nested struct for error message
        let message: String
    }
    let debug_logs: [String]?

    // Custom init if needed, for now relying on synthesized one after struct change
    init(command_id: String, success: Bool = false, error: ErrorDetail, debug_logs: [String]?) {
        self.command_id = command_id
        self.success = success
        self.error = error
        self.debug_logs = debug_logs
    }
}

// For AXElement.attributes which can be [String: Any]
// Using a simplified AnyCodable for testing purposes

struct AXElementData: Codable { // Renamed from AXElement to avoid conflict if AXorcist.AXElement is imported
    let attributes: [String: AnyCodable]? // Dictionary of attributes using AnyCodable from AXorcist module
    let path: [String]? // Optional path from root
    // Add other fields like role, description if they become part of the AXElement structure in axorc output

    // Explicit init to allow nil for attributes and path
    init(attributes: [String: AnyCodable]? = nil, path: [String]? = nil) { // Use direct AnyCodable
        self.attributes = attributes
        self.path = path
    }
}

// Matches QueryResponse implicitly defined in axorc.swift for getFocusedElement
struct QueryResponse: Codable {
    let command_id: String
    let success: Bool
    let command: String // e.g., "getFocusedElement"
    let data: AXElementData? // This will contain the AX element's data
    let error: ErrorDetail? // Changed from String?
    let debug_logs: [String]?
}

// Added for batch command testing
struct BatchOperationResponse: Codable {
    let command_id: String
    let success: Bool
    let results: [QueryResponse] // Assuming batch results are QueryResponses
    let debug_logs: [String]?
}

// MARK: - Test Cases

@Test("Test Ping via STDIN")
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
    let (output, errorOutput, terminationStatus) = try runAXORCCommandWithStdin(
        inputJSON: inputJSON,
        arguments: ["--stdin"]
    )

    #expect(
        terminationStatus == 0,
        "axorc command failed with status \(terminationStatus). Error: \(errorOutput ?? "N/A")"
    )
    #expect(errorOutput == nil || errorOutput!.isEmpty, "Expected no error output, but got: \(errorOutput!)")

    guard let outputString = output else {
        #expect(Bool(false), "Output was nil for ping via STDIN")
        return
    }

    guard let responseData = outputString.data(using: .utf8) else {
        #expect(Bool(false), "Failed to convert output to Data for ping via STDIN. Output: \(outputString)")
        return
    }
    let decodedResponse = try JSONDecoder().decode(SimpleSuccessResponse.self, from: responseData)
    #expect(decodedResponse.success == true)
    #expect(
        decodedResponse.message == "Ping handled by AXORCCommand. Input source: STDIN",
        "Unexpected success message: \(decodedResponse.message)"
    )
    #expect(decodedResponse.details == "Hello from testPingViaStdin")
}

@Test("Test Ping via --file")
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

    // axorc needs --file flag
    let (output, errorOutput, terminationStatus) = try runAXORCCommand(arguments: ["--file", tempFilePath])

    #expect(
        terminationStatus == 0,
        "axorc command failed with status \(terminationStatus). Error: \(errorOutput ?? "N/A")"
    )
    #expect(errorOutput == nil || errorOutput!.isEmpty, "Expected no error output, but got: \(errorOutput ?? "N/A")")

    guard let outputString = output else {
        #expect(Bool(false), "Output was nil for ping via file")
        return
    }
    guard let responseData = outputString.data(using: .utf8) else {
        #expect(Bool(false), "Failed to convert output to Data for ping via file. Output: \(outputString)")
        return
    }
    // Use the updated SimpleSuccessResponse for decoding
    let decodedResponse = try JSONDecoder().decode(SimpleSuccessResponse.self, from: responseData)
    #expect(decodedResponse.success == true)
    #expect(
        decodedResponse.message.lowercased().contains("file: \(tempFilePath.lowercased())"),
        "Message should contain file path. Got: \(decodedResponse.message)"
    )
    #expect(decodedResponse.details == payloadMessage)
}

@Test("Test Ping via direct positional argument")
func testPingViaDirectPayload() async throws {
    let payloadMessage = "Hello from testPingViaDirectPayload"
    // Ensure the JSON string is compact and valid for a command-line argument
    let inputJSON =
        "{\"command_id\":\"test_ping_direct\",\"command\":\"ping\",\"payload\":{\"message\":\"\(payloadMessage)\"}}"

    let (output, errorOutput,
         terminationStatus) = try runAXORCCommand(arguments: [inputJSON]) // No --stdin or --file for direct

    #expect(
        terminationStatus == 0,
        "axorc command failed with status \(terminationStatus). Error: \(errorOutput ?? "N/A")"
    )
    #expect(errorOutput == nil || errorOutput!.isEmpty, "Expected no error output, but got: \(errorOutput ?? "N/A")")

    guard let outputString = output else {
        #expect(Bool(false), "Output was nil for ping via direct payload")
        return
    }
    guard let responseData = outputString.data(using: .utf8) else {
        #expect(Bool(false), "Failed to convert output to Data for ping via direct payload. Output: \(outputString)")
        return
    }
    let decodedResponse = try JSONDecoder().decode(SimpleSuccessResponse.self, from: responseData)
    #expect(decodedResponse.success == true)
    #expect(
        decodedResponse.message.contains("Direct Argument Payload"),
        "Unexpected success message: \(decodedResponse.message)"
    )
    #expect(decodedResponse.details == payloadMessage)
}

@Test("Test Error: Multiple Input Methods (stdin and file)")
func testErrorMultipleInputMethods() async throws {
    let inputJSON = """
    {
        "command_id": "test_error_multiple_inputs",
        "command": "ping",
        "payload": { "message": "This should not be processed" }
    }
    """
    let tempFilePath = try createTempFile(content: "{}") // Empty JSON for file
    defer { try? FileManager.default.removeItem(atPath: tempFilePath) }

    // Pass arguments that trigger multiple inputs, including --stdin for runAXORCCommandWithStdin
    let (output, errorOutput, terminationStatus) = try runAXORCCommandWithStdin(
        inputJSON: inputJSON,
        arguments: ["--file", tempFilePath]
    ) // --stdin is added by the helper

    // axorc.swift now prints error to STDOUT and exits 0
    #expect(
        terminationStatus == 0,
        "axorc command should return 0 with error on stdout. Status: \(terminationStatus). Error STDOUT: \(output ?? "nil"). Error STDERR: \(errorOutput ?? "nil")"
    )

    guard let outputString = output, !outputString.isEmpty else {
        #expect(Bool(false), "Output was nil or empty for multiple input methods error test")
        return
    }
    guard let responseData = outputString.data(using: .utf8) else {
        #expect(
            Bool(false),
            "Failed to convert output to Data for multiple input methods error. Output: \(outputString)"
        )
        return
    }
    // Use the updated ErrorResponse for decoding
    let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: responseData)
    #expect(errorResponse.success == false)
    #expect(
        errorResponse.error.message.contains("Multiple input flags specified"),
        "Unexpected error message: \(errorResponse.error.message)"
    )
}

@Test("Test Error: No Input Provided for Ping")
func testErrorNoInputProvidedForPing() async throws {
    // Run axorc with no input flags or direct payload
    let (output, errorOutput, terminationStatus) = try runAXORCCommand(arguments: [])

    #expect(
        terminationStatus == 0,
        "axorc should return 0 with error on stdout. Status: \(terminationStatus). Error STDOUT: \(output ?? "nil"). Error STDERR: \(errorOutput ?? "nil")"
    )

    guard let outputString = output, !outputString.isEmpty else {
        #expect(Bool(false), "Output was nil or empty for no input test.")
        return
    }
    guard let responseData = outputString.data(using: .utf8) else {
        #expect(Bool(false), "Failed to convert output to Data for no input error. Output: \(outputString)")
        return
    }
    let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: responseData)
    #expect(errorResponse.success == false)
    #expect(
        errorResponse.command_id == "input_error",
        "Expected command_id to be input_error, got \(errorResponse.command_id)"
    )
    #expect(
        errorResponse.error.message.contains("No JSON input method specified"),
        "Unexpected error message for no input: \(errorResponse.error.message)"
    )
}

// The original failing test, now adapted
@Test("Launch TextEdit, Get Focused Element via STDIN")
func testLaunchAndQueryTextEdit() async throws {
    // Close TextEdit if it's running from a previous test
    await closeTextEdit() // Now async and @MainActor
    try await Task.sleep(for: .milliseconds(500)) // Pause after closing

    // Setup TextEdit (launch, activate, ensure window) - this is @MainActor
    let (pid, _) = try await setupTextEditAndGetInfo()
    #expect(pid != 0, "PID should not be zero after TextEdit setup")
    // axAppElement from setupTextEditAndGetInfo is not directly used hereafter, but setup ensures app is ready.

    // Prepare the JSON command for axorc
    let commandId = "focused_textedit_test_\(UUID().uuidString)"
    let attributesToFetch: [String] = [
        ApplicationServices.kAXRoleAttribute as String,
        ApplicationServices.kAXRoleDescriptionAttribute as String,
        ApplicationServices.kAXValueAttribute as String,
        "AXPlaceholderValue" // Custom attribute
    ]

    let commandEnvelope = CommandEnvelope(
        command_id: commandId,
        command: .getFocusedElement,
        application: "com.apple.TextEdit",
        attributes: attributesToFetch,
        debug_logging: true,
        locator: nil, // Explicitly nil if not used for this command, or provide actual locator
        payload: nil // Ensure all params of init are present or defaulted
    )

    let encoder = JSONEncoder()
    let inputJSONData = try encoder.encode(commandEnvelope)
    guard let inputJSON = String(data: inputJSONData, encoding: .utf8) else {
        throw TestError.generic("Failed to encode CommandEnvelope to JSON string")
    }

    print("Input JSON for axorc:\n\(inputJSON)")

    let (output, errorOutput, terminationStatus) = try runAXORCCommandWithStdin(
        inputJSON: inputJSON,
        arguments: ["--debug"]
    )

    print("axorc STDOUT:\n\(output ?? "nil")")
    print("axorc STDERR:\n\(errorOutput ?? "nil")")
    print("axorc Termination Status: \(terminationStatus)")

    #expect(
        terminationStatus == 0,
        "axorc command failed with status \(terminationStatus). Error Output: \(errorOutput ?? "N/A")"
    )

    guard let outputJSONString = output else {
        throw TestError.generic("axorc output was nil or empty for getFocusedElement. STDERR: \(errorOutput ?? "N/A")")
    }

    let decoder = JSONDecoder()
    guard let responseData = outputJSONString.data(using: .utf8) else {
        throw TestError
            .generic("Failed to convert axorc output string to Data for getFocusedElement. Output: \(outputJSONString)")
    }

    let queryResponse: QueryResponse
    do {
        queryResponse = try decoder.decode(QueryResponse.self, from: responseData)
    } catch {
        print("JSON Decoding Error: \(error)")
        print("Problematic JSON string from axorc: \(outputJSONString)") // Print the problematic JSON
        throw TestError
            .generic(
                "Failed to decode QueryResponse from axorc: \(error.localizedDescription). Original JSON: \(outputJSONString)"
            )
    }

    #expect(
        queryResponse.success == true,
        "axorc command was not successful. Error: \(queryResponse.error?.message ?? "Unknown error"). Logs: \(queryResponse.debug_logs?.joined(separator: "\n") ?? "")"
    )
    #expect(queryResponse.command_id == commandId)
    #expect(queryResponse.command == CommandType.getFocusedElement.rawValue) // Compare with rawValue

    guard let elementData = queryResponse.data else {
        throw TestError
            .generic(
                "QueryResponse data is nil. Error: \(queryResponse.error?.message ?? "N/A"). Logs: \(queryResponse.debug_logs?.joined(separator: "\n") ?? "")"
            )
    }

    // Validate attributes (example)
    // Cast kAXTextAreaRole (CFString) to String for comparison
    // Use ApplicationServices for standard AX constants
    let expectedRole = ApplicationServices.kAXTextAreaRole as String
    let actualRole = elementData.attributes?[ApplicationServices.kAXRoleAttribute as String]?.value as? String
    #expect(
        actualRole == expectedRole,
        "Focused element role should be '\(expectedRole)'. Got: '\(actualRole ?? "nil")'. Attributes: \(elementData.attributes?.keys.map { $0 } ?? [])"
    )

    // Use ApplicationServices.kAXValueAttribute and cast to String for key
    #expect(
        elementData.attributes?.keys.contains(ApplicationServices.kAXValueAttribute as String) == true,
        "Focused element attributes should contain kAXValueAttribute as it was requested."
    )

    if let logs = queryResponse.debug_logs, !logs.isEmpty {
        print("axorc Debug Logs:")
        logs.forEach { print($0) }
    }

    // Clean up TextEdit
    await closeTextEdit() // Now async and @MainActor
}

@Test("Get Attributes for TextEdit Application")
@MainActor
func testGetAttributesForTextEditApplication() async throws {
    let commandId = "getattributes-textedit-app-\(UUID().uuidString)"
    let textEditBundleId = "com.apple.TextEdit"
    let requestedAttributes = ["AXRole", "AXTitle", "AXWindows", "AXFocusedWindow", "AXMainWindow", "AXIdentifier"]

    // Ensure TextEdit is running
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

    // For getAttributes on the application itself
    let appLocator = Locator(criteria: [:]) // Empty criteria, or specify if known e.g. ["AXRole": "AXApplication"]

    let commandEnvelope = CommandEnvelope(
        command_id: commandId,
        command: .getAttributes,
        application: textEditBundleId,
        attributes: requestedAttributes,
        debug_logging: true,
        locator: appLocator // Specify the locator for the application
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = .withoutEscapingSlashes
    let jsonData = try encoder.encode(commandEnvelope)
    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
        throw TestError.generic("Failed to create JSON string for getAttributes command.")
    }

    print("Sending getAttributes command to axorc: \(jsonString)")
    let (output, errorOutput, exitCode) = try runAXORCCommand(arguments: [jsonString])

    #expect(exitCode == 0, "axorc process should exit with 0. Error: \(errorOutput ?? "N/A")")
    #expect(errorOutput == nil || errorOutput!.isEmpty, "STDERR should be empty on success. Got: \(errorOutput ?? "")")

    guard let outputString = output, !outputString.isEmpty else {
        throw TestError.generic("Output string was nil or empty for getAttributes.")
    }
    print("Received output from axorc (getAttributes): \(outputString)")

    guard let responseData = outputString.data(using: .utf8) else {
        throw TestError.generic("Could not convert output string to data for getAttributes. Output: \(outputString)")
    }

    let decoder = JSONDecoder()
    do {
        let queryResponse = try decoder.decode(QueryResponse.self, from: responseData)

        #expect(queryResponse.command_id == commandId)
        #expect(
            queryResponse.success == true,
            "getAttributes command should succeed. Error: \(queryResponse.error?.message ?? "None")"
        )
        #expect(queryResponse.command == CommandType.getAttributes.rawValue)
        #expect(queryResponse.error == nil, "Error field should be nil. Got: \(queryResponse.error?.message ?? "N/A")")
        #expect(queryResponse.data != nil, "Data field should not be nil.")
        #expect(queryResponse.data?.attributes != nil, "AXElement attributes should not be nil.")

        // Check some specific attributes
        let attributes = queryResponse.data?.attributes
        #expect(
            attributes?["AXRole"]?.value as? String == "AXApplication",
            "Application role should be AXApplication. Got: \(String(describing: attributes?["AXRole"]?.value))"
        )
        #expect(
            attributes?["AXTitle"]?.value as? String == "TextEdit",
            "Application title should be TextEdit. Got: \(String(describing: attributes?["AXTitle"]?.value))"
        )

        // AXWindows should be an array
        if let windowsAttr = attributes?["AXWindows"] {
            #expect(windowsAttr.value is [Any], "AXWindows should be an array. Type: \(type(of: windowsAttr.value))")
            if let windowsArray = windowsAttr.value as? [AnyCodable] {
                #expect(!windowsArray.isEmpty, "AXWindows array should not be empty if TextEdit has windows.")
            } else if let windowsArray = windowsAttr.value as? [Any] { // More general check
                #expect(!windowsArray.isEmpty, "AXWindows array should not be empty (general type check).")
            }
        } else {
            #expect(attributes?["AXWindows"] != nil, "AXWindows attribute should be present.")
        }

        #expect(queryResponse.debug_logs != nil, "Debug logs should be present.")
        #expect(
            queryResponse.debug_logs?
                .contains {
                    $0.contains("Handling getAttributes command") || $0.contains("handleGetAttributes completed") } ==
                true,
            "Debug logs should indicate getAttributes execution."
        )

    } catch {
        throw TestError
            .generic(
                "Failed to decode QueryResponse for getAttributes: \(error.localizedDescription). Original JSON: \(outputString)"
            )
    }
}

@Test("Query for TextEdit Text Area")
@MainActor
func testQueryForTextEditTextArea() async throws {
    let commandId = "query-textedit-textarea-\(UUID().uuidString)"
    let textEditBundleId = "com.apple.TextEdit"
    // Use kAXTextAreaRole from ApplicationServices for accuracy
    let textAreaRole = ApplicationServices.kAXTextAreaRole as String
    let requestedAttributes = ["AXRole", "AXValue", "AXSelectedText", "AXNumberOfCharacters"]

    // Ensure TextEdit is running and has a window
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

    // Locator to find the first text area in TextEdit
    let textAreaLocator = Locator(
        criteria: ["AXRole": textAreaRole]
    )

    let commandEnvelope = CommandEnvelope(
        command_id: commandId,
        command: .query,
        application: textEditBundleId,
        attributes: requestedAttributes,
        debug_logging: true,
        locator: textAreaLocator
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = .withoutEscapingSlashes
    let jsonData = try encoder.encode(commandEnvelope)
    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
        throw TestError.generic("Failed to create JSON string for query command.")
    }

    print("Sending query command to axorc: \(jsonString)")
    let (output, errorOutput, exitCode) = try runAXORCCommand(arguments: [jsonString])

    #expect(exitCode == 0, "axorc process should exit with 0. Error: \(errorOutput ?? "N/A")")
    #expect(errorOutput == nil || errorOutput!.isEmpty, "STDERR should be empty on success. Got: \(errorOutput ?? "")")

    guard let outputString = output, !outputString.isEmpty else {
        throw TestError.generic("Output string was nil or empty for query.")
    }
    print("Received output from axorc (query): \(outputString)")

    guard let responseData = outputString.data(using: .utf8) else {
        throw TestError.generic("Could not convert output string to data for query. Output: \(outputString)")
    }

    let decoder = JSONDecoder()
    do {
        let queryResponse = try decoder.decode(QueryResponse.self, from: responseData)

        #expect(queryResponse.command_id == commandId)
        #expect(
            queryResponse.success == true,
            "query command should succeed. Error: \(queryResponse.error?.message ?? "None")"
        )
        #expect(queryResponse.command == CommandType.query.rawValue)
        #expect(queryResponse.error == nil, "Error field should be nil. Got: \(queryResponse.error?.message ?? "N/A")")
        #expect(queryResponse.data != nil, "Data field should not be nil.")
        #expect(queryResponse.data?.attributes != nil, "AXElement attributes should not be nil.")

        let attributes = queryResponse.data?.attributes
        #expect(
            attributes?["AXRole"]?.value as? String == textAreaRole,
            "Element role should be \(textAreaRole). Got: \(String(describing: attributes?["AXRole"]?.value))"
        )

        // AXValue might be an empty string if the new document is empty, which is fine.
        #expect(attributes?["AXValue"]?.value is String, "AXValue should exist and be a string.")
        #expect(attributes?["AXNumberOfCharacters"]?.value is Int, "AXNumberOfCharacters should exist and be an Int.")

        #expect(queryResponse.debug_logs != nil, "Debug logs should be present.")
        #expect(
            queryResponse.debug_logs?
                .contains { $0.contains("Handling query command") || $0.contains("handleQuery completed") } == true,
            "Debug logs should indicate query execution."
        )

    } catch {
        throw TestError
            .generic(
                "Failed to decode QueryResponse for query: \(error.localizedDescription). Original JSON: \(outputString)"
            )
    }
}

@Test("Describe TextEdit Text Area")
@MainActor
func testDescribeTextEditTextArea() async throws {
    let commandId = "describe-textedit-textarea-\(UUID().uuidString)"
    let textEditBundleId = "com.apple.TextEdit"
    let textAreaRole = ApplicationServices.kAXTextAreaRole as String

    // Ensure TextEdit is running and has a window
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

    // Locator to find the first text area in TextEdit
    let textAreaLocator = Locator(
        criteria: ["AXRole": textAreaRole]
    )

    let commandEnvelope = CommandEnvelope(
        command_id: commandId,
        command: .describeElement,
        application: textEditBundleId,
        // No attributes explicitly requested for describeElement
        debug_logging: true,
        locator: textAreaLocator
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = .withoutEscapingSlashes
    let jsonData = try encoder.encode(commandEnvelope)
    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
        throw TestError.generic("Failed to create JSON string for describeElement command.")
    }

    print("Sending describeElement command to axorc: \(jsonString)")
    let (output, errorOutput, exitCode) = try runAXORCCommand(arguments: [jsonString])

    #expect(exitCode == 0, "axorc process should exit with 0. Error: \(errorOutput ?? "N/A")")
    #expect(errorOutput == nil || errorOutput!.isEmpty, "STDERR should be empty on success. Got: \(errorOutput ?? "")")

    guard let outputString = output, !outputString.isEmpty else {
        throw TestError.generic("Output string was nil or empty for describeElement.")
    }
    print("Received output from axorc (describeElement): \(outputString)")

    guard let responseData = outputString.data(using: .utf8) else {
        throw TestError.generic("Could not convert output string to data for describeElement. Output: \(outputString)")
    }

    let decoder = JSONDecoder()
    do {
        let queryResponse = try decoder.decode(QueryResponse.self, from: responseData)

        #expect(queryResponse.command_id == commandId)
        #expect(
            queryResponse.success == true,
            "describeElement command should succeed. Error: \(queryResponse.error?.message ?? "None")"
        )
        #expect(queryResponse.command == CommandType.describeElement.rawValue)
        #expect(queryResponse.error == nil, "Error field should be nil. Got: \(queryResponse.error?.message ?? "N/A")")
        #expect(queryResponse.data != nil, "Data field should not be nil.")

        guard let attributes = queryResponse.data?.attributes else {
            throw TestError.generic("Attributes dictionary is nil in describeElement response.")
        }

        #expect(
            attributes["AXRole"]?.value as? String == textAreaRole,
            "Element role should be \(textAreaRole). Got: \(String(describing: attributes["AXRole"]?.value))"
        )

        // describeElement should return many attributes. Check for a few common ones.
        #expect(attributes["AXRoleDescription"]?.value is String, "AXRoleDescription should exist.")
        #expect(attributes["AXEnabled"]?.value is Bool, "AXEnabled should exist.")
        #expect(attributes["AXPosition"]?.value != nil,
                "AXPosition should exist.") // Value can be complex (e.g., AXValue containing a CGPoint)
        #expect(attributes["AXSize"]?.value != nil,
                "AXSize should exist.") // Value can be complex (e.g., AXValue containing a CGSize)
        #expect(
            attributes.count > 10,
            "Expected describeElement to return many attributes (e.g., > 10). Got \(attributes.count)"
        )

        #expect(queryResponse.debug_logs != nil, "Debug logs should be present.")
        #expect(
            queryResponse.debug_logs?
                .contains {
                    $0.contains("Handling describeElement command") || $0.contains("handleDescribeElement completed")
                } ==
                true,
            "Debug logs should indicate describeElement execution."
        )

    } catch {
        throw TestError
            .generic(
                "Failed to decode QueryResponse for describeElement: \(error.localizedDescription). Original JSON: \(outputString)"
            )
    }
}

@Test("Perform Action: Set Value of TextEdit Text Area")
@MainActor
func testPerformActionSetTextEditTextAreaValue() async throws {
    let actionCommandId = "performaction-setvalue-\(UUID().uuidString)"
    let queryCommandId = "query-verify-setvalue-\(UUID().uuidString)"
    let textEditBundleId = "com.apple.TextEdit"
    let textAreaRole = ApplicationServices.kAXTextAreaRole as String
    let textToSet = "Hello from AXORC performAction test! Time: \(Date())"

    // Ensure TextEdit is running and has a window
    do {
        _ = try await setupTextEditAndGetInfo()
        print("TextEdit setup completed for performAction test.")
    } catch {
        throw TestError.generic("TextEdit setup failed for performAction: \(error.localizedDescription)")
    }
    defer {
        Task { await closeTextEdit() }
        print("TextEdit close process initiated for performAction test.")
    }

    // Locator for the text area
    let textAreaLocator = Locator(
        criteria: ["AXRole": textAreaRole]
    )

    // 1. Perform AXSetValueAction
    let performActionEnvelope = CommandEnvelope(
        command_id: actionCommandId,
        command: .performAction,
        application: textEditBundleId,
        debug_logging: true,
        locator: textAreaLocator,
        action_name: "AXSetValue", // Standard action for setting value
        action_value: AnyCodable(textToSet) // AXorcist.AnyCodable wrapping the string
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = .withoutEscapingSlashes
    var jsonData = try encoder.encode(performActionEnvelope)
    guard var jsonString = String(data: jsonData, encoding: .utf8) else {
        throw TestError.generic("Failed to create JSON for performAction command.")
    }

    print("Sending performAction (AXSetValue) command: \(jsonString)")
    var (output, errorOutput, exitCode) = try runAXORCCommand(arguments: [jsonString])

    #expect(exitCode == 0, "performAction axorc call failed. Error: \(errorOutput ?? "N/A")")
    #expect(
        errorOutput == nil || errorOutput!.isEmpty,
        "STDERR for performAction should be empty. Got: \(errorOutput ?? "")"
    )

    guard let actionOutputString = output, !actionOutputString.isEmpty else {
        throw TestError.generic("Output for performAction was nil/empty.")
    }
    print("Received output from performAction: \(actionOutputString)")
    guard let actionResponseData = actionOutputString.data(using: .utf8) else {
        throw TestError.generic("Could not convert performAction output to data. Output: \(actionOutputString)")
    }

    let decoder = JSONDecoder()
    do {
        let actionResponse = try decoder
            .decode(QueryResponse.self, from: actionResponseData) // performAction returns a QueryResponse
        #expect(actionResponse.command_id == actionCommandId)
        #expect(
            actionResponse.success == true,
            "performAction command was not successful. Error: \(actionResponse.error?.message ?? "N/A")"
        )
        // Some actions might not return data, but AXSetValue might confirm the element it acted upon.
        // For now, primary check is success.
    } catch {
        throw TestError
            .generic(
                "Failed to decode QueryResponse for performAction: \(error.localizedDescription). JSON: \(actionOutputString)"
            )
    }

    // Brief pause for UI to update if necessary, though AXSetValue is often synchronous.
    try await Task.sleep(for: .milliseconds(100))

    // 2. Query the AXValue to verify
    let queryEnvelope = CommandEnvelope(
        command_id: queryCommandId,
        command: .query,
        application: textEditBundleId,
        attributes: ["AXValue"], // Only need AXValue
        debug_logging: true,
        locator: textAreaLocator
    )

    jsonData = try encoder.encode(queryEnvelope)
    guard let queryJsonString = String(data: jsonData, encoding: .utf8) else {
        throw TestError.generic("Failed to create JSON for query (verify) command.")
    }

    print("Sending query (to verify AXSetValue) command: \(queryJsonString)")
    (output, errorOutput, exitCode) = try runAXORCCommand(arguments: [queryJsonString])

    #expect(exitCode == 0, "Query (verify) axorc call failed. Error: \(errorOutput ?? "N/A")")
    #expect(
        errorOutput == nil || errorOutput!.isEmpty,
        "STDERR for query (verify) should be empty. Got: \(errorOutput ?? "")"
    )

    guard let queryOutputString = output, !queryOutputString.isEmpty else {
        throw TestError.generic("Output for query (verify) was nil/empty.")
    }
    print("Received output from query (verify): \(queryOutputString)")
    guard let queryResponseData = queryOutputString.data(using: .utf8) else {
        throw TestError.generic("Could not convert query (verify) output to data. Output: \(queryOutputString)")
    }

    do {
        let verifyResponse = try decoder.decode(QueryResponse.self, from: queryResponseData)
        #expect(verifyResponse.command_id == queryCommandId)
        #expect(
            verifyResponse.success == true,
            "Query (verify) command failed. Error: \(verifyResponse.error?.message ?? "N/A")"
        )

        guard let attributes = verifyResponse.data?.attributes else {
            throw TestError.generic("Attributes nil in query (verify) response.")
        }
        let retrievedValue = attributes["AXValue"]?.value as? String
        #expect(
            retrievedValue == textToSet,
            "AXValue after AXSetValue action did not match. Expected: '\(textToSet)'. Got: '\(retrievedValue ?? "nil")'"
        )

        #expect(verifyResponse.debug_logs != nil)
    } catch {
        throw TestError
            .generic(
                "Failed to decode QueryResponse for query (verify): \(error.localizedDescription). JSON: \(queryOutputString)"
            )
    }
}

@Test("Extract Text from TextEdit Text Area")
@MainActor
func testExtractTextFromTextEditTextArea() async throws {
    let setValueCommandId = "setvalue-for-extract-\(UUID().uuidString)"
    let extractTextCommandId = "extracttext-textedit-textarea-\(UUID().uuidString)"
    let textEditBundleId = "com.apple.TextEdit"
    let textAreaRole = ApplicationServices.kAXTextAreaRole as String
    let textToSetAndExtract = "Text to be extracted by AXORC. Unique: \(UUID().uuidString)"

    // Ensure TextEdit is running and has a window
    do {
        _ = try await setupTextEditAndGetInfo()
        print("TextEdit setup completed for extractText test.")
    } catch {
        throw TestError.generic("TextEdit setup failed for extractText: \(error.localizedDescription)")
    }
    defer {
        Task { await closeTextEdit() }
        print("TextEdit close process initiated for extractText test.")
    }

    // Locator for the text area
    let textAreaLocator = Locator(
        criteria: ["AXRole": textAreaRole]
    )

    // 1. Set a known value in the text area using performAction
    let performActionEnvelope = CommandEnvelope(
        command_id: setValueCommandId,
        command: .performAction,
        application: textEditBundleId,
        debug_logging: true,
        locator: textAreaLocator,
        action_name: "AXSetValue",
        action_value: AnyCodable(textToSetAndExtract)
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = .withoutEscapingSlashes
    var jsonData = try encoder.encode(performActionEnvelope)
    guard var jsonString = String(data: jsonData, encoding: .utf8) else {
        throw TestError.generic("Failed to create JSON for performAction (set value) command.")
    }

    print("Sending performAction (AXSetValue) for extractText setup: \(jsonString)")
    var (output, errorOutput, exitCode) = try runAXORCCommand(arguments: [jsonString])

    #expect(exitCode == 0, "performAction (set value) call failed. Error: \(errorOutput ?? "N/A")")
    guard let actionOutputString = output,
          !actionOutputString.isEmpty
    else { throw TestError.generic("Output for performAction (set value) was nil/empty.") }
    let actionResponse = try JSONDecoder().decode(QueryResponse.self, from: Data(actionOutputString.utf8))
    #expect(
        actionResponse.success == true,
        "performAction (set value) was not successful. Error: \(actionResponse.error?.message ?? "N/A")"
    )

    try await Task.sleep(for: .milliseconds(100)) // Brief pause

    // 2. Perform extractText command
    let extractTextEnvelope = CommandEnvelope(
        command_id: extractTextCommandId,
        command: .extractText,
        application: textEditBundleId,
        debug_logging: true,
        locator: textAreaLocator
    )

    jsonData = try encoder.encode(extractTextEnvelope)
    guard let extractJsonString = String(data: jsonData, encoding: .utf8) else {
        throw TestError.generic("Failed to create JSON for extractText command.")
    }

    print("Sending extractText command: \(extractJsonString)")
    (output, errorOutput, exitCode) = try runAXORCCommand(arguments: [extractJsonString])

    #expect(exitCode == 0, "extractText axorc call failed. Error: \(errorOutput ?? "N/A")")
    #expect(
        errorOutput == nil || errorOutput!.isEmpty,
        "STDERR for extractText should be empty. Got: \(errorOutput ?? "")"
    )

    guard let extractOutputString = output, !extractOutputString.isEmpty else {
        throw TestError.generic("Output for extractText was nil/empty.")
    }
    print("Received output from extractText: \(extractOutputString)")
    guard let extractResponseData = extractOutputString.data(using: .utf8) else {
        throw TestError.generic("Could not convert extractText output to data. Output: \(extractOutputString)")
    }

    let decoder = JSONDecoder()
    do {
        let extractQueryResponse = try decoder.decode(QueryResponse.self, from: extractResponseData)
        #expect(extractQueryResponse.command_id == extractTextCommandId)
        #expect(
            extractQueryResponse.success == true,
            "extractText command failed. Error: \(extractQueryResponse.error?.message ?? "N/A")"
        )
        #expect(extractQueryResponse.command == CommandType.extractText.rawValue)

        guard let attributes = extractQueryResponse.data?.attributes else {
            throw TestError.generic("Attributes nil in extractText response.")
        }

        // AXorcist.handleExtractText is expected to return the text.
        // The most straightforward way for it to appear in QueryResponse is via an attribute in `data.attributes`.
        // Common attribute for text content is AXValue. Let's assume extractText populates this or a specific "ExtractedText" attribute.
        // For now, checking AXValue as it's the most standard for text areas.
        let extractedValue = attributes["AXValue"]?.value as? String
        #expect(
            extractedValue == textToSetAndExtract,
            "Extracted text did not match set text. Expected: '\(textToSetAndExtract)'. Got: '\(extractedValue ?? "nil")'"
        )

        #expect(extractQueryResponse.debug_logs != nil)
        #expect(
            extractQueryResponse.debug_logs?
                .contains { $0.contains("Handling extractText command") || $0.contains("handleExtractText completed")
                } ==
                true,
            "Debug logs should indicate extractText execution."
        )

    } catch {
        throw TestError
            .generic(
                "Failed to decode QueryResponse for extractText: \(error.localizedDescription). JSON: \(extractOutputString)"
            )
    }
}

@Test("Batch Command: GetFocusedElement and Query TextEdit")
@MainActor
func testBatchCommand_GetFocusedElementAndQuery() async throws {
    let batchCommandId = "batch-textedit-\(UUID().uuidString)"
    let focusedElementSubCmdId = "batch-sub-getfocused-\(UUID().uuidString)"
    let querySubCmdId = "batch-sub-querytextarea-\(UUID().uuidString)"
    let textEditBundleId = "com.apple.TextEdit"
    let textAreaRole = ApplicationServices.kAXTextAreaRole as String

    // Ensure TextEdit is running and has a window
    do {
        _ = try await setupTextEditAndGetInfo()
        print("TextEdit setup completed for batch command test.")
    } catch {
        throw TestError.generic("TextEdit setup failed for batch command: \(error.localizedDescription)")
    }
    defer {
        Task { await closeTextEdit() }
        print("TextEdit close process initiated for batch command test.")
    }

    // Sub-command 1: Get Focused Element
    let getFocusedElementSubCommand = CommandEnvelope(
        command_id: focusedElementSubCmdId,
        command: .getFocusedElement,
        application: textEditBundleId,
        debug_logging: true
    )

    // Sub-command 2: Query for Text Area
    let queryTextAreaSubCommandLocator = Locator(criteria: ["AXRole": textAreaRole])
    let queryTextAreaSubCommand = CommandEnvelope(
        command_id: querySubCmdId,
        command: .query,
        application: textEditBundleId,
        attributes: ["AXRole", "AXValue"], // Request some attributes for the text area
        debug_logging: true,
        locator: queryTextAreaSubCommandLocator
    )

    // Main Batch Command
    let batchCommandEnvelope = CommandEnvelope(
        command_id: batchCommandId,
        command: .batch,
        application: nil, // Application context is per sub-command if needed
        debug_logging: true,
        sub_commands: [getFocusedElementSubCommand, queryTextAreaSubCommand]
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted // Easier to debug JSON if needed
    let jsonData = try encoder.encode(batchCommandEnvelope)
    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
        throw TestError.generic("Failed to create JSON string for batch command.")
    }

    print("Sending batch command to axorc: \(jsonString)")
    let (output, errorOutput, exitCode) = try runAXORCCommand(arguments: [jsonString])

    #expect(exitCode == 0, "axorc process for batch command should exit with 0. Error: \(errorOutput ?? "N/A")")
    #expect(
        errorOutput == nil || errorOutput!.isEmpty,
        "STDERR for batch command should be empty on success. Got: \(errorOutput ?? "")"
    )

    guard let outputString = output, !outputString.isEmpty else {
        throw TestError.generic("Output string was nil or empty for batch command.")
    }
    print("Received output from axorc (batch command): \(outputString)")

    guard let responseData = outputString.data(using: .utf8) else {
        throw TestError.generic("Could not convert output string to data for batch command. Output: \(outputString)")
    }

    let decoder = JSONDecoder()
    do {
        let batchResponse = try decoder.decode(BatchOperationResponse.self, from: responseData)

        #expect(batchResponse.command_id == batchCommandId)
        #expect(
            batchResponse.success == true,
            "Batch command overall should succeed. Error: \(batchResponse.results.first(where: { !$0.success })?.error?.message ?? "None")"
        )
        #expect(
            batchResponse.results.count == 2,
            "Expected 2 results in batch response, got \(batchResponse.results.count)"
        )

        // Check first sub-command result (getFocusedElement)
        let result1 = batchResponse.results[0]
        #expect(result1.command_id == focusedElementSubCmdId)
        #expect(
            result1.success == true,
            "Sub-command getFocusedElement failed. Error: \(result1.error?.message ?? "N/A")"
        )
        #expect(result1.command == CommandType.getFocusedElement.rawValue)
        #expect(result1.data != nil, "Data for getFocusedElement should not be nil")
        #expect(
            result1.data?.attributes?["AXRole"]?.value as? String == textAreaRole,
            "Focused element (from batch) should be text area. Got \(String(describing: result1.data?.attributes?["AXRole"]?.value))"
        )

        // Check second sub-command result (query for text area)
        let result2 = batchResponse.results[1]
        #expect(result2.command_id == querySubCmdId)
        #expect(
            result2.success == true,
            "Sub-command query text area failed. Error: \(result2.error?.message ?? "N/A")"
        )
        #expect(result2.command == CommandType.query.rawValue)
        #expect(result2.data != nil, "Data for query text area should not be nil")
        #expect(
            result2.data?.attributes?["AXRole"]?.value as? String == textAreaRole,
            "Queried element (from batch) should be text area. Got \(String(describing: result2.data?.attributes?["AXRole"]?.value))"
        )

        #expect(batchResponse.debug_logs != nil, "Batch response debug logs should be present.")
        #expect(
            batchResponse.debug_logs?
                .contains { $0.contains("Executing batch command") || $0.contains("Batch command processing completed")
                } == true,
            "Debug logs should indicate batch execution."
        )

    } catch {
        throw TestError
            .generic(
                "Failed to decode BatchOperationResponse: \(error.localizedDescription). Original JSON: \(outputString)"
            )
    }
}

// TestError enum definition
enum TestError: Error, CustomStringConvertible {
    case appNotRunning(String)
    case axError(String)
    case appleScriptError(String)
    case generic(String)

    var description: String {
        switch self {
        case .appNotRunning(let s): return "AppNotRunning: \(s)"
        case .axError(let s): return "AXError: \(s)"
        case .appleScriptError(let s): return "AppleScriptError: \(s)"
        case .generic(let s): return "GenericTestError: \(s)"
        }
    }
}

// Products directory helper (if not already present from previous steps)
var productsDirectory: URL {
    #if os(macOS)
        // First, try the .xctest bundle method (works well in Xcode)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }

        // Fallback for SPM command-line tests if .xctest bundle isn't found as expected.
        // This navigates up from the test file to the package root, then to .build/debug.
        let currentFileURL = URL(fileURLWithPath: #filePath)
        // Assuming Tests/AXorcistTests/AXorcistIntegrationTests.swift structure:
        // currentFileURL.deletingLastPathComponent() // AXorcistTests directory
        //   .deletingLastPathComponent() // Tests directory
        //   .deletingLastPathComponent() // AXorcist package root directory
        let packageRootPath = currentFileURL.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()

        // Try common build paths for SwiftPM
        let buildPathsToTry = [
            packageRootPath.appendingPathComponent(".build/debug"),
            packageRootPath.appendingPathComponent(".build/arm64-apple-macosx/debug"),
            packageRootPath.appendingPathComponent(".build/x86_64-apple-macosx/debug")
        ]

        let fileManager = FileManager.default
        for path in buildPathsToTry {
            // Check if the directory exists and contains the axorc executable
            if fileManager.fileExists(atPath: path.appendingPathComponent("axorc").path) {
                return path
            }
        }

        fatalError(
            "couldn\'t find the products directory via Bundle or SPM fallback. Package root guessed as: \(packageRootPath.path). Searched paths: \(buildPathsToTry.map { $0.path }.joined(separator: ", "))"
        )
    #else
        return Bundle.main.bundleURL
    #endif
}
