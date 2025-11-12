@preconcurrency import AppKit
import Testing
@testable import AXorcist

extension Tag {
    @Tag static var safe: Self
    @Tag static var automation: Self
}

@preconcurrency
enum AXTestEnvironment {
    @inline(__always)
    @preconcurrency nonisolated static func flag(_ key: String) -> Bool {
        ProcessInfo.processInfo.environment[key]?.lowercased() == "true"
    }

    @preconcurrency nonisolated(unsafe) static var runAutomationScenarios: Bool {
        flag("RUN_AUTOMATION_TESTS") || flag("RUN_LOCAL_TESTS")
    }
}


// Result struct for AXORC commands
struct CommandResult {
    let output: String?
    let errorOutput: String?
    let exitCode: Int32
}

// MARK: - Test Helpers

func setupTextEditAndGetInfo() async throws -> (pid: pid_t, axAppElement: AXUIElement?) {
    let runningApp = try await ensureTextEditRunning()
    let pid = runningApp.processIdentifier
    let axAppElement = AXUIElementCreateApplication(pid)
    try await ensureWindowExists(for: runningApp, axAppElement: axAppElement)
    logFocusedElement(axAppElement: axAppElement)
    return (pid, axAppElement)
}

private func ensureTextEditRunning() async throws -> NSRunningApplication {
    let textEditBundleId = "com.apple.TextEdit"
    if let app = NSRunningApplication.runningApplications(withBundleIdentifier: textEditBundleId).first {
        return app
    }

    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: textEditBundleId) else {
        throw TestError.generic("Could not find URL for TextEdit application.")
    }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false

    do {
        let launchedApp = try await withCheckedThrowingContinuation { continuation in
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { runningApp, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let runningApp {
                    continuation.resume(returning: runningApp)
                } else {
                    continuation.resume(
                        throwing: TestError.appNotRunning(
                            "openApplication completion returned nil without error."
                        )
                    )
                }
            }
        }
        return try await waitForTextEdit(launchedApp: launchedApp)
    } catch {
        throw TestError.appNotRunning(
            "Failed to launch TextEdit using openApplication: \(error.localizedDescription)"
        )
    }
}

@MainActor
private func waitForTextEdit(launchedApp: NSRunningApplication) async throws -> NSRunningApplication {
    let textEditBundleId = "com.apple.TextEdit"
    for attempt in 1 ... 10 {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: textEditBundleId).first {
            print("TextEdit found running after launch, attempt \(attempt)")
            return running
        }
        try await Task.sleep(for: .milliseconds(500))
        print("Waiting for TextEdit to appear in running list... attempt \(attempt)")
    }
    throw TestError.appNotRunning("TextEdit did not appear in running applications list after launch attempt.")
}

@MainActor
private func ensureWindowExists(for app: NSRunningApplication, axAppElement: AXUIElement) async throws {
    try await activate(app)
    if try await axWindowCount(for: axAppElement) == 0 {
        try await createNewDocument()
    }
    try await activate(app)
}

@MainActor
private func activate(_ app: NSRunningApplication) async throws {
    guard !app.isActive else { return }
    app.activate(options: [.activateAllWindows])
    try await Task.sleep(for: .seconds(1))
}

@MainActor
private func axWindowCount(for appElement: AXUIElement) async throws -> Int {
    var window: AnyObject?
    let result = AXUIElementCopyAttributeValue(
        appElement,
        ApplicationServices.kAXWindowsAttribute as CFString,
        &window
    )
    guard result == AXError.success else { return 0 }
    return (window as? [AXUIElement])?.count ?? 0
}

@MainActor
private func createNewDocument() async throws {
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
        try await Task.sleep(for: .seconds(2))
    }
}

@MainActor
private func logFocusedElement(axAppElement: AXUIElement) {
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
}

