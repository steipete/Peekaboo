import Foundation
import MCP
import os.log
import PeekabooAutomation
import TachikomaMCP

@MainActor
struct AppToolActions {
    enum FocusMode {
        case focus
        case appSwitch
    }

    let service: any ApplicationServiceProtocol
    let automation: any UIAutomationServiceProtocol
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
        let descriptor = self.identifier(for: appInfo)

        let quitSuccess = try await self.service.quitApplication(identifier: descriptor, force: request.force)
        if !quitSuccess {
            return ToolResponse.error("Failed to quit \(appInfo.name). It may have unsaved changes.")
        }

        let terminated = await self.waitForRunningState(identifier: descriptor, desiredState: false, timeout: 5.0)
        if !terminated {
            return ToolResponse.error("App \(appInfo.name) did not terminate within 5 seconds")
        }

        if request.wait > 0 {
            try await Task.sleep(nanoseconds: UInt64(request.wait * 1_000_000_000))
        }

        _ = try await self.service.launchApplication(identifier: descriptor)

        if request.waitUntilReady {
            _ = await self.waitForRunningState(identifier: descriptor, desiredState: true, timeout: 10.0)
        }

        let refreshedInfo = try await self.service.findApplication(identifier: descriptor)
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
            await self.cycleApplications()
            return ToolResponse(
                content: [.text(
                    text: "\(AgentDisplayTokens.Status.success) Switched to next application",
                    annotations: nil,
                    _meta: nil)],
                meta: self.executionMeta(from: request.startTime))

        case .appSwitch:
            guard let identifier = request.switchTarget else {
                return ToolResponse.error("Must specify 'to' for switch action")
            }
            let app = try await self.service.findApplication(identifier: identifier)
            guard await self.activateApplication(app) else {
                return ToolResponse.error("Failed to focus \(app.name). Application may not be running.")
            }
            return self.focusResponse(app: app, startTime: request.startTime, verb: "Switched")

        case .focus:
            guard let identifier = request.name else {
                return ToolResponse.error("Must specify 'name' for focus action")
            }
            let app = try await self.service.findApplication(identifier: identifier)
            guard await self.activateApplication(app) else {
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

        let baseMeta: [String: Value] = [
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
        ]
        let summaryMeta = self.makeSummary(for: nil, action: "List Applications", notes: "Found \(apps.count) apps")
        return ToolResponse(
            content: [
                .text(text: summary, annotations: nil, _meta: nil),
                .text(text: countLine, annotations: nil, _meta: nil),
            ],
            meta: ToolEventSummary.merge(summary: summaryMeta, into: .object(baseMeta)))
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
                let success = try await self.service.quitApplication(
                    identifier: self.identifier(for: app),
                    force: request.force)
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

        let baseMeta: [String: Value] = [
            "quit_count": .double(Double(quitCount)),
            "failed": .array(failed.map(Value.string)),
            "except": .array(excluded.map(Value.string)),
            "execution_time": .double(executionTime),
            "force": .bool(request.force),
        ]
        let summary = self.makeSummary(for: nil, action: "Quit Applications", notes: "Quit \(quitCount) apps")
        return ToolResponse(
            content: [.text(text: message, annotations: nil, _meta: nil)],
            meta: ToolEventSummary.merge(summary: summary, into: .object(baseMeta)))
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

        let summary = self.makeSummary(for: app, action: self.actionDescription(from: message), notes: nil)
        return ToolResponse(
            content: [.text(text: message, annotations: nil, _meta: nil)],
            meta: ToolEventSummary.merge(summary: summary, into: .object(meta)))
    }

    private func focusResponse(app: ServiceApplicationInfo, startTime: Date, verb: String) -> ToolResponse {
        let statusLine = "\(AgentDisplayTokens.Status.success) \(verb) \(app.name) (PID: \(app.processIdentifier))"
        let baseMeta: [String: Value] = [
            "app_name": .string(app.name),
            "process_id": .double(Double(app.processIdentifier)),
            "execution_time": .double(self.executionTime(since: startTime)),
        ]
        let summary = self.makeSummary(for: app, action: verb, notes: nil)
        return ToolResponse(
            content: [.text(text: statusLine, annotations: nil, _meta: nil)],
            meta: ToolEventSummary.merge(summary: summary, into: .object(baseMeta)))
    }

    private func executionMeta(from startTime: Date) -> Value {
        let baseMeta: Value = .object(["execution_time": .double(self.executionTime(since: startTime))])
        let summary = self.makeSummary(for: nil, action: "Switch Applications", notes: nil)
        return ToolEventSummary.merge(summary: summary, into: baseMeta)
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

    private func makeSummary(for app: ServiceApplicationInfo?, action: String, notes: String?) -> ToolEventSummary {
        var summary = ToolEventSummary(
            targetApp: app?.name,
            actionDescription: action,
            notes: notes)
        summary.elementValue = app?.bundleIdentifier
        return summary
    }

    private func actionDescription(from message: String) -> String {
        guard let token = message.split(separator: " ").dropFirst().first else {
            return "App"
        }
        return String(token)
    }

    private func identifier(for app: ServiceApplicationInfo) -> String {
        if let bundleId = app.bundleIdentifier, !bundleId.isEmpty {
            return bundleId
        }
        if !app.name.isEmpty {
            return app.name
        }
        return "PID:\(app.processIdentifier)"
    }

    private func waitForRunningState(
        identifier: String,
        desiredState: Bool,
        timeout: TimeInterval) async -> Bool
    {
        let interval: TimeInterval = 0.1
        var elapsed: TimeInterval = 0

        while elapsed < timeout {
            let isRunning = await self.service.isApplicationRunning(identifier: identifier)
            if isRunning == desiredState {
                return true
            }
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            elapsed += interval
        }

        let finalState = await self.service.isApplicationRunning(identifier: identifier)
        return finalState == desiredState
    }

    private func activateApplication(_ appInfo: ServiceApplicationInfo) async -> Bool {
        let identifier = self.identifier(for: appInfo)
        do {
            try await self.service.activateApplication(identifier: identifier)
            return true
        } catch {
            self.logger.error("Failed to activate \(appInfo.name, privacy: .public): \(error, privacy: .public)")
            return false
        }
    }

    private func cycleApplications() async {
        do {
            try await self.automation.hotkey(keys: "cmd,tab", holdDuration: 50)
        } catch {
            self.logger.error("Failed to send Cmd+Tab: \(error, privacy: .public)")
        }
    }
}
