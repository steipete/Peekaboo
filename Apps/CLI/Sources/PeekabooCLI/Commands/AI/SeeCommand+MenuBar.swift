import AppKit
import AXorcist
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation
import ScreenCaptureKit

@MainActor
extension SeeCommand {
    private func captureMenuBar() async throws -> CaptureResult {
        let rect = try self.menuBarRect()
        return try await ScreenCaptureBridge.captureArea(services: self.services, rect: rect)
    }

    private struct MenuBarPopoverContext {
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

    private struct MenuBarCandidateState {
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

    private func menuBarWindowList() -> [[String: Any]]? {
        CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]]
    }

    private func resolveInitialCandidates(
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

    private func relaxCandidatesIfNeeded(
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

    private func applyOwnerNameFallbackIfNeeded(
        context: MenuBarPopoverContext,
        fullWindowList: [[String: Any]],
        state: MenuBarCandidateState
    ) -> MenuBarCandidateState {
        guard let preferredOwnerName = context.preferredOwnerName,
              !preferredOwnerName.isEmpty,
              state.usedFilteredWindowList else {
            return state
        }

        let windowInfoMap = self.windowInfoById(from: state.windowList)
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

    private func selectCandidates(
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

    private func captureMenuBarPopoverByOCR(
        candidates: [MenuBarPopoverCandidate],
        windowInfoById: [Int: MenuBarPopoverWindowInfo],
        hint: String,
        preferredOwnerName: String?,
        preferredX: CGFloat?
    ) async throws -> MenuBarPopoverCapture? {
        let normalized = hint.lowercased()
        let ranked = MenuBarPopoverSelector.rankCandidates(
            candidates: candidates,
            windowInfoById: windowInfoById,
            preferredOwnerName: preferredOwnerName,
            preferredX: preferredX
        )
        for candidate in ranked {
            let captureResult = try await ScreenCaptureBridge.captureWindowById(
                services: self.services,
                windowId: candidate.windowId
            )
            guard let ocr = try? OCRService.recognizeText(in: captureResult.imageData) else { continue }
            let text = ocr.observations.map(\.text).joined(separator: " ").lowercased()
            if text.contains(normalized) {
                self.logger.verbose(
                    "Selected menu bar popover via OCR",
                    category: "Capture",
                    metadata: [
                        "windowId": candidate.windowId,
                        "hint": hint
                    ]
                )
                return MenuBarPopoverCapture(
                    captureResult: captureResult,
                    windowBounds: candidate.bounds,
                    windowId: candidate.windowId
                )
            }
        }
        return nil
    }

    func captureMenuBarPopoverByArea(
        preferredX: CGFloat,
        hint: String?,
        ownerHint: String?
    ) async throws -> MenuBarPopoverCapture? {
        guard let screen = self.screenForMenuBarX(preferredX) else { return nil }
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

        let captureResult = try await ScreenCaptureBridge.captureArea(
            services: self.services,
            rect: rect
        )

        if let ocr = try? OCRService.recognizeText(in: captureResult.imageData),
           self.ocrMatchesHints(ocr, hint: hint, ownerHint: ownerHint) {
            self.logger.verbose(
                "Selected menu bar popover via area capture",
                category: "Capture",
                metadata: [
                    "rect": "\(rect)"
                ]
            )
            return MenuBarPopoverCapture(
                captureResult: captureResult,
                windowBounds: rect,
                windowId: nil
            )
        }

        return nil
    }

    private func captureMenuBarPopoverFromOpenMenu(
        openExtra: MenuExtraInfo?,
        appHint: String?
    ) async throws -> MenuBarPopoverCapture? {
        let ownerPID: pid_t? = {
            guard let openExtra else { return nil }
            return self.resolveMenuExtraOwnerPID(openExtra)
        }()
        let titles = [
            openExtra?.title,
            openExtra?.ownerName,
            openExtra?.rawTitle,
            appHint,
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }

        for candidate in titles where !candidate.isEmpty {
            if let frame = try? await self.services.menu.menuExtraOpenMenuFrame(
                title: candidate,
                ownerPID: ownerPID
            ),
                let capture = try await self.captureMenuBarPopoverByFrame(
                    frame,
                    hint: appHint ?? openExtra?.title,
                    ownerHint: openExtra?.ownerName
                ) {
                return capture
            }
        }

        return nil
    }

    private func captureMenuBarPopoverByFrame(
        _ frame: CGRect,
        hint: String?,
        ownerHint: String?
    ) async throws -> MenuBarPopoverCapture? {
        let padded = frame.insetBy(dx: -8, dy: -8)
        guard let clamped = self.clampRectToScreens(padded) else { return nil }

        let captureResult = try await ScreenCaptureBridge.captureArea(
            services: self.services,
            rect: clamped
        )

        if let ocr = try? OCRService.recognizeText(in: captureResult.imageData),
           self.ocrMatchesHints(ocr, hint: hint, ownerHint: ownerHint) {
            self.logger.verbose(
                "Selected menu bar popover via AX menu frame",
                category: "Capture",
                metadata: [
                    "rect": "\(clamped)"
                ]
            )
            return MenuBarPopoverCapture(
                captureResult: captureResult,
                windowBounds: clamped,
                windowId: nil
            )
        }

        return nil
    }

    private func ocrMatchesHints(
        _ ocr: OCRTextResult,
        hint: String?,
        ownerHint: String?
    ) -> Bool {
        let hints = [hint, ownerHint]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !hints.isEmpty else { return !ocr.observations.isEmpty }
        let text = ocr.observations.map(\.text).joined(separator: " ").lowercased()
        return hints.contains { hint in
            text.contains(hint.lowercased())
        }
    }

    private func clampRectToScreens(_ rect: CGRect) -> CGRect? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        for screen in screens where screen.frame.intersects(rect) {
            return rect.intersection(screen.frame)
        }
        return rect
    }

    private func screenForMenuBarX(_ x: CGFloat) -> NSScreen? {
        if let screen = NSScreen.screens.first(where: { $0.frame.minX <= x && x <= $0.frame.maxX }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
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

    private func menuBarPopoverCandidatesByBand(
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

    private func resolveMenuExtraHint(
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

    private func resolveOpenMenuExtra(from extras: [MenuExtraInfo]) async throws -> MenuExtraInfo? {
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

    private func resolveMenuExtraOwnerPID(_ extra: MenuExtraInfo) -> pid_t? {
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

    func menuBarRect() throws -> CGRect {
        guard let mainScreen = NSScreen.main ?? NSScreen.screens.first else {
            throw PeekabooError.captureFailed("No main screen found")
        }

        let menuBarHeight = self.menuBarHeight(for: mainScreen)
        return CGRect(
            x: mainScreen.frame.origin.x,
            y: mainScreen.frame.origin.y + mainScreen.frame.height - menuBarHeight,
            width: mainScreen.frame.width,
            height: menuBarHeight
        )
    }

    private func menuBarHeight(for screen: NSScreen?) -> CGFloat {
        guard let screen else { return 24.0 }
        let height = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        return height > 0 ? height : 24.0
    }

    private func menuBarHeight(for screen: MenuBarPopoverDetector.ScreenBounds) -> CGFloat {
        let height = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        return height > 0 ? height : 24.0
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

    func ocrElements(imageData: Data, windowBounds: CGRect?) throws -> [DetectedElement] {
        guard let windowBounds else { return [] }
        let result = try OCRService.recognizeText(in: imageData)
        return self.buildOCRElements(from: result, windowBounds: windowBounds)
    }

    private func buildOCRElements(from result: OCRTextResult, windowBounds: CGRect) -> [DetectedElement] {
        let minConfidence: Float = 0.3
        var elements: [DetectedElement] = []
        var index = 1

        for observation in result.observations where observation.confidence >= minConfidence {
            let rect = self.screenRect(
                from: observation.boundingBox,
                imageSize: result.imageSize,
                windowBounds: windowBounds
            )

            guard rect.width > 2, rect.height > 2 else { continue }

            let attributes = [
                "description": "ocr",
                "confidence": String(format: "%.2f", observation.confidence)
            ]

            elements.append(
                DetectedElement(
                    id: "ocr_\(index)",
                    type: .staticText,
                    label: observation.text,
                    value: nil,
                    bounds: rect,
                    isEnabled: true,
                    isSelected: nil,
                    attributes: attributes
                )
            )
            index += 1
        }

        return elements
    }

    private func screenRect(
        from normalizedBox: CGRect,
        imageSize: CGSize,
        windowBounds: CGRect
    ) -> CGRect {
        let width = normalizedBox.width * imageSize.width
        let height = normalizedBox.height * imageSize.height
        let x = normalizedBox.origin.x * imageSize.width
        let y = (1.0 - normalizedBox.origin.y - normalizedBox.height) * imageSize.height
        return CGRect(
            x: windowBounds.origin.x + x,
            y: windowBounds.origin.y + y,
            width: width,
            height: height
        )
    }

    func saveScreenshot(_ imageData: Data) throws -> String {
        let outputPath: String

        if let providedPath = path {
            outputPath = NSString(string: providedPath).expandingTildeInPath
        } else {
            let timestamp = Date().timeIntervalSince1970
            let filename = "peekaboo_see_\(Int(timestamp)).png"
            let defaultPath = ConfigurationManager.shared.getDefaultSavePath(cliValue: nil)
            outputPath = (defaultPath as NSString).appendingPathComponent(filename)
        }

        // Create directory if needed
        let directory = (outputPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )

        // Save the image
        try imageData.write(to: URL(fileURLWithPath: outputPath))
        self.logger.verbose("Saved screenshot to: \(outputPath)")

        return outputPath
    }

    func resolveSeeWindowIndex(appIdentifier: String, titleFragment: String?) async throws -> Int? {
        // IMPORTANT: ScreenCaptureService's modern path interprets `windowIndex` as an index into the
        // ScreenCaptureKit window list (SCShareableContent.windows filtered by PID), not the
        // Accessibility/WindowManagementService ordering. Resolve indices against SC first to avoid
        // capturing the wrong window when apps have hidden/auxiliary windows (e.g. Playground).
        //
        // When no title is provided, prefer `nil` so the capture service can auto-pick a renderable window.
        guard let fragment = titleFragment, !fragment.isEmpty else {
            return nil
        }

        let appInfo = try await self.services.applications.findApplication(identifier: appIdentifier)

        let content = try await AXTimeoutHelper.withTimeout(seconds: 5.0) {
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        }

        let appWindows = content.windows.filter { window in
            window.owningApplication?.processID == appInfo.processIdentifier
        }

        guard !appWindows.isEmpty else {
            throw CaptureError.windowNotFound
        }

        // Prefer matching via CGWindowList title -> windowID, then map to SCWindow.windowID.
        if let targetWindowID = self.resolveCGWindowID(
            forPID: appInfo.processIdentifier,
            titleFragment: fragment
        ) {
            if let index = appWindows.firstIndex(where: { Int($0.windowID) == Int(targetWindowID) }) {
                return index
            }
        }

        // Fallback: some windows may not expose a CG title; try SCWindow.title directly.
        if let index = appWindows.firstIndex(where: { window in
            (window.title ?? "").localizedCaseInsensitiveContains(fragment)
        }) {
            return index
        }

        throw CaptureError.windowNotFound
    }

    private func resolveCGWindowID(forPID pid: Int32, titleFragment: String) -> CGWindowID? {
        let windowList = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        for info in windowList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32, ownerPID == pid else { continue }
            let title = info[kCGWindowName as String] as? String ?? ""
            guard title.localizedCaseInsensitiveContains(titleFragment) else { continue }
            if let windowID = info[kCGWindowNumber as String] as? CGWindowID {
                return windowID
            }
        }

        return nil
    }

    func resolveWindowId(appIdentifier: String, titleFragment: String?) async throws -> Int? {
        guard let fragment = titleFragment, !fragment.isEmpty else {
            return nil
        }

        let windows = try await self.services.windows.listWindows(
            target: .applicationAndTitle(app: appIdentifier, title: fragment)
        )
        return windows.first?.windowID
    }

    // swiftlint:disable function_body_length
    func generateAnnotatedScreenshot(
        snapshotId: String,
        originalPath: String
    ) async throws -> String {
        // Get detection result from snapshot
        guard let detectionResult = try await self.services.snapshots.getDetectionResult(snapshotId: snapshotId)
        else {
            self.logger.info("No detection result found for snapshot")
            return originalPath
        }

        // Create annotated image
        let annotatedPath = (originalPath as NSString).deletingPathExtension + "_annotated.png"

        // Load original image
        guard let nsImage = NSImage(contentsOfFile: originalPath) else {
            throw CaptureError.fileIOError("Failed to load image from \(originalPath)")
        }

        // Get image size
        let imageSize = nsImage.size

        // Create bitmap context
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(imageSize.width),
            pixelsHigh: Int(imageSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        else {
            throw CaptureError.captureFailure("Failed to create bitmap representation")
        }

        // Draw into context
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            self.logger.error("Failed to create graphics context")
            throw CaptureError.captureFailure("Failed to create graphics context")
        }
        NSGraphicsContext.current = context
        self.logger.verbose("Graphics context created successfully")

        // Draw original image
        nsImage.draw(in: NSRect(origin: .zero, size: imageSize))
        self.logger.verbose("Original image drawn")

        // Configure text attributes - smaller font for less occlusion
        let fontSize: CGFloat = 8
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]

        // Role-based colors from spec
        let roleColors: [ElementType: NSColor] = [
            .button: NSColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0), // #007AFF
            .textField: NSColor(red: 0.204, green: 0.78, blue: 0.349, alpha: 1.0), // #34C759
            .link: NSColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0), // #007AFF
            .checkbox: NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0), // #8E8E93
            .slider: NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0), // #8E8E93
            .menu: NSColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0), // #007AFF
        ]

        // Draw UI elements
        let enabledElements = detectionResult.elements.all.filter(\.isEnabled)

        if enabledElements.isEmpty {
            self.logger.info("No enabled elements to annotate. Total elements: \(detectionResult.elements.all.count)")
            print("\(AgentDisplayTokens.Status.warning)  No interactive UI elements found to annotate")
            return originalPath // Return original image if no elements to annotate
        }

        self.logger.info(
            "Annotating \(enabledElements.count) enabled elements out of \(detectionResult.elements.all.count) total"
        )
        self.logger.verbose("Image size: \(imageSize)")

        // Calculate window origin from element bounds if we have elements
        var windowOrigin = CGPoint.zero
        if !detectionResult.elements.all.isEmpty {
            // Find the leftmost and topmost element to estimate window origin
            let minX = detectionResult.elements.all.map(\.bounds.minX).min() ?? 0
            let minY = detectionResult.elements.all.map(\.bounds.minY).min() ?? 0
            windowOrigin = CGPoint(x: minX, y: minY)
            self.logger.verbose("Estimated window origin from elements: \(windowOrigin)")
        }

        // Convert all element bounds to window-relative coordinates and flip Y
        var elementRects: [(element: DetectedElement, rect: NSRect)] = []
        for element in enabledElements {
            let elementFrame = CGRect(
                x: element.bounds.origin.x - windowOrigin.x,
                y: element.bounds.origin.y - windowOrigin.y,
                width: element.bounds.width,
                height: element.bounds.height
            )

            let rect = NSRect(
                x: elementFrame.origin.x,
                y: imageSize.height - elementFrame.origin.y - elementFrame.height, // Flip Y coordinate
                width: elementFrame.width,
                height: elementFrame.height
            )

            elementRects.append((element: element, rect: rect))
        }

        // Create smart label placer for intelligent label positioning
        let labelPlacer = SmartLabelPlacer(
            image: nsImage,
            fontSize: fontSize,
            debugMode: self.verbose,
            logger: self.logger
        )

        // Draw elements and calculate label positions
        var labelPositions: [(rect: NSRect, connection: NSPoint?, element: DetectedElement)] = []

        for (element, rect) in elementRects {
            let drawingDetails = [
                "Drawing element: \(element.id)",
                "type: \(element.type)",
                "original bounds: \(element.bounds)",
                "window rect: \(rect)"
            ].joined(separator: ", ")
            self.logger.verbose(drawingDetails)

            // Get color for element type
            let color = roleColors[element.type] ?? NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)

            // Draw bounding box
            color.withAlphaComponent(0.5).setFill()
            rect.fill()

            color.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 2
            path.stroke()

            // Calculate label size
            let idString = NSAttributedString(string: element.id, attributes: textAttributes)
            let textSize = idString.size()
            let labelPadding: CGFloat = 4
            let labelSize = NSSize(width: textSize.width + labelPadding * 2, height: textSize.height + labelPadding)

            // Use smart label placer to find best position
            if let placement = labelPlacer.findBestLabelPosition(
                for: element,
                elementRect: rect,
                labelSize: labelSize,
                existingLabels: labelPositions.map { ($0.rect, $0.element) },
                allElements: elementRects
            ) {
                labelPositions.append((
                    rect: placement.labelRect,
                    connection: placement.connectionPoint,
                    element: element
                ))
            }
        }

        // NOTE: Old placement code removed - now using SmartLabelPlacer

        // [OLD CODE REMOVED - lines 483-785 contained the old placement logic]

        // Draw all labels and connection lines
        for (labelRect, connectionPoint, element) in labelPositions {
            // Draw connection line if label is outside - make it more subtle
            if let connection = connectionPoint {
                NSColor.black.withAlphaComponent(0.3).setStroke()
                let linePath = NSBezierPath()
                linePath.lineWidth = 0.5

                // Draw line from connection point to nearest edge of label
                linePath.move(to: connection)

                // Find the closest point on label rectangle to the connection point
                let closestX = max(labelRect.minX, min(connection.x, labelRect.maxX))
                let closestY = max(labelRect.minY, min(connection.y, labelRect.maxY))
                linePath.line(to: NSPoint(x: closestX, y: closestY))

                linePath.stroke()
            }

            // Draw label background - more transparent to show content beneath
            NSColor.black.withAlphaComponent(0.7).setFill()
            NSBezierPath(roundedRect: labelRect, xRadius: 1, yRadius: 1).fill()

            // Draw label border (same color as element) - thinner for less occlusion
            let color = roleColors[element.type] ?? NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)
            color.withAlphaComponent(0.8).setStroke()
            let borderPath = NSBezierPath(roundedRect: labelRect, xRadius: 1, yRadius: 1)
            borderPath.lineWidth = 0.5
            borderPath.stroke()

            // Draw label text
            let idString = NSAttributedString(string: element.id, attributes: textAttributes)
            idString.draw(at: NSPoint(x: labelRect.origin.x + 4, y: labelRect.origin.y + 2))
        }

        NSGraphicsContext.restoreGraphicsState()

        // Save annotated image
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw CaptureError.captureFailure("Failed to create PNG data")
        }

        try pngData.write(to: URL(fileURLWithPath: annotatedPath))
        self.logger.verbose("Created annotated screenshot: \(annotatedPath)")

        // Log annotation info only in non-JSON mode
        if !self.jsonOutput {
            let interactableElements = detectionResult.elements.all.filter(\.isEnabled)
            print("📝 Created annotated screenshot with \(interactableElements.count) interactive elements")
        }

        return annotatedPath
    }
    // swiftlint:enable function_body_length

    // [OLD CODE REMOVED - massive cleanup of duplicate placement logic]
}
