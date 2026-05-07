import Foundation
import PeekabooAutomation

enum MCPInteractionTargetError: LocalizedError {
    case windowIndexRequiresApp
    case invalidWindowId

    var errorDescription: String? {
        switch self {
        case .windowIndexRequiresApp:
            "window_index requires app (or pid) so the index can be resolved deterministically."
        case .invalidWindowId:
            "window_id must be a positive integer."
        }
    }
}

struct MCPInteractionTarget {
    let app: String?
    let pid: Int?
    let windowTitle: String?
    let windowIndex: Int?
    let windowId: Int?

    var appIdentifier: String? {
        if let pid {
            return "PID:\(pid)"
        }
        return self.app
    }

    func validate() throws {
        if let windowId, windowId <= 0 {
            throw MCPInteractionTargetError.invalidWindowId
        }

        let hasTitle = !(self.windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        if self.windowIndex != nil, !hasTitle, self.appIdentifier?.isEmpty ?? true {
            throw MCPInteractionTargetError.windowIndexRequiresApp
        }
    }

    func toWindowTarget() throws -> WindowTarget? {
        try self.validate()

        if let windowId {
            return .windowId(windowId)
        }

        if let title = self.windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            if let appId = self.appIdentifier, !appId.isEmpty {
                return .applicationAndTitle(app: appId, title: title)
            }
            return .title(title)
        }

        if let windowIndex {
            return .index(app: self.appIdentifier ?? "", index: windowIndex)
        }

        if let appId = self.appIdentifier, !appId.isEmpty {
            return .application(appId)
        }

        return nil
    }

    func focusIfRequested(windows: any WindowManagementServiceProtocol) async throws -> WindowTarget? {
        let target = try self.toWindowTarget()
        guard let target else { return nil }
        try await windows.focusWindow(target: target)
        return target
    }

    func resolveWindowTitleIfNeeded(windows: any WindowManagementServiceProtocol) async throws -> String? {
        if let windowTitle, !windowTitle.isEmpty {
            return windowTitle
        }

        // Only attempt a lookup when the user used an ID/index selector.
        guard self.windowId != nil || self.windowIndex != nil else { return nil }
        guard let target = try self.toWindowTarget() else { return nil }

        let windowsInfo = try await windows.listWindows(target: target)
        return windowsInfo.first?.title
    }
}
