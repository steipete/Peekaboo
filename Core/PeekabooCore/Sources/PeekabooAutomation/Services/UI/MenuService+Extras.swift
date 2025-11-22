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

// MARK: - CGS private helpers (mirrored from Ice)

private struct CGSWindowListOption: OptionSet {
    let rawValue: UInt32
    static let onScreen     = CGSWindowListOption(rawValue: 1 << 0)
    static let menuBarItems = CGSWindowListOption(rawValue: 1 << 1)
    static let activeSpace  = CGSWindowListOption(rawValue: 1 << 2)
}

private func cgsMenuBarWindowIDs(onScreen: Bool = false, activeSpace: Bool = false) -> [CGWindowID] {
    typealias CGSConnectionID = UInt32
    typealias CGSMainConnectionFunc = @convention(c) () -> CGSConnectionID
    typealias CGSCopyWindowsFunc = @convention(c) (CGSConnectionID, Int32, UInt32) -> CFArray?

    guard
        let cgHandle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW),
        let mainConnSym = dlsym(cgHandle, "CGSMainConnectionID"),
        let copyWinSym = dlsym(cgHandle, "CGSCopyWindowsWithOptions")
    else {
        return []
    }

    let mainConnection = unsafeBitCast(mainConnSym, to: CGSMainConnectionFunc.self)
    let copyWindows = unsafeBitCast(copyWinSym, to: CGSCopyWindowsFunc.self)

    let cid = mainConnection()
    var opts: CGSWindowListOption = .menuBarItems
    if onScreen { opts.insert(.onScreen) }
    if activeSpace { opts.insert(.activeSpace) }

    guard let raw = copyWindows(cid, 0, opts.rawValue) as? [UInt32] else {
        return []
    }
    return raw.map { CGWindowID($0) }
}

@MainActor
extension MenuService {
    public func clickMenuExtra(title: String) async throws {
        let systemWide = Element.systemWide()

        guard let menuBar = systemWide.menuBar() else {
            throw PeekabooError.operationError(message: "System menu bar not found")
        }

        let menuBarItems = menuBar.children() ?? []
        guard let menuExtrasGroup = menuBarItems.last(where: { $0.role() == "AXGroup" }) else {
            var context = ErrorContext()
            context.add("menuExtra", title)
            throw NotFoundError(
                code: .menuNotFound,
                userMessage: "Menu extras group not found in system menu bar",
                context: context.build())
        }

        let extras = menuExtrasGroup.children() ?? []
        guard let menuExtra = extras.first(where: { element in
            element.title() == title ||
                element.help() == title ||
                element.descriptionText()?.contains(title) == true
        }) else {
            var context = ErrorContext()
            context.add("menuExtra", title)
            context.add("availableExtras", extras.count)
            throw NotFoundError(
                code: .menuNotFound,
                userMessage: "Menu extra '\(title)' not found in system menu bar",
                context: context.build())
        }

        do {
            try menuExtra.performAction(.press)
        } catch {
            throw OperationError.interactionFailed(
                action: "click menu extra",
                reason: "Failed to click menu extra '\(title)'")
        }
    }

    public func listMenuExtras() async throws -> [MenuExtraInfo] {
        let axExtras = self.getMenuBarItemsViaAccessibility()
        let windowExtras = self.getMenuBarItemsViaWindows()
        let controlCenterExtras = self.getMenuBarItemsFromControlCenterAX()
        return Self.mergeMenuExtras(
            accessibilityExtras: axExtras,
            fallbackExtras: windowExtras + controlCenterExtras)
    }

