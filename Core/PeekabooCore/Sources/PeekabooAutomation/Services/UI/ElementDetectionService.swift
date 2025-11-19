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
    private let windowIdentityService = WindowIdentityService()
    private let windowManagementService = WindowManagementService()

    public init(sessionManager: (any SessionManagerProtocol)? = nil) {
        self.sessionManager = sessionManager ?? SessionManager()
    }

    /// Detect UI elements in a screenshot
    public func detectElements(
        in imageData: Data,
        sessionId: String?,
        windowContext: WindowContext?) async throws -> ElementDetectionResult
    {
        self.logger.info("Starting element detection")

        let targetApp = try self.resolveApplication(windowContext: windowContext)
        let windowResolution = try await self.resolveWindow(for: targetApp, context: windowContext)
        let windowName = windowResolution.window.title() ?? "Untitled"
        self.logger.debug("Found \(windowResolution.windowTypeDescription): \(windowName)")

        var elementIdMap: [String: DetectedElement] = [:]
        let allowWebFocus = windowContext?.shouldFocusWebContent ?? true
        let detectedElements = await self.collectElements(
            window: windowResolution.window,
            appElement: windowResolution.appElement,
            appIsActive: targetApp.isActive,
            allowWebFocus: allowWebFocus,
            elementIdMap: &elementIdMap)

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
            isDialog: windowResolution.isDialog)

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
}

extension ElementDetectionService {
    private static let textualRoles: Set<String> = [
        "axstatictext",
        "axtext",
        "axbutton",
        "axlink",
        "axdescription",
        "axunknown",
    ]
    private static let textFieldRoles: Set<String> = [
        "axtextfield",
        "axtextarea",
        "axsearchfield",
        "axsecuretextfield",
    ]
    private static let maxTraversalDepth = 80
    private static let maxWebFocusAttempts = 2

    // MARK: - Helper Methods

    private func mapRoleToElementType(_ role: String) -> ElementType {
        switch role.lowercased() {
        case "axbutton", "axpopupbutton":
            .button
        case _ where Self.textFieldRoles.contains(role.lowercased()):
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

    private func resolveApplication(windowContext: WindowContext?) throws -> NSRunningApplication {
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
            return app
        }

        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            self.logger.error("No frontmost application")
            throw PeekabooError.operationError(message: "No frontmost application")
        }
        return frontmost
    }

    private func resolveWindow(
        for app: NSRunningApplication,
        context: WindowContext?) async throws -> WindowResolution
    {
        let appElement = AXApp(app).element
        // Chrome and other multi-process apps occasionally return an empty window list unless we set
        // an explicit AX messaging timeout, so prefer the guarded helper.
        let axWindows = appElement.windowsWithTimeout() ?? []
        self.logger.debug("Found \(axWindows.count) windows for \(app.localizedName ?? "app")")

        let renderableWindows = self.renderableWindows(from: axWindows)
        let candidateWindows = renderableWindows.isEmpty ? axWindows : renderableWindows
        self.logger.notice("Renderable AX windows: \(renderableWindows.count) / \(axWindows.count)")

        let initialWindow = self.selectWindow(allWindows: candidateWindows, title: context?.windowTitle)
        let dialogResolution = self.detectDialogWindow(in: candidateWindows, targetWindow: initialWindow)

        var finalWindow = dialogResolution.window ??
            initialWindow ??
            candidateWindows.first { $0.isMain() == true } ??
            candidateWindows.first

        if finalWindow == nil {
            finalWindow = self.focusedWindowIfMatches(app: app)
        }

        // When AX window enumeration yields nothing, progressively fall back to CG metadata
        if finalWindow == nil {
            finalWindow = await self.resolveWindowViaCGFallback(for: app, title: context?.windowTitle)
        }

        if finalWindow == nil {
            finalWindow = await self.resolveWindowViaWindowServiceFallback(for: app, title: context?.windowTitle)
        }

        guard let resolvedWindow = finalWindow else {
            try self.handleMissingWindow(app: app, windows: axWindows)
        }

        return WindowResolution(
            appElement: appElement,
            window: resolvedWindow,
            isDialog: dialogResolution.isDialog)
    }

    private func selectWindow(allWindows: [Element], title: String?) -> Element? {
        guard let title else { return nil }
        self.logger.debug("Looking for window with title: \(title)")
        return allWindows.first { window in
            window.title()?.localizedCaseInsensitiveContains(title) == true
        }
    }

