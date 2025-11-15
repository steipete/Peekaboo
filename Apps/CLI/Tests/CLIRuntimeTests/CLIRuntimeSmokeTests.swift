import Foundation
import Subprocess
import Testing

enum CLIRuntimeEnvironment {
    static var shouldRunSmokeTests: Bool {
        ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != nil &&
            TestChildProcess.canLocatePeekabooBinary()
    }
}

@Suite("CLI Runtime via swift-subprocess")
struct CLIRuntimeSmokeTests {
    @discardableResult
    private static func ensureLocalRuntimeAvailable() -> Bool {
        if TestChildProcess.canLocatePeekabooBinary() {
            return true
        }
        Issue.record("Build peekaboo (or set PEEKABOO_CLI_BINARY) before running CLI runtime smoke tests.")
        return false
    }

    @Test("peekaboo list apps emits JSON via Commander")
    func commanderListApps() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo(["list", "apps", "--json-output"])
        #expect(result.status == .exited(0))
        #expect(result.standardOutput.contains("\"applications\""))
    }

    @Test("peekaboo list windows requires --app")
    func listWindowsWithoutAppFails() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo(["list", "windows", "--json-output"])
        #expect(result.status != .exited(0))
        #expect(result.standardError.contains("Missing argument: app"))
    }

    @Test("peekaboo sleep executes via Commander")
    func commanderSleep() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo(["sleep", "1"])
        #expect(result.status == .exited(0))
        #expect(result.standardOutput.contains("Paused"))
    }

    @Test("peekaboo mcp without subcommand errors via Commander")
    func commanderMcpMissingSubcommand() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo(["mcp"])
        #expect(result.status != .exited(0))
        #expect(result.standardError.contains("requires a subcommand"))
    }

    @Test("peekaboo mcp add requires a command payload")
    func commanderMcpAddRequiresCommand() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo([
            "mcp",
            "add",
            "demo",
            "--transport",
            "stdio"
        ])
        #expect(result.status != .exited(0))
        #expect(result.standardError.contains("Command is required"))
    }

    @Test("peekaboo agent warns when no provider credentials exist")
    func commanderAgentMissingCredentials() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo([
            "agent",
            "list files",
            "--dry-run"
        ], environment: ["PEEKABOO_DISABLE_AGENT": "1"])
        #expect(result.status == .exited(0))
        #expect(result.standardOutput.contains("Agent service not available"))
    }

    @Test("peekaboo learn prints comprehensive guide")
    func commanderLearnGuide() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo(["learn"])
        #expect(result.status == .exited(0))
        #expect(result.standardOutput.contains("# Peekaboo Comprehensive Guide"))
        #expect(result.standardOutput.contains("## Commander Command Signatures"))
    }
}
