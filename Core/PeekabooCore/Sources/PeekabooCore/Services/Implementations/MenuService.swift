import Foundation
import CoreGraphics
import AppKit
import AXorcist

/// Default implementation of menu interaction operations
public final class MenuService: MenuServiceProtocol {
    
    private let applicationService: ApplicationServiceProtocol
    
    public init(applicationService: ApplicationServiceProtocol? = nil) {
        self.applicationService = applicationService ?? ApplicationService()
    }
    
    public func listMenus(for appIdentifier: String) async throws -> MenuStructure {
        let appInfo = try await applicationService.findApplication(identifier: appIdentifier)
        
        return try await MainActor.run {
            // Get AX element for the application
            let axApp = AXUIElementCreateApplication(appInfo.processIdentifier)
            let appElement = Element(axApp)
            
            // Get menu bar
            guard let menuBar = appElement.menuBar() else {
                var context = ErrorContext()
                context.add("application", appInfo.name)
                throw NotFoundError(
                    code: .menuNotFound,
                    userMessage: "Menu bar not found for application '\(appInfo.name)'",
                    context: context.build()
                )
            }
            
            // Collect all menus
            var menus: [Menu] = []
            
            let topLevelMenus = menuBar.children() ?? []
            for menuBarItem in topLevelMenus {
                if let menu = extractMenu(from: menuBarItem, parentPath: "") {
                    menus.append(menu)
                }
            }
            
            return MenuStructure(application: appInfo, menus: menus)
        }
    }
    
    public func listFrontmostMenus() async throws -> MenuStructure {
        let frontmostApp = try await applicationService.getFrontmostApplication()
        return try await listMenus(for: frontmostApp.bundleIdentifier ?? frontmostApp.name)
    }
    
    public func clickMenuItem(app: String, itemPath: String) async throws {
        let appInfo = try await applicationService.findApplication(identifier: app)
        
        // Parse menu path
        let pathComponents = itemPath.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Perform all menu operations within MainActor context
        try await MainActor.run {
            // Get AX element for the application
            let axApp = AXUIElementCreateApplication(appInfo.processIdentifier)
            let appElement = Element(axApp)
            
            guard let menuBar = appElement.menuBar() else {
                var context = ErrorContext()
                context.add("application", appInfo.name)
                throw NotFoundError(
                    code: .menuNotFound,
                    userMessage: "Menu bar not found for application '\(appInfo.name)'",
                    context: context.build()
                )
            }
            
            // Navigate menu hierarchy
            var currentElement: Element = menuBar
            
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
                        context: context.build()
                    )
                }
                
