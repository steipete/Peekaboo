import Foundation
import PeekabooFoundation

@MainActor
extension ProcessService {
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
}
