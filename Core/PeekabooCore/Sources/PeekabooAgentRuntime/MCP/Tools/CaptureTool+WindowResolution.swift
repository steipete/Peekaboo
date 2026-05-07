import Foundation
import PeekabooAutomation
import PeekabooAutomationKit
import PeekabooFoundation

enum CaptureToolWindowResolver {
    static func scope(
        app: String?,
        pid: Int?,
        windowTitle: String?,
        windowIndex: Int?,
        windows: any WindowManagementServiceProtocol) async throws -> CaptureScope
    {
        let appIdentifier = CaptureToolArgumentResolver.applicationIdentifier(app: app, pid: pid)
        let title = self.normalizedTitle(windowTitle)

        guard title != nil || windowIndex != nil else {
            return CaptureScope(kind: .window, applicationIdentifier: appIdentifier, windowIndex: nil)
        }

        guard let selectedWindow = try await self.selectWindow(
            appIdentifier: appIdentifier,
            hasExplicitApp: self.hasExplicitApplication(app: app, pid: pid),
            title: title,
            index: windowIndex,
            windows: windows)
        else {
            if let title {
                throw PeekabooError.windowNotFound(criteria: "window title '\(title)'")
            }
            throw PeekabooError.windowNotFound(criteria: "window index \(windowIndex ?? 0) for \(appIdentifier)")
        }

        // The watch loop captures repeatedly; resolve human selectors once so frame acquisition is by stable CG ID.
        return CaptureScope(
            kind: .window,
            windowId: UInt32(exactly: selectedWindow.windowID),
            applicationIdentifier: appIdentifier,
            windowIndex: selectedWindow.index)
    }

    private static func selectWindow(
        appIdentifier: String,
        hasExplicitApp: Bool,
        title: String?,
        index: Int?,
        windows: any WindowManagementServiceProtocol) async throws -> ServiceWindowInfo?
    {
        if let title, hasExplicitApp {
            let candidates = try await self.captureCandidates(
                target: .application(appIdentifier),
                windows: windows)
            return candidates.first { $0.title.localizedCaseInsensitiveContains(title) }
        }

        if let title {
            let candidates = try await self.captureCandidates(
                target: .title(title),
                windows: windows)
            return candidates.first { $0.title.localizedCaseInsensitiveContains(title) }
        }

        guard let index else { return nil }
        guard hasExplicitApp else { return nil }

        let candidates = try await self.captureCandidates(
            target: .application(appIdentifier),
            windows: windows)
        return candidates.first { $0.index == index }
    }

    private static func captureCandidates(
        target: WindowTarget,
        windows: any WindowManagementServiceProtocol) async throws -> [ServiceWindowInfo]
    {
        let listed = try await windows.listWindows(target: target)
        return ObservationTargetResolver.captureCandidates(from: listed)
    }

    private static func normalizedTitle(_ title: String?) -> String? {
        guard let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func hasExplicitApplication(app: String?, pid: Int?) -> Bool {
        if pid != nil { return true }
        return !(app?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
}
