//
//  MenuService+Extras.swift
//  PeekabooCore
//

import AppKit
import AXorcist
import CoreFoundation
import CoreGraphics
import Foundation
import PeekabooFoundation

@MainActor
extension MenuService {
    private var menuBarAXTimeoutSec: Float { 0.25 }
    private var deepMenuBarAXSweepEnabled: Bool {
        ProcessInfo.processInfo.environment["PEEKABOO_MENUBAR_DEEP_AX_SWEEP"] == "1"
    }

    public func clickMenuExtra(title: String) async throws {
        let systemWide = Element.systemWide()

        guard let menuBar = systemWide.menuBar() else {
            throw PeekabooError.operationError(message: "System menu bar not found")
        }

        let menuBarItems = menuBar.children(strict: true) ?? []
        guard let menuExtrasGroup = menuBarItems.last(where: { $0.role() == "AXGroup" }) else {
            var context = ErrorContext()
            context.add("menuExtra", title)
            throw NotFoundError(
                code: .menuNotFound,
                userMessage: "Menu extras group not found in system menu bar",
                context: context.build())
        }

        let extras = menuExtrasGroup.children(strict: true) ?? []
        let normalizedTarget = normalizedMenuTitle(title)
        guard let menuExtra = extras.first(where: { element in
            let candidates = [
                element.title(),
                element.help(),
                element.descriptionText(),
                element.identifier(),
            ]
            if candidates.contains(where: { titlesMatch(candidate: $0, target: title, normalizedTarget: normalizedTarget) }) {
                return true
            }
            if self.partialMatchEnabled,
               candidates.contains(where: { titlesMatchPartial(
                   candidate: $0,
                   target: title,
                   normalizedTarget: normalizedTarget) })
            {
                return true
            }
            return false
        }) else {
            var context = ErrorContext()
            context.add("menuExtra", title)
            context.add("availableExtras", extras.count)
            throw NotFoundError(
                code: .menuNotFound,
                userMessage: "Menu extra '\(title)' not found in system menu bar",
                context: context.build())
        }

        if !menuExtra.showMenu(), !menuExtra.press() {
            throw OperationError.interactionFailed(
                action: "click menu extra",
                reason: "Failed to click menu extra '\(title)'")
        }
    }

    public func isMenuExtraMenuOpen(title: String, ownerPID: pid_t?) async throws -> Bool {
        let timeoutSeconds = max(TimeInterval(self.menuBarAXTimeoutSec), 0.5)
        do {
            return try await AXTimeoutHelper.withTimeout(
                seconds: timeoutSeconds
            ) { [self] in
                await MainActor.run {
                    self.isMenuExtraMenuOpenInternal(
                        title: title,
                        ownerPID: ownerPID,
                        timeout: Float(timeoutSeconds))
                }
            }
        } catch {
            self.logger.debug("Menu extra open check timed out: \(error.localizedDescription)")
            return false
        }
    }

    private func isMenuExtraMenuOpenInternal(
        title: String,
        ownerPID: pid_t?,
        timeout: Float) -> Bool
    {
        let systemWide = Element.systemWide()
        systemWide.setMessagingTimeout(timeout)
        defer { systemWide.setMessagingTimeout(0) }

        guard let menuBar = systemWide.menuBar() else {
            return false
        }

        let menuBarItems = menuBar.children(strict: true) ?? []
        guard let menuExtrasGroup = menuBarItems.last(where: { $0.role() == "AXGroup" }) else {
            return false
        }

        let extras = menuExtrasGroup.children(strict: true) ?? []
        let normalizedTarget = normalizedMenuTitle(title)
        if let menuExtra = self.findMenuExtra(
            in: extras,
            title: title,
            normalizedTarget: normalizedTarget,
            ownerPID: ownerPID)
        {
            if self.menuExtraHasOpenMenu(menuExtra) {
                return true
            }
        }

        let systemMenus = (systemWide.children(strict: true) ?? []).filter { $0.isMenu() }
        guard !systemMenus.isEmpty else { return false }

        for menu in systemMenus {
            if self.menuMatches(menu: menu, normalizedTarget: normalizedTarget, ownerPID: ownerPID) {
                return true
            }
        }

        return false
    }

    private func findMenuExtra(
        in extras: [Element],
        title: String,
        normalizedTarget: String?,
        ownerPID: pid_t?) -> Element?
    {
        if let match = extras.first(where: { element in
            let candidates = [
                element.title(),
                element.help(),
                element.descriptionText(),
                element.identifier(),
            ]
            if candidates.contains(where: { titlesMatch(candidate: $0, target: title, normalizedTarget: normalizedTarget) }) {
                return true
            }
            if self.partialMatchEnabled,
               candidates.contains(where: { titlesMatchPartial(
                   candidate: $0,
                   target: title,
                   normalizedTarget: normalizedTarget) })
            {
                return true
            }
            return false
        }) {
            return match
        }

        guard let ownerPID else { return nil }
        return extras.first(where: { $0.pid() == ownerPID })
    }

    private func menuExtraHasOpenMenu(_ menuExtra: Element) -> Bool {
        if let menuElement: AXUIElement = menuExtra.attribute(Attribute<AXUIElement>("AXMenu")) {
            let menu = Element(menuElement)
            if let children = menu.children(strict: true), !children.isEmpty {
                return true
            }
        }

        let children = menuExtra.children(strict: true) ?? []
        return children.contains(where: { $0.isMenu() || $0.isMenuItem() })
    }

