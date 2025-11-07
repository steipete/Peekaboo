import AppKit
@preconcurrency import AXorcist
import CoreGraphics
import Foundation
import os.log
import PeekabooFoundation

/**
 * AI-powered UI element detection service for screenshot analysis.
 *
 * Combines computer vision with accessibility APIs to detect and classify interactive
 * UI elements in screenshots. Provides element identification, bounds calculation,
 * and accessibility correlation for automation targeting.
 *
 * ## Detection Capabilities
 * - Button, text field, image, and static text recognition
 * - Element bounds and coordinate mapping
 * - Accessibility attribute extraction
 * - Session-based element caching
 *
 * ## Usage Example
 * ```swift
 * let detectionService = ElementDetectionService(sessionManager: sessionManager)
 *
 * let result = try await detectionService.detectElements(
 *     in: screenshotData,
 *     sessionId: "session_123",
 *     windowContext: WindowContext(applicationName: "Safari")
 * )
 *
 * print("Detected \(result.elements.all.count) elements")
 * ```
 *
 * - Note: Core component of UIAutomationService's element recognition pipeline
 * - Since: PeekabooCore 1.0.0
 */
@MainActor
public final class ElementDetectionService {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "ElementDetectionService")
    private let sessionManager: any SessionManagerProtocol

    public init(sessionManager: (any SessionManagerProtocol)? = nil) {
        self.sessionManager = sessionManager ?? SessionManager()
    }

    /// Detect UI elements in a screenshot
    public func detectElements(
        in imageData: Data,
        sessionId: String?,
        windowContext: WindowContext?) async throws -> ElementDetectionResult
    {
        // Detect UI elements in a screenshot
        self.logger.info("Starting element detection")

        // Get the frontmost application or specified one
        let targetApp: NSRunningApplication
        if let appName = windowContext?.applicationName {
            self.logger.debug("Looking for application: \(appName)")
            let apps = NSWorkspace.shared.runningApplications.filter { app in
                app.localizedName?.localizedCaseInsensitiveContains(appName) == true ||
                    app.bundleIdentifier?.localizedCaseInsensitiveContains(appName) == true
            }

            guard let app = apps.first else {
                self.logger.error("Application not found: \(appName)")
                throw PeekabooError.appNotFound(appName)
            }
            targetApp = app
        } else {
            guard let app = NSWorkspace.shared.frontmostApplication else {
                self.logger.error("No frontmost application")
                throw PeekabooError.operationError(message: "No frontmost application")
            }
            targetApp = app
        }

        self.logger
            .debug("Target application: \(targetApp.localizedName ?? "Unknown") (PID: \(targetApp.processIdentifier))")

        // Create AX element for the application
        let axApp = AXUIElementCreateApplication(targetApp.processIdentifier)
        let appElement = Element(axApp)

        // Find the target window
        let allWindows = appElement.windows() ?? []
        self.logger.debug("Found \(allWindows.count) windows for \(targetApp.localizedName ?? "app")")

        // Check for dialogs if no regular windows
        var targetWindow: Element?
        var isDialog = false

        // First, look for the specific window if a title is provided
        if let windowTitle = windowContext?.windowTitle {
            self.logger.debug("Looking for window with title: \(windowTitle)")
            targetWindow = allWindows.first { window in
                window.title()?.localizedCaseInsensitiveContains(windowTitle) == true
            }
        }

        // Always check all windows to detect dialogs
        self.logger.debug("Checking \(allWindows.count) windows for dialog characteristics")

        for window in allWindows {
            let title = window.title() ?? ""
            let subrole = window.subrole() ?? ""
            let isMain = window.isMain() ?? false

            self.logger.debug("Window: '\(title)', subrole: '\(subrole)', isMain: \(isMain)")

            // Check if this is a file dialog based on title and characteristics
            let isFileDialog = title == "Open" ||
                title == "Save" ||
                title.hasPrefix("Save As") ||
                title == "Export" ||
                title == "Import"

            // Also check for traditional dialog subroles
            let isDialogSubrole = subrole == "AXDialog" ||
                subrole == "AXSystemDialog" ||
                subrole == "AXSheet"

            if isFileDialog || isDialogSubrole {
                // If we already have a target window and it matches this dialog, mark it as dialog
                if let target = targetWindow, target.title() == window.title() {
                    isDialog = true
                    self.logger
                        .info(
                            "🗨️ Target window is a dialog: '\(title)' (subrole: \(subrole), isFileDialog: \(isFileDialog))")
                }
                // If we don't have a target window yet, use this dialog
                else if targetWindow == nil {
                    targetWindow = window
                    isDialog = true
                    self.logger
                        .info("🗨️ Using dialog window: '\(title)' (subrole: \(subrole), isFileDialog: \(isFileDialog))")
                }
            }
        }

        // If no window found yet, try to find main window
        if targetWindow == nil {
            targetWindow = allWindows.first { $0.isMain() == true }
        }

        // Fall back to any window
        if targetWindow == nil {
            targetWindow = allWindows.first
        }

        guard let window = targetWindow else {
            // Provide detailed error message
            let appName = targetApp.localizedName ?? "Unknown app"

            if allWindows.isEmpty {
                self.logger.error("App '\(appName)' has no windows")
                throw PeekabooError
                    .windowNotFound(criteria: "App '\(appName)' is running but has no windows or dialogs")
            } else {
                self.logger.error("No suitable window found for app '\(appName)'")
                throw PeekabooError.windowNotFound(criteria: "No accessible window found for '\(appName)'")
            }
        }

        let windowType = isDialog ? "dialog" : "window"
        self.logger.debug("Found \(windowType): \(window.title() ?? "Untitled")")

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

            // Debug logging for button label issues
            if role.lowercased() == "axbutton" {
                self.logger
                    .debug(
                        "🔍 Button debug - title: '\(title ?? "nil")', label: '\(label ?? "nil")', value: '\(value ?? "nil")', roleDescription: '\(roleDescription ?? "nil")', description: '\(description ?? "nil")', identifier: '\(identifier ?? "nil")'")
            }
            let isEnabled = element.isEnabled() ?? false

            // Skip elements outside window bounds or too small
            guard frame.width > 5, frame.height > 5 else { return }

            // Generate unique ID
            let elementId = "elem_\(detectedElements.count)"

            // Map role to ElementType
            let elementType = self.mapRoleToElementType(role)

            // Check if actionable
            let isActionable = self.isElementActionable(element, role: role)

            // Extract keyboard shortcut if available
            let keyboardShortcut = self.extractKeyboardShortcut(element)

            // Enhanced label extraction for SwiftUI compatibility
            var effectiveLabel = label ?? title ?? value ?? roleDescription

            // Special handling for SwiftUI buttons
            if role.lowercased() == "axbutton", effectiveLabel == "button" {
                // Try description as it might contain the actual button text
                if let desc = description, !desc.isEmpty, desc != "button" {
                    effectiveLabel = desc
                }
                // Try identifier which might be set via .accessibilityIdentifier()
                else if let id = identifier, !id.isEmpty {
                    // Convert identifier like "minimize-button" to "Minimize"
                    let cleaned = id.replacingOccurrences(of: "-button", with: "")
                        .replacingOccurrences(of: "-", with: " ")
                        .split(separator: " ")
                        .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                        .joined(separator: " ")
                    effectiveLabel = cleaned
                }
            }

            // Create detected element
            let detectedElement = DetectedElement(
                id: elementId,
                type: elementType,
                label: effectiveLabel,
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
                    keyboardShortcut: keyboardShortcut))

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
            self.processMenuBar(menuBar, elements: &menuBarElements, elementIdMap: &elementIdMap)
        }

        // Combine all elements
        detectedElements.append(contentsOf: menuBarElements)

        // Note: Parent-child relationships are not directly supported in the protocol's DetectedElement struct

        self.logger.info("Detected \(detectedElements.count) elements")

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
                ![ElementType.button, .textField, .link, .image, .group, .slider, .checkbox, .menu]
                    .contains(element.type)
            })

        let metadata = DetectionMetadata(
            detectionTime: 0.0, // Would need to track actual time
            elementCount: detectedElements.count,
            method: "AXorcist",
            warnings: [],
            windowContext: windowContext,
            isDialog: isDialog)

        let result = ElementDetectionResult(
            sessionId: sessionId ?? UUID().uuidString,
            screenshotPath: "", // Would need to save screenshot
            elements: detectedElementsCollection,
            metadata: metadata)

        // Store in session if provided
        if let sessionId {
            try await self.sessionManager.storeDetectionResult(sessionId: sessionId, result: result)
        }

        return result
    }

    // MARK: - Helper Methods

    private func mapRoleToElementType(_ role: String) -> ElementType {
        switch role.lowercased() {
        case "axbutton", "axpopupbutton":
            .button
        case "axtextfield", "axtextarea", "axsearchfield":
            .textField
        case "axlink", "axweblink":
            .link
        case "aximage":
            .image
        case "axstatictext", "axtext":
            .other // text not in protocol
        case "axcheckbox":
            .checkbox
        case "axradiobutton":
            .checkbox // Use checkbox for radio buttons
        case "axcombobox":
            .other // Not in protocol
        case "axslider":
            .slider
        case "axmenu":
            .menu
        case "axmenuitem":
            .other // menuItem not in protocol
        case "axtab":
            .other // Not in protocol
        case "axtable":
            .other // Not in protocol
        case "axlist":
            .other // Not in protocol
        case "axgroup":
            .group
        case "axtoolbar":
            .other // Not in protocol
        case "axwindow":
            .other // Not in protocol
        default:
            .other
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
            "axslider", "axtab",
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
           description.contains("⌘") || description.contains("⌥") || description.contains("⌃")
        {
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
        keyboardShortcut: String?) -> [String: String]
    {
        var attributes: [String: String] = [:]

        attributes["role"] = role
        if let title { attributes["title"] = title }
        if let description { attributes["description"] = description }
        if let help { attributes["help"] = help }
        if let roleDescription { attributes["roleDescription"] = roleDescription }
        if let identifier { attributes["identifier"] = identifier }
        if isActionable { attributes["isActionable"] = "true" }
        if let shortcut = keyboardShortcut { attributes["keyboardShortcut"] = shortcut }

        return attributes
    }

    private func processMenuBar(
        _ menuBar: Element,
        elements: inout [DetectedElement],
        elementIdMap: inout [String: DetectedElement])
    {
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
                attributes: ["role": "AXMenu"])

            elements.append(menuElement)
            elementIdMap[menuId] = menuElement

            // Process menu items if menu is open
            if let menuItems = menu.children() {
                self.processMenuItems(menuItems, parentId: menuId, elements: &elements, elementIdMap: &elementIdMap)
            }
        }
    }

    @MainActor
    private func processMenuItems(
        _ items: [Element],
        parentId: String,
        elements: inout [DetectedElement],
        elementIdMap: inout [String: DetectedElement])
    {
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
                attributes: self.createMenuItemAttributes(item))

            elements.append(menuItemElement)
            elementIdMap[itemId] = menuItemElement

            // Note: Parent-child relationships not supported in protocol

            // Process submenu items
            if let submenu = item.children(), !submenu.isEmpty {
                self.processMenuItems(submenu, parentId: itemId, elements: &elements, elementIdMap: &elementIdMap)
            }
        }
    }

    @MainActor
    private func createMenuItemAttributes(_ item: Element) -> [String: String] {
        var attributes = ["role": "AXMenuItem"]

        if let title = item.title() { attributes["title"] = title }
        if let shortcut = extractKeyboardShortcut(item) { attributes["keyboardShortcut"] = shortcut }
        if item.isEnabled() == false { attributes["isEnabled"] = "false" }

        // Note: Check for special menu item types like checkmarks not implemented yet

        return attributes
    }
}
