import Foundation
import CoreGraphics
@preconcurrency import AXorcist
import AppKit
import os.log

/// Service for detecting UI elements in screenshots and applications
@MainActor
public final class ElementDetectionService: Sendable {
    
    private let logger = Logger(subsystem: "com.steipete.PeekabooCore", category: "ElementDetectionService")
    private let sessionManager: SessionManagerProtocol
    
    public init(sessionManager: SessionManagerProtocol? = nil) {
        self.sessionManager = sessionManager ?? SessionManager()
    }
    
    /// Detect UI elements in a screenshot
    public func detectElements(in imageData: Data, sessionId: String?, windowContext: WindowContext?) async throws -> ElementDetectionResult {
        logger.info("Starting element detection")
        
        // Get the frontmost application or specified one
        let targetApp: NSRunningApplication
        if let appName = windowContext?.applicationName {
            logger.debug("Looking for application: \(appName)")
            let apps = NSWorkspace.shared.runningApplications.filter { app in
                app.localizedName?.localizedCaseInsensitiveContains(appName) == true ||
                app.bundleIdentifier?.localizedCaseInsensitiveContains(appName) == true
            }
            
            guard let app = apps.first else {
                logger.error("Application not found: \(appName)")
                throw PeekabooError.appNotFound(appName)
            }
            targetApp = app
        } else {
            guard let app = NSWorkspace.shared.frontmostApplication else {
                logger.error("No frontmost application")
                throw PeekabooError.operationError(message: "No frontmost application")
            }
            targetApp = app
        }
        
        logger.debug("Target application: \(targetApp.localizedName ?? "Unknown") (PID: \(targetApp.processIdentifier))")
        
        // Create AX element for the application
        let axApp = AXUIElementCreateApplication(targetApp.processIdentifier)
        let appElement = Element(axApp)
        
        // Find the target window
        let targetWindow: Element?
        if let windowTitle = windowContext?.windowTitle {
            logger.debug("Looking for window with title: \(windowTitle)")
            targetWindow = appElement.windows()?.first { window in
                window.title()?.localizedCaseInsensitiveContains(windowTitle) == true
            }
        } else {
            // Use frontmost window
            targetWindow = appElement.windows()?.first { $0.isMain() == true } ?? appElement.windows()?.first
        }
        
        guard let window = targetWindow else {
            logger.error("No window found")
            throw PeekabooError.windowNotFound()
        }
        
        logger.debug("Found window: \(window.title() ?? "Untitled")")
        
        // Detect elements in window
        var detectedElements: [DetectedElement] = []
        var elementIdMap: [String: DetectedElement] = [:]
        
        // Process UI elements recursively
        func processElement(_ element: Element, parentId: String? = nil, depth: Int = 0) {
            guard depth < 20 else { return }
            
            // Get element properties
            let frame = element.frame() ?? .zero
            let role = element.role() ?? "Unknown"
            let title = element.title()
            let label = element.label()
            let value = element.stringValue()
            let description = element.descriptionText()
            let help = element.help()
            let roleDescription = element.roleDescription()
            let identifier = element.identifier()
            let isEnabled = element.isEnabled() ?? false
            
            // Skip elements outside window bounds or too small
            guard frame.width > 5 && frame.height > 5 else { return }
            
            // Generate unique ID
            let elementId = "elem_\(detectedElements.count)"
            
            // Map role to ElementType
            let elementType = mapRoleToElementType(role)
            
            // Check if actionable
            let isActionable = isElementActionable(element, role: role)
            
            // Extract keyboard shortcut if available
            let keyboardShortcut = extractKeyboardShortcut(element)
            
            // Create detected element
            let detectedElement = DetectedElement(
                id: elementId,
                type: elementType,
                label: label ?? title ?? value ?? roleDescription,
                value: value,
                bounds: frame,
                isEnabled: isEnabled,
                isSelected: nil, // Could be determined for checkboxes/radio buttons
                attributes: createElementAttributes(
                    role: role,
                    title: title,
                    description: description,
                    help: help,
                    roleDescription: roleDescription,
                    identifier: identifier,
                    isActionable: isActionable,
                    keyboardShortcut: keyboardShortcut
                )
            )
            
            detectedElements.append(detectedElement)
            elementIdMap[elementId] = detectedElement
            
            // Process children
            if let children = element.children() {
                for child in children {
                    processElement(child, parentId: elementId, depth: depth + 1)
                }
            }
        }
        
        // Start processing from window
        processElement(window)
        
        // Also process menu bar if it's the frontmost app
        var menuBarElements: [DetectedElement] = []
        if targetApp.isActive, let menuBar = appElement.menuBar() {
            processMenuBar(menuBar, elements: &menuBarElements, elementIdMap: &elementIdMap)
        }
        
        // Combine all elements
        detectedElements.append(contentsOf: menuBarElements)
        
        // Note: Parent-child relationships are not directly supported in the protocol's DetectedElement struct
        
        logger.info("Detected \(detectedElements.count) elements")
        
        // Create result
        let detectedElementsCollection = DetectedElements(
            buttons: detectedElements.filter { $0.type == .button },
            textFields: detectedElements.filter { $0.type == .textField },
            links: detectedElements.filter { $0.type == .link },
            images: detectedElements.filter { $0.type == .image },
            groups: detectedElements.filter { $0.type == .group },
            sliders: detectedElements.filter { $0.type == .slider },
            checkboxes: detectedElements.filter { $0.type == .checkbox },
            menus: detectedElements.filter { $0.type == .menu },
            other: detectedElements.filter { element in
                ![ElementType.button, .textField, .link, .image, .group, .slider, .checkbox, .menu].contains(element.type)
            }
        )
        
        let metadata = DetectionMetadata(
            detectionTime: 0.0, // Would need to track actual time
            elementCount: detectedElements.count,
            method: "AXorcist",
            warnings: [],
            windowContext: windowContext
        )
        
        let result = ElementDetectionResult(
            sessionId: sessionId ?? UUID().uuidString,
            screenshotPath: "", // Would need to save screenshot
            elements: detectedElementsCollection,
            metadata: metadata
        )
        
        // Store in session if provided
        if let sessionId = sessionId {
            try await sessionManager.storeDetectionResult(sessionId: sessionId, result: result)
        }
        
        return result
    }
    
