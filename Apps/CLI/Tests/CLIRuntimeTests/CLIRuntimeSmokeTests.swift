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
        let payload = !result.standardOutput.isEmpty ? result.standardOutput : result.standardError
        let data = Data(payload.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any],
              let error = json["error"] as? [String: Any] else {
            Issue.record("Expected JSON parse-error output from list windows.")
            return
        }
        #expect(json["success"] as? Bool == false)
        #expect(error["code"] as? String == "INVALID_ARGUMENT")
        #expect((error["message"] as? String)?.contains("Missing argument: app") == true)
    }

    @Test
    func `peekaboo sleep executes via Commander`() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo(["sleep", "1", "--no-remote"])
        #expect(result.status == .exited(0))
        #expect(result.standardOutput.contains("Paused"))
    }

    @Test
    func `peekaboo parse errors honor JSON mode`() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo(["sleep", "1", "--bogus", "--json", "--no-remote"])
        #expect(result.status == .exited(1))

        let payload = !result.standardOutput.isEmpty ? result.standardOutput : result.standardError
        let data = Data(payload.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any],
              let error = json["error"] as? [String: Any] else {
            Issue.record("Expected JSON parse-error output.")
            return
        }

        #expect(json["success"] as? Bool == false)
        #expect(error["code"] as? String == "INVALID_ARGUMENT")
        #expect((error["message"] as? String)?.contains("Unknown option --bogus") == true)
    }

    @Test
    func `peekaboo tools emits standard JSON envelope`() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo(["tools", "--json", "--no-remote"])
        #expect(result.status == .exited(0))

        let data = Data(result.standardOutput.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any] else {
            Issue.record("Expected JSON object output from tools command.")
            return
        }

        #expect(json["success"] as? Bool == true)
        let dataPayload = json["data"] as? [String: Any]
        #expect((dataPayload?["tools"] as? [[String: Any]])?.isEmpty == false)
        #expect((dataPayload?["count"] as? Int ?? 0) > 0)
    }

    @Test
    func `peekaboo config show effective emits only JSON in JSON mode`() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo([
            "config",
            "show",
            "--effective",
            "--json",
            "--no-remote",
        ])
        #expect(result.status == .exited(0))

        let data = Data(result.standardOutput.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any] else {
            Issue.record("Expected JSON object output from config show --effective.")
            return
        }

        #expect(json["success"] as? Bool == true)
        #expect(json["data"] is [String: Any])
        #expect(json["debug_logs"] is [Any])
        #expect(result.standardOutput.contains("Providers:") == false)
    }

    @Test
    func `peekaboo config errors emit standard JSON envelope`() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo([
            "config",
            "add-provider",
            "bad id",
            "--type",
            "openai",
            "--name",
            "Bad",
            "--base-url",
            "https://example.com",
            "--api-key",
            "dummy",
            "--json",
            "--no-remote",
        ])
        #expect(result.status == .exited(1))

        let data = Data(result.standardOutput.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any],
              let error = json["error"] as? [String: Any] else {
            Issue.record("Expected JSON object output from config error.")
            return
        }

        #expect(json["success"] as? Bool == false)
        #expect(error["code"] as? String == "INVALID_ID")
        #expect(json["debug_logs"] is [Any])
    }

    @Test
    func `peekaboo list menubar emits standard JSON envelope`() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo(["list", "menubar", "--json", "--no-remote"])

        let data = Data(result.standardOutput.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any] else {
            Issue.record("Expected JSON object output from list menubar command.")
            return
        }

        if result.status != .exited(0) {
            #expect(json["success"] as? Bool == false)
            return
        }

        #expect(json["success"] as? Bool == true)
        let dataPayload = json["data"] as? [String: Any]
        #expect(dataPayload?["items"] is [[String: Any]])
        #expect(dataPayload?["count"] as? Int == (dataPayload?["items"] as? [[String: Any]])?.count)
    }

    @Test
    func `peekaboo list permissions emits standard JSON envelope`() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo(["list", "permissions", "--json", "--no-remote"])
        #expect(result.status == .exited(0))

        let data = Data(result.standardOutput.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any] else {
            Issue.record("Expected JSON object output from list permissions command.")
            return
        }

        #expect(json["success"] as? Bool == true)
        let dataPayload = json["data"] as? [String: Any]
        #expect(dataPayload?["permissions"] is [[String: Any]])
    }

    @Test
    func `peekaboo dialog list emits structured JSON success or error`() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let result = try await TestChildProcess.runPeekaboo(["dialog", "list", "--json", "--no-remote"])

        let payload = !result.standardOutput.isEmpty ? result.standardOutput : result.standardError
        let data = Data(payload.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any],
              let success = json["success"] as? Bool else {
            Issue.record("Expected JSON object output from dialog list command.")
            return
        }

        if success {
            #expect(result.status == .exited(0))
            #expect(json["data"] is [String: Any])
        } else {
            #expect(result.status != .exited(0))
            let error = json["error"] as? [String: Any]
            #expect((error?["code"] as? String)?.isEmpty == false)
        }
    }

    @Test
    func `peekaboo clipboard get JSON includes exact text`() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let text = "Peekaboo exact clipboard text \(UUID().uuidString)"

        try await Self.withSavedClipboard {
            let setResult = try await TestChildProcess.runPeekaboo([
                "clipboard",
                "--action",
                "set",
                "--text",
                text,
                "--json",
                "--no-remote"
            ])
            #expect(setResult.status == .exited(0))

            let getResult = try await TestChildProcess.runPeekaboo([
                "clipboard",
                "--action",
                "get",
                "--json",
                "--no-remote"
            ])
            #expect(getResult.status == .exited(0))
            let payload = try Self.jsonDataPayload(from: getResult.standardOutput)
            #expect(payload["text"] as? String == text)
            #expect(payload["textPreview"] as? String == text)

            let stdoutJSONResult = try await TestChildProcess.runPeekaboo([
                "clipboard",
                "--action",
                "get",
                "--output",
                "-",
                "--json",
                "--no-remote"
            ])
            #expect(stdoutJSONResult.status == .exited(0))
            let stdoutJSONPayload = try Self.jsonDataPayload(from: stdoutJSONResult.standardOutput)
            #expect(stdoutJSONPayload["text"] as? String == text)

            let stdoutResult = try await TestChildProcess.runPeekaboo([
                "clipboard",
                "--action",
                "get",
                "--output",
                "-",
                "--no-remote"
            ])
            #expect(stdoutResult.status == .exited(0))
            #expect(stdoutResult.standardOutput == text)
        }
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

    @Test
    func `peekaboo visualizer fails fast when visual feedback is disabled`() async throws {
        guard Self.ensureLocalRuntimeAvailable() else { return }
        let startTime = Date()
        let result = try await TestChildProcess.runPeekaboo(
            ["visualizer", "--json", "--no-remote"],
            environment: ["PEEKABOO_VISUAL_FEEDBACK": "false"]
        )
        let duration = Date().timeIntervalSince(startTime)

        let payload = !result.standardOutput.isEmpty ? result.standardOutput : result.standardError
        let data = Data(payload.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any] else {
            Issue.record("Expected JSON object output from visualizer command.")
            return
        }

        #expect(json["success"] as? Bool == false)
        #expect(result.status == .exited(1))
        #expect(duration < 1.0)
    }

    private static func withSavedClipboard(_ body: () async throws -> Void) async throws {
        let slot = "cli-runtime-smoke-\(UUID().uuidString)"
        let saveResult = try await TestChildProcess.runPeekaboo([
            "clipboard",
            "--action",
            "save",
            "--slot",
            slot,
            "--json",
            "--no-remote"
        ])

        guard saveResult.status == .exited(0) else {
            Issue.record("Unable to save current clipboard before smoke test; skipping clipboard mutation check.")
            return
        }

        do {
            try await body()
            _ = try await TestChildProcess.runPeekaboo([
                "clipboard",
                "--action",
                "restore",
                "--slot",
                slot,
                "--json",
                "--no-remote"
            ])
        } catch {
            _ = try? await TestChildProcess.runPeekaboo([
                "clipboard",
                "--action",
                "restore",
                "--slot",
                slot,
                "--json",
                "--no-remote"
            ])
            throw error
        }
    }

    private static func jsonDataPayload(from output: String) throws -> [String: Any] {
        let data = Data(output.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let json = object as? [String: Any],
              json["success"] as? Bool == true,
              let payload = json["data"] as? [String: Any] else {
            Issue.record("Expected successful JSON envelope.")
            return [:]
        }
        return payload
    }
}