@MainActor
func closeTextEdit() async {
    let textEditBundleId = "com.apple.TextEdit"
    guard let textEdit = NSRunningApplication.runningApplications(withBundleIdentifier: textEditBundleId).first else {
        return
    }

    textEdit.terminate()
    for _ in 0 ..< 5 {
        if textEdit.isTerminated { break }
        try? await Task.sleep(for: .milliseconds(500))
    }

    if !textEdit.isTerminated {
        textEdit.forceTerminate()
        try? await Task.sleep(for: .milliseconds(500))
    }
}

func runAXORCCommand(arguments: [String]) throws -> CommandResult {
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

    let output = String(data: outputData, encoding: String.Encoding.utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let errorOutput = String(data: errorData, encoding: String.Encoding.utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)

    let cleanOutput = stripJSONPrefix(from: output)

    return CommandResult(output: cleanOutput, errorOutput: errorOutput, exitCode: process.terminationStatus)
}

func createTempFile(content: String) throws -> String {
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = UUID().uuidString + ".json"
    let fileURL = tempDir.appendingPathComponent(fileName)
    try content.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
    return fileURL.path
}

func stripJSONPrefix(from output: String?) -> String? {
    guard let output else { return nil }
    let prefix = "AXORC_JSON_OUTPUT_PREFIX:::"
    if output.hasPrefix(prefix) {
        return String(output.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return output
}

func runAXORCCommandWithStdin(inputJSON: String, arguments: [String]) throws -> CommandResult {
    let axorcUrl = productsDirectory.appendingPathComponent("axorc")

    let process = Process()
    process.executableURL = axorcUrl
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

    if let inputData = inputJSON.data(using: String.Encoding.utf8) {
        try inputPipe.fileHandleForWriting.write(contentsOf: inputData)
        inputPipe.fileHandleForWriting.closeFile()
    } else {
        inputPipe.fileHandleForWriting.closeFile()
        print("Warning: Could not convert inputJSON to Data for STDIN.")
    }

    process.waitUntilExit()

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

    let output = String(data: outputData, encoding: String.Encoding.utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let errorOutput = String(data: errorData, encoding: String.Encoding.utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)

    let cleanOutput = stripJSONPrefix(from: output)

    return CommandResult(output: cleanOutput, errorOutput: errorOutput, exitCode: process.terminationStatus)
}

// MARK: - Test Models

enum CommandType: String, Codable {
    case ping
    case getFocusedElement
    case collectAll, query, describeElement, getAttributes, performAction, extractText, batch
}

struct CommandEnvelope: Codable {
    // MARK: Lifecycle

    init(commandId: String,
         command: CommandType,
         application: String? = nil,
         attributes: [String]? = nil,
         debugLogging: Bool? = nil,
         locator: Locator? = nil,
         pathHint: [String]? = nil,
         maxElements: Int? = nil,
         outputFormat: OutputFormat? = nil,
         actionName: String? = nil,
         actionValue: AttributeValue? = nil,
         payload: [String: AttributeValue]? = nil,
         subCommands: [CommandEnvelope]? = nil)
    {
        self.commandId = commandId
        self.command = command
        self.application = application
        self.attributes = attributes
        self.debugLogging = debugLogging
        self.locator = locator
        self.pathHint = pathHint
        self.maxElements = maxElements
        self.outputFormat = outputFormat
        self.actionName = actionName
        self.actionValue = actionValue
        self.payload = payload
        self.subCommands = subCommands
    }

    // MARK: Internal

    enum CodingKeys: String, CodingKey {
        case commandId = "command_id"
        case command
        case application
        case attributes
        case debugLogging = "debug_logging"
        case locator
        case pathHint = "path_hint"
        case maxElements = "max_elements"
        case outputFormat = "output_format"
        case actionName = "action_name"
        case actionValue = "action_value"
        case payload
        case subCommands = "sub_commands"
    }

    let commandId: String
    let command: CommandType
    let application: String?
    let attributes: [String]?
    let debugLogging: Bool?
    let locator: Locator?
    let pathHint: [String]?
    let maxElements: Int?
    let outputFormat: OutputFormat?
    let actionName: String?
    let actionValue: AttributeValue?
    let payload: [String: AttributeValue]?
    let subCommands: [CommandEnvelope]?
}

struct SimpleSuccessResponse: Codable {
    // MARK: Lifecycle

    init(commandId: String,
         success: Bool = true,
         status: String?,
         message: String,
         details: String?,
         debugLogs: [String]?)
    {
        self.commandId = commandId
        self.success = success
        self.status = status
        self.message = message
        self.details = details
        self.debugLogs = debugLogs
    }

    // MARK: Internal

    enum CodingKeys: String, CodingKey {
        case commandId = "command_id"
        case success
        case status
        case message
        case details
        case debugLogs = "debug_logs"
    }

    let commandId: String
    let success: Bool
    let status: String?
    let message: String
    let details: String?
    let debugLogs: [String]?
}

struct ErrorResponse: Codable {
    // MARK: Lifecycle

    init(commandId: String, success: Bool = false, error: ErrorDetail, debugLogs: [String]?) {
        self.commandId = commandId
        self.success = success
        self.error = error
        self.debugLogs = debugLogs
    }

    // MARK: Internal

    struct ErrorDetail: Codable {
        let message: String
    }

    enum CodingKeys: String, CodingKey {
        case commandId = "command_id"
        case success
        case error
        case debugLogs = "debug_logs"
    }

    let commandId: String
    let success: Bool
    let error: ErrorDetail

    let debugLogs: [String]?
}

struct AXElementData: Codable {
    // MARK: Lifecycle

    init(attributes: [String: AttributeValue]? = nil, path: [String]? = nil) {
        self.attributes = attributes
        self.path = path
    }

    // MARK: Internal

    let attributes: [String: AttributeValue]?
    let path: [String]?
}

struct QueryResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case commandId = "command_id"
        case success
        case command
        case data
        case error
        case debugLogs = "debug_logs"
    }

    let commandId: String
    let success: Bool
    let command: String
    let data: AXElementData?
    let error: ErrorResponse.ErrorDetail?
    let debugLogs: [String]?
}

struct BatchOperationResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case commandId = "command_id"
        case success
        case results
        case debugLogs = "debug_logs"
    }

    let commandId: String
    let success: Bool
    let results: [QueryResponse]
    let debugLogs: [String]?
}