    private func menuMatches(menu: Element, normalizedTarget: String?, ownerPID: pid_t?) -> Bool {
        if let ownerPID, menu.pid() == ownerPID {
            return true
        }

        if let ownerPID {
            var remaining = 200
            if self.menuContainsPID(menu: menu, ownerPID: ownerPID, depth: 0, remaining: &remaining) {
                return true
            }
        }

        guard let normalizedTarget else { return false }
        var remaining = 200
        return self.menuContainsTitle(menu: menu, normalizedTarget: normalizedTarget, depth: 0, remaining: &remaining)
    }

    private func menuContainsPID(
        menu: Element,
        ownerPID: pid_t,
        depth: Int,
        remaining: inout Int) -> Bool
    {
        guard remaining > 0 else { return false }
        guard let children = menu.children(strict: true) else { return false }

        for child in children {
            guard remaining > 0 else { break }
            remaining -= 1

            if child.pid() == ownerPID {
                return true
            }

            if depth < 2,
               let submenu = child.children(strict: true)?.first(where: { $0.isMenu() })
            {
                if self.menuContainsPID(menu: submenu, ownerPID: ownerPID, depth: depth + 1, remaining: &remaining) {
                    return true
                }
            }
        }

        return false
    }

    private func menuContainsTitle(
        menu: Element,
        normalizedTarget: String,
        depth: Int,
        remaining: inout Int) -> Bool
    {
        guard remaining > 0 else { return false }
        guard let children = menu.children(strict: true) else { return false }

        for child in children {
            guard remaining > 0 else { break }
            remaining -= 1

            if self.menuItemMatchesTitle(child, normalizedTarget: normalizedTarget) {
                return true
            }

            if depth < 2,
               let submenu = child.children(strict: true)?.first(where: { $0.isMenu() })
            {
                if self.menuContainsTitle(
                    menu: submenu,
                    normalizedTarget: normalizedTarget,
                    depth: depth + 1,
                    remaining: &remaining)
                {
                    return true
                }
            }
        }

        return false
    }

    private func menuItemMatchesTitle(_ element: Element, normalizedTarget: String) -> Bool {
        let candidates: [String?] = [
            element.title(),
            element.descriptionText(),
            (element.value() as? NSAttributedString)?.string,
        ]
        return menuTitleCandidatesContainNormalized(candidates, normalizedTarget: normalizedTarget)
    }

    public func listMenuExtras() async throws -> [MenuExtraInfo] {
        // Menu bar enumeration must never hang: agents depend on this returning quickly.
        // AX can block on misbehaving apps; keep the default path cheap and bounded.
        let windowExtras = self.getMenuBarItemsViaWindows()

        // Fast path: WindowServer enumeration is usually sufficient and avoids AX calls entirely.
        // Only fall back to accessibility sweeps when explicitly enabled or when WindowServer looks incomplete.
        if !windowExtras.isEmpty,
           !self.deepMenuBarAXSweepEnabled,
           !self.shouldAugmentWindowExtrasWithAX(windowExtras)
        {
            return windowExtras
        }

        let axExtras = self.getMenuBarItemsViaAccessibility(timeout: self.menuBarAXTimeoutSec)
        let controlCenterExtras = self.getMenuBarItemsFromControlCenterAX(timeout: self.menuBarAXTimeoutSec)

        let appAXExtras: [MenuExtraInfo] = if self.deepMenuBarAXSweepEnabled {
            self.getMenuBarItemsFromAppsAX(
                timeout: self.menuBarAXTimeoutSec,
                apps: NSWorkspace.shared.runningApplications)
        } else {
            self.getMenuBarItemsFromAppsAX(
                timeout: self.menuBarAXTimeoutSec,
                apps: self.accessoryAppsForMenuExtras())
        }

        // Avoid AX hit-testing by default (can hang); enable via PEEKABOO_MENUBAR_DEEP_AX_SWEEP=1.
        let fallbackExtras: [MenuExtraInfo] = if self.deepMenuBarAXSweepEnabled {
            self.enrichWindowExtrasWithAXHitTest(windowExtras, timeout: self.menuBarAXTimeoutSec)
        } else {
            windowExtras
        }

        return Self.mergeMenuExtras(
            accessibilityExtras: axExtras + controlCenterExtras + appAXExtras,
            fallbackExtras: fallbackExtras)
    }

    public func listMenuBarItems(includeRaw: Bool = false) async throws -> [MenuBarItemInfo] {
        let extras = try await listMenuExtras()

        return extras.indexed().map { index, extra in
            let displayTitle = self.resolvedMenuBarTitle(for: extra, index: index)
            return MenuBarItemInfo(
                title: displayTitle,
                index: index,
                isVisible: extra.isVisible,
                description: extra.identifier ?? extra.rawTitle ?? extra.ownerName ?? extra.title,
                rawTitle: extra.rawTitle,
                bundleIdentifier: extra.bundleIdentifier,
                ownerName: extra.ownerName,
                frame: CGRect(origin: extra.position, size: .zero),
                identifier: extra.identifier,
                axIdentifier: extra.identifier,
                axDescription: extra.rawTitle,
                rawWindowID: includeRaw ? extra.windowID : nil,
                rawWindowLayer: includeRaw ? extra.windowLayer : nil,
                rawOwnerPID: includeRaw ? extra.ownerPID : nil,
                rawSource: includeRaw ? extra.source : nil)
        }
    }

