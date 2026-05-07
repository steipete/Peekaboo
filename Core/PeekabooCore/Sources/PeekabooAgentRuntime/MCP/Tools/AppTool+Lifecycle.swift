import Foundation
import MCP
import os.log
import PeekabooAutomation
import TachikomaMCP

@MainActor
extension AppToolActions {
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

    func waitForRunningState(
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
}
