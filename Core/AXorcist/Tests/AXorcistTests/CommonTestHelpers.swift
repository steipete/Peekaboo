@preconcurrency import AppKit
@testable import AXorcist
import XCTest


// Result struct for AXORC commands
struct CommandResult {
    let output: String?
    let errorOutput: String?
    let exitCode: Int32
}

// MARK: - Test Helpers

func setupTextEditAndGetInfo() async throws -> (pid: pid_t, axAppElement: AXUIElement?) {
    let textEditBundleId = "com.apple.TextEdit"
    var app: NSRunningApplication? = NSRunningApplication.runningApplications(withBundleIdentifier: textEditBundleId)
        .first

    if app == nil {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: textEditBundleId) else {
            throw TestError.generic("Could not find URL for TextEdit application.")
        }

        print("Attempting to launch TextEdit from URL: \(url.path)")
        let configuration: [NSWorkspace.LaunchConfigurationKey: Any] = [:]
        do {
            app = try NSWorkspace.shared.launchApplication(at: url,
                                                           options: [.async, .withoutActivation],
                                                           configuration: configuration)
            print("launchApplication call completed. App PID if returned: \(app?.processIdentifier ?? -1)")
        } catch {
            throw TestError
                .appNotRunning(
                    "Failed to launch TextEdit using launchApplication(at:options:configuration:): " +
                        "\(error.localizedDescription)"
                )
        }

        var launchedApp: NSRunningApplication?
        for attempt in 1 ... 10 {
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
        app = runningAppAfterLaunch
    }

    guard let runningApp = app else {
        throw TestError.appNotRunning("TextEdit is unexpectedly nil before activation checks.")
    }

    let pid = runningApp.processIdentifier
    let axAppElement = AXUIElementCreateApplication(pid)

    if !runningApp.isActive {
        runningApp.activate(options: [.activateAllWindows])
        try await Task.sleep(for: .seconds(1.5))
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
            try await Task.sleep(for: .seconds(2))
        }
    }

    if !runningApp.isActive {
        runningApp.activate(options: [.activateAllWindows])
        try await Task.sleep(for: .seconds(1))
    }

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
         actionValue: AnyCodable? = nil,
         payload: [String: AnyCodable]? = nil,
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
    let actionValue: AnyCodable?
    let payload: [String: AnyCodable]?
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

    init(attributes: [String: AnyCodable]? = nil, path: [String]? = nil) {
        self.attributes = attributes
        self.path = path
    }

    // MARK: Internal

    let attributes: [String: AnyCodable]?
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
