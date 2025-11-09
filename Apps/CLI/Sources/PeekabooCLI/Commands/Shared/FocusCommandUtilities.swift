@preconcurrency import ArgumentParser
import CoreGraphics
import PeekabooCore

extension AsyncParsableCommand {
    /// Ensure the target window is focused before executing a command.
    @MainActor
    func ensureFocused(
        sessionId: String? = nil,
        windowID: CGWindowID? = nil,
        applicationName: String? = nil,
        windowTitle: String? = nil,
        options: any FocusOptionsProtocol = DefaultFocusOptions(),
        services: PeekabooServices) async throws
    {
        guard options.autoFocus else {
            return
        }

        let focusService = FocusManagementService()
        let targetWindow: CGWindowID?

        if let windowID {
            targetWindow = windowID
        } else if let sessionId,
        let session = try await services.sessions.getUIAutomationSession(sessionId: sessionId)
        {
            targetWindow = session.windowID
        } else if let appName = applicationName {
            targetWindow = try await focusService.findBestWindow(
                applicationName: appName,
                windowTitle: windowTitle)
        } else {
            targetWindow = nil
        }

        guard let windowID = targetWindow else {
            return
        }

        let focusOptions = FocusManagementService.FocusOptions(
            timeout: options.focusTimeout ?? 5.0,
            retryCount: options.focusRetryCount ?? 3,
            switchSpace: options.spaceSwitch,
            bringToCurrentSpace: options.bringToCurrentSpace)

        try await focusService.focusWindow(windowID: windowID, options: focusOptions)
    }
}
