import Foundation
import Subprocess
import Testing

enum CLIRuntimeEnvironment {
    static var shouldRunSmokeTests: Bool {
        ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != nil &&
            TestChildProcess.canLocatePeekabooBinary()
    }
}

struct CLIRuntimeSmokeTests {
    @discardableResult
    private static func ensureLocalRuntimeAvailable() -> Bool {
        if TestChildProcess.canLocatePeekabooBinary() {
            return true
        }
        Issue.record("Build peekaboo (or set PEEKABOO_CLI_BINARY) before running CLI runtime smoke tests.")
        return false
    }

    @Test
    func `peekaboo list apps emits JSON via Commander`() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo(["list", "apps", "--json", "--no-remote"])

        if result.status == .exited(0) {
            #expect(result.standardOutput.contains("\"applications\""))
            return
        }

        // Local smoke runs may surface expected permission failures.
        let payload = !result.standardOutput.isEmpty ? result.standardOutput : result.standardError
        let data = Data(payload.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any],
              let success = json["success"] as? Bool,
              success == false,
              let error = json["error"] as? [String: Any],
              let code = error["code"] as? String else {
            Issue.record("Expected successful app list JSON or structured permission error JSON.")
            return
        }
        #expect(code == "PERMISSION_ERROR_SCREEN_RECORDING")
    }

    @Test
    func `peekaboo list windows requires --app`() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo(["list", "windows", "--json", "--no-remote"])
        #expect(result.status != .exited(0))
        #expect(result.standardError.contains("Missing argument: app"))
    }

    @Test
    func `peekaboo sleep executes via Commander`() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo(["sleep", "1", "--no-remote"])
        #expect(result.status == .exited(0))
        #expect(result.standardOutput.contains("Paused"))
    }

    @Test
    func `peekaboo mcp help renders without starting server`() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo(["mcp", "--help"])
        #expect(result.status == .exited(0))
        #expect(result.standardOutput.contains("Start Peekaboo as an MCP server"))
    }

    @Test
    func `peekaboo agent warns when no provider credentials exist`() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo([
            "agent",
            "list files",
            "--dry-run"
        ], environment: ["PEEKABOO_DISABLE_AGENT": "1", "PEEKABOO_NO_REMOTE": "1"])
        #expect(result.status == .exited(0))
        #expect(result.standardOutput.contains("Agent service not available"))
    }

    @Test
    func `peekaboo learn prints comprehensive guide`() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo(["learn", "--no-remote"])
        #expect(result.status == .exited(0))
        #expect(result.standardOutput.contains("# Peekaboo Comprehensive Guide"))
        #expect(result.standardOutput.contains("## Commander Command Signatures"))
    }

    @Test
    func `peekaboo visualizer emits JSON (success or error)`() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo(["visualizer", "--json", "--no-remote"])

        let payload = !result.standardOutput.isEmpty ? result.standardOutput : result.standardError
        #expect(!payload.isEmpty)

        let data = Data(payload.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any] else {
            Issue.record("Expected JSON object output from visualizer command.")
            return
        }

        guard let success = json["success"] as? Bool else {
            Issue.record("Visualizer JSON output missing 'success' field.")
            return
        }

        let exitedSuccessfully = result.status == .exited(0)
        #expect(exitedSuccessfully == success)
    }
}