    public func clickMenuBarItem(named name: String) async throws -> ClickResult {
        do {
            try await self.clickMenuExtra(title: name)
            return ClickResult(
                elementDescription: "Menu bar item: \(name)",
                location: nil)
        } catch {
            let items = try await listMenuBarItems(includeRaw: false)
            let normalizedName = normalizedMenuTitle(name)

            if let item = items.first(where: { titlesMatch(
                candidate: $0.title,
                target: name,
                normalizedTarget: normalizedName) })
            {
                return try await self.clickMenuBarItem(at: item.index)
            }

            if partialMatchEnabled,
               let item = items.first(where: { titlesMatchPartial(
                   candidate: $0.title,
                   target: name,
                   normalizedTarget: normalizedName) })
            {
                return try await self.clickMenuBarItem(at: item.index)
            }

            throw NotFoundError(
                code: .menuNotFound,
                userMessage: "Menu bar item '\(name)' not found",
                context: ["availableItems": items.compactMap(\.title).joined(separator: ", ")])
        }
    }

    public func clickMenuBarItem(at index: Int) async throws -> ClickResult {
        let extras = try await listMenuExtras()

        guard index >= 0, index < extras.count else {
            throw PeekabooError
                .invalidInput("Invalid menu bar item index: \(index). Valid range: 0-\(extras.count - 1)")
        }

        let extra = extras[index]
        guard let clickPoint = self.resolveMenuExtraClickPoint(for: extra) else {
            throw PeekabooError.operationError(message: "Menu bar item has no clickable position")
        }

        try? InputDriver.move(to: clickPoint)

        if !self.tryWindowTargetedClick(extra: extra, point: clickPoint) {
            let clickService = ClickService()
            try await clickService.click(
                target: .coordinates(clickPoint),
                clickType: .single,
                snapshotId: nil)
        }

        return ClickResult(
            elementDescription: "Menu bar item [\(index)]: \(extra.title)",
            location: clickPoint)
    }

    @_spi(Testing) public func resolvedMenuBarTitle(for extra: MenuExtraInfo, index: Int) -> String {
        let title = extra.title
        let titleIsPlaceholder = isPlaceholderMenuTitle(title) ||
            (isPlaceholderMenuTitle(extra.rawTitle) && title == extra.ownerName)

        if !titleIsPlaceholder {
            return title
        }

        if let identifierName = humanReadableMenuIdentifier(extra.identifier ?? extra.rawTitle),
           !identifierName.isEmpty
        {
            if let ownerName = extra.ownerName,
               let normalizedIdentifier = normalizedMenuTitle(identifierName)?.replacingOccurrences(of: " ", with: ""),
               let normalizedOwner = normalizedMenuTitle(ownerName)?.replacingOccurrences(of: " ", with: ""),
               normalizedIdentifier == normalizedOwner
            {
                // Skip identifier-based label when it matches the owner (e.g., Control Center).
            } else {
                self.logger.debug("MenuService replacing placeholder '\(title)' with identifier '\(identifierName)'")
                return identifierName
            }
        }

        if let ownerName = extra.ownerName, !ownerName.isEmpty {
            return "\(ownerName) #\(index)"
        }

        if let raw = extra.rawTitle, !raw.isEmpty {
            return "\(raw) #\(index)"
        }

        return "Menu Bar Item #\(index)"
    }

    #if DEBUG
    @_spi(Testing) public func makeDebugDisplayName(
        rawTitle: String?,
        ownerName: String?,
        bundleIdentifier: String?) async -> String
    {
        self.makeMenuExtraDisplayName(
            rawTitle: rawTitle,
            ownerName: ownerName,
            bundleIdentifier: bundleIdentifier,
            identifier: rawTitle)
    }
    #endif

    // MARK: - Menu Extra Utilities

