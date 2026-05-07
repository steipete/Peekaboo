import AppKit
import Foundation
import os
import PeekabooFoundation

/// Dock-specific errors
public enum DockError: Error {
    case dockNotFound
    case dockListNotFound
    case itemNotFound(String)
    case menuItemNotFound(String)
    case positionNotFound
    case launchFailed(String)
    case scriptError(String)
}

/// Default implementation of Dock interaction operations using AXorcist
@MainActor
public final class DockService: DockServiceProtocol {
    let feedbackClient: any AutomationFeedbackClient
    let logger = Logger(subsystem: "boo.peekaboo.core", category: "DockService")

    public init(feedbackClient: any AutomationFeedbackClient = NoopAutomationFeedbackClient()) {
        self.feedbackClient = feedbackClient
        Task { @MainActor in
            self.feedbackClient.connect()
        }
    }

    public func listDockItems(includeAll: Bool = false) async throws -> [DockItem] {
        try await self.listDockItemsImpl(includeAll: includeAll)
    }

    public func launchFromDock(appName: String) async throws {
        try await self.launchFromDockImpl(appName: appName)
    }

    public func addToDock(path: String, persistent: Bool = true) async throws {
        try await self.addToDockImpl(path: path, persistent: persistent)
    }

    public func removeFromDock(appName: String) async throws {
        try await self.removeFromDockImpl(appName: appName)
    }

    public func rightClickDockItem(appName: String, menuItem: String?) async throws {
        try await self.rightClickDockItemImpl(appName: appName, menuItem: menuItem)
    }

    public func hideDock() async throws {
        try await self.hideDockImpl()
    }

    public func showDock() async throws {
        try await self.showDockImpl()
    }

    public func isDockAutoHidden() async -> Bool {
        await self.isDockAutoHiddenImpl()
    }

    public func findDockItem(name: String) async throws -> DockItem {
        try await self.findDockItemImpl(name: name)
    }
}
