import Commander
import CoreGraphics
import PeekabooCore

enum FocusTargetRequest: Equatable, Sendable {
    case windowId(CGWindowID)
    case bestWindow(applicationName: String, windowTitle: String?)
}

enum FocusTargetResolver {
    static func resolve(
        windowID: CGWindowID?,
        snapshot: UIAutomationSnapshot?,
        applicationName: String?,
        windowTitle: String?
    ) -> FocusTargetRequest? {
        if let windowID {
            return .windowId(windowID)
        }

        if let snapshotWindowID = snapshot?.windowID {
            return .windowId(snapshotWindowID)
        }

        let resolvedApplicationName =
            applicationName ?? snapshot?.applicationBundleId ?? snapshot?.applicationName
        let resolvedWindowTitle = windowTitle ?? snapshot?.windowTitle

        if let resolvedApplicationName {
            return .bestWindow(applicationName: resolvedApplicationName, windowTitle: resolvedWindowTitle)
        }

        return nil
    }
}

/// Ensure the target window is focused before executing a command.
func ensureFocused(
    snapshotId: String? = nil,
    windowID: CGWindowID? = nil,
    applicationName: String? = nil,
    windowTitle: String? = nil,
    options: any FocusOptionsProtocol,
    services: any PeekabooServiceProviding
) async throws {
    guard options.autoFocus else {
        return
    }

    let focusService = FocusManagementActor.shared

    let snapshot = if let snapshotId {
        try await services.snapshots.getUIAutomationSnapshot(snapshotId: snapshotId)
    } else {
        nil as UIAutomationSnapshot?
    }

    let targetRequest = FocusTargetResolver.resolve(
        windowID: windowID,
        snapshot: snapshot,
        applicationName: applicationName,
        windowTitle: windowTitle
    )

    let targetWindow: CGWindowID? = switch targetRequest {
    case let .windowId(windowID):
        windowID
    case let .bestWindow(applicationName, windowTitle):
        try await focusService.findBestWindow(applicationName: applicationName, windowTitle: windowTitle)
    case nil:
        nil
    }

    guard let windowID = targetWindow else {
        return
    }

    let focusOptions = FocusManagementService.FocusOptions(
        timeout: options.focusTimeout ?? 5.0,
        retryCount: options.focusRetryCount ?? 3,
        switchSpace: options.spaceSwitch,
        bringToCurrentSpace: options.bringToCurrentSpace
    )

    do {
        try await focusService.focusWindow(windowID: windowID, options: focusOptions)
    } catch let error as FocusError {
        switch error {
        case .windowNotFound, .axElementNotFound:
            var fallbackErrors: [any Error] = []
            var fallbackTargets: [WindowTarget] = [.windowId(Int(windowID))]
            if let applicationName {
                fallbackTargets.append(.application(applicationName))
            }
            fallbackTargets.append(.frontmost)

            for target in fallbackTargets {
                do {
                    try await WindowServiceBridge.focusWindow(windows: services.windows, target: target)
                    return
                } catch {
                    fallbackErrors.append(error)
                }
            }

            if let appName = applicationName {
                do {
                    try await services.applications.activateApplication(identifier: appName)
                    return
                } catch {
                    fallbackErrors.append(error)
                }
            }

            throw fallbackErrors.last ?? error
        default:
            throw error
        }
    }
}

/// Ensure focus using shared interaction target flags (`--app/--pid/--window-title/--window-index`).
func ensureFocused(
    snapshotId: String? = nil,
    target: InteractionTargetOptions,
    options: any FocusOptionsProtocol,
    services: any PeekabooServiceProviding
) async throws {
    let windowID = try await target.resolveWindowID(services: services)
    let appIdentifier = try target.resolveApplicationIdentifierOptional()
    try await ensureFocused(
        snapshotId: snapshotId,
        windowID: windowID,
        applicationName: appIdentifier,
        windowTitle: target.windowTitle,
        options: options,
        services: services
    )
}

@MainActor
final class FocusManagementActor {
    static let shared = FocusManagementActor()

    private let inner = FocusManagementService()

    func findBestWindow(applicationName: String, windowTitle: String?) async throws -> CGWindowID? {
        try await self.inner.findBestWindow(applicationName: applicationName, windowTitle: windowTitle)
    }

    func focusWindow(windowID: CGWindowID, options: FocusManagementService.FocusOptions) async throws {
        try await self.inner.focusWindow(windowID: windowID, options: options)
    }
}