    public func listMenuBarItems() async throws -> [MenuBarItemInfo] {
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
                axDescription: extra.rawTitle)
        }
    }

    public func clickMenuBarItem(named name: String) async throws -> ClickResult {
        do {
            try await self.clickMenuExtra(title: name)
            return ClickResult(
                elementDescription: "Menu bar item: \(name)",
                location: nil)
        } catch {
            let items = try await listMenuBarItems()
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

        let clickService = ClickService()
        try await clickService.click(
            target: .coordinates(extra.position),
            clickType: .single,
            sessionId: nil)

        return ClickResult(
            elementDescription: "Menu bar item [\(index)]: \(extra.title)",
            location: extra.position)
    }

    func resolvedMenuBarTitle(for extra: MenuExtraInfo, index: Int) -> String {
        let title = extra.title
        let titleIsPlaceholder = isPlaceholderMenuTitle(title) ||
            (isPlaceholderMenuTitle(extra.rawTitle) && title == extra.ownerName)

        if !titleIsPlaceholder {
            return title
        }

        if let identifierName = humanReadableMenuIdentifier(extra.identifier ?? extra.rawTitle),
           !identifierName.isEmpty
        {
            self.logger.debug("MenuService replacing placeholder '\(title)' with identifier '\(identifierName)'")
            return identifierName
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
    func makeDebugDisplayName(
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

        // Preferred path: CGS menuBarItems window list (private API, mirrored from Ice).
        let cgsIDs = cgsMenuBarWindowIDs(onScreen: true, activeSpace: true)
        self.logger.debug("CGS menuBarItems returned \(cgsIDs.count) ids")
        if !cgsIDs.isEmpty {
            // Use CGWindow metadata per window ID to resolve owner/bundle.
            for id in cgsIDs {
                if let item = self.makeMenuExtra(from: id) {
                    items.append(item)
                } else {
                    self.logger.debug("CGS menu item window \(id) had no metadata")
                }
            }
            return items
        } else {
            self.logger.debug("CGS menuBarItems returned 0 ids; falling back to CGWindowList")
        }

        // Fallback: public CGWindowList heuristics.
        let windowList = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID) as? [[String: Any]] ?? []

        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID else { continue }
            if let item = self.makeMenuExtra(from: windowID, info: windowInfo) {
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
                  let first = refreshed.first {
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

        var bundleID: String?
        if let app = NSRunningApplication(processIdentifier: ownerPID) {
            bundleID = app.bundleIdentifier
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
            identifier: bundleID ?? windowTitle)
    }

    /// Attempt to pull status items hosted inside Control Center/system UI via accessibility.
    private func getMenuBarItemsFromControlCenterAX() -> [MenuExtraInfo] {
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
            if let children = element.children() {
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
            let candidates = collectElements(from: axApp)
            for extra in candidates {
                let baseTitle = extra.title() ?? extra.help() ?? extra.descriptionText() ?? "Unknown"
                let identifier = extra.identifier()
                let hasIdentifier = identifier?.isEmpty == false
                let hasNonPlaceholderTitle = !isPlaceholderMenuTitle(baseTitle)
                if !hasIdentifier && !hasNonPlaceholderTitle {
                    continue
                }

                var effectiveTitle = baseTitle
                if isPlaceholderMenuTitle(effectiveTitle),
                   let children = extra.children()
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
                    identifier: identifier)
                items.append(info)
            }
        }

        return items
    }

    private func getMenuBarItemsViaAccessibility() -> [MenuExtraInfo] {
        let systemWide = Element.systemWide()

        guard let menuBar = systemWide.menuBar() else {
            return []
        }

        func flattenExtras(_ element: Element) -> [Element] {
            guard let children = element.children() else { return [] }
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
            let baseTitle = extra.title() ?? extra.help() ?? extra.descriptionText() ?? "Unknown"
            var effectiveTitle = baseTitle
            if isPlaceholderMenuTitle(effectiveTitle),
               let children = extra.children()
            {
                if let childDerived = children
                    .compactMap({ sanitizedMenuText($0.title()) ?? sanitizedMenuText($0.descriptionText()) })
                    .first(where: { !isPlaceholderMenuTitle($0) })
                {
                    effectiveTitle = childDerived
                }
                else if let ident = sanitizedMenuText(extra.identifier()), !ident.isEmpty {
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
                identifier: identifier)
        }
    }

    static func mergeMenuExtras(
        accessibilityExtras: [MenuExtraInfo],
        fallbackExtras: [MenuExtraInfo]) -> [MenuExtraInfo]
    {
        var merged = [MenuExtraInfo]()

        func upsert(_ extra: MenuExtraInfo) {
            let bothHavePosition = extra.position != .zero && merged.first(where: { $0.position != .zero }) != nil
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
            if "Control Center".caseInsensitiveCompare(resolved) != .orderedSame {
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

        return resolved
    }
}

// MARK: - Helpers

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

func humanReadableMenuIdentifier(
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

struct ControlCenterIdentifierLookup {
    static let shared = ControlCenterIdentifierLookup()

    private let mapping: [String: String]

    init(mapping: [String: String]) {
        self.mapping = mapping
    }

    init() {
        self.mapping = Self.loadMapping()
    }

    func displayName(for identifier: String) -> String? {
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
            identifier: self.identifier ?? candidate.identifier)
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
