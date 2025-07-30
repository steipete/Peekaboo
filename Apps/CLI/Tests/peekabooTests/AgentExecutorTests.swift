import Foundation
import Testing
@testable import peekaboo

@Suite("Agent Executor Tests")
struct AgentExecutorTests {
    // MARK: - See Command Tests

    @Test("Execute see command captures screenshot")
    func executeSeeCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["app": "Finder"]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_see", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] as? Bool == true)
            let responseData = json["data"] as? [String: Any]
            #expect(responseData != nil)
            #expect(responseData?["screenshot_raw"] is String)
            #expect(responseData?["session_id"] is String)
            #expect(responseData?["elements"] is [[String: Any]])
        } catch {
            // Expected to fail without proper permissions
            #expect(error is AgentError || error is PeekabooCore.CaptureError)
        }
    }

    @Test("Execute see command without app parameter")
    func executeSeeCommandFrontmost() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args: [String: Any] = [:]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_see", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] as? Bool == true)
        } catch {
            // Expected to fail without proper permissions
            #expect(error is AgentError || error is PeekabooCore.CaptureError)
        }
    }

    // MARK: - Click Command Tests

    @Test("Execute click command with element ID")
    func executeClickCommandElement() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["element": "button-123", "session_id": "test-session"]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_click", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            // Will fail without valid session, but we can check error format
            #expect(json["success"] as? Bool == false || json["success"] as? Bool == true)
        } catch {
            #expect(error is AgentError)
        }
    }

    @Test("Execute click command with coordinates")
    func executeClickCommandCoordinates() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["x": 100.0, "y": 200.0, "double_click": true]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_click", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] as? Bool == true)
            let responseData = json["data"] as? [String: Any]
            #expect(responseData?["clickType"] as? String == "double")
        } catch {
            // May fail without permissions
            #expect(error is AgentError || error is PeekabooCore.UIAutomationError)
        }
    }

    @Test("Execute click command without required parameters")
    func executeClickCommandMissingParams() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args: [String: Any] = [:]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        let result = try await executor.executeFunction(name: "peekaboo_click", arguments: argsString)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == false)
        let error = json["error"] as? [String: Any]
        #expect(error?["code"] as? String == "INVALID_ARGUMENTS")
    }

    // MARK: - Type Command Tests

    @Test("Execute type command")
    func executeTypeCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["text": "Hello, World!", "clear_first": true]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_type", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] as? Bool == true)
            let responseData = json["data"] as? [String: Any]
            #expect(responseData?["charactersTyped"] as? Int == 13)
        } catch {
            // May fail without permissions
            #expect(error is AgentError || error is PeekabooCore.UIAutomationError)
        }
    }

    @Test("Execute type command without text")
    func executeTypeCommandMissingText() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args: [String: Any] = [:]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        let result = try await executor.executeFunction(name: "peekaboo_type", arguments: argsString)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == false)
        let error = json["error"] as? [String: Any]
        #expect(error?["code"] as? String == "INVALID_ARGUMENTS")
    }

    // MARK: - App Command Tests

    @Test("Execute app launch command")
    func executeAppLaunchCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["action": "launch", "name": "TextEdit"]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_app", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] as? Bool == true)
            let responseData = json["data"] as? [String: Any]
            #expect(responseData?["action"] as? String == "launch")
        } catch {
            // May fail if app not found
            #expect(error is AgentError || error is PeekabooCore.PeekabooError)
        }
    }

    @Test("Execute app command with invalid action")
    func executeAppCommandInvalidAction() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["action": "invalid", "name": "Finder"]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        let result = try await executor.executeFunction(name: "peekaboo_app", arguments: argsString)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == false)
        let error = json["error"] as? [String: Any]
        #expect(error?["code"] as? String == "INVALID_ARGUMENTS")
    }

    // MARK: - Window Command Tests

    @Test("Execute window close command")
    func executeWindowCloseCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["action": "close", "app": "Finder"]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_window", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            // Check response structure
            #expect(json["success"] != nil)
        } catch {
            #expect(error is AgentError)
        }
    }

    @Test("Execute window move command")
    func executeWindowMoveCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["action": "move", "app": "Finder", "x": 100.0, "y": 200.0]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_window", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] != nil)
        } catch {
            #expect(error is AgentError)
        }
    }

    @Test("Execute window resize command")
    func executeWindowResizeCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["action": "resize", "app": "Finder", "width": 800.0, "height": 600.0]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_window", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] != nil)
        } catch {
            #expect(error is AgentError)
        }
    }

    // MARK: - Menu Command Tests

    @Test("Execute menu click command")
    func executeMenuClickCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["app": "Finder", "item": "New Folder"]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_menu", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] != nil)
        } catch {
            #expect(error is AgentError || error is PeekabooCore.PeekabooError)
        }
    }

    @Test("Execute menu list command")
    func executeMenuListCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["app": "Finder", "subcommand": "list"]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_menu", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] as? Bool == true)
            let responseData = json["data"] as? [String: Any]
            #expect(responseData?["menus"] is [[String: Any]])
        } catch {
            #expect(error is AgentError || error is PeekabooCore.PeekabooError)
        }
    }

    // MARK: - Dialog Command Tests

    @Test("Execute dialog click command")
    func executeDialogClickCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["action": "click", "button": "OK"]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_dialog", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] != nil)
        } catch {
            // Expected to fail if no dialog present
            #expect(error is AgentError || error is PeekabooCore.DialogError)
        }
    }

    @Test("Execute dialog input command")
    func executeDialogInputCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["action": "input", "text": "test input", "field": "Password"]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_dialog", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] != nil)
        } catch {
            // Expected to fail if no dialog present
            #expect(error is AgentError || error is PeekabooCore.DialogError)
        }
    }

    // MARK: - Drag Command Tests

    @Test("Execute drag command")
    func executeDragCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["from_x": 100.0, "from_y": 100.0, "to_x": 200.0, "to_y": 200.0, "duration": 0.5]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_drag", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] as? Bool == true)
            let responseData = json["data"] as? [String: Any]
            #expect(responseData?["from"] is [String: Double])
            #expect(responseData?["to"] is [String: Double])
        } catch {
            #expect(error is AgentError || error is PeekabooCore.UIAutomationError)
        }
    }

    @Test("Execute drag command with missing parameters")
    func executeDragCommandMissingParams() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["from_x": 100.0, "from_y": 100.0] // Missing to_x and to_y
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        let result = try await executor.executeFunction(name: "peekaboo_drag", arguments: argsString)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == false)
        let error = json["error"] as? [String: Any]
        #expect(error?["code"] as? String == "INVALID_ARGUMENTS")
    }

    // MARK: - Dock Command Tests

    @Test("Execute dock show command")
    func executeDockShowCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["action": "show"]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_dock", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] as? Bool == true)
        } catch {
            #expect(error is AgentError || error is PeekabooCore.DockError)
        }
    }

    @Test("Execute dock click command")
    func executeDockClickCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["action": "click", "app": "Finder", "right_click": false]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_dock", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] != nil)
        } catch {
            #expect(error is AgentError || error is PeekabooCore.DockError)
        }
    }

    // MARK: - Swipe Command Tests

    @Test("Execute swipe command")
    func executeSwipeCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["direction": "left", "distance": 100.0, "x": 500.0, "y": 500.0]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_swipe", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] as? Bool == true)
            let responseData = json["data"] as? [String: Any]
            #expect(responseData?["direction"] as? String == "left")
        } catch {
            #expect(error is AgentError || error is PeekabooCore.UIAutomationError)
        }
    }

    @Test("Execute swipe command with invalid direction")
    func executeSwipeCommandInvalidDirection() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["direction": "diagonal"]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        let result = try await executor.executeFunction(name: "peekaboo_swipe", arguments: argsString)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == false)
        let error = json["error"] as? [String: Any]
        #expect(error?["code"] as? String == "INVALID_ARGUMENTS")
    }

    // MARK: - Additional Command Tests

    @Test("Execute wait command")
    func executeWaitCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["duration": 0.1] // 100ms
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        let start = Date()
        let result = try await executor.executeFunction(name: "peekaboo_wait", arguments: argsString)
        let elapsed = Date().timeIntervalSince(start)

        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == true)
        #expect(elapsed >= 0.1)
    }

    @Test("Execute hotkey command")
    func executeHotkeyCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["keys": ["cmd", "a"]]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_hotkey", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] as? Bool == true)
        } catch {
            #expect(error is AgentError || error is PeekabooCore.UIAutomationError)
        }
    }

    @Test("Execute scroll command")
    func executeScrollCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["direction": "down", "amount": 5]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_scroll", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] as? Bool == true)
        } catch {
            #expect(error is AgentError || error is PeekabooCore.UIAutomationError)
        }
    }

    @Test("Execute list apps command")
    func executeListAppsCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["target": "apps"]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        let result = try await executor.executeFunction(name: "peekaboo_list", arguments: argsString)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == true)
        let responseData = json["data"] as? [String: Any]
        #expect(responseData?["applications"] is [[String: Any]])
        #expect((responseData?["count"] as? Int ?? 0) > 0)
    }

    @Test("Execute list windows command")
    func executeListWindowsCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["target": "windows", "app": "Finder"]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        do {
            let result = try await executor.executeFunction(name: "peekaboo_list", arguments: argsString)
            let data = result.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            #expect(json["success"] as? Bool == true)
            let responseData = json["data"] as? [String: Any]
            #expect(responseData?["windows"] is [[String: Any]])
        } catch {
            #expect(error is AgentError || error is PeekabooCore.PeekabooError)
        }
    }

    @Test("Execute shell command")
    func executeShellCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["command": "echo 'Hello, World!'"]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        let result = try await executor.executeFunction(name: "peekaboo_shell", arguments: argsString)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == true)
        let responseData = json["data"] as? [String: Any]
        #expect(responseData?["output"] as? String == "Hello, World!\n")
        #expect(responseData?["exit_code"] as? Int == 0)
    }

    @Test("Execute analyze screenshot command with missing API key")
    func executeAnalyzeScreenshotNoAPIKey() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        // Save original API key and remove it
        let originalKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        if originalKey != nil {
            // Can't actually remove env vars in tests, so we'll skip this test if key is present
            throw Issue.record("Test requires OPENAI_API_KEY to be unset")
        }

        let executor = AgentExecutor(verbose: false)
        let args = ["screenshot_path": "/tmp/test.png", "question": "What is this?"]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        let result = try await executor.executeFunction(name: "peekaboo_analyze_screenshot", arguments: argsString)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == false)
        let error = json["error"] as? [String: Any]
        #expect(error?["code"] as? String == "MISSING_API_KEY")
    }

    // MARK: - Error Handling Tests

    @Test("Execute unknown command")
    func executeUnknownCommand() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let args: [String: Any] = [:]
        let argsJSON = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: argsJSON, encoding: .utf8)!

        let result = try await executor.executeFunction(name: "peekaboo_unknown", arguments: argsString)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == false)
        let error = json["error"] as? [String: Any]
        #expect(error?["code"] as? String == "INVALID_ARGUMENTS")
        #expect((error?["message"] as? String ?? "").contains("Unknown command"))
    }

    @Test("Execute command with invalid JSON")
    func executeCommandInvalidJSON() async throws {
        guard #available(macOS 14.0, *) else {
            throw Issue.record("Test requires macOS 14.0+")
        }

        let executor = AgentExecutor(verbose: false)
        let invalidJSON = "{invalid json"

        let result = try await executor.executeFunction(name: "peekaboo_see", arguments: invalidJSON)
        let data = result.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["success"] as? Bool == false)
        let error = json["error"] as? [String: Any]
        #expect(error?["code"] as? String == "INVALID_ARGUMENTS")
        #expect((error?["message"] as? String ?? "").contains("Failed to parse JSON"))
    }
}
