import CoreGraphics
import Foundation
import PeekabooCore

@MainActor
extension SeeCommand {
    func menuBarWindowSnapshot() -> ObservationMenuBarPopoverSnapshot {
        ObservationMenuBarWindowCatalog.currentPopoverSnapshot(
            screens: self.services.screens.listScreens()
        )
    }

    func resolveInitialCandidates(
        context: MenuBarPopoverContext,
        snapshot: ObservationMenuBarPopoverSnapshot
    ) -> MenuBarCandidateState {
        let filteredCandidates: [MenuBarPopoverCandidate] = if context.canFilterByOwnerPid {
            snapshot.candidates.filter { candidate in
                context.ownerPidSet.contains(candidate.ownerPID)
            }
        } else {
            snapshot.candidates
        }

        let usedFilteredWindowList = context.canFilterByOwnerPid &&
            !filteredCandidates.isEmpty &&
            filteredCandidates.count != snapshot.candidates.count
        let baseCandidates = usedFilteredWindowList ? filteredCandidates : snapshot.candidates

        var candidates = self.menuBarPopoverCandidates(
            candidates: baseCandidates,
            ownerPID: context.preferredOwnerPid
        )
        if candidates.isEmpty, context.preferredOwnerPid != nil {
            candidates = self.menuBarPopoverCandidates(
                candidates: baseCandidates,
                ownerPID: nil
            )
        }

        return MenuBarCandidateState(
            candidates: candidates,
            windowInfoMap: snapshot.windowInfoByID,
            usedFilteredWindowList: usedFilteredWindowList
        )
    }

    func relaxCandidatesIfNeeded(
        context: MenuBarPopoverContext,
        snapshot: ObservationMenuBarPopoverSnapshot,
        state: MenuBarCandidateState
    ) -> MenuBarCandidateState {
        guard state.candidates.isEmpty,
              context.shouldRelaxFilter,
              state.usedFilteredWindowList else {
            return state
        }

        self.logger.debug("Relaxing menu bar popover filter to full window list")

        var candidates = self.menuBarPopoverCandidates(
            candidates: snapshot.candidates,
            ownerPID: context.preferredOwnerPid
        )
        if candidates.isEmpty, context.preferredOwnerPid != nil {
            candidates = self.menuBarPopoverCandidates(
                candidates: snapshot.candidates,
                ownerPID: nil
            )
        }

        return MenuBarCandidateState(
            candidates: candidates,
            windowInfoMap: snapshot.windowInfoByID,
            usedFilteredWindowList: false
        )
    }

    func applyOwnerNameFallbackIfNeeded(
        context: MenuBarPopoverContext,
        snapshot: ObservationMenuBarPopoverSnapshot,
        state: MenuBarCandidateState
    ) -> MenuBarCandidateState {
        guard let preferredOwnerName = context.preferredOwnerName,
              !preferredOwnerName.isEmpty,
              state.usedFilteredWindowList else {
            return state
        }

        let normalized = preferredOwnerName.lowercased()
        let ownerMatches = state.candidates.filter { candidate in
            let ownerName = state.windowInfoMap[candidate.windowId]?.ownerName?.lowercased() ?? ""
            return ownerName == normalized || ownerName.contains(normalized)
        }
        guard ownerMatches.isEmpty else { return state }

        var candidates = self.menuBarPopoverCandidates(
            candidates: snapshot.candidates,
            ownerPID: context.preferredOwnerPid
        )
        if candidates.isEmpty, context.preferredOwnerPid != nil {
            candidates = self.menuBarPopoverCandidates(
                candidates: snapshot.candidates,
                ownerPID: nil
            )
        }

        return MenuBarCandidateState(
            candidates: candidates,
            windowInfoMap: snapshot.windowInfoByID,
            usedFilteredWindowList: false
        )
    }

    func selectCandidates(
        from candidates: [MenuBarPopoverCandidate],
        preferredOwnerName: String?,
        windowInfoMap: [Int: MenuBarPopoverWindowInfo],
        openExtra: MenuExtraInfo?
    ) -> [MenuBarPopoverCandidate]? {
        guard let preferredOwnerName, !preferredOwnerName.isEmpty else { return candidates }
        let normalized = preferredOwnerName.lowercased()
        let ownerMatches = candidates.filter { candidate in
            let ownerName = windowInfoMap[candidate.windowId]?.ownerName?.lowercased() ?? ""
            return ownerName == normalized || ownerName.contains(normalized)
        }
        if !ownerMatches.isEmpty {
            return ownerMatches
        }
        return openExtra == nil ? nil : candidates
    }

    private func menuBarPopoverCandidates(
        candidates: [MenuBarPopoverCandidate],
        ownerPID: pid_t?
    ) -> [MenuBarPopoverCandidate] {
        guard let ownerPID else { return candidates }
        return candidates.filter { $0.ownerPID == ownerPID }
    }

    func menuBarPopoverCandidatesByBand(
        snapshot _: ObservationMenuBarPopoverSnapshot,
        preferredX: CGFloat
    ) -> [MenuBarPopoverCandidate] {
        ObservationMenuBarWindowCatalog.currentBandCandidates(
            preferredX: preferredX,
            screens: self.services.screens.listScreens()
        )
    }

    func menuBarAppHint() -> String? {
        guard let app = self.app?.trimmingCharacters(in: .whitespacesAndNewlines),
              !app.isEmpty else {
            return nil
        }
        let lower = app.lowercased()
        if lower == "menubar" || lower == "frontmost" {
            return nil
        }
        return app
    }

    func resolveMenuExtraHint(
        appHint: String?,
        extras: [MenuExtraInfo]
    ) -> MenuExtraInfo? {
        guard let appHint else { return nil }
        let normalized = appHint.lowercased()
        return extras.first { extra in
            let candidates = [
                extra.title,
                extra.rawTitle,
                extra.ownerName,
                extra.bundleIdentifier,
                extra.identifier
            ].compactMap { $0?.lowercased() }
            return candidates.contains(where: { $0 == normalized }) ||
                candidates.contains(where: { $0.contains(normalized) })
        }
    }

    func resolveOpenMenuExtra(from extras: [MenuExtraInfo]) async throws -> MenuExtraInfo? {
        for extra in extras {
            let candidates = [
                extra.title,
                extra.ownerName,
                extra.rawTitle,
                extra.identifier,
                extra.bundleIdentifier,
            ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }

            for candidate in candidates where !candidate.isEmpty {
                let ownerPID: pid_t? = if let extraOwnerPID = extra.ownerPID {
                    extraOwnerPID
                } else {
                    await self.resolveMenuExtraOwnerPID(extra)
                }
                let isOpen = await (try? self.services.menu.isMenuExtraMenuOpen(
                    title: candidate,
                    ownerPID: ownerPID
                )) ?? false
                if isOpen {
                    return extra
                }
            }
        }
        return nil
    }

    func resolveMenuExtraOwnerPID(_ extra: MenuExtraInfo) async -> pid_t? {
        if let ownerPID = extra.ownerPID {
            return ownerPID
        }
        guard let runningApps = try? await self.services.applications.listApplications().data.applications else {
            return nil
        }
        if let bundleIdentifier = extra.bundleIdentifier,
           let match = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return match.processIdentifier
        }
        if let ownerName = extra.ownerName {
            if let match = runningApps.first(where: { $0.name == ownerName }) {
                return match.processIdentifier
            }
            let normalizedOwner = ownerName.lowercased()
            if let match = runningApps.first(where: {
                ($0.bundleIdentifier ?? "").lowercased().contains(normalizedOwner)
            }) {
                return match.processIdentifier
            }
        }
        return nil
    }
}