    private func getMenuBarItemsViaWindows() -> [MenuExtraInfo] {
        var items: [MenuExtraInfo] = []

        // Preferred: call LSUIElement helper (AppKit context) to get WindowServer view like Ice.
        if let helperItems = self.getMenuBarItemsViaHelper(), !helperItems.isEmpty {
            self.logger.debug("MenuService helper returned \(helperItems.count) items")
            return helperItems
        }

        // Preferred path: CGS menuBarItems window list (private API, mirrored from Ice).
        let cgsIDs = cgsMenuBarWindowIDs(onScreen: true, activeSpace: true)
        let legacyIDs = cgsProcessMenuBarWindowIDs(onScreenOnly: true)
        let combinedIDs = Array(Set(cgsIDs + legacyIDs))
        self.logger.debug(
            """
            CGS menuBarItems returned \(cgsIDs.count) ids;
            processMenuBar returned \(legacyIDs.count); combined \(combinedIDs.count)
            """)
        var seenIDs = Set<CGWindowID>()
        if !combinedIDs.isEmpty {
            // Use CGWindow metadata per window ID to resolve owner/bundle.
            for id in combinedIDs {
                if let item = self.makeMenuExtra(from: id) {
                    items.append(item)
                    seenIDs.insert(id)
                } else {
                    self.logger.debug("CGS menu item window \(id) had no metadata")
                }
            }
        } else {
            self.logger.debug("CGS menuBarItems returned 0 ids; falling back to CGWindowList")
        }

        // Fallback: public CGWindowList heuristics.
        let windowList = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID) as? [[String: Any]] ?? []

        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID else { continue }
            guard !seenIDs.contains(windowID) else { continue }
            if let item = self.makeMenuExtra(from: windowID, info: windowInfo) {
                items.append(item)
                seenIDs.insert(windowID)
            }
        }

        return items
    }

    private func resolveMenuExtraClickPoint(for extra: MenuExtraInfo) -> CGPoint? {
        if let windowID = extra.windowID,
           let bounds = self.windowBounds(for: windowID)
        {
            return CGPoint(x: bounds.midX, y: bounds.midY)
        }

        if extra.position != .zero {
            return extra.position
        }

        return nil
    }

    private func windowBounds(for windowID: CGWindowID) -> CGRect? {
        guard let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]],
              let first = info.first,
              let boundsDict = first[kCGWindowBounds as String] as? [String: Any],
              let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let width = boundsDict["Width"] as? CGFloat,
              let height = boundsDict["Height"] as? CGFloat
        else {
            return nil
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func tryWindowTargetedClick(extra: MenuExtraInfo, point: CGPoint) -> Bool {
        guard let windowID = extra.windowID else {
            return false
        }
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }

        let userData = Int64(truncatingIfNeeded: Int(bitPattern: ObjectIdentifier(source)))
        let windowIDValue = Int64(windowID)

        guard
            let down = CGEvent(
                mouseEventSource: source,
                mouseType: .leftMouseDown,
                mouseCursorPosition: point,
                mouseButton: .left),
            let up = CGEvent(
                mouseEventSource: source,
                mouseType: .leftMouseUp,
                mouseCursorPosition: point,
                mouseButton: .left)
        else {
            return false
        }

        if let ownerPID = extra.ownerPID {
            let pidValue = Int64(ownerPID)
            down.setIntegerValueField(.eventTargetUnixProcessID, value: pidValue)
            up.setIntegerValueField(.eventTargetUnixProcessID, value: pidValue)
        }

        for event in [down, up] {
            event.setIntegerValueField(.eventSourceUserData, value: userData)
            event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: windowIDValue)
            event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: windowIDValue)
            event.setIntegerValueField(.windowID, value: windowIDValue)
            event.setIntegerValueField(.mouseEventClickState, value: 1)
        }

        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
        return true
    }

    private func isLikelyMenuBarAXPosition(_ position: CGPoint) -> Bool {
        guard position != .zero else { return true }
        return position.y <= self.menuBarAXMaxY(for: position)
    }

    private func menuBarAXMaxY(for position: CGPoint) -> CGFloat {
        let fallbackHeight: CGFloat = 24
        guard let screen = NSScreen.screens.first(where: { screen in
            position.x >= screen.frame.minX && position.x <= screen.frame.maxX
        }) else {
            return fallbackHeight + 12
        }

        let height = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        let menuBarHeight = height > 0 ? height : fallbackHeight
        return menuBarHeight + 12
    }

    /// Invoke the LSUIElement helper (if built) to enumerate menu bar windows from a GUI context.
    private func getMenuBarItemsViaHelper() -> [MenuExtraInfo]? {
        let helperPath = [
            FileManager.default.currentDirectoryPath,
            "Helpers",
            "MenuBarHelper",
            "build",
            "MenubarHelper.app",
            "Contents",
            "MacOS",
            "menubar-helper",
        ].joined(separator: "/")
        guard FileManager.default.isExecutableFile(atPath: helperPath) else {
            return nil
        }

        let process = Process()
        process.launchPath = helperPath

        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
        } catch {
            self.logger.debug("Failed to run menubar helper: \(error.localizedDescription)")
            return nil
        }

        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ids = json["window_ids"] as? [UInt32]
        else { return nil }

        // Enrich each window ID locally via CGWindowList so we can keep coordinates/owner.
        var items: [MenuExtraInfo] = []
        for id in ids {
            if let item = self.makeMenuExtra(from: CGWindowID(id)) {
                items.append(item)
            }
        }
        return items
    }

    private func makeMenuExtra(from windowID: CGWindowID, info: [String: Any]? = nil) -> MenuExtraInfo? {
        let windowInfo: [String: Any]
        if let info {
            windowInfo = info
        } else if let refreshed = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]],
                  let first = refreshed.first
        {
            windowInfo = first
        } else {
            return nil
        }

        let windowLayer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
        if !(windowLayer == 24 || windowLayer == 25) { return nil }

        guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let width = boundsDict["Width"] as? CGFloat,
              let height = boundsDict["Height"] as? CGFloat
        else {
            return nil
        }

        guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t else { return nil }
        let ownerName = windowInfo[kCGWindowOwnerName as String] as? String ?? "Unknown"
        let windowTitle = windowInfo[kCGWindowName as String] as? String ?? ""

        if ownerName == "Window Server", windowTitle == "Menubar" {
            return nil
        }

        var bundleID: String?
        if let app = NSRunningApplication(processIdentifier: ownerPID) {
            bundleID = app.bundleIdentifier
            // If window title is empty, prefer localized app name for display.
            if windowTitle.isEmpty, let appName = app.localizedName {
                return MenuExtraInfo(
                    title: self.makeMenuExtraDisplayName(
                        rawTitle: appName,
                        ownerName: appName,
                        bundleIdentifier: bundleID),
                    rawTitle: windowTitle.isEmpty ? appName : windowTitle,
                    bundleIdentifier: bundleID,
                    ownerName: appName,
                    position: CGPoint(x: x + width / 2, y: y + height / 2),
                    isVisible: true,
                    identifier: bundleID ?? windowTitle,
                    windowID: windowID,
                    windowLayer: windowLayer,
                    ownerPID: ownerPID,
                    source: info == nil ? "cgs" : "cgwindow")
            }
        }

        if bundleID == "com.apple.finder", windowTitle.isEmpty {
            return nil
        }

        let titleOrOwner = windowTitle.isEmpty ? ownerName : windowTitle
        let friendlyTitle = self.makeMenuExtraDisplayName(
            rawTitle: titleOrOwner, ownerName: ownerName, bundleIdentifier: bundleID)

        return MenuExtraInfo(
            title: friendlyTitle,
            rawTitle: titleOrOwner,
            bundleIdentifier: bundleID,
            ownerName: ownerName,
            position: CGPoint(x: x + width / 2, y: y + height / 2),
            isVisible: true,
            identifier: bundleID ?? windowTitle,
            windowID: windowID,
            windowLayer: windowLayer,
            ownerPID: ownerPID,
            source: info == nil ? "cgs" : "cgwindow")
    }

    /// Attempt to pull status items hosted inside Control Center/system UI via accessibility.
    private func getMenuBarItemsFromControlCenterAX(timeout: Float) -> [MenuExtraInfo] {
        let hostBundleIDs = [
            "com.apple.controlcenter",
            "com.apple.systemuiserver",
        ]
        let hosts = NSWorkspace.shared.runningApplications.filter { app in
            if let bid = app.bundleIdentifier {
                return hostBundleIDs.contains(bid)
            }
            return false
        }

        func collectElements(from element: Element, depth: Int = 0, limit: Int = 6) -> [Element] {
            if depth > limit { return [] }
            var results: [Element] = []
            element.setMessagingTimeout(timeout)
            if let children = element.children(strict: true) {
                for child in children {
                    results.append(child)
                    results.append(contentsOf: collectElements(from: child, depth: depth + 1, limit: limit))
                }
            }
            return results
        }

        var items: [MenuExtraInfo] = []

        for host in hosts {
            let axApp = AXApp(host).element
            axApp.setMessagingTimeout(timeout)
            let candidates = collectElements(from: axApp)
            for extra in candidates {
                extra.setMessagingTimeout(timeout)
                let baseTitle = extra.title() ?? extra.help() ?? extra.descriptionText() ?? "Unknown"
                let identifier = extra.identifier()
                let hasIdentifier = identifier?.isEmpty == false
                let hasNonPlaceholderTitle = !isPlaceholderMenuTitle(baseTitle)
                if !hasIdentifier, !hasNonPlaceholderTitle {
                    continue
                }

                var effectiveTitle = baseTitle
                if isPlaceholderMenuTitle(effectiveTitle),
                   let children = extra.children(strict: true)
                {
                    if let childDerived = children
                        .compactMap({ sanitizedMenuText($0.title()) ?? sanitizedMenuText($0.descriptionText()) })
                        .first(where: { !isPlaceholderMenuTitle($0) })
                    {
                        effectiveTitle = childDerived
                    } else if let ident = sanitizedMenuText(identifier), !ident.isEmpty {
                        effectiveTitle = ident
                    }
                }

                let position = extra.position() ?? .zero
                if !self.isLikelyMenuBarAXPosition(position) {
                    continue
                }

                let info = MenuExtraInfo(
                    title: self.makeMenuExtraDisplayName(
                        rawTitle: effectiveTitle,
                        ownerName: host.localizedName,
                        bundleIdentifier: host.bundleIdentifier,
                        identifier: identifier),
                    rawTitle: baseTitle,
                    bundleIdentifier: host.bundleIdentifier,
                    ownerName: host.localizedName,
                    position: position,
                    isVisible: true,
                    identifier: identifier,
                    source: "ax-control-center")
                items.append(info)
            }
        }

        return items
    }

    private func getMenuBarItemsViaAccessibility(timeout: Float) -> [MenuExtraInfo] {
        let systemWide = Element.systemWide()

        guard let menuBar = systemWide.menuBarWithTimeout(timeout: timeout) else {
            return []
        }

        func flattenExtras(_ element: Element) -> [Element] {
            element.setMessagingTimeout(timeout)
            guard let children = element.children(strict: true) else { return [] }
            var results: [Element] = []
            for child in children {
                if child.role() == "AXMenuBarItem" || child.role() == "AXGroup" {
                    results.append(child)
                }
                results.append(contentsOf: flattenExtras(child))
            }
            return results
        }

        let candidates = flattenExtras(menuBar)

        return candidates.compactMap { extra in
            extra.setMessagingTimeout(timeout)
            let baseTitle = extra.title() ?? extra.help() ?? extra.descriptionText() ?? "Unknown"
            var effectiveTitle = baseTitle
            if isPlaceholderMenuTitle(effectiveTitle),
               let children = extra.children(strict: true)
            {
                if let childDerived = children
                    .compactMap({ sanitizedMenuText($0.title()) ?? sanitizedMenuText($0.descriptionText()) })
                    .first(where: { !isPlaceholderMenuTitle($0) })
                {
                    effectiveTitle = childDerived
                } else if let ident = sanitizedMenuText(extra.identifier()), !ident.isEmpty {
                    effectiveTitle = ident
                }
            }
            let position = extra.position() ?? .zero
            let identifier = extra.identifier()

            return MenuExtraInfo(
                title: self.makeMenuExtraDisplayName(
                    rawTitle: effectiveTitle,
                    ownerName: nil,
                    bundleIdentifier: nil,
                    identifier: identifier),
                rawTitle: baseTitle,
                bundleIdentifier: nil,
                ownerName: nil,
                position: position,
                isVisible: true,
                identifier: identifier,
                source: "ax-menubar")
        }
    }

    /// Sweep AX trees of all running apps to find menu bar/status items that expose AX titles or identifiers.
    private func accessoryAppsForMenuExtras() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy != .regular
        }
    }

    private func shouldAugmentWindowExtrasWithAX(_ extras: [MenuExtraInfo]) -> Bool {
        guard !extras.isEmpty else { return true }

        let hasThirdParty = extras.contains { extra in
            guard let bundleID = extra.bundleIdentifier else { return false }
            return !bundleID.hasPrefix("com.apple.")
        }
        if hasThirdParty {
            return false
        }

        if extras.contains(where: { isPlaceholderMenuTitle($0.title) }) {
            return true
        }

        let titles = extras.map { $0.title.lowercased() }.filter { !$0.isEmpty }
        guard !titles.isEmpty else { return true }
        let counts = titles.reduce(into: [String: Int]()) { counts, title in
            counts[title, default: 0] += 1
        }
        let mostCommon = counts.values.max() ?? 0
        if mostCommon >= max(3, extras.count / 2) {
            return true
        }

        return false
    }

    private func getMenuBarItemsFromAppsAX(
        timeout: Float,
        apps: [NSRunningApplication]) -> [MenuExtraInfo]
    {
        let running = apps
        var results: [MenuExtraInfo] = []
        let commonMenuTitles: Set<String> = [
            "apple", "file", "edit", "view", "window", "help", "history", "bookmarks", "navigate", "tab", "tools",
            "cut", "copy", "paste", "format",
        ]

        func collectElements(from element: Element, depth: Int = 0, limit: Int = 4) -> [Element] {
            if depth > limit { return [] }
            var list: [Element] = []
            element.setMessagingTimeout(timeout)
            if let children = element.children(strict: true) {
                for child in children {
                    list.append(child)
                    list.append(contentsOf: collectElements(from: child, depth: depth + 1, limit: limit))
                }
            }
            return list
        }

        for app in running {
            let axApp = AXApp(app).element
            axApp.setMessagingTimeout(timeout)
            let candidates = collectElements(from: axApp)
            for extra in candidates {
                extra.setMessagingTimeout(timeout)
                let role = extra.role() ?? ""
                let subrole = extra.subrole() ?? ""
                let isStatusLike = role == "AXStatusItem" || subrole == "AXStatusItem" || subrole == "AXMenuExtra"
                if !isStatusLike { continue }

                let baseTitle = extra.title() ?? extra.help() ?? extra.descriptionText() ?? ""
                let identifier = extra.identifier()
                let nonPlaceholder = !isPlaceholderMenuTitle(baseTitle) || (identifier?.isEmpty == false)
                guard nonPlaceholder else { continue }

                // Prefer stable identifier/help over child-derived titles to avoid menu-item leakage.
                var effectiveTitle: String = sanitizedMenuText(identifier)
                    ?? sanitizedMenuText(extra.help())
                    ?? sanitizedMenuText(baseTitle)
                    ?? baseTitle

                // Fallbacks to app name when placeholder/short/common menu words.
                if isPlaceholderMenuTitle(effectiveTitle) ||
                    effectiveTitle.count <= 2 ||
                    commonMenuTitles.contains(effectiveTitle.lowercased())
                {
                    effectiveTitle = app.localizedName ?? effectiveTitle
                }

                let position = extra.position() ?? .zero
                // Restrict to top-of-screen positions to avoid stray elements.
                if !self.isLikelyMenuBarAXPosition(position) { continue }

                // Avoid duplicating children of a status item: require that this element itself is status-like.
                let childrenRoles = (extra.children(strict: true) ?? []).compactMap { $0.role() }
                if !isStatusLike, childrenRoles.contains(where: { $0 == "AXMenuItem" }) {
                    continue
                }

                let info = MenuExtraInfo(
                    title: self.makeMenuExtraDisplayName(
                        rawTitle: effectiveTitle,
                        ownerName: app.localizedName,
                        bundleIdentifier: app.bundleIdentifier,
                        identifier: identifier),
                    rawTitle: baseTitle,
                    bundleIdentifier: app.bundleIdentifier,
                    ownerName: app.localizedName,
                    position: position,
                    isVisible: true,
                    identifier: identifier,
                    ownerPID: app.processIdentifier,
                    source: "ax-app")
                results.append(info)
            }
        }

        return results
    }

    /// Hit-test window extras to attach AX identifiers/titles when CGS gives only placeholders.
    private func enrichWindowExtrasWithAXHitTest(_ extras: [MenuExtraInfo], timeout: Float) -> [MenuExtraInfo] {
        extras.map { extra in
            guard extra
                .identifier == nil || isPlaceholderMenuTitle(extra.title) || isPlaceholderMenuTitle(extra.rawTitle),
                extra.position != .zero
            else { return extra }

            Element.systemWide().setMessagingTimeout(timeout)
            guard let hit = Element.elementAtPoint(extra.position) else {
                return extra
            }

            hit.setMessagingTimeout(timeout)
            let role = hit.role() ?? ""
            let subrole = hit.subrole() ?? ""
            let isStatusLike = role == "AXStatusItem" || subrole == "AXStatusItem" || subrole == "AXMenuExtra"
            if !isStatusLike { return extra }

            let hitTitle = sanitizedMenuText(hit.identifier())
                ?? sanitizedMenuText(hit.help())
                ?? sanitizedMenuText(hit.title())
                ?? hit.descriptionText()
                ?? extra.rawTitle
                ?? extra.title
            let hitIdentifier = hit.identifier() ?? extra.identifier

            return MenuExtraInfo(
                title: self.makeMenuExtraDisplayName(
                    rawTitle: hitTitle,
                    ownerName: extra.ownerName,
                    bundleIdentifier: extra.bundleIdentifier,
                    identifier: hitIdentifier),
                rawTitle: hitTitle,
                bundleIdentifier: extra.bundleIdentifier,
                ownerName: extra.ownerName,
                position: extra.position,
                isVisible: extra.isVisible,
                identifier: hitIdentifier,
                windowID: extra.windowID,
                windowLayer: extra.windowLayer,
                ownerPID: extra.ownerPID,
                source: extra.source ?? "cgs-hit")
        }
    }

    @_spi(Testing) public static func mergeMenuExtras(
        accessibilityExtras: [MenuExtraInfo],
        fallbackExtras: [MenuExtraInfo]) -> [MenuExtraInfo]
    {
        var merged = [MenuExtraInfo]()

        func upsert(_ extra: MenuExtraInfo) {
            let bothHavePosition = extra.position != .zero && merged.contains { $0.position != .zero }
            if bothHavePosition,
               let index = merged.firstIndex(where: { $0.position.distance(to: extra.position) < 5 })
            {
                merged[index] = merged[index].merging(with: extra)
            } else {
                merged.append(extra)
            }
        }

        fallbackExtras.forEach(upsert)
        accessibilityExtras.forEach(upsert)

        merged.sort { $0.position.x < $1.position.x }
        return merged
    }

    private func makeMenuExtraDisplayName(
        rawTitle: String?,
        ownerName: String?,
        bundleIdentifier: String?,
        identifier: String? = nil) -> String
    {
        var resolved = rawTitle?.isEmpty == false ? rawTitle! : (ownerName ?? "Unknown")
        let namespace = MenuExtraNamespace(bundleIdentifier: bundleIdentifier)
        switch namespace {
        case .controlCenter:
            if isPlaceholderMenuTitle(resolved) {
                resolved = "Control Center"
            }
        case .systemUIServer:
            if resolved.lowercased() == "menu extras" {
                resolved = "System Menu Extras"
            }
        case .spotlight:
            if isPlaceholderMenuTitle(resolved) {
                resolved = "Spotlight"
            }
        case .siri:
            if isPlaceholderMenuTitle(resolved) {
                resolved = "Siri"
            }
        case .passwords:
            if isPlaceholderMenuTitle(resolved) {
                resolved = "Passwords"
            }
        case .other:
            break
        }

        let identifierSource = identifier ?? rawTitle
        if let identifierName = humanReadableMenuIdentifier(identifierSource),
           isPlaceholderMenuTitle(resolved)
        {
            self.logger.debug("MenuService replacing placeholder '\(resolved)' with identifier '\(identifierName)'")
            return identifierName
        }

        if isPlaceholderMenuTitle(resolved),
           let ownerName,
           !ownerName.isEmpty
        {
            self.logger.debug("MenuService replacing placeholder '\(resolved)' with owner '\(ownerName)'")
            return ownerName
        }

        if namespace == .controlCenter,
           resolved.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
           resolved.count > 4,
           resolved.range(of: #"[A-Z].*[a-z]|[a-z].*[A-Z]"#, options: .regularExpression) != nil
        {
            let humanized = camelCaseToWords(resolved)
            if !humanized.isEmpty, !isPlaceholderMenuTitle(humanized) {
                return humanized
            }
        }

        return resolved
    }
}

