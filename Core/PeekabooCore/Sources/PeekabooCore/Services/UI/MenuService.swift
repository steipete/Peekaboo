import AppKit
import AXorcist
import CoreGraphics
import Foundation
import os
import PeekabooFoundation

/// Default implementation of menu interaction operations
@MainActor
public final class MenuService: MenuServiceProtocol {
    private let applicationService: any ApplicationServiceProtocol
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "MenuService")

    // Visualizer client for visual feedback
    private let visualizerClient = VisualizationClient.shared

    public init(applicationService: (any ApplicationServiceProtocol)? = nil) {
        self.applicationService = applicationService ?? ApplicationService()
        // Connect to visualizer if available
        // Only connect to visualizer if we're not running inside the Mac app
        // The Mac app provides the visualizer service, not consumes it
        let isMacApp = Bundle.main.bundleIdentifier?.hasPrefix("boo.peekaboo.mac") == true
        if !isMacApp {
            self.logger.debug("Connecting to visualizer service (running as CLI/external tool)")
            self.visualizerClient.connect()
        } else {
            self.logger.debug("Skipping visualizer connection (running inside Mac app)")
        }
    }

}

@MainActor
extension MenuService {

    public func listMenus(for appIdentifier: String) async throws -> MenuStructure {
        let appInfo = try await applicationService.findApplication(identifier: appIdentifier)

        // Get AX element for the application
        let axApp = AXUIElementCreateApplication(appInfo.processIdentifier)
        let appElement = Element(axApp)

        let menuBar = try self.menuBar(for: appElement, appInfo: appInfo)
        let menus = self.collectMenus(from: menuBar, appInfo: appInfo)
        return MenuStructure(application: appInfo, menus: menus)
    }

    public func listFrontmostMenus() async throws -> MenuStructure {
        let frontmostApp = try await applicationService.getFrontmostApplication()
        return try await self.listMenus(for: frontmostApp.bundleIdentifier ?? frontmostApp.name)
    }

    public func clickMenuItem(app: String, itemPath: String) async throws {
        let appInfo = try await applicationService.findApplication(identifier: app)

        // Parse menu path
        let pathComponents = itemPath.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }

        // Get AX element for the application
        let axApp = AXUIElementCreateApplication(appInfo.processIdentifier)
        let appElement = Element(axApp)

        guard let menuBar = appElement.menuBar() else {
            var context = ErrorContext()
            context.add("application", appInfo.name)
            throw NotFoundError(
                code: .menuNotFound,
                userMessage: "Menu bar not found for application '\(appInfo.name)'",
                context: context.build())
        }

        // Navigate menu hierarchy
        var currentElement: Element = menuBar
        var menuPath: [String] = []

        for (index, component) in pathComponents.enumerated() {
            // Get children of current menu
            let children = currentElement.children() ?? []

            // Find matching menu item
            guard let menuItem = findMenuItem(named: component, in: children) else {
                var context = ErrorContext()
                context.add("menuItem", component)
                context.add("path", itemPath)
                context.add("application", appInfo.name)
                throw NotFoundError(
                    code: .menuNotFound,
                    userMessage: "Menu item '\(component)' not found in path '\(itemPath)'",
                    context: context.build())
            }

            // Add to menu path for visual feedback
            menuPath.append(component)

            // If this is the last component, click it
            if index == pathComponents.count - 1 {
                // Show menu navigation visual feedback
                _ = await self.visualizerClient.showMenuNavigation(menuPath: menuPath)

                do {
                    try menuItem.performAction(Attribute<String>("AXPress"))
                } catch {
                    throw OperationError.interactionFailed(
                        action: "click menu item",
                        reason: "Failed to click menu item '\(component)'")
                }
            } else {
                // Otherwise, open the submenu
                do {
                    try menuItem.performAction(Attribute<String>("AXPress"))
                } catch {
                    throw OperationError.interactionFailed(
                        action: "open submenu",
                        reason: "Failed to open submenu '\(component)'")
                }

                // Wait for submenu to appear
                if pathComponents.count > 1 {
                    try await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000)) // 50ms
                }

                // Get the submenu
                guard let submenuChildren = menuItem.children(),
                      let submenu = submenuChildren.first
                else {
                    var context = ErrorContext()
                    context.add("submenu", component)
                    context.add("path", itemPath)
                    context.add("application", appInfo.name)
                    throw NotFoundError(
                        code: .menuNotFound,
                        userMessage: "Submenu '\(component)' not found",
                        context: context.build())
                }