// MARK: - Error Types

enum TestError: Error, CustomStringConvertible {
    case appNotRunning(String)
    case axError(String)
    case appleScriptError(String)
    case generic(String)

    // MARK: Internal

    var description: String {
        switch self {
        case let .appNotRunning(string): "AppNotRunning: \(string)"
        case let .axError(string): "AXError: \(string)"
        case let .appleScriptError(string): "AppleScriptError: \(string)"
        case let .generic(string): "GenericTestError: \(string)"
        }
    }
}

// MARK: - Helper Properties

var productsDirectory: URL {
    #if os(macOS)
    for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
        return bundle.bundleURL.deletingLastPathComponent()
    }

    let currentFileURL = URL(fileURLWithPath: #filePath)
    let packageRootPath = currentFileURL.deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()

    let buildPathsToTry = [
        packageRootPath.appendingPathComponent(".build/debug"),
        packageRootPath.appendingPathComponent(".build/arm64-apple-macosx/debug"),
        packageRootPath.appendingPathComponent(".build/x86_64-apple-macosx/debug"),
    ]

    let fileManager = FileManager.default
    for path in buildPathsToTry where fileManager.fileExists(atPath: path.appendingPathComponent("axorc").path) {
        return path
    }

    let searchedPaths = buildPathsToTry.map(\.path).joined(separator: ", ")
    fatalError(
        "couldn't find the products directory via Bundle or SPM fallback. " +
            "Package root guessed as: \(packageRootPath.path). " +
            "Searched paths: \(searchedPaths)"
    )
    #else
    return Bundle.main.bundleURL
    #endif
}
