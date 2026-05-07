import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

@MainActor
struct MenuBarClickVerifier {
    let services: any PeekabooServiceProviding

    func captureFocusSnapshot() async throws -> MenuBarFocusSnapshot {
        let frontmost = try await self.services.applications.getFrontmostApplication()
        let focused = try await WindowServiceBridge.getFocusedWindow(windows: self.services.windows)

        return MenuBarFocusSnapshot(
            appPID: frontmost.processIdentifier,
            appName: frontmost.name,
            bundleIdentifier: frontmost.bundleIdentifier,
            windowId: focused?.windowID,
            windowTitle: focused?.title,
            windowBounds: focused?.bounds
        )
    }

    func verifyClick(
        target: MenuBarVerifyTarget,
        preFocus: MenuBarFocusSnapshot?,
        clickLocation: CGPoint?,
        timeout: TimeInterval = 1.5
    ) async throws -> MenuBarClickVerification {
        let preferredX = clickLocation?.x ?? target.preferredX
        let context = MenuBarPopoverResolverContext.build(
            appHint: target.title ?? target.ownerName,
            preferredOwnerName: target.ownerName,
            ownerPID: target.ownerPID,
            preferredX: preferredX,
            hints: [target.title, target.ownerName]
        )

        if let resolution = try await self.waitForPopoverResolution(
            context: context,
            timeout: timeout,
            allowOCR: false,
            allowAreaFallback: false
        ) {
            return MenuBarClickVerification(
                verified: true,
                method: resolution.reason.rawValue,
                windowId: resolution.windowId
            )
        }

        if let focusResolution = await self.waitForFocusedWindowChange(
            target: target,
            preFocus: preFocus,
            timeout: timeout
        ) {
            return MenuBarClickVerification(
                verified: true,
                method: focusResolution.reason.rawValue,
                windowId: focusResolution.windowId
            )
        }

        if let ownerWindowResolution = await self.waitForOwnerWindow(
            ownerPID: target.ownerPID,
            expectedTitle: target.title,
            timeout: timeout
        ) {
            return MenuBarClickVerification(
                verified: true,
                method: ownerWindowResolution.reason.rawValue,
                windowId: ownerWindowResolution.windowId
            )
        }

        let expectedTitle = target.title ?? target.ownerName
        if let expectedTitle, !expectedTitle.isEmpty {
            if ProcessInfo.processInfo.environment["PEEKABOO_MENUBAR_AX_VERIFY"] == "1" {
                if await self.waitForMenuExtraMenuOpen(
                    expectedTitle: expectedTitle,
                    ownerPID: target.ownerPID,
                    timeout: timeout
                ) {
                    return MenuBarClickVerification(
                        verified: true,
                        method: MenuBarPopoverResolution.Reason.axMenu.rawValue,
                        windowId: nil
                    )
                }
            }
        }

        let ocrEnabled = ProcessInfo.processInfo.environment["PEEKABOO_MENUBAR_OCR_VERIFY"] != "0"
        let allowOCR = ocrEnabled && !context.ocrHints.isEmpty
        if allowOCR {
            if let resolution = try await self.waitForPopoverResolution(
                context: context,
                timeout: timeout,
                allowOCR: true,
                allowAreaFallback: true
            ) {
                return MenuBarClickVerification(
                    verified: true,
                    method: resolution.reason.rawValue,
                    windowId: resolution.windowId
                )
            }
        }

        throw PeekabooError.operationError(message: "Menu bar verification failed: popover not detected")
    }

    private func waitForFocusedWindowChange(
        target: MenuBarVerifyTarget,
        preFocus: MenuBarFocusSnapshot?,
        timeout: TimeInterval
    ) async -> MenuBarPopoverResolution? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            guard let frontmost = try? await self.services.applications.getFrontmostApplication() else {
                try? await Task.sleep(nanoseconds: 120_000_000)
                continue
            }

            if !Self.frontmostMatchesTarget(
                frontmost: frontmost,
                ownerPID: target.ownerPID,
                ownerName: target.ownerName,
                bundleIdentifier: target.bundleIdentifier
            ) {
                try? await Task.sleep(nanoseconds: 120_000_000)
                continue
            }

            let focused = try? await WindowServiceBridge.getFocusedWindow(windows: self.services.windows)
            if self.focusDidChange(preFocus: preFocus, frontmost: frontmost, focused: focused) {
                return MenuBarPopoverResolution(
                    windowId: focused?.windowID,
                    bounds: focused?.bounds,
                    confidence: 0.7,
                    reason: .focusedWindow,
                    captureResult: nil
                )
            }