// MARK: - Helpers

private extension CGEventField {
    static let windowID = CGEventField(rawValue: 0x33)!
}

private enum MenuExtraNamespace {
    case controlCenter, systemUIServer, spotlight, siri, passwords, other

    init(bundleIdentifier: String?) {
        switch bundleIdentifier {
        case "com.apple.controlcenter": self = .controlCenter
        case "com.apple.systemuiserver": self = .systemUIServer
        case "com.apple.Spotlight": self = .spotlight
        case "com.apple.Siri": self = .siri
        case "com.apple.Passwords.MenuBarExtra": self = .passwords
        default: self = .other
        }
    }
}

@_spi(Testing) public func humanReadableMenuIdentifier(
    _ identifier: String?,
    lookup: ControlCenterIdentifierLookup = .shared) -> String?
{
    guard let identifier = sanitizedMenuText(identifier) else { return nil }

    if let mapped = lookup.displayName(for: identifier) {
        return mapped
    }

    let separators = CharacterSet(charactersIn: "._-:/")
    let tokens = identifier.split { character in
        character.unicodeScalars.contains { separators.contains($0) }
    }
    guard let rawToken = tokens.last else { return nil }
    let candidate = String(rawToken)
    guard !isPlaceholderMenuTitle(candidate) else { return nil }
    let spaced = camelCaseToWords(candidate)
    return spaced.isEmpty ? nil : spaced
}

