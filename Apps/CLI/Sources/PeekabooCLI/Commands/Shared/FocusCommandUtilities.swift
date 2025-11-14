import Commander
import CoreGraphics
import PeekabooCore

/// Ensure the target window is focused before executing a command.
func ensureFocused(
    sessionId: String? = nil,
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
    let targetWindow: CGWindowID? = if let windowID {
        windowID
    } else if let sessionId,
              let session = try await services.sessions.getUIAutomationSession(sessionId: sessionId) {
        session.windowID
    } else if let appName = applicationName {
        try await focusService.findBestWindow(
            applicationName: appName,
            windowTitle: windowTitle
        )
    } else {
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
