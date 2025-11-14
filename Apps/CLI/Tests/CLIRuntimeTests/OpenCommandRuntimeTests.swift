import AppKit
#if canImport(AppKit)
import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite("OpenCommand Runtime Tests")
@MainActor
struct OpenCommandRuntimeTests {
    @Test("open command produces JSON with default handler")
    func openCommandJSONOutput() async throws {
        let launcher = RuntimeStubLauncher()
        launcher.openResponses = [RuntimeStubRunningApplication(localizedName: "Safari", bundleIdentifier: "com.apple.Safari")]
        let resolver = RuntimeStubResolver()

        let originalLauncher = OpenCommand.launcher
        let originalResolver = OpenCommand.resolver
        OpenCommand.launcher = launcher
        OpenCommand.resolver = resolver
        defer {
            OpenCommand.launcher = originalLauncher
            OpenCommand.resolver = originalResolver
        }

        let result = try await TestCommandRunner.run(["open", "https://example.com", "--json-output"])
        let json = try parseJSON(from: result.stdout)
        #expect(json["success"] as? Bool == true)
        let data = json["data"] as? [String: Any]
        #expect(data?["target"] as? String == "https://example.com")
        #expect(data?["handler_app"] as? String == "Safari")
        #expect(launcher.openCalls.count == 1)
    }
}

@Suite("AppCommand Runtime Tests")
@MainActor
struct AppCommandRuntimeTests {
    @Test("app launch with --open uses stub launcher")
    func appLaunchWithOpenDocuments() async throws {
        let launcher = RuntimeStubLauncher()
        launcher.launchWithDocsResponses = [
            RuntimeStubRunningApplication(localizedName: "Preview", bundleIdentifier: "com.apple.Preview")
        ]
        let resolver = RuntimeStubResolver()
        resolver.applicationMap["Preview"] = URL(fileURLWithPath: "/Applications/Preview.app")

        let originalLauncher = AppCommand.LaunchSubcommand.launcher
        let originalResolver = AppCommand.LaunchSubcommand.resolver
        AppCommand.LaunchSubcommand.launcher = launcher
        AppCommand.LaunchSubcommand.resolver = resolver
        defer {
            AppCommand.LaunchSubcommand.launcher = originalLauncher
            AppCommand.LaunchSubcommand.resolver = originalResolver
        }

        let result = try await TestCommandRunner.run([
            "app", "launch", "Preview",
            "--open", "~/Desktop/file1.pdf",
            "--open", "https://example.com",
            "--no-focus",
            "--json-output"
        ])

        let json = try parseJSON(from: result.stdout)
        #expect(json["success"] as? Bool == true)
        let data = json["data"] as? [String: Any]
        #expect(data?["app_name"] as? String == "Preview")
        let call = try #require(launcher.launchWithDocsCalls.first)
        #expect(call.activates == false)
        #expect(call.documents.count == 2)
    }
}

// MARK: - Helpers

private enum RuntimeTestError: Error {
    case invalidJSON
}

private func parseJSON(from string: String) throws -> [String: Any] {
    let data = Data(string.utf8)
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw RuntimeTestError.invalidJSON
    }
    return json
}

@MainActor
private final class RuntimeStubRunningApplication: RunningApplicationHandle {
    var localizedName: String?
    var bundleIdentifier: String?
    var processIdentifier: Int32
    private var finishedLaunching = false
    private(set) var isActiveState: Bool

    init(localizedName: String?, bundleIdentifier: String?, pid: Int32 = 1234, startActive: Bool = false) {
        self.localizedName = localizedName
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = pid
        self.isActiveState = startActive
    }

    var isFinishedLaunching: Bool {
        if !self.finishedLaunching {
            self.finishedLaunching = true
            return true
        }
        return true
    }

    var isActive: Bool { self.isActiveState }

    @discardableResult
    func activate(options _: NSApplication.ActivationOptions) -> Bool {
        self.isActiveState = true
        return true
    }
}

@MainActor
private final class RuntimeStubLauncher: ApplicationLaunching {
    struct LaunchCall {
        let appURL: URL
        let activates: Bool
    }

    struct LaunchWithDocsCall {
        let appURL: URL
        let documents: [URL]
        let activates: Bool
    }

    struct OpenCall {
        let target: URL
        let handler: URL?
        let activates: Bool
    }

