import CoreGraphics
import Foundation
import MCP
import os.log
import TachikomaMCP

/// MCP tool for controlling applications
public struct AppTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "AppTool")

    public let name = "app"

    public var description: String {
        """
        Control applications - launch, quit, relaunch, focus, hide, unhide, and switch between apps.

        Actions:
        - launch: Start an application (e.g., Calculator for calculations, Notes for writing)
        - quit: Quit an application (with optional force flag)
        - relaunch: Quit and restart an application (with configurable wait time)
        - focus/switch: Bring an application to the foreground
        - hide: Hide an application
        - unhide: Show a hidden application
        - list: List all running applications

        Target applications by name (e.g., "Safari", "Calculator"), bundle ID (e.g., "com.apple.Safari"),
        or process ID (e.g., "PID:663"). Fuzzy matching is supported for application names.

        Common apps: Calculator, Safari, Chrome, Firefox, TextEdit, Notes, Terminal, Finder, 
        System Settings, Activity Monitor, Mail, Calendar, Messages, Music, Photos, Preview

        Examples:
        - Launch Calculator for math: { "action": "launch", "name": "Calculator" }
        - Launch Safari: { "action": "launch", "name": "Safari" }
        - Quit TextEdit: { "action": "quit", "name": "TextEdit" }
        - Relaunch Chrome: { "action": "relaunch", "name": "Google Chrome", "wait": 3 }
        - Focus Terminal: { "action": "focus", "name": "Terminal" }
        - List running apps: { "action": "list" }
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "action": SchemaBuilder.string(
                    description: "The action to perform on the application",
                    enum: ["launch", "quit", "relaunch", "focus", "hide", "unhide", "switch", "list"]),
                "name": SchemaBuilder.string(
                    description: "Application name, bundle ID, or process ID (e.g., 'Safari', 'com.apple.Safari', 'PID:663')"),
                "bundleId": SchemaBuilder.string(
                    description: "Launch by bundle identifier instead of name (for 'launch' action)"),
                "force": SchemaBuilder.boolean(
                    description: "Force quit the application (for 'quit' and 'relaunch' actions)",
                    default: false),
                "wait": SchemaBuilder.number(
                    description: "Wait time in seconds between quit and launch (for 'relaunch' action, default: 2)",
                    default: 2.0),
                "waitUntilReady": SchemaBuilder.boolean(
                    description: "Wait for the application to be ready (for 'launch' and 'relaunch' actions)",
                    default: false),
                "all": SchemaBuilder.boolean(
                    description: "Quit all applications (for 'quit' action)",
                    default: false),
                "except": SchemaBuilder.string(
                    description: "Comma-separated list of apps to exclude when using --all (for 'quit' action)"),
                "to": SchemaBuilder.string(
                    description: "Application to switch to (for 'switch' action)"),
                "cycle": SchemaBuilder.boolean(
                    description: "Cycle to next application like Cmd+Tab (for 'switch' action)",
                    default: false),
            ],
            required: ["action"])
    }

    public init() {}

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        guard let action = arguments.getString("action") else {
            return ToolResponse.error("Missing required parameter: action")
        }

        let name = arguments.getString("name")
        let bundleId = arguments.getString("bundleId")
        let force = arguments.getBool("force") ?? false
        let wait = arguments.getNumber("wait") ?? 2.0
        let waitUntilReady = arguments.getBool("waitUntilReady") ?? false
        let all = arguments.getBool("all") ?? false
        let except = arguments.getString("except")
        let to = arguments.getString("to")
        let cycle = arguments.getBool("cycle") ?? false

        let applicationService = PeekabooServices.shared.applications

        do {
            let startTime = Date()

            switch action {
            case "launch":
                return try await self.handleLaunch(
                    service: applicationService,
                    name: name,
                    bundleId: bundleId,
                    waitUntilReady: waitUntilReady,
                    startTime: startTime)

            case "quit":
                return try await self.handleQuit(
                    service: applicationService,
                    name: name,
                    force: force,
                    all: all,
                    except: except,
                    startTime: startTime)

            case "relaunch":
                return try await self.handleRelaunch(
                    service: applicationService,
                    name: name,
                    force: force,
                    wait: wait,
                    waitUntilReady: waitUntilReady,
                    startTime: startTime)

            case "focus", "switch":
                return try await self.handleFocus(
                    service: applicationService,
                    name: name,
                    to: to,
                    cycle: cycle,
                    startTime: startTime)

            case "hide":
                return try await self.handleHide(
                    service: applicationService,
                    name: name,
                    startTime: startTime)

            case "unhide":
                return try await self.handleUnhide(
                    service: applicationService,
                    name: name,
                    startTime: startTime)

            case "list":
                return try await self.handleList(
                    service: applicationService,
                    startTime: startTime)

            default:
                return ToolResponse
                    .error(
                        "Unknown action: \(action). Supported actions: launch, quit, relaunch, focus, hide, unhide, switch, list")
            }

        } catch {
            self.logger.error("App control execution failed: \(error)")
            return ToolResponse.error("Failed to \(action) application: \(error.localizedDescription)")
        }
    }

    // MARK: - Action Handlers

    private func handleLaunch(
        service: ApplicationServiceProtocol,
        name: String?,
        bundleId: String?,
        waitUntilReady: Bool,
        startTime: Date) async throws -> ToolResponse
    {
        let identifier = bundleId ?? name
        guard let identifier else {
            return ToolResponse.error("Must specify either 'name' or 'bundleId' for launch action")
        }

        let app = try await service.launchApplication(identifier: identifier)

        if waitUntilReady {
            // Wait a bit for the app to fully launch
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }

        let executionTime = Date().timeIntervalSince(startTime)

        return ToolResponse(
            content: [
                .text(
                    "\(AgentDisplayTokens.Status.success) Launched \(app.name) (PID: \(app.processIdentifier)) in \(String(format: "%.2f", executionTime))s"),
            ],
            meta: .object([
                "app_name": .string(app.name),
                "process_id": .double(Double(app.processIdentifier)),
                "bundle_id": app.bundleIdentifier != nil ? .string(app.bundleIdentifier!) : .null,
                "execution_time": .double(executionTime),
            ]))
    }

    private func handleQuit(
        service: ApplicationServiceProtocol,
        name: String?,
        force: Bool,
        all: Bool,
        except: String?,
        startTime: Date) async throws -> ToolResponse
    {
        if all {
            return try await self.handleQuitAll(
                service: service,
                except: except,
                force: force,
                startTime: startTime)
        }

        guard let name else {
            return ToolResponse.error("Must specify 'name' for quit action (or use 'all': true)")
        }

        let app = try await service.findApplication(identifier: name)
        let success = try await service.quitApplication(identifier: name, force: force)

        let executionTime = Date().timeIntervalSince(startTime)
        let forceText = force ? " (force quit)" : ""

        if success {
            return ToolResponse(
                content: [
                    .text(
                        "\(AgentDisplayTokens.Status.success) Quit \(app.name)\(forceText) in \(String(format: "%.2f", executionTime))s"),
                ],
                meta: .object([
                    "app_name": .string(app.name),
                    "process_id": .double(Double(app.processIdentifier)),
                    "force_quit": .bool(force),
                    "execution_time": .double(executionTime),
                ]))
        } else {
            return ToolResponse.error("Failed to quit \(app.name). The application may have refused to quit.")
        }
    }

    private func handleQuitAll(
        service: ApplicationServiceProtocol,
        except: String?,
        force: Bool,
        startTime: Date) async throws -> ToolResponse
    {
        let allApps = try await service.listApplications()
        let exceptSet = Set((except ?? "").split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() })

        var quitCount = 0
        var failedApps: [String] = []

        for app in allApps.data.applications {
            // Skip system apps and apps in the exception list
            let appNameLower = app.name.lowercased()
            if exceptSet.contains(appNameLower) ||
                exceptSet.contains(app.bundleIdentifier?.lowercased() ?? "") ||
                app.name == "Finder" || // Always preserve Finder
                app.bundleIdentifier?.starts(with: "com.apple.") == true
            {
                continue
            }

            do {
                let success = try await service.quitApplication(identifier: app.name, force: force)
                if success {
                    quitCount += 1
                } else {
                    failedApps.append(app.name)
                }
            } catch {
                failedApps.append(app.name)
            }
        }

        let executionTime = Date().timeIntervalSince(startTime)
        let forceText = force ? " (force quit)" : ""

        var message = "\(AgentDisplayTokens.Status.success) Quit \(quitCount) applications\(forceText)"
        if !failedApps.isEmpty {
            message += " (failed: \(failedApps.joined(separator: ", ")))"
        }
        message += " in \(String(format: "%.2f", executionTime))s"

        return ToolResponse(
            content: [.text(message)],
            meta: .object([
                "quit_count": .double(Double(quitCount)),
                "failed_apps": .array(failedApps.map { .string($0) }),
                "force_quit": .bool(force),
                "execution_time": .double(executionTime),
            ]))
    }

    private func handleRelaunch(
        service: ApplicationServiceProtocol,
        name: String?,
        force: Bool,
        wait: Double,
        waitUntilReady: Bool,
        startTime: Date) async throws -> ToolResponse
    {
        guard let name else {
            return ToolResponse.error("Must specify 'name' for relaunch action")
        }

        // First, get app info before quitting
        let originalApp = try await service.findApplication(identifier: name)

        // Quit the application
        let quitSuccess = try await service.quitApplication(identifier: name, force: force)
        if !quitSuccess {
            return ToolResponse.error("Failed to quit \(originalApp.name) for relaunch")
        }

        // Wait the specified time
        let waitNanoseconds = UInt64(wait * 1_000_000_000)
        try await Task.sleep(nanoseconds: waitNanoseconds)

        // Relaunch the application
        let newApp = try await service.launchApplication(identifier: name)

        if waitUntilReady {
            // Wait a bit for the app to fully launch
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }

        let executionTime = Date().timeIntervalSince(startTime)
        let forceText = force ? " (force quit)" : ""

        return ToolResponse(
            content: [
                .text(
                    "\(AgentDisplayTokens.Status.success) Relaunched \(newApp.name)\(forceText) with \(wait)s wait in \(String(format: "%.2f", executionTime))s"),
            ],
            meta: .object([
                "app_name": .string(newApp.name),
                "old_process_id": .double(Double(originalApp.processIdentifier)),
                "new_process_id": .double(Double(newApp.processIdentifier)),
                "bundle_id": newApp.bundleIdentifier != nil ? .string(newApp.bundleIdentifier!) : .null,
                "wait_time": .double(wait),
                "force_quit": .bool(force),
                "execution_time": .double(executionTime),
            ]))
    }

    private func handleFocus(
        service: ApplicationServiceProtocol,
        name: String?,
        to: String?,
        cycle: Bool,
        startTime: Date) async throws -> ToolResponse
    {
        if cycle {
            // Implement Cmd+Tab like cycling functionality
            // This simulates pressing Cmd+Tab to cycle to the next app
            let event = CGEvent(keyboardEventSource: nil, virtualKey: 0x30, keyDown: true) // Tab key
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)

            // Release the keys
            let releaseEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x30, keyDown: false)
            releaseEvent?.flags = []
            releaseEvent?.post(tap: .cghidEventTap)

            // Small delay to allow the switch to complete
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms

            // Get the newly focused app
            let appsOutput = try await service.listApplications()
            guard let focusedApp = appsOutput.data.applications.first(where: { $0.isActive }) else {
                return ToolResponse.error("Failed to determine focused app after cycling")
            }

            let executionTime = Date().timeIntervalSince(startTime)

            return ToolResponse(
                content: [
                    .text(
                        "\(AgentDisplayTokens.Status.success) Cycled to \(focusedApp.name) in \(String(format: "%.2f", executionTime))s"),
                ],
                meta: .object([
                    "app_name": .string(focusedApp.name),
                    "process_id": .double(Double(focusedApp.processIdentifier)),
                    "bundle_id": focusedApp.bundleIdentifier != nil ? .string(focusedApp.bundleIdentifier!) : .null,
                    "execution_time": .double(executionTime),
                ]))
        }

        let targetName = to ?? name
        guard let targetName else {
            return ToolResponse.error("Must specify 'name' or 'to' for focus/switch action")
        }

        let app = try await service.findApplication(identifier: targetName)
        try await service.activateApplication(identifier: targetName)

        let executionTime = Date().timeIntervalSince(startTime)

        return ToolResponse(
            content: [
                .text(
                    "\(AgentDisplayTokens.Status.success) Focused \(app.name) in \(String(format: "%.2f", executionTime))s"),
            ],
            meta: .object([
                "app_name": .string(app.name),
                "process_id": .double(Double(app.processIdentifier)),
                "bundle_id": app.bundleIdentifier != nil ? .string(app.bundleIdentifier!) : .null,
                "execution_time": .double(executionTime),
            ]))
    }

    private func handleHide(
        service: ApplicationServiceProtocol,
        name: String?,
        startTime: Date) async throws -> ToolResponse
    {
        guard let name else {
            return ToolResponse.error("Must specify 'name' for hide action")
        }

        let app = try await service.findApplication(identifier: name)
        try await service.hideApplication(identifier: name)

        let executionTime = Date().timeIntervalSince(startTime)

        return ToolResponse(
            content: [
                .text(
                    "\(AgentDisplayTokens.Status.success) Hidden \(app.name) in \(String(format: "%.2f", executionTime))s"),
            ],
            meta: .object([
                "app_name": .string(app.name),
                "process_id": .double(Double(app.processIdentifier)),
                "execution_time": .double(executionTime),
            ]))
    }

    private func handleUnhide(
        service: ApplicationServiceProtocol,
        name: String?,
        startTime: Date) async throws -> ToolResponse
    {
        guard let name else {
            return ToolResponse.error("Must specify 'name' for unhide action")
        }

        let app = try await service.findApplication(identifier: name)
        try await service.unhideApplication(identifier: name)

        let executionTime = Date().timeIntervalSince(startTime)

        return ToolResponse(
            content: [
                .text(
                    "\(AgentDisplayTokens.Status.success) Unhidden \(app.name) in \(String(format: "%.2f", executionTime))s"),
            ],
            meta: .object([
                "app_name": .string(app.name),
                "process_id": .double(Double(app.processIdentifier)),
                "execution_time": .double(executionTime),
            ]))
    }

    private func handleList(
        service: ApplicationServiceProtocol,
        startTime: Date) async throws -> ToolResponse
    {
        let apps = try await service.listApplications()
        let executionTime = Date().timeIntervalSince(startTime)

        let appList = apps.data.applications.map { app in
            var info = "\(app.name) (PID: \(app.processIdentifier))"
            if let bundleId = app.bundleIdentifier {
                info += " [\(bundleId)]"
            }
            if app.isActive {
                info += " [ACTIVE]"
            }
            if app.isHidden {
                info += " [HIDDEN]"
            }
            return info
        }.joined(separator: "\n")

        let message = "[apps] Running Applications (\(apps.data.applications.count) total):\n\(appList)\n\nCompleted in \(String(format: "%.2f", executionTime))s"

        return ToolResponse(
            content: [.text(message)],
            meta: .object([
                "application_count": .double(Double(apps.data.applications.count)),
                "applications": .array(apps.data.applications.map { app in
                    .object([
                        "name": .string(app.name),
                        "process_id": .double(Double(app.processIdentifier)),
                        "bundle_id": app.bundleIdentifier != nil ? .string(app.bundleIdentifier!) : .null,
                        "is_active": .bool(app.isActive),
                        "is_hidden": .bool(app.isHidden),
                        "window_count": .double(Double(app.windowCount)),
                    ])
                }),
                "execution_time": .double(executionTime),
            ]))
    }
}
