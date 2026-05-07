import CoreGraphics
import Foundation
import PeekabooFoundation

@MainActor
extension ProcessService {
    func executeWindowCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
        let context = try self.windowCommandContext(from: step)
        let windows = try await self.fetchWindows(for: context.app)
        let window = try self.selectWindow(
            from: windows,
            title: context.title,
            index: context.index)

        try await self.performWindowAction(
            context.action,
            window: window,
            resizeParams: context.resizeParams)

        return StepExecutionResult(
            output: .data([
                "window": .success(window.title),
                "action": .success(context.action),
            ]),
            snapshotId: snapshotId)
    }

    private struct WindowCommandContext {
        let action: String
        let app: String?
        let title: String?
        let index: Int?
        let resizeParams: ProcessCommandParameters.ResizeWindowParameters?
    }

    private func windowCommandContext(from step: ScriptStep) throws -> WindowCommandContext {
        if case let .focusWindow(params) = step.params {
            return WindowCommandContext(
                action: "focus",
                app: params.app,
                title: params.title,
                index: params.index,
                resizeParams: nil)
        } else if case let .resizeWindow(params) = step.params {
            let action = if params.maximize == true {
                "maximize"
            } else if params.minimize == true {
                "minimize"
            } else if params.x != nil || params.y != nil {
                "move"
            } else {
                "resize"
            }

            return WindowCommandContext(
                action: action,
                app: params.app,
                title: nil,
                index: nil,
                resizeParams: params)
        }

        throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for window command")
    }

    private func fetchWindows(for app: String?) async throws -> [ServiceWindowInfo] {
        if let appName = app {
            return try await self.windowManagementService.listWindows(target: .application(appName))
        }

        let appsOutput = try await self.applicationService.listApplications()
        var allWindows: [ServiceWindowInfo] = []
        for app in appsOutput.data.applications {
            let appWindows = try await self.windowManagementService.listWindows(target: .application(app.name))
            allWindows.append(contentsOf: appWindows)
        }
        return allWindows
    }

    private func selectWindow(
        from windows: [ServiceWindowInfo],
        title: String?,
        index: Int?) throws -> ServiceWindowInfo
    {
        if let windowTitle = title,
           let match = windows.first(where: { $0.title.contains(windowTitle) })
        {
            return match
        }

        if let windowIndex = index,
           windows.indices.contains(windowIndex)
        {
            return windows[windowIndex]
        }

        if let first = windows.first {
            return first
        }

        throw PeekabooError.windowNotFound()
    }

    private func performWindowAction(
        _ action: String,
        window: ServiceWindowInfo,
        resizeParams: ProcessCommandParameters.ResizeWindowParameters?) async throws
    {
        switch action.lowercased() {
        case "close":
            try await self.windowManagementService.closeWindow(target: .windowId(window.windowID))
        case "minimize":
            try await self.windowManagementService.minimizeWindow(target: .windowId(window.windowID))
        case "maximize":
            try await self.windowManagementService.maximizeWindow(target: .windowId(window.windowID))
        case "focus":
            try await self.windowManagementService.focusWindow(target: .windowId(window.windowID))
        case "move":
            guard let params = resizeParams, let x = params.x, let y = params.y else {
                throw PeekabooError.invalidInput(field: "params", reason: "Move action requires x and y coordinates")
            }
            try await self.windowManagementService.moveWindow(
                target: .windowId(window.windowID),
                to: CGPoint(x: x, y: y))
        case "resize":
            guard let params = resizeParams, let width = params.width, let height = params.height else {
                throw PeekabooError.invalidInput(
                    field: "params",
                    reason: "Resize action requires width and height values")
            }
            try await self.windowManagementService.resizeWindow(
                target: .windowId(window.windowID),
                to: CGSize(width: width, height: height))
        default:
            throw PeekabooError.invalidInput(field: "action", reason: "Invalid action '\(action)' for window command")
        }
    }
}