    // MARK: - Helper Methods
    
    private func mapRoleToElementType(_ role: String) -> ElementType {
        switch role.lowercased() {
        case "axbutton", "axpopupbutton":
            return .button
        case "axtextfield", "axtextarea", "axsearchfield":
            return .textField
        case "axlink", "axweblink":
            return .link
        case "aximage":
            return .image
        case "axstatictext", "axtext":
            return .other // text not in protocol
        case "axcheckbox":
            return .checkbox
        case "axradiobutton":
            return .checkbox // Use checkbox for radio buttons
        case "axcombobox":
            return .other // Not in protocol
        case "axslider":
            return .slider
        case "axmenu":
            return .menu
        case "axmenuitem":
            return .other // menuItem not in protocol
        case "axtab":
            return .other // Not in protocol
        case "axtable":
            return .other // Not in protocol
        case "axlist":
            return .other // Not in protocol
        case "axgroup":
            return .group
        case "axtoolbar":
            return .other // Not in protocol
        case "axwindow":
            return .other // Not in protocol
        default:
            return .other
        }
    }
    
    private func isElementActionable(_ element: Element, role: String) -> Bool {
        // Check if element has press action
        if let actions = element.supportedActions(), actions.contains("AXPress") {
            return true
        }
        
        // Check by role
        let actionableRoles = [
            "axbutton", "axpopupbutton", "axtextfield", "axlink",
            "axcheckbox", "axradiobutton", "axmenuitem", "axcombobox",
            "axslider", "axtab"
        ]
        
        return actionableRoles.contains(role.lowercased())
    }
    
    @MainActor
    private func extractKeyboardShortcut(_ element: Element) -> String? {
        // Use the new keyboardShortcut() method from AXorcist
        if let shortcut = element.keyboardShortcut() {
            return shortcut
        }
        
        // Fallback: For some elements, check description which may contain shortcuts
        if let description = element.descriptionText(),
           description.contains("⌘") || description.contains("⌥") || description.contains("⌃") {
            return description
        }
        
        return nil
    }
    
    private func createElementAttributes(
        role: String,
        title: String?,
        description: String?,
        help: String?,
        roleDescription: String?,
        identifier: String?,
        isActionable: Bool,
        keyboardShortcut: String?
    ) -> [String: String] {
        var attributes: [String: String] = [:]
        
        attributes["role"] = role
        if let title = title { attributes["title"] = title }
        if let description = description { attributes["description"] = description }
        if let help = help { attributes["help"] = help }
        if let roleDescription = roleDescription { attributes["roleDescription"] = roleDescription }
        if let identifier = identifier { attributes["identifier"] = identifier }
        if isActionable { attributes["isActionable"] = "true" }
        if let shortcut = keyboardShortcut { attributes["keyboardShortcut"] = shortcut }
        
        return attributes
    }
    
    private func processMenuBar(_ menuBar: Element, elements: inout [DetectedElement], elementIdMap: inout [String: DetectedElement]) {
        guard let menus = menuBar.children() else { return }
        
        for menu in menus {
            let menuId = "menu_\(elements.count)"
            let menuFrame = menu.frame() ?? .zero
            
            let menuElement = DetectedElement(
                id: menuId,
                type: .menu,
                label: menu.title() ?? "Menu",
                value: nil,
                bounds: menuFrame,
                isEnabled: menu.isEnabled() ?? true,
                isSelected: nil,
                attributes: ["role": "AXMenu"]
            )
            
            elements.append(menuElement)
            elementIdMap[menuId] = menuElement
            
            // Process menu items if menu is open
            if let menuItems = menu.children() {
                processMenuItems(menuItems, parentId: menuId, elements: &elements, elementIdMap: &elementIdMap)
            }
        }
    }
    
    @MainActor
    private func processMenuItems(_ items: [Element], parentId: String, elements: inout [DetectedElement], elementIdMap: inout [String: DetectedElement]) {
        for item in items {
            let itemId = "menuitem_\(elements.count)"
            let itemFrame = item.frame() ?? .zero
            
            let menuItemElement = DetectedElement(
                id: itemId,
                type: .other, // menuItem not in protocol
                label: item.title() ?? "Menu Item",
                value: nil,
                bounds: itemFrame,
                isEnabled: item.isEnabled() ?? true,
                isSelected: nil,
                attributes: createMenuItemAttributes(item)
            )
            
            elements.append(menuItemElement)
            elementIdMap[itemId] = menuItemElement
            
            // Note: Parent-child relationships not supported in protocol
            
            // Process submenu items
            if let submenu = item.children(), !submenu.isEmpty {
                processMenuItems(submenu, parentId: itemId, elements: &elements, elementIdMap: &elementIdMap)
            }
        }
    }
    
    @MainActor
    private func createMenuItemAttributes(_ item: Element) -> [String: String] {
        var attributes: [String: String] = ["role": "AXMenuItem"]
        
        if let title = item.title() { attributes["title"] = title }
        if let shortcut = extractKeyboardShortcut(item) { attributes["keyboardShortcut"] = shortcut }
        if item.isEnabled() == false { attributes["isEnabled"] = "false" }
        
        // Note: Check for special menu item types like checkmarks not implemented yet
        
        return attributes
    }
}