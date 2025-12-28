import CoreGraphics
import Foundation
import PeekabooCore

@MainActor
extension SeeCommand {
    private func captureMenuBar() async throws -> CaptureResult {
        let rect = try self.menuBarRect()
        return try await ScreenCaptureBridge.captureArea(services: self.services, rect: rect)
    }

    struct MenuBarPopoverContext {
        let extras: [MenuExtraInfo]
        let ownerPidSet: Set<pid_t>
        let canFilterByOwnerPid: Bool
        let appHint: String?
        let hintExtra: MenuExtraInfo?
        let openExtra: MenuExtraInfo?
        let preferredExtra: MenuExtraInfo?
        let preferredOwnerName: String?
        let preferredOwnerPid: pid_t?
        let preferredX: CGFloat?

        var shouldRelaxFilter: Bool {
            self.openExtra != nil || self.appHint != nil
        }

        var hintName: String? {
            self.appHint ?? self.preferredExtra?.title ?? self.preferredExtra?.ownerName
        }
    }

    struct MenuBarCandidateState {
        var candidates: [MenuBarPopoverCandidate]
        var windowList: [[String: Any]]
        var usedFilteredWindowList: Bool
    }

    func captureMenuBarPopover(allowAreaFallback: Bool = false) async throws -> MenuBarPopoverCapture? {
        let context = try await self.makeMenuBarPopoverContext()
        self.logOpenMenuExtraIfNeeded(context)

        guard let windowList = self.menuBarWindowList() else { return nil }

        var state = self.resolveInitialCandidates(context: context, windowList: windowList)
        state = self.relaxCandidatesIfNeeded(
            context: context,
            fullWindowList: windowList,
            state: state
        )
        state = self.applyOwnerNameFallbackIfNeeded(
            context: context,
            fullWindowList: windowList,
            state: state
        )

        if state.candidates.isEmpty {
            if let capture = try await self.fallbackCaptureForEmptyCandidates(
                context: context,
                windowList: windowList,
                state: &state
            ) {
                return capture
            }
        }

        guard !state.candidates.isEmpty else { return nil }

        return try await self.capturePopoverFromCandidates(
            context: context,
            allowAreaFallback: allowAreaFallback,
            state: state
        )
    }

    private func makeMenuBarPopoverContext() async throws -> MenuBarPopoverContext {
        let extras = try await self.services.menu.listMenuExtras()
        let ownerPidSet = Set(extras.compactMap(\.ownerPID))
        let canFilterByOwnerPid = !ownerPidSet.isEmpty

        let appHint = self.menuBarAppHint()
        let hintExtra = self.resolveMenuExtraHint(appHint: appHint, extras: extras)
        let openExtra = try await self.resolveOpenMenuExtra(from: extras)

        let preferredExtra = appHint != nil ? (hintExtra ?? openExtra) : (openExtra ?? hintExtra)
        let preferredOwnerName = appHint ?? preferredExtra?.ownerName ?? preferredExtra?.title
        let preferredX = preferredExtra?.position.x
        let preferredOwnerPid = preferredExtra?.ownerPID

        return MenuBarPopoverContext(
            extras: extras,
            ownerPidSet: ownerPidSet,
            canFilterByOwnerPid: canFilterByOwnerPid,
            appHint: appHint,
            hintExtra: hintExtra,
            openExtra: openExtra,
            preferredExtra: preferredExtra,
            preferredOwnerName: preferredOwnerName,
            preferredOwnerPid: preferredOwnerPid,
            preferredX: preferredX
        )
    }

    private func logOpenMenuExtraIfNeeded(_ context: MenuBarPopoverContext) {
        guard let openExtra = context.openExtra, let openPid = openExtra.ownerPID else { return }
        self.logger.verbose(
            "Detected open menu extra",
            category: "Capture",
            metadata: [
                "title": openExtra.title,
                "ownerPID": openPid
            ]
        )
    }

    private func fallbackCaptureForEmptyCandidates(
        context: MenuBarPopoverContext,
        windowList: [[String: Any]],
        state: inout MenuBarCandidateState
    ) async throws -> MenuBarPopoverCapture? {
        if let openMenuCapture = try await self.captureMenuBarPopoverFromOpenMenu(
            openExtra: context.openExtra ?? context.hintExtra,
            appHint: context.appHint
        ) {
            return openMenuCapture
        }

        if let preferredX = context.preferredX {
            let bandCandidates = self.menuBarPopoverCandidatesByBand(
                windowList: windowList,
                preferredX: preferredX
            )
            if !bandCandidates.isEmpty {
                state.candidates = bandCandidates
                state.windowList = windowList
                state.usedFilteredWindowList = false
            }
        }

        return nil
    }

    private func capturePopoverFromCandidates(
        context: MenuBarPopoverContext,
        allowAreaFallback: Bool,
        state: MenuBarCandidateState
    ) async throws -> MenuBarPopoverCapture? {
        let windowInfoMap = self.windowInfoById(from: state.windowList)

        if let hintName = context.hintName,
           state.candidates.count > 1,
           let ocrCapture = try await self.captureMenuBarPopoverByOCR(
               candidates: state.candidates,
               windowInfoById: windowInfoMap,
               hint: hintName,
               preferredOwnerName: context.preferredOwnerName,
               preferredX: context.preferredX
           ) {
            return ocrCapture
        }

        if context.openExtra != nil || allowAreaFallback,
           let preferredX = context.preferredX,
           let areaCapture = try await self.captureMenuBarPopoverByArea(
               preferredX: preferredX,
               hint: context.hintName,
               ownerHint: context.preferredOwnerName
           ) {
            return areaCapture
        }

        let selectionCandidates = self.selectCandidates(
            from: state.candidates,
            preferredOwnerName: context.preferredOwnerName,
            windowInfoMap: windowInfoMap,
            openExtra: context.openExtra
        )
        guard let selectionCandidates else { return nil }

        guard let selected = MenuBarPopoverSelector.selectCandidate(
            candidates: selectionCandidates,
            windowInfoById: windowInfoMap,
            preferredOwnerName: nil,
            preferredX: context.preferredX
        ) else {
            return nil
        }

        if let info = windowInfoMap[selected.windowId] {
            self.logger.verbose(
                "Selected menu bar popover window",
                category: "Capture",
                metadata: [
                    "windowId": selected.windowId,
                    "owner": info.ownerName ?? "unknown",
                    "title": info.title ?? ""
                ]
            )
        }

        let captureResult = try await ScreenCaptureBridge.captureWindowById(
            services: self.services,
            windowId: selected.windowId
        )

        return MenuBarPopoverCapture(
            captureResult: captureResult,
            windowBounds: selected.bounds,
            windowId: selected.windowId
        )
    }
}
