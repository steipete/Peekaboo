import AppKit
import CoreGraphics
import Foundation
import MCP
import os.log
import TachikomaMCP

/// MCP tool for controlling applications (launch/quit/focus/etc.)
public struct AppTool: MCPTool {
    private let logger = Logger(subsystem: "boo.peekaboo.mcp", category: "AppTool")

    public let name = "app"

    public var description: String {
        """
        Control applications - launch, quit, relaunch, focus, hide, unhide, switch, and list running apps.
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "action": SchemaBuilder.string(
                    description: "Action to perform",
                    enum: ["launch", "quit", "relaunch", "focus", "hide", "unhide", "switch", "list"]),
                "name": SchemaBuilder.string(
                    description: "App name/bundle ID/PID (e.g., 'Safari', 'com.apple.Safari', 'PID:663')"),
                "bundleId": SchemaBuilder.string(
                    description: "Bundle identifier when launching"),
                "force": SchemaBuilder.boolean(
                    description: "Force quit application",
                    default: false),
                "wait": SchemaBuilder.number(
                    description: "Wait time (seconds) between quit/launch for relaunch",
                    default: 2.0),
                "waitUntilReady": SchemaBuilder.boolean(
                    description: "Wait until the launched app is ready",
                    default: false),
                "all": SchemaBuilder.boolean(
                    description: "Quit all applications",
                    default: false),
                "except": SchemaBuilder.string(
                    description: "Comma-separated list of apps to exclude when quitting all"),
                "to": SchemaBuilder.string(description: "Target application when switching"),
                "cycle": SchemaBuilder.boolean(
                    description: "Cycle to the next application (like Cmd+Tab)",
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

        let request = AppToolRequest(
            name: arguments.getString("name"),
            bundleId: arguments.getString("bundleId"),
            force: arguments.getBool("force") ?? false,
            wait: arguments.getNumber("wait") ?? 2.0,
            waitUntilReady: arguments.getBool("waitUntilReady") ?? false,
            all: arguments.getBool("all") ?? false,
            except: arguments.getString("except"),
            switchTarget: arguments.getString("to"),
            cycle: arguments.getBool("cycle") ?? false,
            startTime: Date())

        do {
            let actions = AppToolActions(
                service: PeekabooServices.shared.applications,
                logger: self.logger)
            return try await actions.perform(action: action, request: request)
        } catch {
            self.logger.error("App control execution failed: \(error, privacy: .public)")
            return ToolResponse.error("Failed to \(action) application: \(error.localizedDescription)")
        }
    }
}

// MARK: - Request & Helpers

private struct AppToolRequest {
    let name: String?
    let bundleId: String?
    let force: Bool
    let wait: Double
    let waitUntilReady: Bool
    let all: Bool
    let except: String?
    let switchTarget: String?
    let cycle: Bool
    let startTime: Date
}

@MainActor
private struct AppToolActions {
    enum FocusMode {
        case focus
        case appSwitch
    }

    let service: any ApplicationServiceProtocol
    let logger: Logger

    func perform(action: String, request: AppToolRequest) async throws -> ToolResponse {
        switch action {
        case "launch":
            return try await self.handleLaunch(request: request)
        case "quit":
            return try await self.handleQuit(request: request)
        case "relaunch":
            return try await self.handleRelaunch(request: request)
        case "focus":
            return try await self.handleFocus(request: request, mode: .focus)
        case "switch":
            return try await self.handleFocus(request: request, mode: .appSwitch)
        case "hide":
            return try await self.handleHide(request: request)
        case "unhide":
            return try await self.handleUnhide(request: request)
        case "list":
            return try await self.handleList(request: request)
        default:
            let supported = "launch, quit, relaunch, focus, hide, unhide, switch, list"
            return ToolResponse.error("Unknown action: \(action). Supported actions: \(supported)")
        }
    }

    // MARK: Action handlers

    func handleLaunch(request: AppToolRequest) async throws -> ToolResponse {
        let identifier = request.bundleId ?? request.name
        guard let identifier else {
            return ToolResponse.error("Must specify either 'name' or 'bundleId' for launch action")
        }

        let app = try await self.service.launchApplication(identifier: identifier)
        if request.waitUntilReady {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        let timing = self.executionTimeString(since: request.startTime)
        let message = "\(AgentDisplayTokens.Status.success) Launched \(app.name) "
            + "(PID: \(app.processIdentifier)) in \(timing)"
        return self.buildResponse(
            message: message,
            app: app,
            startTime: request.startTime)
    }

    func handleQuit(request: AppToolRequest) async throws -> ToolResponse {
        if request.all {
            return try await self.handleQuitAll(request: request)
        }

        guard let name = request.name else {
            return ToolResponse.error("Must specify 'name' for quit action (or set 'all': true)")
        }

        let appInfo = try await self.service.findApplication(identifier: name)
        let success = try await self.service.quitApplication(identifier: name, force: request.force)

        guard success else {
            return ToolResponse.error("Failed to quit \(appInfo.name). The application may have refused to quit.")
        }

        let timing = self.executionTimeString(since: request.startTime)
        let suffix = request.force ? " (force quit)" : ""
        let message = "\(AgentDisplayTokens.Status.success) Quit \(appInfo.name)\(suffix) in \(timing)"
        return self.buildResponse(
            message: message,
            app: appInfo,
            startTime: request.startTime,
            extraMeta: ["force_quit": .bool(request.force)])
    }

    func handleRelaunch(request: AppToolRequest) async throws -> ToolResponse {
        guard let identifier = request.name ?? request.bundleId else {
            return ToolResponse.error("Must specify 'name' (or 'bundleId') for relaunch action")
        }

        let appInfo = try await self.service.findApplication(identifier: identifier)
        guard let runningApp = self.runningApplication(for: appInfo.processIdentifier) else {
            return ToolResponse.error("Application \(appInfo.name) is not currently running")
        }

        let quitSuccess = request.force ? runningApp.forceTerminate() : runningApp.terminate()
        if !quitSuccess {
            return ToolResponse.error("Failed to quit \(appInfo.name). It may have unsaved changes.")
        }

        let terminated = await self.waitForTermination(of: runningApp, timeout: 5.0)
        if !terminated {
            return ToolResponse.error("App \(appInfo.name) did not terminate within 5 seconds")
        }

        if request.wait > 0 {
            try await Task.sleep(nanoseconds: UInt64(request.wait * 1_000_000_000))
        }

        let relaunchedApp = try await self.launchApplication(for: appInfo)

        if request.waitUntilReady {
            await self.waitForLaunchCompletion(of: relaunchedApp, timeout: 10.0)
        }

        // Refresh app info using new PID
        let refreshedInfo = try await self.service.findApplication(identifier: "PID:\(relaunchedApp.processIdentifier)")
        let timing = self.executionTimeString(since: request.startTime)
        let message = "\(AgentDisplayTokens.Status.success) Relaunched \(refreshedInfo.name) "
            + "(PID: \(refreshedInfo.processIdentifier)) in \(timing)"

        return self.buildResponse(
            message: message,
            app: refreshedInfo,
            startTime: request.startTime,
            extraMeta: [
                "previous_pid": .double(Double(appInfo.processIdentifier)),
                "wait": .double(request.wait),
                "wait_until_ready": .bool(request.waitUntilReady),
                "force": .bool(request.force),
            ])
    }

    func handleFocus(request: AppToolRequest, mode: FocusMode) async throws -> ToolResponse {
        switch mode {
        case .appSwitch where request.cycle:
            self.cycleApplications()
            return ToolResponse(
                content: [.text("\(AgentDisplayTokens.Status.success) Switched to next application")],
                meta: self.executionMeta(from: request.startTime))

        case .appSwitch:
            guard let identifier = request.switchTarget else {
                return ToolResponse.error("Must specify 'to' for switch action")
            }
            let app = try await self.service.findApplication(identifier: identifier)
            guard self.activateApplication(app) else {
                return ToolResponse.error("Failed to focus \(app.name). Application may not be running.")
            }
            return self.focusResponse(app: app, startTime: request.startTime, verb: "Switched")

        case .focus:
            guard let identifier = request.name else {
                return ToolResponse.error("Must specify 'name' for focus action")
            }
            let app = try await self.service.findApplication(identifier: identifier)
            guard self.activateApplication(app) else {
                return ToolResponse.error("Failed to focus \(app.name). Application may not be running.")
            }
            return self.focusResponse(app: app, startTime: request.startTime, verb: "Focused")
        }
    }

    func handleHide(request: AppToolRequest) async throws -> ToolResponse {
        guard let name = request.name else {
            return ToolResponse.error("Must specify 'name' for hide action")
        }
        let app = try await self.service.findApplication(identifier: name)
        try await self.service.hideApplication(identifier: name)
        let message = "\(AgentDisplayTokens.Status.success) Hid \(app.name) "
            + "(PID: \(app.processIdentifier)) in \(self.executionTimeString(since: request.startTime))"
        return self.buildResponse(
            message: message,
            app: app,
            startTime: request.startTime)
    }

    func handleUnhide(request: AppToolRequest) async throws -> ToolResponse {
        guard let name = request.name else {
            return ToolResponse.error("Must specify 'name' for unhide action")
        }
        let app = try await self.service.findApplication(identifier: name)
        try await self.service.unhideApplication(identifier: name)
        let message = "\(AgentDisplayTokens.Status.success) Unhid \(app.name) "
            + "(PID: \(app.processIdentifier)) in \(self.executionTimeString(since: request.startTime))"
        return self.buildResponse(
            message: message,
            app: app,
            startTime: request.startTime)
    }

    func handleList(request: AppToolRequest) async throws -> ToolResponse {
        let appsOutput = try await self.service.listApplications()
        let apps = appsOutput.data.applications
        let executionTime = self.executionTime(since: request.startTime)

        let summary = apps
            .sorted { $0.isActive && !$1.isActive }
            .map { app in
                let prefix = app.isActive ? AgentDisplayTokens.Status.success : AgentDisplayTokens.Status.info
                return "\(prefix) \(app.name) (PID: \(app.processIdentifier))"
            }
            .joined(separator: "\n")
        let countLine = "\(AgentDisplayTokens.Status.info) Found \(apps.count) running applications "
            + "in \(self.executionTimeString(from: executionTime))"

        return ToolResponse(
            content: [
                .text(summary),
                .text(countLine),
            ],
            meta: .object([
                "apps": .array(
                    apps.map { app in
                        .object([
                            "name": .string(app.name),
                            "bundle_id": app.bundleIdentifier != nil ? .string(app.bundleIdentifier!) : .null,
                            "process_id": .double(Double(app.processIdentifier)),
                            "is_active": .bool(app.isActive),
                            "is_hidden": .bool(app.isHidden),
                        ])
                    }),
                "execution_time": .double(executionTime),
            ]))
    }

    // MARK: Helpers

    private func handleQuitAll(request: AppToolRequest) async throws -> ToolResponse {
        let excluded = request.except?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? []

        let appsOutput = try await self.service.listApplications()
        let allApps = appsOutput.data.applications
        let remaining = allApps.filter { app in
            excluded.contains { exclusion in exclusion.caseInsensitiveCompare(app.name) == .orderedSame }
        }
        let targets = allApps.filter { app in
            !remaining.contains(where: { $0.processIdentifier == app.processIdentifier })
        }

        var quitCount = 0
        var failed = [String]()
        for app in targets {
            do {
                let success = try await self.service.quitApplication(identifier: app.name, force: request.force)
                if success {
                    quitCount += 1
                } else {
                    failed.append(app.name)
                }
            } catch {
                self.logger.error("Failed to quit \(app.name, privacy: .public): \(error, privacy: .public)")
                failed.append(app.name)
            }
        }

        let executionTime = self.executionTime(since: request.startTime)
        var message = "\(AgentDisplayTokens.Status.success) Quit \(quitCount) applications"
        if !excluded.isEmpty {
            message += " (except \(excluded.joined(separator: ", ")))"
        }
        message += " in \(self.executionTimeString(from: executionTime))"
        if !failed.isEmpty {
            let failureList = failed.joined(separator: ", ")
            let warningLine = "\n\(AgentDisplayTokens.Status.warning) Failed to quit: \(failureList)"
            message += warningLine
        }

        return ToolResponse(
            content: [.text(message)],
            meta: .object([
                "quit_count": .double(Double(quitCount)),
                "failed": .array(failed.map(Value.string)),
                "except": .array(excluded.map(Value.string)),
                "execution_time": .double(executionTime),
                "force": .bool(request.force),
            ]))
    }

    private func buildResponse(
        message: String,
        app: ServiceApplicationInfo,
        startTime: Date,
        extraMeta: [String: Value] = [:]) -> ToolResponse
    {
        var meta: [String: Value] = [
            "app_name": .string(app.name),
            "process_id": .double(Double(app.processIdentifier)),
            "bundle_id": app.bundleIdentifier != nil ? .string(app.bundleIdentifier!) : .null,
            "execution_time": .double(self.executionTime(since: startTime)),
        ]
        meta.merge(extraMeta) { $1 }

        return ToolResponse(
            content: [.text(message)],
            meta: .object(meta))
    }

    private func focusResponse(app: ServiceApplicationInfo, startTime: Date, verb: String) -> ToolResponse {
        let statusLine = "\(AgentDisplayTokens.Status.success) \(verb) \(app.name) (PID: \(app.processIdentifier))"
        return ToolResponse(
            content: [.text(statusLine)],
            meta: .object([
                "app_name": .string(app.name),
                "process_id": .double(Double(app.processIdentifier)),
                "execution_time": .double(self.executionTime(since: startTime)),
            ]))
    }

    private func executionMeta(from startTime: Date) -> Value {
        .object(["execution_time": .double(self.executionTime(since: startTime))])
    }

    private func executionTime(since startTime: Date) -> Double {
        Date().timeIntervalSince(startTime)
    }

    private func executionTimeString(since startTime: Date) -> String {
        self.executionTimeString(from: self.executionTime(since: startTime))
    }

    private func executionTimeString(from interval: Double) -> String {
        "\(String(format: "%.2f", interval))s"
    }

    private func runningApplication(for pid: Int32) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.processIdentifier == pid }
    }

    private func waitForTermination(of app: NSRunningApplication, timeout: TimeInterval) async -> Bool {
        var elapsed: TimeInterval = 0
        while !app.isTerminated, elapsed < timeout {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            elapsed += 0.1
        }
        return app.isTerminated
    }

    private func waitForLaunchCompletion(of app: NSRunningApplication, timeout: TimeInterval) async {
        var elapsed: TimeInterval = 0
        while !app.isFinishedLaunching, elapsed < timeout {
            try? await Task.sleep(nanoseconds: 100_000_000)
            elapsed += 0.1
        }
    }

    private func launchApplication(for appInfo: ServiceApplicationInfo) async throws -> NSRunningApplication {
        let workspace = NSWorkspace.shared
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        if let bundleId = appInfo.bundleIdentifier,
           let url = workspace.urlForApplication(withBundleIdentifier: bundleId)
        {
            return try await workspace.openApplication(at: url, configuration: config)
        } else if let bundlePath = appInfo.bundlePath {
            let url = URL(fileURLWithPath: bundlePath)
            return try await workspace.openApplication(at: url, configuration: config)
        }

        throw ToolError(message: "Unable to relaunch \(appInfo.name). Missing bundle information.")
    }

    private func activateApplication(_ appInfo: ServiceApplicationInfo) -> Bool {
        guard let runningApp = self.runningApplication(for: appInfo.processIdentifier) else {
            return false
        }
        return runningApp.activate(options: [.activateAllWindows])
    }

    private func cycleApplications() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x30, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x30, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

private struct ToolError: LocalizedError {
    let message: String
    var errorDescription: String? { self.message }
}