    private func detectDialogWindow(in windows: [Element], targetWindow: Element?) -> DialogResolution {
        self.logger.debug("Checking \(windows.count) windows for dialog characteristics")
        for window in windows {
            let title = window.title() ?? ""
            let subrole = window.subrole() ?? ""
            let isFileDialog = self.isFileDialogTitle(title)
            let isDialogRole = ["AXDialog", "AXSystemDialog", "AXSheet"].contains(subrole)

            guard isFileDialog || isDialogRole else { continue }
            if let targetWindow, targetWindow.title() == window.title() {
                self.logger.info("🗨️ Target window is a dialog: '\(title)' (subrole: \(subrole))")
                return DialogResolution(window: targetWindow, isDialog: true)
            }

            self.logger.info("🗨️ Using dialog window: '\(title)' (subrole: \(subrole))")
            return DialogResolution(window: window, isDialog: true)
        }
        return DialogResolution(window: targetWindow, isDialog: false)
    }

    private func isFileDialogTitle(_ title: String) -> Bool {
        ["Open", "Save", "Export", "Import"].contains(title) || title.hasPrefix("Save As")
    }

    private func handleMissingWindow(app: NSRunningApplication, windows: [Element]) throws -> Never {
        let appName = app.localizedName ?? "Unknown app"
        if windows.isEmpty {
            self.logger.error("App '\(appName)' has no windows")
            throw PeekabooError
                .windowNotFound(criteria: "App '\(appName)' is running but has no windows or dialogs")
        }

        self.logger.error("No suitable window found for app '\(appName)'")
        throw PeekabooError.windowNotFound(criteria: "No accessible window found for '\(appName)'")
    }

    private func renderableWindows(from windows: [Element]) -> [Element] {
        windows.filter { window in
            guard
                let frame = window.frame(),
                frame.width >= 50,
                frame.height >= 50,
                window.isMinimized() != true
            else { return false }
            return true
        }
    }

    private func resolveWindowViaCGFallback(for app: NSRunningApplication, title: String?) async -> Element? {
        let cgWindows = self.windowIdentityService.getWindows(for: app)
        guard !cgWindows.isEmpty else {
            self.logger.notice("CG fallback found 0 windows for \(app.localizedName ?? "app")")
            return nil
        }

        let renderable = cgWindows.filter(\.isRenderable)
        let orderedWindows = (renderable.isEmpty ? cgWindows : renderable)
            .sorted { $0.bounds.size.area > $1.bounds.size.area }
        self.logger.notice("CG fallback renderable windows: \(renderable.count) / \(cgWindows.count)")

        if let title {
            if let matching = orderedWindows.first(where: {
                $0.title?.localizedCaseInsensitiveContains(title) == true
            }), let element = self.windowIdentityService.findWindow(byID: matching.windowID)?.element {
                let fallbackTarget = app.localizedName ?? "app"
                let fallbackTitle = matching.title ?? "Untitled"
                self.logger.info("Using CG fallback window '\(fallbackTitle)' for \(fallbackTarget)")
                await self.focusWindow(withID: Int(matching.windowID), appName: app.localizedName ?? "app")
                if let focused = self.focusedWindowIfMatches(app: app) {
                    return focused
                }
                return element
            }
        }

        for info in orderedWindows {
            if let element = self.windowIdentityService.findWindow(byID: info.windowID)?.element {
                let fallbackTarget = app.localizedName ?? "app"
                let fallbackTitle = info.title ?? "Untitled"
                self.logger.info("Using CG fallback window '\(fallbackTitle)' for \(fallbackTarget)")
                await self.focusWindow(withID: Int(info.windowID), appName: app.localizedName ?? "app")
                if let focused = self.focusedWindowIfMatches(app: app) {
                    return focused
                }
                return element
            }
        }

        return nil
    }

