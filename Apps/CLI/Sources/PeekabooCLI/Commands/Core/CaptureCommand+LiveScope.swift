import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

@MainActor
extension CaptureLiveCommand {
    func resolveScope() async throws -> CaptureScope {
        let mode = try self.resolveMode()
        switch mode {
        case .screen:
            let displayInfo = try await self.displayInfo(for: self.screenIndex)
            return CaptureScope(
                kind: .screen,
                screenIndex: displayInfo?.index,
                displayUUID: displayInfo?.uuid,
                windowId: nil,
                applicationIdentifier: nil,
                windowIndex: nil,
                region: nil
            )
        case .frontmost:
            return CaptureScope(
                kind: .frontmost,
                screenIndex: nil,
                displayUUID: nil,
                windowId: nil,
                applicationIdentifier: nil,
                windowIndex: nil,
                region: nil
            )
        case .window:
            let identifier = try self.resolveApplicationIdentifier()
            let windowReference = try await self.resolveWindowReference(for: identifier)
            return CaptureScope(
                kind: .window,
                screenIndex: nil,
                displayUUID: nil,
                windowId: windowReference.windowID,
                applicationIdentifier: identifier,
                windowIndex: windowReference.windowIndex,
                region: nil
            )
        case .area:
            let rect = try self.parseRegion()
            return CaptureScope(kind: .region, region: rect)
        case .multi:
            throw ValidationError("capture live does not support multi-mode captures")
        }
    }

    /// Exposed internally for tests.
    func resolveMode() throws -> LiveCaptureMode {
        if let explicit = self.mode {
            let normalized = explicit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized == "region" { return .area }
            guard let mode = LiveCaptureMode(rawValue: normalized) else {
                throw ValidationError(
                    "Unsupported capture live mode '\(explicit)'. Use screen, window, frontmost, or area."
                )
            }
            return mode
        }
        if self.region != nil { return .area }
        if self.app != nil || self.pid != nil || self.windowTitle != nil || self.windowIndex != nil { return .window }
        return .frontmost
    }

    func parseRegion() throws -> CGRect {
        guard let region = self.region?.trimmingCharacters(in: .whitespacesAndNewlines),
              !region.isEmpty
        else {
            throw PeekabooError.invalidInput("Region must be provided when --mode area is set")
        }
        let parts = region
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 4,
              let x = Double(parts[0]),
              let y = Double(parts[1]),
              let width = Double(parts[2]),
              let height = Double(parts[3])
        else {
            throw PeekabooError.invalidInput("Region must be x,y,width,height")
        }
        guard width > 0, height > 0 else {
            throw PeekabooError.invalidInput("Region width and height must be greater than zero")
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func displayInfo(for index: Int?) async throws -> (index: Int, uuid: String)? {
        guard let index else { return nil }
        let screens = self.services.screens.listScreens()
        guard let match = screens.first(where: { $0.index == index }) else {
            throw PeekabooError.invalidInput("Screen index \(index) not found")
        }
        return (index, "\(match.displayID)")
    }

    private func resolveWindowReference(for identifier: String) async throws -> (windowID: UInt32?, windowIndex: Int?) {
        guard self.windowTitle != nil || self.windowIndex != nil else {
            return (nil, nil)
        }

        let windows = try await WindowServiceBridge.listWindows(
            windows: self.services.windows,
            target: .application(identifier)
        )
        let renderable = ObservationTargetResolver.captureCandidates(from: windows)

        // Freeze explicit title/index selections to a stable window ID before the watch loop starts.
        let selectedWindow: ServiceWindowInfo? = if let title = self.windowTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !title.isEmpty {
            renderable.first { $0.title.localizedCaseInsensitiveContains(title) }
        } else if let explicitIndex = self.windowIndex {
            renderable.first { $0.index == explicitIndex }
        } else {
            nil
        }

        guard let selectedWindow else {
            let criteria = self.windowTitle.map { "window title '\($0)' for \(identifier)" }
                ?? self.windowIndex.map { "window index \($0) for \(identifier)" }
                ?? "window for \(identifier)"
            throw PeekabooError.windowNotFound(criteria: criteria)
        }

        return (
            windowID: UInt32(exactly: selectedWindow.windowID),
            windowIndex: selectedWindow.index
        )
    }
}