                currentElement = submenu
            }
        }
    }

    /// Click a menu item by searching for it recursively in the menu hierarchy
    public func clickMenuItemByName(app: String, itemName: String) async throws {
        // Click a menu item by searching for it recursively in the menu hierarchy
        let appInfo = try await applicationService.findApplication(identifier: app)

        // First, get the menu structure to find the full path
        let menuStructure = try await listMenus(for: app)

        // Search for the item recursively
        var foundPath: String?
        for menu in menuStructure.menus {
            if let path = findItemPath(itemName: itemName, in: menu.items, currentPath: menu.title) {
                foundPath = path
                break
            }
        }

        guard let itemPath = foundPath else {
            var context = ErrorContext()
            context.add("application", appInfo.name)
            context.add("item", itemName)
            throw NotFoundError(
                code: .menuNotFound,
                userMessage: "Menu item '\(itemName)' not found in application '\(appInfo.name)'",
                context: context.build())
        }

        // Now click using the full path
        try await self.clickMenuItem(app: app, itemPath: itemPath)
    }

    /// Recursively find the full path to a menu item by name
    private func findItemPath(itemName: String, in items: [MenuItem], currentPath: String) -> String? {
        // Recursively find the full path to a menu item by name
        for item in items {
            if item.title == itemName, !item.isSeparator {
                return "\(currentPath) > \(item.title)"
            }

            // Search in submenu
            if !item.submenu.isEmpty {
                if let path = findItemPath(
                    itemName: itemName,
                    in: item.submenu,
                    currentPath: "\(currentPath) > \(item.title)")
                {
                    return path
                }
            }
        }
        return nil
    }

    public func clickMenuExtra(title: String) async throws {
        // Get system-wide element
        let systemWide = Element.systemWide()

        // Find menu bar
        guard let menuBar = systemWide.menuBar() else {
            throw PeekabooError.operationError(message: "System menu bar not found")
        }

        // Find menu extras (they're typically in a specific group)
        let menuBarItems = menuBar.children() ?? []

        // Menu extras are usually in the last group
        guard let menuExtrasGroup = menuBarItems.last(where: { $0.role() == "AXGroup" }) else {
            var context = ErrorContext()
            context.add("menuExtra", title)
            throw NotFoundError(
                code: .menuNotFound,
                userMessage: "Menu extras group not found in system menu bar",
                context: context.build())
        }

        // Find the specific menu extra
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

        // Click the menu extra with retry logic
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
        return Self.mergeMenuExtras(
            accessibilityExtras: axExtras,
            fallbackExtras: windowExtras
        )
    }

    // MARK: - Private Helpers

    private func menuBar(for appElement: Element, appInfo: ServiceApplicationInfo) throws -> Element {
        guard let menuBar = appElement.menuBarWithTimeout(timeout: 2.0) else {
            var context = ErrorContext()
            context.add("application", appInfo.name)
            throw NotFoundError(
                code: .menuNotFound,
                userMessage: "Menu bar not found for application '\(appInfo.name)'",
                context: context.build())
        }
        return menuBar
    }

    private func collectMenus(from menuBar: Element, appInfo: ServiceApplicationInfo) -> [Menu] {
        var menus: [Menu] = []
        let timeout: TimeInterval = 5.0
        let startTime = Date()

        for menuBarItem in menuBar.children() ?? [] {
            guard Date().timeIntervalSince(startTime) <= timeout else {
                self.logger.warning("Menu enumeration timed out after \(timeout)s, collected \(menus.count) menus")
                break
            }

            let extractionStart = Date()
            if let menu = self.extractMenu(from: menuBarItem, parentPath: "", application: appInfo) {
                let duration = Date().timeIntervalSince(extractionStart)
                if duration > 1.0 {
                    self.logger.debug("Menu '\(menu.title)' took \(duration)s to process")
                }
                menus.append(menu)
            }
        }

        return menus
    }

    @MainActor
    private func extractMenu(
        from menuBarItem: Element,
        parentPath: String,
        application: ServiceApplicationInfo
    ) -> Menu? {
        guard let title = menuBarItem.title() else { return nil }

        let isEnabled = menuBarItem.isEnabled() ?? true
        var items: [MenuItem] = []

        // Look for the actual menu (first child with AXMenu role)
        if let children = menuBarItem.children(),
           let menuElement = children.first(where: { $0.role() == AXRoleNames.kAXMenuRole })
        {
            if let menuChildren = menuElement.children() {
                let currentPath = parentPath.isEmpty ? title : "\(parentPath) > \(title)"
                // Limit depth to prevent excessive recursion
                let maxDepth = 3
                let currentDepth = currentPath.split(separator: ">").count
                if currentDepth < maxDepth {
                    items = self.extractMenuItems(
                        from: menuChildren,
                        parentPath: currentPath,
                        application: application
                    )
                } else {
                    self.logger.debug("Skipping menu items at depth \(currentDepth) (max: \(maxDepth))")
                }
            }
        }

        return Menu(
            title: title,
            bundleIdentifier: application.bundleIdentifier,
            ownerName: application.name,
            items: items,
            isEnabled: isEnabled)
    }

    @MainActor
    private func extractMenuItems(
        from elements: [Element],
        parentPath: String,
        application: ServiceApplicationInfo
    ) -> [MenuItem] {
        // Process all items now that we have timeout protection
        elements.compactMap { element in
            self.extractMenuItem(
                from: element,
                parentPath: parentPath,
                application: application
            )
        }
    }

    @MainActor
    private func extractMenuItem(
        from element: Element,
        parentPath: String,
        application: ServiceApplicationInfo
    ) -> MenuItem? {
        // Check if it's a separator
        if element.role() == "AXSeparatorMenuItem" {
            return MenuItem(
                title: "---",
                bundleIdentifier: application.bundleIdentifier,
                ownerName: application.name,
                isSeparator: true,
                path: "\(parentPath) > ---")
        }

        // Get title (handle attributed strings)
        let title = element.title() ?? self.attributedTitle(for: element)?.string ?? ""
        guard !title.isEmpty else { return nil }

        let path = "\(parentPath) > \(title)"
        let isEnabled = element.isEnabled() ?? true
        let isChecked = element.value() as? Bool ?? false

        // Get keyboard shortcut
        let keyboardShortcut = self.extractKeyboardShortcut(from: element)

        // Check for submenu
        var submenuItems: [MenuItem] = []
        if let children = element.children(),
           let submenuElement = children.first(where: { $0.role() == AXRoleNames.kAXMenuRole })
        {
            if let submenuChildren = submenuElement.children() {
                submenuItems = self.extractMenuItems(
                    from: submenuChildren,
                    parentPath: path,
                    application: application
                )
            }
        }

        return MenuItem(
            title: title,
            bundleIdentifier: application.bundleIdentifier,
            ownerName: application.name,
            keyboardShortcut: keyboardShortcut,
            isEnabled: isEnabled,
            isChecked: isChecked,
            isSeparator: false,
            submenu: submenuItems,
            path: path)
    }

    @MainActor
    private func findMenuItem(named name: String, in elements: [Element]) -> Element? {
        elements.first { element in
            if let title = element.title(), title == name {
                return true
            }
            // Try to get attributed title for menu items with special formatting
            if let attrTitle = element.value() as? NSAttributedString,
               attrTitle.string == name
            {
                return true
            }
            return false
        }
    }

    @MainActor
    private func attributedTitle(for element: Element) -> NSAttributedString? {
        // Try to get attributed title for menu items with special formatting
        if let attrTitle = element.value() as? NSAttributedString {
            return attrTitle
        }
        return nil
    }

    @MainActor
    private func extractKeyboardShortcut(from element: Element) -> KeyboardShortcut? {
        // Try to get keyboard shortcut from various attributes
        if let cmdChar = element.attribute(Attribute<String>("AXMenuItemCmdChar")),
           let modifiers = element.attribute(Attribute<Int>("AXMenuItemCmdModifiers"))
        {
            return self.formatKeyboardShortcut(cmdChar: cmdChar, modifiers: modifiers)
        }
        return nil
    }

    @MainActor
    private func getMenuBarItemsViaWindows() -> [MenuExtraInfo] {
        var items: [MenuExtraInfo] = []

        // Get all windows
        let windowList = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID) as? [[String: Any]] ?? []

        for windowInfo in windowList {
            // Check window layer - menu bar items are at layer 25 (kCGStatusWindowLevel)
            let windowLayer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            guard windowLayer == 25 else { continue }

            // Get window bounds
            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat
            else {
                continue
            }

            let frame = CGRect(x: x, y: y, width: width, height: height)

            // Skip off-screen items
            if x < 0 { continue }

            // Get window details
            guard (windowInfo[kCGWindowNumber as String] as? CGWindowID) != nil,
                  let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t
            else {
                continue
            }

            // Get app info
            let ownerName = windowInfo[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let windowTitle = windowInfo[kCGWindowName as String] as? String ?? ""

            // Get bundle identifier if possible
            var bundleID: String?
            if let app = NSRunningApplication(processIdentifier: ownerPID) {
                bundleID = app.bundleIdentifier
            }

            // Skip certain system windows that aren't menu bar items
            if bundleID == "com.apple.finder", windowTitle.isEmpty {
                continue
            }

            let titleOrOwner = windowTitle.isEmpty ? ownerName : windowTitle
            // Determine display name
            let friendlyTitle = self.makeMenuExtraDisplayName(
                rawTitle: titleOrOwner, ownerName: ownerName, bundleIdentifier: bundleID)

            let item = MenuExtraInfo(
                title: friendlyTitle,
                rawTitle: titleOrOwner,
                bundleIdentifier: bundleID,
                ownerName: ownerName,
                position: CGPoint(x: frame.midX, y: frame.midY),
                isVisible: true)

            items.append(item)
        }

        return items
    }

    @MainActor
    private func getMenuBarItemsViaAccessibility() -> [MenuExtraInfo] {
        // Get system-wide element
        let systemWide = Element.systemWide()

        // Find menu bar
        guard let menuBar = systemWide.menuBar() else {
            return []
        }

        // Find menu extras group
        let menuBarItems = menuBar.children() ?? []
        guard let menuExtrasGroup = menuBarItems.last(where: { $0.role() == "AXGroup" }) else {
            return []
        }

        // Extract menu extras
        let extras = menuExtrasGroup.children() ?? []
        return extras.compactMap { extra in
            let title = extra.title() ?? extra.help() ?? extra.descriptionText() ?? "Unknown"
            let position = extra.position() ?? .zero

            return MenuExtraInfo(
                title: makeMenuExtraDisplayName(
                    rawTitle: title,
                    ownerName: nil,
                    bundleIdentifier: nil
                ),
                rawTitle: title,
                bundleIdentifier: nil,
                ownerName: nil,
                position: position,
                isVisible: true)
        }
    }

    @MainActor
    internal static func mergeMenuExtras(
        accessibilityExtras: [MenuExtraInfo],
        fallbackExtras: [MenuExtraInfo]
    ) -> [MenuExtraInfo] {
        var merged = [MenuExtraInfo]()
        var seen = Set<MenuExtraIdentifier>()

        func appendIfNew(_ extra: MenuExtraInfo) {
            if merged.contains(where: { $0.position.distance(to: extra.position) < 5 }) {
                return
            }
            let identifier = MenuExtraIdentifier(extra: extra)
            guard !seen.contains(identifier) else { return }
            seen.insert(identifier)
            merged.append(extra)
        }

        accessibilityExtras.forEach(appendIfNew)
        fallbackExtras.forEach(appendIfNew)

        merged.sort { $0.position.x < $1.position.x }
        return merged
    }

    private struct MenuExtraIdentifier: Hashable {
        let bundleIdentifier: String?
        let normalizedTitle: String

        init(extra: MenuExtraInfo) {
            self.bundleIdentifier = extra.bundleIdentifier
            self.normalizedTitle = (extra.rawTitle ?? extra.title).lowercased()
        }
    }

    private func makeMenuExtraDisplayName(
        rawTitle: String?,
        ownerName: String?,
        bundleIdentifier: String?
    ) -> String {
        let fallback = rawTitle?.isEmpty == false ? rawTitle! : (ownerName ?? "Unknown")
        let namespace = MenuExtraNamespace(bundleIdentifier: bundleIdentifier)
        switch namespace {
        case .controlCenter:
            switch rawTitle {
            case "WiFi": return "Wi-Fi"
            case "BentoBox": return "Control Center"
            case "FocusModes": return "Focus"
            case "NowPlaying": return "Now Playing"
            case "ScreenMirroring": return "Screen Mirroring"
            case "KeyboardBrightness": return "Keyboard Brightness"
            case "MusicRecognition": return "Music Recognition"
            case "StageManager": return "Stage Manager"
            default: return fallback
            }
        case .systemUIServer:
            switch rawTitle {
            case "TimeMachine.TMMenuExtraHost", "TimeMachineMenuExtra.TMMenuExtraHost":
                return "Time Machine"
            default:
                return fallback
            }
        case .spotlight:
            return "Spotlight"
        case .siri:
            return "Siri"
        case .passwords:
            return "Passwords"
        case .other:
            return fallback
        }
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


    private func formatKeyboardShortcut(cmdChar: String, modifiers: Int) -> KeyboardShortcut {
        var modifierSet: Set<String> = []
        var displayParts: [String] = []

        if modifiers & (1 << 0) != 0 {
            modifierSet.insert("cmd")
            displayParts.append("⌘")
        }
        if modifiers & (1 << 1) != 0 {
            modifierSet.insert("shift")
            displayParts.append("⇧")
        }
        if modifiers & (1 << 2) != 0 {
            modifierSet.insert("option")
            displayParts.append("⌥")
        }
        if modifiers & (1 << 3) != 0 {
            modifierSet.insert("ctrl")
            displayParts.append("⌃")
        }

        displayParts.append(cmdChar.uppercased())

        return KeyboardShortcut(
            modifiers: modifierSet,
            key: cmdChar,
            displayString: displayParts.joined())
    }

    // MARK: - Menu Bar Item Methods

    /// List all menu bar items (status items)
    public func listMenuBarItems() async throws -> [MenuBarItemInfo] {
        // List all menu bar items (status items)
        let extras = try await listMenuExtras()

        // Convert MenuExtraInfo to MenuBarItemInfo with index
        return extras.enumerated().map { index, extra in
            MenuBarItemInfo(
                title: extra.title,
                index: index,
                isVisible: extra.isVisible,
                description: extra.title,
                rawTitle: extra.rawTitle,
                bundleIdentifier: extra.bundleIdentifier,
                ownerName: extra.ownerName,
                frame: CGRect(origin: extra.position, size: .zero))
        }
    }

    /// Click a menu bar item by name
    public func clickMenuBarItem(named name: String) async throws -> ClickResult {
        // Try to find and click using the existing menu extra functionality
        do {
            try await self.clickMenuExtra(title: name)
            return ClickResult(
                elementDescription: "Menu bar item: \(name)",
                location: nil)
        } catch {
            // If that fails, try to find it in the list and click by position
            let items = try await listMenuBarItems()

            // Try exact match first
            if let item = items.first(where: { $0.title == name }) {
                return try await self.clickMenuBarItem(at: item.index)
            }

            // Try case-insensitive match
            if let item = items.first(where: { $0.title?.lowercased() == name.lowercased() }) {
                return try await self.clickMenuBarItem(at: item.index)
            }

            // Try partial match
            if let item = items.first(where: { $0.title?.lowercased().contains(name.lowercased()) ?? false }) {
                return try await self.clickMenuBarItem(at: item.index)
            }

            throw NotFoundError(
                code: .menuNotFound,
                userMessage: "Menu bar item '\(name)' not found",
                context: ["availableItems": items.compactMap(\.title).joined(separator: ", ")])
        }
    }

    /// Click a menu bar item by index
    public func clickMenuBarItem(at index: Int) async throws -> ClickResult {
        // Click a menu bar item by index
        let extras = try await listMenuExtras()

        guard index >= 0, index < extras.count else {
            throw PeekabooError
                .invalidInput("Invalid menu bar item index: \(index). Valid range: 0-\(extras.count - 1)")
        }

        let extra = extras[index]

        // Click at the item's position
        let clickService = ClickService()
        try await clickService.click(
            target: .coordinates(extra.position),
            clickType: .single,
            sessionId: nil)

        return ClickResult(
            elementDescription: "Menu bar item [\(index)]: \(extra.title)",
            location: extra.position)
    }
}

// MARK: - Element Extension for Menu Bar

extension Element {
    @MainActor
    func menuBar() -> Element? {
        // Resolve the root menu bar element if the attribute is available.
        guard let menuBar = attribute(Attribute<AXUIElement>("AXMenuBar")) else {
            return nil
        }
        return Element(menuBar)
    }

    @MainActor
    static func systemWide() -> Element {
        // Return the shared system-wide accessibility element for menu interactions.
        Element(AXUIElementCreateSystemWide())
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