    // Fallback #3: ask the window-management service (which already talks to CG+AX) for candidates
    private func resolveWindowViaWindowServiceFallback(
        for app: NSRunningApplication,
        title: String?) async -> Element?
    {
        let identifier = app.localizedName ?? app.bundleIdentifier ?? "PID:\(app.processIdentifier)"
        do {
            let windows = try await self.windowManagementService.listWindows(target: .application(identifier))
            guard !windows.isEmpty else {
                self.logger.notice("Window service fallback found 0 windows for \(identifier)")
                return nil
            }

            self.logger.notice("Window service fallback inspecting \(windows.count) windows for \(identifier)")

            let ordered = windows.sorted { lhs, rhs in
                let lArea = lhs.bounds.size.area
                let rArea = rhs.bounds.size.area
                return lArea > rArea
            }

            let targetWindowInfo: ServiceWindowInfo? = if let title,
                                                          let match = ordered
                                                              .first(where: {
                                                                  $0.title.localizedCaseInsensitiveContains(title)
                                                              })
            {
                match
            } else {
                ordered.first
            }

            guard let windowInfo = targetWindowInfo,
                  let element = self.windowIdentityService.findWindow(byID: CGWindowID(windowInfo.windowID))?.element
            else {
                self.logger.warning("Window service fallback could not resolve AX window for \(identifier)")
                return nil
            }

            self.logger.notice("Using window service fallback window '\(windowInfo.title)' for \(identifier)")
            await self.focusWindow(withID: windowInfo.windowID, appName: identifier)
            if let focused = self.focusedWindowIfMatches(app: app) {
                return focused
            }
            return element
        } catch {
            self.logger.error("Window service fallback failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func focusedWindowIfMatches(app: NSRunningApplication) -> Element? {
        let systemWide = Element.systemWide()
        guard let focusedWindow = systemWide.focusedWindow(),
              let pid = focusedWindow.pid()
        else {
            return nil
        }

        if pid != app.processIdentifier {
            guard
                let ownerApp = NSRunningApplication(processIdentifier: pid),
                ownerApp.bundleIdentifier == app.bundleIdentifier
            else {
                return nil
            }
        }

        self.logger.notice("Using focused window fallback for \(app.localizedName ?? "app")")
        return focusedWindow
    }

    private func focusWindow(withID windowID: Int, appName: String) async {
        do {
            try await self.windowManagementService.focusWindow(target: .windowId(windowID))
        } catch {
            self.logger.warning("Failed to focus window \(windowID) for \(appName): \(error.localizedDescription)")
        }
    }

    private func collectElements(
        window: Element,
        appElement: Element,
        appIsActive: Bool,
        allowWebFocus: Bool,
        elementIdMap: inout [String: DetectedElement]) async -> [DetectedElement]
    {
        var detectedElements: [DetectedElement] = []
        var attempt = 0

        repeat {
            elementIdMap.removeAll(keepingCapacity: true)
            detectedElements.removeAll(keepingCapacity: true)

            var visitedElements = Set<Element>()
            self.processElement(
                window,
                depth: 0,
                detectedElements: &detectedElements,
                elementIdMap: &elementIdMap,
                visitedElements: &visitedElements)

            self.processElement(
                appElement,
                depth: 0,
                detectedElements: &detectedElements,
                elementIdMap: &elementIdMap,
                visitedElements: &visitedElements)

            if let focusedElement = appElement.focusedUIElement() {
                self.processElement(
                    focusedElement,
                    depth: 0,
                    detectedElements: &detectedElements,
                    elementIdMap: &elementIdMap,
                    visitedElements: &visitedElements)
            }

            if appIsActive, let menuBar = appElement.menuBar() {
                self.processMenuBar(menuBar, elements: &detectedElements, elementIdMap: &elementIdMap)
            }

            if detectedElements.contains(where: { $0.type == .textField }) {
                break
            }

            guard attempt < Self.maxWebFocusAttempts,
                  allowWebFocus,
                  self.focusWebContentIfNeeded(window: window, appElement: appElement)
            else {
                break
            }

            attempt += 1
            try? await Task.sleep(nanoseconds: 150_000_000)
        } while true

        return detectedElements
    }

    private func processElement(
        _ element: Element,
        depth: Int,
        detectedElements: inout [DetectedElement],
        elementIdMap: inout [String: DetectedElement],
        visitedElements: inout Set<Element>)
    {
        guard depth < Self.maxTraversalDepth else { return }
        guard visitedElements.insert(element).inserted else { return }
        guard let descriptor = self.describeElement(element) else { return }

        self.logButtonDebugInfoIfNeeded(descriptor)

        let elementId = "elem_\(detectedElements.count)"
        let baseType = self.mapRoleToElementType(descriptor.role)
        let elementType = self.adjustedElementType(element: element, descriptor: descriptor, baseType: baseType)
        let isActionable = self.isElementActionable(element, role: descriptor.role)
        let keyboardShortcut = self.extractKeyboardShortcut(element)
        let label = self.effectiveLabel(for: element, descriptor: descriptor)

        let attributes = self.createElementAttributes(
            ElementAttributeInput(
                role: descriptor.role,
                title: descriptor.title,
                description: descriptor.description,
                help: descriptor.help,
                roleDescription: descriptor.roleDescription,
                identifier: descriptor.identifier,
                isActionable: isActionable,
                keyboardShortcut: keyboardShortcut,
                placeholder: descriptor.placeholder))

        let detectedElement = DetectedElement(
            id: elementId,
            type: elementType,
            label: label,
            value: descriptor.value,
            bounds: descriptor.frame,
            isEnabled: descriptor.isEnabled,
            isSelected: nil,
            attributes: attributes)

        detectedElements.append(detectedElement)
        elementIdMap[elementId] = detectedElement

        self.processChildren(
            of: element,
            depth: depth + 1,
            detectedElements: &detectedElements,
            elementIdMap: &elementIdMap,
            visitedElements: &visitedElements)
    }

    private func describeElement(_ element: Element) -> ElementDescriptor? {
        let frame = element.frame() ?? .zero
        guard frame.width > 5, frame.height > 5 else { return nil }

        return ElementDescriptor(
            frame: frame,
            role: element.role() ?? "Unknown",
            title: element.title(),
            label: element.label(),
            value: element.stringValue(),
            description: element.descriptionText(),
            help: element.help(),
            roleDescription: element.roleDescription(),
            identifier: element.identifier(),
            isEnabled: element.isEnabled() ?? false,
            placeholder: element.placeholderValue())
    }

    private func processChildren(
        of element: Element,
        depth: Int,
        detectedElements: inout [DetectedElement],
        elementIdMap: inout [String: DetectedElement],
        visitedElements: inout Set<Element>)
    {
        guard let children = element.children() else { return }
        for child in children {
            self.processElement(
                child,
                depth: depth,
                detectedElements: &detectedElements,
                elementIdMap: &elementIdMap,
                visitedElements: &visitedElements)
        }
    }

    private func logButtonDebugInfoIfNeeded(_ descriptor: ElementDescriptor) {
        guard descriptor.role.lowercased() == "axbutton" else { return }
        let parts = [
            "title: '\(descriptor.title ?? "nil")'",
            "label: '\(descriptor.label ?? "nil")'",
            "value: '\(descriptor.value ?? "nil")'",
            "roleDescription: '\(descriptor.roleDescription ?? "nil")'",
            "description: '\(descriptor.description ?? "nil")'",
            "identifier: '\(descriptor.identifier ?? "nil")'",
        ]
        self.logger.debug("🔍 Button debug - \(parts.joined(separator: ", "))")
    }

    private func effectiveLabel(for element: Element, descriptor: ElementDescriptor) -> String? {
        let info = ElementLabelInfo(
            role: descriptor.role,
            label: descriptor.label,
            title: descriptor.title,
            value: descriptor.value,
            roleDescription: descriptor.roleDescription,
            description: descriptor.description,
            identifier: descriptor.identifier,
            placeholder: descriptor.placeholder)

        let childTexts = self.textualDescendants(of: element)
        return ElementLabelResolver.resolve(
            info: info,
            childTexts: childTexts,
            identifierCleaner: self.cleanedIdentifier)
    }

    private func textualDescendants(of element: Element, depth: Int = 0, limit: Int = 4) -> [String] {
        guard depth < 3, limit > 0, let children = element.children(), !children.isEmpty else {
            return []
        }

        var results: [String] = []
        for child in children {
            if let role = child.role()?.lowercased(),
               Self.textualRoles.contains(role)
            {
                if let candidate = child.title() ?? child.label() ?? child.stringValue() ?? child.descriptionText() {
                    let normalized = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !normalized.isEmpty {
                        results.append(normalized)
                        if results.count >= limit { break }
                    }
                }
            }

            if results.count >= limit { break }

            let remaining = limit - results.count
            let nested = self.textualDescendants(of: child, depth: depth + 1, limit: remaining)
            results.append(contentsOf: nested)
            if results.count >= limit { break }
        }

        return results
    }

    private func cleanedIdentifier(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "-button", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    private func adjustedElementType(
        element: Element,
        descriptor: ElementDescriptor,
        baseType: ElementType) -> ElementType
    {
        let roleInfo = ElementRoleInfo(
            role: descriptor.role,
            roleDescription: descriptor.roleDescription,
            isEditable: element.isEditable() ?? false)
        let resolved = ElementRoleResolver.resolveType(baseType: baseType, info: roleInfo)

        let loweredTitle = descriptor.title?.lowercased()
        let loweredLabel = descriptor.label?.lowercased()
        let keywords = ["email", "password", "username", "phone", "code"]
        let matchesKeyword =
            loweredTitle.map { title in keywords.contains(where: { title.contains($0) }) } ?? false ||
            loweredLabel.map { label in keywords.contains(where: { label.contains($0) }) } ?? false

        if resolved == .group,
           descriptor.placeholder?.isEmpty == false ||
           matchesKeyword ||
           self.containsTextFieldDescendant(element, depth: 0, remainingDepth: 2)
        {
            return .textField
        }

        return resolved
    }

    private func containsTextFieldDescendant(
        _ element: Element,
        depth: Int,
        remainingDepth: Int) -> Bool
    {
        guard remainingDepth >= 0 else { return false }
        guard let children = element.children(strict: true) else { return false }

        for child in children {
            if let role = child.role()?.lowercased(),
               Self.textFieldRoles.contains(role)
            {
                return true
            }

            if child.isEditable() == true {
                return true
            }

            if self.containsTextFieldDescendant(child, depth: depth + 1, remainingDepth: remainingDepth - 1) {
                return true
            }
        }

        return false
    }

    private func focusWebContentIfNeeded(window: Element, appElement: Element) -> Bool {
        guard let target = self.findWebArea(in: window) ?? self.findWebArea(in: appElement) else {
            return false
        }

        do {
            try target.performAction(.press)
            self.logger.debug("Focused AXWebArea to expose embedded web content")
            return true
        } catch {
            self.logger.error("Failed to focus AXWebArea: \(error.localizedDescription)")
            return false
        }
    }

    private func findWebArea(in element: Element, depth: Int = 0) -> Element? {
        guard depth < 6 else { return nil }

        let role = element.role()?.lowercased()
        let roleDescription = element.roleDescription()?.lowercased()
        if role == "axwebarea" || roleDescription?.contains("web area") == true {
            return element
        }

        guard let children = element.children(strict: depth >= 1) else { return nil }
        for child in children {
            if let found = self.findWebArea(in: child, depth: depth + 1) {
                return found
            }
        }
        return nil
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
        _ input: ElementAttributeInput) -> [String: String]
    {
        var attributes: [String: String] = [:]

        attributes["role"] = input.role
        if let title = input.title { attributes["title"] = title }
        if let description = input.description { attributes["description"] = description }
        if let help = input.help { attributes["help"] = help }
        if let roleDescription = input.roleDescription { attributes["roleDescription"] = roleDescription }
        if let identifier = input.identifier { attributes["identifier"] = identifier }
        if input.isActionable { attributes["isActionable"] = "true" }
        if let shortcut = input.keyboardShortcut { attributes["keyboardShortcut"] = shortcut }
        if let placeholder = input.placeholder { attributes["placeholder"] = placeholder }

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

private struct WindowResolution {
    let appElement: Element
    let window: Element
    let isDialog: Bool

    var windowTypeDescription: String {
        self.isDialog ? "dialog" : "window"
    }
}

private struct DialogResolution {
    let window: Element?
    let isDialog: Bool
}

private struct ElementDescriptor {
    let frame: CGRect
    let role: String
    let title: String?
    let label: String?
    let value: String?
    let description: String?
    let help: String?
    let roleDescription: String?
    let identifier: String?
    let isEnabled: Bool
    let placeholder: String?
}

private struct ElementAttributeInput {
    let role: String
    let title: String?
    let description: String?
    let help: String?
    let roleDescription: String?
    let identifier: String?
    let isActionable: Bool
    let keyboardShortcut: String?
    let placeholder: String?
}

extension CGSize {
    fileprivate var area: CGFloat { width * height }
}
