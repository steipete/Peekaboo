import AppKit
import CoreGraphics
import Foundation
import PeekabooCore

@MainActor
extension SeeCommand {
    func menuBarWindowList() -> [[String: Any]]? {
        CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]]
    }

    func resolveInitialCandidates(
        context: MenuBarPopoverContext,
        windowList: [[String: Any]]
    ) -> MenuBarCandidateState {
        let filteredWindowList: [[String: Any]] = if context.canFilterByOwnerPid {
            windowList.filter { info in
                guard let ownerPID = self.ownerPid(from: info) else { return false }
                return context.ownerPidSet.contains(ownerPID)
            }
        } else {
            windowList
        }

        let usedFilteredWindowList = context.canFilterByOwnerPid &&
            !filteredWindowList.isEmpty &&
            filteredWindowList.count != windowList.count
        let candidatesWindowList = usedFilteredWindowList ? filteredWindowList : windowList

        var candidates = self.menuBarPopoverCandidates(
            windowList: candidatesWindowList,
            ownerPID: context.preferredOwnerPid
        )
        if candidates.isEmpty, context.preferredOwnerPid != nil {
            candidates = self.menuBarPopoverCandidates(
                windowList: candidatesWindowList,
                ownerPID: nil
            )
        }

        return MenuBarCandidateState(
            candidates: candidates,
            windowList: candidatesWindowList,
            usedFilteredWindowList: usedFilteredWindowList
        )
    }

    func relaxCandidatesIfNeeded(
        context: MenuBarPopoverContext,
        fullWindowList: [[String: Any]],
        state: MenuBarCandidateState
    ) -> MenuBarCandidateState {
        guard state.candidates.isEmpty,
              context.shouldRelaxFilter,
              state.usedFilteredWindowList else {
            return state
        }

        self.logger.debug("Relaxing menu bar popover filter to full window list")

        var candidates = self.menuBarPopoverCandidates(
            windowList: fullWindowList,
            ownerPID: context.preferredOwnerPid
        )
        if candidates.isEmpty, context.preferredOwnerPid != nil {
            candidates = self.menuBarPopoverCandidates(
                windowList: fullWindowList,
                ownerPID: nil
            )
        }

        return MenuBarCandidateState(
            candidates: candidates,
            windowList: fullWindowList,
            usedFilteredWindowList: false
        )
    }

    func applyOwnerNameFallbackIfNeeded(
        context: MenuBarPopoverContext,
        fullWindowList: [[String: Any]],
        state: MenuBarCandidateState
    ) -> MenuBarCandidateState {
        guard let preferredOwnerName = context.preferredOwnerName,
              !preferredOwnerName.isEmpty,
              state.usedFilteredWindowList else {
            return state
        }

        let windowInfoMap = MenuBarPopoverResolver.windowInfoById(from: state.windowList)
        let normalized = preferredOwnerName.lowercased()
        let ownerMatches = state.candidates.filter { candidate in
            let ownerName = windowInfoMap[candidate.windowId]?.ownerName?.lowercased() ?? ""
            return ownerName == normalized || ownerName.contains(normalized)
        }
        guard ownerMatches.isEmpty else { return state }

        var candidates = self.menuBarPopoverCandidates(
            windowList: fullWindowList,
            ownerPID: context.preferredOwnerPid
        )
        if candidates.isEmpty, context.preferredOwnerPid != nil {
            candidates = self.menuBarPopoverCandidates(
                windowList: fullWindowList,
                ownerPID: nil
            )
        }

        return MenuBarCandidateState(
            candidates: candidates,
            windowList: fullWindowList,
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
        windowList: [[String: Any]],
        ownerPID: pid_t?
    ) -> [MenuBarPopoverCandidate] {
        let screens = NSScreen.screens.map { screen in
            MenuBarPopoverDetector.ScreenBounds(
                frame: screen.frame,
                visibleFrame: screen.visibleFrame
            )
        }

        return MenuBarPopoverDetector.candidates(
            windowList: windowList,
            screens: screens,
            ownerPID: ownerPID
        )
    }

    func menuBarPopoverCandidatesByBand(
        windowList: [[String: Any]],
        preferredX: CGFloat
    ) -> [MenuBarPopoverCandidate] {
        let screens = NSScreen.screens.map { screen in
            MenuBarPopoverDetector.ScreenBounds(
                frame: screen.frame,
                visibleFrame: screen.visibleFrame
            )
        }
        let bandHalfWidth: CGFloat = 260
        var candidates: [MenuBarPopoverCandidate] = []

        for windowInfo in windowList {
            guard let bounds = self.windowBounds(from: windowInfo) else { continue }
            let windowId = windowInfo[kCGWindowNumber as String] as? Int ?? 0
            if windowId == 0 { continue }

            if bounds.width < 40 || bounds.height < 40 { continue }
            if bounds.maxX < preferredX - bandHalfWidth || bounds.minX > preferredX + bandHalfWidth { continue }

            let screen = self.screenContainingWindow(bounds: bounds, screens: screens)
            if let screen {
                let menuBarHeight = self.menuBarHeight(for: screen)
                let maxHeight = screen.frame.height * 0.85
                if bounds.height > maxHeight { continue }

                let topEdge = screen.visibleFrame.maxY
                if bounds.maxY < topEdge - 48 && bounds.minY > menuBarHeight + 48 { continue }
            }

            let ownerPID = self.ownerPid(from: windowInfo) ?? -1
            candidates.append(
                MenuBarPopoverCandidate(
                    windowId: windowId,
                    ownerPID: ownerPID,
                    bounds: bounds
                )
            )
        }

        return candidates
    }

    private func screenContainingWindow(
        bounds: CGRect,
        screens: [MenuBarPopoverDetector.ScreenBounds]
    ) -> MenuBarPopoverDetector.ScreenBounds? {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        if let screen = screens.first(where: { $0.frame.contains(center) }) {
            return screen
        }

        var bestScreen: MenuBarPopoverDetector.ScreenBounds?
        var maxOverlap: CGFloat = 0
        for screen in screens {
            let intersection = screen.frame.intersection(bounds)
            let overlapArea = intersection.width * intersection.height
            if overlapArea > maxOverlap {
                maxOverlap = overlapArea
                bestScreen = screen
            }
        }

        return bestScreen
    }

    private func ownerPid(from windowInfo: [String: Any]) -> pid_t? {
        if let number = windowInfo[kCGWindowOwnerPID as String] as? NSNumber {
            return pid_t(number.intValue)
        }
        if let intValue = windowInfo[kCGWindowOwnerPID as String] as? Int {
            return pid_t(intValue)
        }
        if let pidValue = windowInfo[kCGWindowOwnerPID as String] as? pid_t {
            return pidValue
        }
        return nil
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
                let ownerPID = extra.ownerPID ?? self.resolveMenuExtraOwnerPID(extra)
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

    func resolveMenuExtraOwnerPID(_ extra: MenuExtraInfo) -> pid_t? {
        if let ownerPID = extra.ownerPID {
            return ownerPID
        }
        let runningApps = NSWorkspace.shared.runningApplications
        if let bundleIdentifier = extra.bundleIdentifier,
           let match = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return match.processIdentifier
        }
        if let ownerName = extra.ownerName {
            if let match = runningApps.first(where: { $0.localizedName == ownerName }) {
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

    private func windowBounds(from windowInfo: [String: Any]) -> CGRect? {
        guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let width = boundsDict["Width"] as? CGFloat,
              let height = boundsDict["Height"] as? CGFloat
        else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
