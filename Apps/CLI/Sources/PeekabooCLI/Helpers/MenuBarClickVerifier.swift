import AppKit
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

struct MenuBarVerifyTarget {
    let title: String?
    let ownerPID: pid_t?
    let ownerName: String?
    let bundleIdentifier: String?
    let preferredX: CGFloat?
}

struct MenuBarClickVerification {
    let verified: Bool
    let method: String
    let windowId: Int?
}

struct MenuBarFocusSnapshot {
    let appPID: pid_t
    let appName: String
    let bundleIdentifier: String?
    let windowId: Int?
    let windowTitle: String?
}

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
            windowTitle: focused?.title
        )
    }

    func verifyClick(
        target: MenuBarVerifyTarget,
        preFocus: MenuBarFocusSnapshot?,
        clickLocation: CGPoint?,
        timeout: TimeInterval = 1.5
    ) async throws -> MenuBarClickVerification {
        let preferredX = clickLocation?.x ?? target.preferredX

        if let ownerPID = target.ownerPID {
            if let candidate = await self.waitForPopover(
                ownerPID: ownerPID,
                preferredOwnerName: target.ownerName,
                preferredX: preferredX,
                timeout: timeout
            ) {
                return MenuBarClickVerification(verified: true, method: "owner_pid", windowId: candidate.windowId)
            }
        }

        if let focusVerification = await self.waitForFocusedWindowChange(
            target: target,
            preFocus: preFocus,
            timeout: timeout
        ) {
            return focusVerification
        }

        if let windowId = await self.waitForOwnerWindow(
            ownerPID: target.ownerPID,
            expectedTitle: target.title,
            timeout: timeout
        ) {
            return MenuBarClickVerification(verified: true, method: "owner_pid_window", windowId: windowId)
        }

        let expectedTitle = target.title ?? target.ownerName
        let ocrHints = [target.title, target.ownerName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let expectedTitle, !expectedTitle.isEmpty {
            if ProcessInfo.processInfo.environment["PEEKABOO_MENUBAR_AX_VERIFY"] == "1" {
                if await self.waitForMenuExtraMenuOpen(
                    expectedTitle: expectedTitle,
                    ownerPID: target.ownerPID,
                    timeout: timeout
                ) {
                    return MenuBarClickVerification(verified: true, method: "ax_menu", windowId: nil)
                }
            }
        }

        let ocrEnabled = ProcessInfo.processInfo.environment["PEEKABOO_MENUBAR_OCR_VERIFY"] != "0"
        if ocrEnabled, !ocrHints.isEmpty {
            if let candidate = try await self.waitForPopoverByOCR(
                expectedHints: ocrHints,
                preferredOwnerName: target.ownerName,
                preferredX: preferredX,
                timeout: timeout
            ) {
                return MenuBarClickVerification(verified: true, method: "ocr", windowId: candidate.windowId)
            }
            if let preferredX,
               await self.verifyPopoverAreaByOCR(preferredX: preferredX, expectedHints: ocrHints) {
                return MenuBarClickVerification(verified: true, method: "ocr_area", windowId: nil)
            }
        }

        throw PeekabooError.operationError(message: "Menu bar verification failed: popover not detected")
    }

    private func waitForFocusedWindowChange(
        target: MenuBarVerifyTarget,
        preFocus: MenuBarFocusSnapshot?,
        timeout: TimeInterval
    ) async -> MenuBarClickVerification? {
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
                return MenuBarClickVerification(
                    verified: true,
                    method: "focused_window",
                    windowId: focused?.windowID
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

    private func waitForPopover(
        ownerPID: pid_t,
        preferredOwnerName: String?,
        preferredX: CGFloat?,
        timeout: TimeInterval
    ) async -> MenuBarPopoverCandidate? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let result = self.findMenuBarPopoverCandidates(ownerPID: ownerPID)
            if let candidate = MenuBarPopoverSelector.selectCandidate(
                candidates: result.candidates,
                windowInfoById: result.windowInfoById,
                preferredOwnerName: preferredOwnerName,
                preferredX: preferredX
            ) {
                return candidate
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return nil
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
    ) async -> Int? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let ownerPID {
                let windowIds = self.windowIDsForPID(ownerPID: ownerPID)
                if let windowId = windowIds.first {
                    return windowId
                }
            }

            if let expectedTitle, !expectedTitle.isEmpty {
                let windowIds = self.windowIDsForOwnerName(expectedTitle)
                if let windowId = windowIds.first {
                    return windowId
                }
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return nil
    }

    private func waitForPopoverByOCR(
        expectedHints: [String],
        preferredOwnerName: String?,
        preferredX: CGFloat?,
        timeout: TimeInterval
    ) async throws -> MenuBarPopoverCandidate? {
        let normalizedHints = expectedHints.map { $0.lowercased() }
        let captureTimeout = min(timeout / 2.0, 0.6)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let result = self.findMenuBarPopoverCandidates(ownerPID: nil)
            let ranked = MenuBarPopoverSelector.rankCandidates(
                candidates: result.candidates,
                windowInfoById: result.windowInfoById,
                preferredOwnerName: preferredOwnerName,
                preferredX: preferredX
            )
            for candidate in ranked.prefix(2) {
                guard let capture = await self.captureWindowWithTimeout(
                    windowId: candidate.windowId,
                    timeout: captureTimeout
                ) else { continue }
                guard let ocr = try? OCRService.recognizeText(in: capture.imageData) else { continue }
                let text = ocr.observations.map(\.text).joined(separator: " ").lowercased()
                if normalizedHints.contains(where: { text.contains($0) }) {
                    return candidate
                }
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        return nil
    }

    private func findMenuBarPopoverCandidates(
        ownerPID: pid_t?
    ) -> (candidates: [MenuBarPopoverCandidate], windowInfoById: [Int: MenuBarPopoverWindowInfo]) {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return ([], [:])
        }

        let screens = NSScreen.screens.map { screen in
            MenuBarPopoverDetector.ScreenBounds(
                frame: screen.frame,
                visibleFrame: screen.visibleFrame
            )
        }

        let candidates = MenuBarPopoverDetector.candidates(
            windowList: windowList,
            screens: screens,
            ownerPID: ownerPID
        )
        let windowInfo = self.windowInfoById(from: windowList)
        return (candidates, windowInfo)
    }

    private func windowInfoById(from windowList: [[String: Any]]) -> [Int: MenuBarPopoverWindowInfo] {
        var info: [Int: MenuBarPopoverWindowInfo] = [:]
        for windowInfo in windowList {
            let windowId = windowInfo[kCGWindowNumber as String] as? Int ?? 0
            if windowId == 0 { continue }
            info[windowId] = MenuBarPopoverWindowInfo(
                ownerName: windowInfo[kCGWindowOwnerName as String] as? String,
                title: windowInfo[kCGWindowName as String] as? String
            )
        }
        return info
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

    private func captureWindowWithTimeout(
        windowId: Int,
        timeout: TimeInterval
    ) async -> CaptureResult? {
        do {
            return try await withTimeout(seconds: timeout) {
                try await self.services.screenCapture.captureWindow(windowID: CGWindowID(windowId))
            }
        } catch {
            return nil
        }
    }

    private func verifyPopoverAreaByOCR(preferredX: CGFloat, expectedHints: [String]) async -> Bool {
        guard let screen = self.screenForMenuBarX(preferredX) else { return false }
        let menuBarHeight = self.menuBarHeight(for: screen)
        let maxHeight = max(120, min(700, screen.frame.height - menuBarHeight))
        let width: CGFloat = 420
        let menuBarTop = screen.frame.maxY - menuBarHeight
        var rect = CGRect(
            x: preferredX - (width / 2.0),
            y: menuBarTop - maxHeight,
            width: width,
            height: maxHeight
        )
        rect.origin.x = max(screen.frame.minX, min(rect.origin.x, screen.frame.maxX - rect.width))
        rect.origin.y = max(screen.frame.minY, rect.origin.y)

        guard let capture = try? await self.services.screenCapture.captureArea(rect) else { return false }
        guard let ocr = try? OCRService.recognizeText(in: capture.imageData) else { return false }
        let text = ocr.observations.map(\.text).joined(separator: " ").lowercased()
        return expectedHints.map { $0.lowercased() }.contains(where: { text.contains($0) })
    }

    private func screenForMenuBarX(_ x: CGFloat) -> NSScreen? {
        if let screen = NSScreen.screens.first(where: { $0.frame.minX <= x && x <= $0.frame.maxX }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private func menuBarHeight(for screen: NSScreen) -> CGFloat {
        let height = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        return height > 0 ? height : 24.0
    }
}
