import CoreGraphics
import Foundation
import PeekabooFoundation
import UniformTypeIdentifiers

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

    func executeMenuCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
        // Extract menu parameters - should already be normalized
        guard case let .menuClick(menuParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for menu command")
        }

        let menuPath = menuParams.menuPath.joined(separator: " > ")
        let app = menuParams.app

        let appName: String
        if let providedApp = app {
            appName = providedApp
        } else {
            // Use frontmost app
            let frontApp = try await applicationService.getFrontmostApplication()
            appName = frontApp.name
        }

        try await self.menuService.clickMenuItem(app: appName, itemPath: menuPath)

        return StepExecutionResult(
            output: .success("Clicked menu: \(menuPath) in \(appName)"),
            snapshotId: snapshotId)
    }

    func executeDockCommand(_ step: ScriptStep) async throws -> StepExecutionResult {
        // Extract dock parameters - should already be normalized
        guard case let .dock(dockParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for dock command")
        }

        switch dockParams.action.lowercased() {
        case "list":
            let items = try await dockService.listDockItems(includeAll: false)
            return StepExecutionResult(
                output: .list(items.map { "\($0.title) (\($0.itemType.rawValue))" }),
                snapshotId: nil)

        case "click":
            guard let itemName = dockParams.item else {
                throw PeekabooError.invalidInput(
                    field: "item",
                    reason: "Missing required parameter for dock click command")
            }
            try await self.dockService.launchFromDock(appName: itemName)
            return StepExecutionResult(
                output: .success("Clicked dock item: \(itemName)"),
                snapshotId: nil)

        case "add":
            guard let path = dockParams.path else {
                throw PeekabooError.invalidInput(
                    field: "path",
                    reason: "Missing required parameter for dock add command")
            }
            try await self.dockService.addToDock(path: path, persistent: true)
            return StepExecutionResult(
                output: .success("Added to Dock: \(path)"),
                snapshotId: nil)

        case "remove":
            guard let item = dockParams.item else {
                throw PeekabooError.invalidInput(
                    field: "item",
                    reason: "Missing required parameter for dock remove command")
            }
            try await self.dockService.removeFromDock(appName: item)
            return StepExecutionResult(
                output: .success("Removed from Dock: \(item)"),
                snapshotId: nil)

        default:
            throw PeekabooError.invalidInput(
                field: "action",
                reason: "Invalid action '\(dockParams.action)' for dock command")
        }
    }

    func executeAppCommand(_ step: ScriptStep) async throws -> StepExecutionResult {
        // Extract app parameters - should already be normalized
        guard case let .launchApp(appParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for app command")
        }

        let appName = appParams.appName
        // Use action from parameters, default to launch
        let action = appParams.action ?? "launch"

        switch action.lowercased() {
        case "launch":
            _ = try await self.applicationService.launchApplication(identifier: appName)
            return StepExecutionResult(
                output: .success("Launched application: \(appName)"),
                snapshotId: nil)

        case "quit":
            _ = try await self.applicationService.quitApplication(identifier: appName, force: appParams.force ?? false)
            return StepExecutionResult(
                output: .success("Quit application: \(appName)"),
                snapshotId: nil)

        case "hide":
            try await self.applicationService.hideApplication(identifier: appName)
            return StepExecutionResult(
                output: .success("Hidden application: \(appName)"),
                snapshotId: nil)

        case "show":
            try await self.applicationService.unhideApplication(identifier: appName)
            return StepExecutionResult(
                output: .success("Shown application: \(appName)"),
                snapshotId: nil)

        case "focus":
            try await self.applicationService.activateApplication(identifier: appName)
            return StepExecutionResult(
                output: .success("Focused application: \(appName)"),
                snapshotId: nil)

        default:
            throw PeekabooError.invalidInput(field: "action", reason: "Invalid action '\(action)' for app command")
        }
    }

    func executeClipboardCommand(_ step: ScriptStep) async throws -> StepExecutionResult {
        guard case let .clipboard(clipboardParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for clipboard command")
        }

        let action = clipboardParams.action.lowercased()
        let slot = clipboardParams.slot ?? "0"

        switch action {
        case "clear":
            self.clipboardService.clear()
            return StepExecutionResult(output: .success("Cleared clipboard."), snapshotId: nil)

        case "save":
            try self.clipboardService.save(slot: slot)
            return StepExecutionResult(output: .success("Saved clipboard to slot \"\(slot)\"."), snapshotId: nil)

        case "restore":
            let result = try self.clipboardService.restore(slot: slot)
            return StepExecutionResult(
                output: .data([
                    "slot": .success(slot),
                    "uti": .success(result.utiIdentifier),
                    "bytes": .success("\(result.data.count)"),
                    "textPreview": .success(result.textPreview),
                ]),
                snapshotId: nil)

        case "get":
            let preferUTI: UTType? = clipboardParams.prefer.flatMap { UTType($0) }
            guard let result = try self.clipboardService.get(prefer: preferUTI) else {
                return StepExecutionResult(output: .success("Clipboard is empty."), snapshotId: nil)
            }

            if let outputPath = clipboardParams.output {
                try result.data.write(to: URL(fileURLWithPath: outputPath))
                return StepExecutionResult(
                    output: .data([
                        "output": .success(outputPath),
                        "uti": .success(result.utiIdentifier),
                        "bytes": .success("\(result.data.count)"),
                        "textPreview": .success(result.textPreview),
                    ]),
                    snapshotId: nil)
            }

            return StepExecutionResult(
                output: .data([
                    "uti": .success(result.utiIdentifier),
                    "bytes": .success("\(result.data.count)"),
                    "textPreview": .success(result.textPreview),
                ]),
                snapshotId: nil)

        case "set", "load":
            let allowLarge = clipboardParams.allowLarge ?? false
            let alsoText = clipboardParams.alsoText

            if let text = clipboardParams.text {
                let request = try ClipboardPayloadBuilder.textRequest(
                    text: text,
                    alsoText: alsoText,
                    allowLarge: allowLarge)
                let result = try self.clipboardService.set(request)
                return StepExecutionResult(
                    output: .data([
                        "uti": .success(result.utiIdentifier),
                        "bytes": .success("\(result.data.count)"),
                        "textPreview": .success(result.textPreview),
                    ]),
                    snapshotId: nil)
            }

            if let filePath = clipboardParams.filePath {
                let url = URL(fileURLWithPath: filePath)
                let data = try Data(contentsOf: url)
                let uti = clipboardParams.uti
                    ?? UTType(filenameExtension: url.pathExtension)?.identifier
                    ?? UTType.data.identifier
                let request = ClipboardPayloadBuilder.dataRequest(
                    data: data,
                    utiIdentifier: uti,
                    alsoText: alsoText,
                    allowLarge: allowLarge)
                let result = try self.clipboardService.set(request)
                return StepExecutionResult(
                    output: .data([
                        "filePath": .success(filePath),
                        "uti": .success(result.utiIdentifier),
                        "bytes": .success("\(result.data.count)"),
                        "textPreview": .success(result.textPreview),
                    ]),
                    snapshotId: nil)
            }

            if let dataBase64 = clipboardParams.dataBase64, let uti = clipboardParams.uti {
                let request = try ClipboardPayloadBuilder.base64Request(
                    base64: dataBase64,
                    utiIdentifier: uti,
                    alsoText: alsoText,
                    allowLarge: allowLarge)
                let result = try self.clipboardService.set(request)
                return StepExecutionResult(
                    output: .data([
                        "uti": .success(result.utiIdentifier),
                        "bytes": .success("\(result.data.count)"),
                        "textPreview": .success(result.textPreview),
                    ]),
                    snapshotId: nil)
            }

            throw ClipboardServiceError.writeFailed(
                "Provide text, file-path/image-path, or data-base64+uti to set the clipboard.")

        default:
            throw PeekabooError.invalidInput(field: "action", reason: "Unknown clipboard action: \(action)")
        }
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

        let appsOutput = try await applicationService.listApplications()
        var allWindows: [ServiceWindowInfo] = []
        for app in appsOutput.data.applications {
            let appWindows = try await windowManagementService.listWindows(target: .application(app.name))
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
