import Foundation
import PeekabooCore

@MainActor
extension ImageCommand {
    func focusIfNeeded(appIdentifier: String) async throws {
        switch self.captureFocus {
        case .background:
            return
        case .auto:
            if await self.hasVisibleCaptureWindow(appIdentifier: appIdentifier) {
                return
            }
            if self.windowTitle == nil, await self.isAlreadyFrontmost(appIdentifier: appIdentifier) {
                return
            }
            let focusIdentifier = await self.resolveFocusIdentifier(appIdentifier: appIdentifier)
            let options = FocusOptions(autoFocus: true, spaceSwitch: false, bringToCurrentSpace: false)
            try await ensureFocused(
                applicationName: focusIdentifier,
                windowTitle: self.windowTitle,
                options: options,
                services: self.services
            )
        case .foreground:
            let focusIdentifier = await self.resolveFocusIdentifier(appIdentifier: appIdentifier)
            let options = FocusOptions(autoFocus: true, spaceSwitch: true, bringToCurrentSpace: true)
            try await ensureFocused(
                applicationName: focusIdentifier,
                windowTitle: self.windowTitle,
                options: options,
                services: self.services
            )
        }
    }

    private func hasVisibleCaptureWindow(appIdentifier: String) async -> Bool {
        guard let app = try? await self.services.applications.findApplication(identifier: appIdentifier) else {
            return false
        }

        let lookupIdentifier = app.bundleIdentifier ?? app.name
        guard let response = try? await self.services.applications.listWindows(for: lookupIdentifier, timeout: 1) else {
            return false
        }

        // Auto focus should not block fast background captures when the app already exposes
        // a renderable window; explicit foreground mode still opts into forced activation.
        let candidates = ObservationTargetResolver.captureCandidates(from: response.data.windows)
        guard !candidates.isEmpty else {
            return false
        }

        guard let windowTitle = self.windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !windowTitle.isEmpty
        else {
            return true
        }

        return candidates.contains {
            $0.title.localizedCaseInsensitiveContains(windowTitle)
        }
    }

    private func isAlreadyFrontmost(appIdentifier: String) async -> Bool {
        guard let frontmost = try? await self.services.applications.getFrontmostApplication(),
              let target = try? await self.services.applications.findApplication(identifier: appIdentifier)
        else {
            return false
        }

        return frontmost.processIdentifier == target.processIdentifier
    }

    private func resolveFocusIdentifier(appIdentifier: String) async -> String {
        guard let app = try? await self.services.applications.findApplication(identifier: appIdentifier) else {
            return appIdentifier
        }
        return "PID:\(app.processIdentifier)"
    }
}