func camelCaseToWords(_ token: String) -> String {
    var result = ""
    var previousWasUppercase = false

    for character in token {
        if character == "_" || character == "-" {
            if !result.hasSuffix(" ") {
                result.append(" ")
            }
            previousWasUppercase = false
            continue
        }

        if character.isUppercase, !previousWasUppercase, !result.isEmpty {
            result.append(" ")
        }

        result.append(character)
        previousWasUppercase = character.isUppercase
    }

    return result
        .replacingOccurrences(of: "  ", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .capitalized
}

@_spi(Testing) public struct ControlCenterIdentifierLookup: Sendable {
    @_spi(Testing) public static let shared = ControlCenterIdentifierLookup()

    private let mapping: [String: String]

    @_spi(Testing) public init(mapping: [String: String]) {
        self.mapping = mapping
    }

    public init() {
        self.mapping = Self.loadMapping()
    }

    @_spi(Testing) public func displayName(for identifier: String) -> String? {
        let upper = identifier.uppercased()
        return self.mapping[upper]
    }

    private static func loadMapping() -> [String: String] {
        guard let rawValue = CFPreferencesCopyAppValue(
            "ControlCenterDisplayableChronoControlsProviderConfiguration" as CFString,
            "com.apple.controlcenter" as CFString)
        else {
            return [:]
        }

        let data: Data
        if let string = rawValue as? String {
            data = Data(string.utf8)
        } else if let dataValue = rawValue as? Data {
            data = dataValue
        } else if let nsData = rawValue as? NSData {
            data = nsData as Data
        } else {
            return [:]
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let controls = json["Controls"] as? [[String: Any]]
        else {
            return [:]
        }

        var mapping: [String: String] = [:]
        for control in controls {
            guard let displayName = control["DisplayName"] as? String else { continue }
            guard let identifiers = control["Identifier"] as? [String] else { continue }
            for identifier in identifiers {
                let key = identifier.uppercased()
                if mapping[key] == nil {
                    mapping[key] = displayName
                }
            }
        }
        return mapping
    }
}

extension MenuExtraInfo {
    fileprivate func merging(with candidate: MenuExtraInfo) -> MenuExtraInfo {
        MenuExtraInfo(
            title: Self.preferredTitle(primary: self, secondary: candidate) ?? self.title,
            rawTitle: self.rawTitle ?? candidate.rawTitle,
            bundleIdentifier: self.bundleIdentifier ?? candidate.bundleIdentifier,
            ownerName: self.ownerName ?? candidate.ownerName,
            position: self.preferredPosition(comparedTo: candidate),
            isVisible: self.isVisible || candidate.isVisible,
            identifier: self.identifier ?? candidate.identifier,
            windowID: self.windowID ?? candidate.windowID,
            windowLayer: self.windowLayer ?? candidate.windowLayer,
            ownerPID: self.ownerPID ?? candidate.ownerPID,
            source: self.source ?? candidate.source)
    }

    private static func preferredTitle(primary: MenuExtraInfo, secondary: MenuExtraInfo) -> String? {
        let primaryTitle = sanitizedMenuText(primary.title) ?? sanitizedMenuText(primary.rawTitle)
        let secondaryTitle = sanitizedMenuText(secondary.title) ?? sanitizedMenuText(secondary.rawTitle)

        let primaryQuality = Self.titleQuality(for: primaryTitle)
        let secondaryQuality = Self.titleQuality(for: secondaryTitle)

        if secondaryQuality > primaryQuality {
            return secondaryTitle ?? primaryTitle
        } else if primaryQuality > secondaryQuality {
            return primaryTitle ?? secondaryTitle
        } else {
            return primaryTitle ?? secondaryTitle
        }
    }

    private static func titleQuality(for title: String?) -> Int {
        guard let title else { return 0 }
        if isPlaceholderMenuTitle(title) { return 0 }
        if title.count <= 2 { return 1 }
        if title.rangeOfCharacter(from: .whitespacesAndNewlines) == nil {
            return 2
        }
        return 3
    }

    private func preferredPosition(comparedTo candidate: MenuExtraInfo) -> CGPoint {
        if self.position.distance(to: candidate.position) <= 1 {
            return self.position
        }
        return self.position.x <= candidate.position.x ? self.position : candidate.position
    }
}

extension CGPoint {
    fileprivate func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