                // If this is the last component, click it
                if index == pathComponents.count - 1 {
                    do {
                        try menuItem.performAction(Attribute<String>("AXPress"))
                    } catch {
                        throw OperationError.interactionFailed(
                            action: "click menu item",
                            reason: "Failed to click menu item '\(component)'"
                        )
                    }
                } else {
                    // Otherwise, open the submenu
                    do {
                        try menuItem.performAction(Attribute<String>("AXPress"))
                    } catch {
                        throw OperationError.interactionFailed(
                            action: "open submenu",
                            reason: "Failed to open submenu '\(component)'"
                        )
                    }
                    
                    // Note: We can't use Task.sleep inside MainActor.run
                    // The submenu should be available immediately after clicking
                    
                    // Get the submenu
                    guard let submenuChildren = menuItem.children(),
                          let submenu = submenuChildren.first else {
                        var context = ErrorContext()
                        context.add("submenu", component)
                        context.add("path", itemPath)
                        context.add("application", appInfo.name)
                        throw NotFoundError(
                            code: .menuNotFound,
                            userMessage: "Submenu '\(component)' not found",
                            context: context.build()
                        )
                    }
                    
                    currentElement = submenu
                }
            }
        }
        
        // If we need a delay between menu operations, do it outside MainActor
        if pathComponents.count > 1 {
            try await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000)) // 50ms
        }
    }
    
    public func clickMenuExtra(title: String) async throws {
        try await MainActor.run {
            // Get system-wide element
            let systemWide = Element.systemWide()
            
            // Find menu bar
            guard let menuBar = systemWide.menuBar() else {
                throw NotFoundError(
                    code: .menuNotFound,
                    userMessage: "System menu bar not found",
                    context: ["type": "system_menu_bar"]
                )
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
                    context: context.build()
                )
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
                    context: context.build()
                )
            }
            
            // Click the menu extra with retry logic
            do {
                try menuExtra.performAction(.press)
            } catch {
                throw OperationError.interactionFailed(
                    action: "click menu extra",
                    reason: "Failed to click menu extra '\(title)'"
                )
            }
        }
    }
    
    public func listMenuExtras() async throws -> [MenuExtraInfo] {
        return await MainActor.run {
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
                    title: title,
                    position: position,
                    isVisible: true
                )
            }
        }
    }
    
    // MARK: - Private Helpers
    
    @MainActor
    private func extractMenu(from menuBarItem: Element, parentPath: String) -> Menu? {
        guard let title = menuBarItem.title() else { return nil }
        
        let isEnabled = menuBarItem.isEnabled() ?? true
        var items: [MenuItem] = []
        
        // Look for the actual menu (first child with AXMenu role)
        if let children = menuBarItem.children() {
            for child in children {
                if child.role() == AXRoleNames.kAXMenuRole {
                    // This is the menu, extract its items
                    if let menuChildren = child.children() {
                        let currentPath = parentPath.isEmpty ? title : "\(parentPath) > \(title)"
                        items = extractMenuItems(from: menuChildren, parentPath: currentPath)
                    }
                    break
                }
            }
        }
        
        return Menu(title: title, items: items, isEnabled: isEnabled)
    }
    
    @MainActor
    private func extractMenuItems(from elements: [Element], parentPath: String) -> [MenuItem] {
        return elements.compactMap { element in
            extractMenuItem(from: element, parentPath: parentPath)
        }
    }
    
    @MainActor
    private func extractMenuItem(from element: Element, parentPath: String) -> MenuItem? {
        // Check if it's a separator
        if element.role() == "AXSeparatorMenuItem" {
            return MenuItem(
                title: "---",
                isSeparator: true,
                path: "\(parentPath) > ---"
            )
        }
        
        // Get title (handle attributed strings)
        let title = element.title() ?? attributedTitle(for: element)?.string ?? ""
        guard !title.isEmpty else { return nil }
        
        let path = "\(parentPath) > \(title)"
        let isEnabled = element.isEnabled() ?? true
        let isChecked = element.value() as? Bool ?? false
        
        // Get keyboard shortcut
        let keyboardShortcut = extractKeyboardShortcut(from: element)
        
        // Check for submenu
        var submenuItems: [MenuItem] = []
        if let children = element.children() {
            for child in children {
                if child.role() == AXRoleNames.kAXMenuRole {
                    if let submenuChildren = child.children() {
                        submenuItems = extractMenuItems(from: submenuChildren, parentPath: path)
                    }
                    break
                }
            }
        }
        
        return MenuItem(
            title: title,
            keyboardShortcut: keyboardShortcut,
            isEnabled: isEnabled,
            isChecked: isChecked,
            isSeparator: false,
            submenu: submenuItems,
            path: path
        )
    }
    
    @MainActor
    private func findMenuItem(named name: String, in elements: [Element]) -> Element? {
        return elements.first { element in
            if let title = element.title(), title == name {
                return true
            }
            // Try to get attributed title for menu items with special formatting
            if let attrTitle = element.value() as? NSAttributedString,
               attrTitle.string == name {
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
           let modifiers = element.attribute(Attribute<Int>("AXMenuItemCmdModifiers")) {
            return formatKeyboardShortcut(cmdChar: cmdChar, modifiers: modifiers)
        }
        return nil
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
            displayString: displayParts.joined()
        )
    }
}

// MARK: - Element Extension for Menu Bar

extension Element {
    @MainActor
    func menuBar() -> Element? {
        guard let menuBar = attribute(Attribute<AXUIElement>("AXMenuBar")) else {
            return nil
        }
        return Element(menuBar)
    }
    
    @MainActor
    static func systemWide() -> Element {
        Element(AXUIElementCreateSystemWide())
    }
}