import PeekabooCore

@MainActor
extension CaptureLiveCommand {
    func focusIfNeeded(appIdentifier: String) async throws {
        switch self.captureFocus {
        case .background: return
        case .auto:
            let options = FocusOptions(
                autoFocus: true,
                focusTimeout: nil,
                focusRetryCount: nil,
                spaceSwitch: false,
                bringToCurrentSpace: false
            )
            try await ensureFocused(
                applicationName: appIdentifier,
                windowTitle: self.windowTitle,
                options: options,
                services: self.services
            )
        case .foreground:
            let options = FocusOptions(
                autoFocus: true,
                focusTimeout: nil,
                focusRetryCount: nil,
                spaceSwitch: true,
                bringToCurrentSpace: true
            )
            try await ensureFocused(
                applicationName: appIdentifier,
                windowTitle: self.windowTitle,
                options: options,
                services: self.services
            )
        }
    }
}
