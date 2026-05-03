import AppKit
import Foundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
private enum HotkeyBackgroundDeliveryIntegrationConfig {
    @preconcurrency
    nonisolated static func enabled() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["RUN_LOCAL_TESTS"] == "true" &&
            !(environment["PEEKABOO_CLI_PATH"] ?? "").isEmpty
    }
}

@Suite(
    .serialized,
    .tags(.automation, .localOnly, .requiresDisplay, .requiresPermissions),
    .enabled(if: HotkeyBackgroundDeliveryIntegrationConfig.enabled())
)
struct HotkeyBackgroundDeliveryIntegrationTests {
    @Test
    @MainActor
    func `background hotkey reaches inactive target process`() async throws {
        let tempDirectory = try self.createTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let probe = try self.buildProbe(scratchDirectory: tempDirectory.appendingPathComponent("build"))
        let logURL = tempDirectory.appendingPathComponent("events.jsonl")
        let readyURL = tempDirectory.appendingPathComponent("ready.json")

        let process = Process()
        process.executableURL = probe
        process.environment = ProcessInfo.processInfo.environment.merging([
            "PEEKABOO_HOTKEY_PROBE_LOG": logURL.path,
            "PEEKABOO_HOTKEY_PROBE_READY": readyURL.path,
        ]) { _, new in new }
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        defer {
            if process.isRunning {
                process.terminate()
            }
            process.waitUntilExit()
        }

        try await self.waitForFile(readyURL, process: process)
        try await self.activateFinder()

        try Data().write(to: logURL)

        var environment = ProcessInfo.processInfo.environment
        environment["PEEKABOO_NO_REMOTE"] = "1"
        let result = try ExternalCommandRunner.runPeekabooCLI(
            [
                "hotkey",
                "cmd,l",
                "--pid", "\(process.processIdentifier)",
                "--focus-background",
                "--no-remote",
                "--json",
            ],
            allowedExitCodes: [0, 1],
            environment: environment
        )

        if result.exitStatus != 0 {
            let error = try? ExternalCommandRunner.decodeJSONResponse(from: result, as: JSONResponse.self)
            if error?.error?.code == ErrorCode.PERMISSION_ERROR_EVENT_SYNTHESIZING.rawValue {
                Issue.record("Event Synthesizing permission is required for background hotkey delivery.")
                return
            }
            Issue.record("Background hotkey command failed: \(result.combinedOutput)")
            return
        }

        let events = try await self.waitForKeyEvents(in: logURL)
        let keyDown = try #require(events.first { $0.type == "keyDown" })
        let keyUp = try #require(events.first { $0.type == "keyUp" })

        #expect(keyDown.pid == process.processIdentifier)
        #expect(keyDown.keyCode == 0x25)
        #expect(keyDown.charactersIgnoringModifiers == "l")
        #expect(keyDown.modifierFlags & NSEvent.ModifierFlags.command.rawValue != 0)
        #expect(!keyDown.isActive)

        #expect(keyUp.pid == process.processIdentifier)
        #expect(keyUp.keyCode == 0x25)
        #expect(keyUp.modifierFlags & NSEvent.ModifierFlags.command.rawValue != 0)
        #expect(!keyUp.isActive)
    }

    private func buildProbe(scratchDirectory: URL) throws -> URL {
        let fixtureRoot = Self.repositoryRootURL()
            .appendingPathComponent("Apps/CLI/TestFixtures/BackgroundHotkeyProbe")
        try FileManager.default.createDirectory(at: scratchDirectory, withIntermediateDirectories: true)

        let build = try self.runProcess(
            executable: "/usr/bin/swift",
            arguments: [
                "build",
                "--package-path", fixtureRoot.path,
                "--scratch-path", scratchDirectory.path,
            ]
        )
        try build.validateExitStatus(allowedExitCodes: [0], arguments: ["swift", "build"])

        let binPath = try self.runProcess(
            executable: "/usr/bin/swift",
            arguments: [
                "build",
                "--package-path", fixtureRoot.path,
                "--scratch-path", scratchDirectory.path,
                "--show-bin-path",
            ]
        )
        try binPath.validateExitStatus(allowedExitCodes: [0], arguments: ["swift", "build", "--show-bin-path"])

        let executable = URL(fileURLWithPath: binPath.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
            .appendingPathComponent("BackgroundHotkeyProbe")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw ProbeTestError.executableMissing(executable.path)
        }
        return executable
    }

    private func runProcess(executable: String, arguments: [String]) throws -> CommandRunResult {
        let process = Process()
        process.currentDirectoryURL = Self.repositoryRootURL()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return CommandRunResult(stdout: stdout, stderr: stderr, exitStatus: process.terminationStatus)
    }

    private func createTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("peekaboo-background-hotkey-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func activateFinder() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Finder"]
        try process.run()
        process.waitUntilExit()
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    private func waitForFile(_ url: URL, process: Process, timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) {
                return
            }
            if !process.isRunning {
                throw ProbeTestError.processExitedBeforeReady(process.terminationStatus)
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw ProbeTestError.timeout("Timed out waiting for \(url.path)")
    }

    private func waitForKeyEvents(in logURL: URL, timeout: TimeInterval = 3) async throws -> [ProbeEvent] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let events = try self.readEvents(from: logURL)
            if events.contains(where: { $0.type == "keyDown" }) &&
                events.contains(where: { $0.type == "keyUp" }) {
                return events
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw ProbeTestError.timeout("Timed out waiting for background hotkey events in \(logURL.path)")
    }

    private func readEvents(from logURL: URL) throws -> [ProbeEvent] {
        guard FileManager.default.fileExists(atPath: logURL.path) else {
            return []
        }
        let contents = try String(contentsOf: logURL, encoding: .utf8)
        return contents.split(separator: "\n").compactMap { line in
            try? JSONDecoder().decode(ProbeEvent.self, from: Data(line.utf8))
        }
    }

    private static func repositoryRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 {
            url.deleteLastPathComponent()
        }
        return url
    }
}

private struct ProbeEvent: Decodable {
    let pid: Int32
    let isActive: Bool
    let type: String
    let keyCode: UInt16
    let modifierFlags: UInt
    let charactersIgnoringModifiers: String
}

private enum ProbeTestError: Error, CustomStringConvertible {
    case executableMissing(String)
    case processExitedBeforeReady(Int32)
    case timeout(String)

    var description: String {
        switch self {
        case let .executableMissing(path):
            "Expected probe executable at \(path)"
        case let .processExitedBeforeReady(status):
            "BackgroundHotkeyProbe exited before it was ready with status \(status)"
        case let .timeout(message):
            message
        }
    }
}
#endif
