import Algorithms
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

@MainActor
extension ImageCommand {
    func performCapture() async throws -> [SavedFile] {
        if let appName = self.app?.lowercased() {
            switch appName {
            case "menubar":
                return try await self.captureMenuBar()
            case "frontmost":
                return try await self.captureFrontmost()
            default:
                break
            }
        }

        let captureMode = self.determineMode()
        var results: [SavedFile] = []

        switch captureMode {
        case .screen:
            results = try await self.captureScreens()
        case .window:
            if let windowId = self.windowId {
                results = try await self.captureWindowById(windowId)
            } else {
                let identifier = try self.resolveApplicationIdentifier()
                results = try await self.captureApplicationWindow(identifier)
            }
        case .multi:
            if self.app != nil || self.pid != nil {
                let identifier = try self.resolveApplicationIdentifier()
                results = try await self.captureAllApplicationWindows(identifier)
            } else {
                results = try await self.captureScreens()
            }
        case .frontmost:
            results = try await self.captureFrontmost()
        case .area:
            throw ValidationError("Area capture mode is not implemented. Use --mode screen or --mode window instead.")
        }

        return results
    }

    private func determineMode() -> PeekabooCore.CaptureMode {
        if let mode {
            return mode
        }

        if self.app != nil || self.pid != nil || self.windowTitle != nil || self.windowIndex != nil || self
            .windowId != nil {
            return .window
        }

        return .frontmost
    }

    private func captureWindowById(_ windowId: Int) async throws -> [SavedFile] {
        let observation = try await self.captureObservation(
            target: .windowID(CGWindowID(windowId)),
            preferredName: "window-\(windowId)",
            index: nil
        )

        let title = observation.capture.metadata.windowInfo?.title
        let preferredName = if let title, !title.isEmpty {
            title
        } else {
            "window-\(windowId)"
        }

        return try [
            self.savedFile(
                from: observation,
                preferredName: preferredName,
                windowIndex: nil
            ),
        ]
    }

    private func captureScreens() async throws -> [SavedFile] {
        if let index = self.screenIndex {
            let observation = try await self.captureObservation(
                target: .screen(index: index),
                preferredName: "screen\(index)",
                index: nil
            )
            return try [
                self.savedFile(
                    from: observation,
                    preferredName: "screen\(index)",
                    windowIndex: nil
                ),
            ]
        }

        let screens = self.services.screens.listScreens()
        let indexes = screens.isEmpty ? [0] : Array(screens.indices)

        var savedFiles: [SavedFile] = []
        for (ordinal, displayIndex) in indexes.indexed() {
            let observation = try await self.captureObservation(
                target: .screen(index: displayIndex),
                preferredName: "screen\(displayIndex)",
                index: ordinal
            )
            try savedFiles.append(self.savedFile(
                from: observation,
                preferredName: "screen\(displayIndex)",
                windowIndex: nil
            ))
        }

        return savedFiles
    }

    private func captureApplicationWindow(_ identifier: String) async throws -> [SavedFile] {
        try await self.focusIfNeeded(appIdentifier: identifier)
        let observation = try await self.captureObservation(
            target: .app(identifier: identifier, window: self.observationWindowSelection),
            preferredName: identifier,
            index: nil
        )
        let resolvedWindow = observation.target.window
        let resolvedTitle = resolvedWindow?.title.trimmingCharacters(in: .whitespacesAndNewlines)

        let saved = try self.savedFile(
            from: observation,
            preferredName: self.windowTitle ?? (resolvedTitle?.isEmpty == false ? resolvedTitle : nil) ?? identifier,
            windowIndex: resolvedWindow?.index
        )

        return [saved]
    }

    private func captureAllApplicationWindows(_ identifier: String) async throws -> [SavedFile] {
        try await self.focusIfNeeded(appIdentifier: identifier)

        let windows = try await WindowServiceBridge.listWindows(
            windows: self.services.windows,
            target: .application(identifier)
        )

        let filtered = ObservationTargetResolver.captureCandidates(from: windows)

        guard !filtered.isEmpty else {
            throw PeekabooError.windowNotFound(criteria: "No shareable windows for \(identifier)")
        }

        var savedFiles: [SavedFile] = []
        for (ordinal, window) in filtered.indexed() {
            let observation = try await self.captureObservation(
                target: .windowID(CGWindowID(window.windowID)),
                preferredName: window.title,
                index: ordinal
            )

            let saved = try self.savedFile(
                from: observation,
                preferredName: window.title,
                windowIndex: window.index
            )
            savedFiles.append(saved)
        }

        return savedFiles
    }

    private func captureFrontmost() async throws -> [SavedFile] {
        let observation = try await self.captureObservation(
            target: .frontmost,
            preferredName: "frontmost",
            index: nil
        )
        return try [
            self.savedFile(
                from: observation,
                preferredName: "frontmost",
                windowIndex: nil
            ),
        ]
    }

    private func captureMenuBar() async throws -> [SavedFile] {
        let observation = try await self.captureObservation(
            target: .menubar,
            preferredName: "menubar",
            index: nil
        )
        return try [
            self.savedFile(
                from: observation,
                preferredName: "menubar",
                windowIndex: nil
            ),
        ]
    }

    private func captureObservation(
        target: DesktopObservationTargetRequest,
        preferredName: String?,
        index: Int?
    ) async throws -> DesktopObservationResult {
        let url = self.makeOutputURL(preferredName: preferredName, index: index)

        return try await self.services.desktopObservation.observe(self.makeObservationRequest(
            target: target,
            outputURL: url
        ))
    }

    private func savedFile(
        from observation: DesktopObservationResult,
        preferredName: String?,
        windowIndex: Int?
    ) throws -> SavedFile {
        guard let path = observation.files.rawScreenshotPath else {
            throw CaptureError.captureFailure("Observation completed without a saved screenshot path")
        }

        let windowInfo = observation.capture.metadata.windowInfo
        return SavedFile(
            path: path,
            item_label: preferredName ?? windowInfo?.title,
            window_title: windowInfo?.title,
            window_id: windowInfo.map { UInt32($0.windowID) },
            window_index: windowIndex ?? windowInfo?.index,
            mime_type: self.format.mimeType
        )
    }

    private func makeOutputURL(preferredName: String?, index: Int?) -> URL {
        if let explicit = self.path {
            let expanded = (explicit as NSString).expandingTildeInPath
            var url = URL(fileURLWithPath: expanded)
            let directory = url.deletingLastPathComponent()
            var stem = url.deletingPathExtension().lastPathComponent
            var ext = url.pathExtension

            if ext.isEmpty {
                ext = self.format.fileExtension
            }

            if let index, index > 0 {
                stem += "_\(index)"
            }

            url = directory.appendingPathComponent(stem).appendingPathExtension(ext)
            return url
        }

        let timestamp = Self.filenameDateFormatter.string(from: Date())
        var components: [String] = []
        if let preferred = preferredName {
            components.append(self.sanitizeFilenameComponent(preferred))
        } else if let appName = self.app {
            components.append(self.sanitizeFilenameComponent(appName))
        } else if let mode = self.mode {
            components.append(mode.rawValue)
        } else {
            components.append("capture")
        }
        components.append(timestamp)
        if let index, index > 0 {
            components.append(String(index))
        }

        let filename = components.joined(separator: "_") + ".\(self.format.fileExtension)"
        let base = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return base.appendingPathComponent(filename)
    }

    private func sanitizeFilenameComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private func focusIfNeeded(appIdentifier: String) async throws {
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

    private static let filenameDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