            try? await Task.sleep(nanoseconds: 120_000_000)
        }

        return nil
    }

    private func focusDidChange(
        preFocus: MenuBarFocusSnapshot?,
        frontmost: ServiceApplicationInfo,
        focused: ServiceWindowInfo?
    ) -> Bool {
        guard let preFocus else { return true }

        if preFocus.appPID != frontmost.processIdentifier {
            return true
        }

        let currentWindowId = focused?.windowID
        if preFocus.windowId != currentWindowId {
            return true
        }

        let currentTitle = focused?.title
        if preFocus.windowTitle != currentTitle {
            return true
        }

        return false
    }

    static func frontmostMatchesTarget(
        frontmost: ServiceApplicationInfo,
        ownerPID: pid_t?,
        ownerName: String?,
        bundleIdentifier: String?
    ) -> Bool {
        if let ownerPID, frontmost.processIdentifier == ownerPID {
            return true
        }

        if let bundleIdentifier,
           let frontBundle = frontmost.bundleIdentifier,
           frontBundle == bundleIdentifier {
            return true
        }

        if let ownerName,
           frontmost.name.compare(ownerName, options: .caseInsensitive) == .orderedSame {
            return true
        }

        return false
    }

    private func waitForMenuExtraMenuOpen(
        expectedTitle: String,
        ownerPID: pid_t?,
        timeout: TimeInterval
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let axVerified = try? await MenuServiceBridge.isMenuExtraMenuOpen(
                menu: self.services.menu,
                title: expectedTitle,
                ownerPID: ownerPID
            ),
                axVerified {
                return true
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return false
    }

    private func waitForOwnerWindow(
        ownerPID: pid_t?,
        expectedTitle: String?,
        timeout: TimeInterval
    ) async -> MenuBarPopoverResolution? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let ownerPID {
                let windowIds = self.windowIDsForPID(ownerPID: ownerPID)
                if let windowId = windowIds.first {
                    return MenuBarPopoverResolution(
                        windowId: windowId,
                        bounds: nil,
                        confidence: 0.6,
                        reason: .ownerWindow,
                        captureResult: nil
                    )
                }
            }

            if let expectedTitle, !expectedTitle.isEmpty {
                let windowIds = self.windowIDsForOwnerName(expectedTitle)
                if let windowId = windowIds.first {
                    return MenuBarPopoverResolution(
                        windowId: windowId,
                        bounds: nil,
                        confidence: 0.6,
                        reason: .ownerWindow,
                        captureResult: nil
                    )
                }
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return nil
    }

    private func menuBarWindowList() -> [[String: Any]]? {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }
        return windowList
    }

    private func waitForPopoverResolution(
        context: MenuBarPopoverResolverContext,
        timeout: TimeInterval,
        allowOCR: Bool,
        allowAreaFallback: Bool
    ) async throws -> MenuBarPopoverResolution? {
        let deadline = Date().addingTimeInterval(timeout)
        let captureTimeout = min(timeout / 2.0, 0.6)
        let ocrSelector = ObservationMenuBarPopoverOCRSelector(
            screenCapture: self.services.screenCapture,
            screens: self.services.screens.listScreens()
        )

        let candidateOCR: MenuBarPopoverResolver.CandidateOCR? = if allowOCR {
            { candidate, _ in
                guard !context.ocrHints.isEmpty else { return nil }
                guard let match = try? await withTimeout(seconds: captureTimeout, operation: {
                    try await ocrSelector.matchCandidate(
                        windowID: CGWindowID(candidate.windowId),
                        bounds: candidate.bounds,
                        hints: context.ocrHints
                    )
                }) else { return nil }
                return MenuBarPopoverResolver.OCRMatch(
                    captureResult: match.captureResult,
                    bounds: match.bounds
                )
            }
        } else {
            nil
        }

        let areaOCR: MenuBarPopoverResolver.AreaOCR? = if allowAreaFallback {
            { preferredX, hints in
                guard let match = try? await ocrSelector.matchArea(preferredX: preferredX, hints: hints) else {
                    return nil
                }
                return MenuBarPopoverResolver.OCRMatch(
                    captureResult: match.captureResult,
                    bounds: match.bounds
                )
            }
        } else {
            nil
        }

        while Date() < deadline {
            guard let windowList = self.menuBarWindowList() else {
                try? await Task.sleep(nanoseconds: 100_000_000)
                continue
            }

            let screens = self.services.screens.listScreens().map { screen in
                MenuBarPopoverDetector.ScreenBounds(
                    frame: screen.frame,
                    visibleFrame: screen.visibleFrame
                )
            }

            let candidates = MenuBarPopoverResolver.candidates(
                from: windowList,
                screens: screens,
                ownerPID: context.ownerPID
            )
            if candidates.isEmpty {
                try? await Task.sleep(nanoseconds: 100_000_000)
                continue
            }

            let windowInfo = MenuBarPopoverResolver.windowInfoById(from: windowList)
            let options = MenuBarPopoverResolver.ResolutionOptions(
                allowOCR: allowOCR,
                allowAreaFallback: allowAreaFallback,
                candidateOCR: candidateOCR,
                areaOCR: areaOCR
            )
            if let resolution = try await MenuBarPopoverResolver.resolve(
                candidates: candidates,
                windowInfoById: windowInfo,
                context: context,
                options: options
            ) {
                return resolution
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        return nil
    }

    private func windowIDsForPID(ownerPID: pid_t) -> [Int] {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        var ids: [Int] = []
        for windowInfo in windowList {
            let pid: pid_t = {
                if let number = windowInfo[kCGWindowOwnerPID as String] as? NSNumber {
                    return pid_t(number.intValue)
                }
                if let intValue = windowInfo[kCGWindowOwnerPID as String] as? Int {
                    return pid_t(intValue)
                }
                return -1
            }()
            guard pid == ownerPID else { continue }

            if let windowId = windowInfo[kCGWindowNumber as String] as? Int {
                ids.append(windowId)
            }
        }
        return ids
    }

    private func windowIDsForOwnerName(_ name: String) -> [Int] {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        let normalized = name.lowercased()
        var ids: [Int] = []
        for windowInfo in windowList {
            let ownerName = (windowInfo[kCGWindowOwnerName as String] as? String)?.lowercased() ?? ""
            let title = (windowInfo[kCGWindowName as String] as? String)?.lowercased() ?? ""
            if ownerName.contains(normalized) || title.contains(normalized) {
                if let windowId = windowInfo[kCGWindowNumber as String] as? Int {
                    ids.append(windowId)
                }
            }
        }
        return ids
    }
}