    var launchCalls: [LaunchCall] = []
    var launchWithDocsCalls: [LaunchWithDocsCall] = []
    var openCalls: [OpenCall] = []
    var launchResponses: [RuntimeStubRunningApplication] = []
    var launchWithDocsResponses: [RuntimeStubRunningApplication] = []
    var openResponses: [RuntimeStubRunningApplication] = []

    func launchApplication(at url: URL, activates: Bool) async throws -> any RunningApplicationHandle {
        self.launchCalls.append(.init(appURL: url, activates: activates))
        if !self.launchResponses.isEmpty {
            return self.launchResponses.removeFirst()
        }
        return RuntimeStubRunningApplication(localizedName: url.lastPathComponent, bundleIdentifier: nil)
    }

    func launchApplication(
        _ url: URL,
        opening documents: [URL],
        activates: Bool
    ) async throws -> any RunningApplicationHandle {
        self.launchWithDocsCalls.append(.init(appURL: url, documents: documents, activates: activates))
        if !self.launchWithDocsResponses.isEmpty {
            return self.launchWithDocsResponses.removeFirst()
        }
        return RuntimeStubRunningApplication(localizedName: url.lastPathComponent, bundleIdentifier: nil)
    }

    func openTarget(
        _ targetURL: URL,
        handlerURL: URL?,
        activates: Bool
    ) async throws -> any RunningApplicationHandle {
        self.openCalls.append(.init(target: targetURL, handler: handlerURL, activates: activates))
        if !self.openResponses.isEmpty {
            return self.openResponses.removeFirst()
        }
        return RuntimeStubRunningApplication(localizedName: handlerURL?.lastPathComponent, bundleIdentifier: handlerURL?.lastPathComponent)
    }
}

@MainActor
private final class RuntimeStubResolver: ApplicationURLResolving {
    var applicationMap: [String: URL] = [:]
    var bundleMap: [String: URL] = [:]

    func resolveApplication(appIdentifier: String, bundleId: String?) throws -> URL {
        if let bundleId, let url = self.bundleMap[bundleId] {
            return url
        }
        if let url = self.applicationMap[appIdentifier] {
            return url
        }
        throw NotFoundError.application(appIdentifier)
    }

    func resolveBundleIdentifier(_ bundleId: String) throws -> URL {
        if let url = self.bundleMap[bundleId] {
            return url
        }
        throw NotFoundError.application("Bundle ID: \(bundleId)")
    }
}

// MARK: - Local command runner

struct CommandRunResult {
    let stdout: String
    let stderr: String
    let exitStatus: Int32

    var combinedOutput: String {
        self.stdout.isEmpty ? self.stderr : self.stdout
    }
}

@MainActor
enum TestCommandRunner {
    static func run(_ arguments: [String]) async throws -> CommandRunResult {
        try await self.captureOutput {
            let (status, stdoutData, stderrData) = try await self.redirectOutput {
                await executePeekabooCLI(arguments: ["peekaboo"] + arguments)
            }

            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""

            return CommandRunResult(stdout: stdout, stderr: stderr, exitStatus: status)
        }
    }

    private static func captureOutput(
        _ operation: () async throws -> CommandRunResult
    ) async throws -> CommandRunResult {
        try await operation()
    }

    private static func redirectOutput(
        _ body: () async throws -> Int32
    ) async throws -> (Int32, Data, Data) {
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        let originalStdout = dup(STDOUT_FILENO)
        let originalStderr = dup(STDERR_FILENO)

        dup2(stdoutPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        dup2(stderrPipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)

        stdoutPipe.fileHandleForWriting.closeFile()
        stderrPipe.fileHandleForWriting.closeFile()

        do {
            let status = try await body()
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            stdoutPipe.fileHandleForReading.closeFile()
            stderrPipe.fileHandleForReading.closeFile()
            dup2(originalStdout, STDOUT_FILENO)
            dup2(originalStderr, STDERR_FILENO)
            close(originalStdout)
            close(originalStderr)
            return (status, stdoutData, stderrData)
        } catch {
            _ = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            _ = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            stdoutPipe.fileHandleForReading.closeFile()
            stderrPipe.fileHandleForReading.closeFile()
            dup2(originalStdout, STDOUT_FILENO)
            dup2(originalStderr, STDERR_FILENO)
            close(originalStdout)
            close(originalStderr)
            throw error
        }
    }
}
#endif
