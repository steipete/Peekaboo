import Foundation
import CoreGraphics
@preconcurrency import AXorcist
import AppKit

/// Enhanced UI automation service with full element detection capabilities
/// This file contains the additional functionality needed for the SeeCommandV2
public extension UIAutomationService {
    
    /// Enhanced element detection that builds a full UI map using AXorcist
    func detectElementsEnhanced(
        in imageData: Data,
        sessionId: String?,
        applicationName: String? = nil,
        windowTitle: String? = nil,
        windowBounds: CGRect? = nil
    ) async throws -> ElementDetectionResult {
        let startTime = Date()
        
        // Create or use existing session
        let session: String
        if let existingSessionId = sessionId {
            session = existingSessionId
        } else {
            session = try await sessionManager.createSession()
        }
        
        // Save the screenshot temporarily
        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(session)_screenshot.png")
            .path
        try imageData.write(to: URL(fileURLWithPath: tempPath))
        
        // Build UI map using AXorcist and capture window information
        let (detectedElements, windowInfo) = try await buildUIMap(
            applicationName: applicationName,
            windowTitle: windowTitle,
            windowBounds: windowBounds
        )
        
        // Create metadata with enhanced information including windowID
        var warnings = buildMetadataWarnings(
            applicationName: applicationName,
            windowTitle: windowTitle,
            windowBounds: windowBounds
        )
        
        // Add window ID to warnings (temporary until metadata structure is enhanced)
        if let windowID = windowInfo?.windowID {
            warnings.append("WINDOW_ID:\(windowID)")
        }
        if let axIdentifier = windowInfo?.axIdentifier {
            warnings.append("AX_IDENTIFIER:\(axIdentifier)")
        }
        
        let metadata = DetectionMetadata(
            detectionTime: Date().timeIntervalSince(startTime),
            elementCount: detectedElements.all.count,
            method: "AXorcist",
            warnings: warnings
        )
        
        return ElementDetectionResult(
            sessionId: session,
            screenshotPath: tempPath,
            elements: detectedElements,
            metadata: metadata
        )
    }
    
    /// Build UI element map for the specified application
    @MainActor
    private func buildUIMap(
        applicationName: String?,
        windowTitle: String?,
        windowBounds: CGRect?
    ) async throws -> (DetectedElements, WindowInfo?) {
        var buttons: [DetectedElement] = []
        var textFields: [DetectedElement] = []
        var links: [DetectedElement] = []
        var images: [DetectedElement] = []
        var groups: [DetectedElement] = []
        var sliders: [DetectedElement] = []
        var checkboxes: [DetectedElement] = []
        var menus: [DetectedElement] = []
        var other: [DetectedElement] = []
        
        var roleCounters: [String: Int] = [:]
        
        // Find the application if specified
        let targetApp: NSRunningApplication?
        if let appName = applicationName {
            targetApp = NSWorkspace.shared.runningApplications.first(where: {
                $0.localizedName == appName || $0.bundleIdentifier == appName
            })
        } else {
            // Get frontmost application
            targetApp = NSWorkspace.shared.frontmostApplication
        }
        
        guard let app = targetApp else {
            // Return empty elements if no app found
            return (DetectedElements(), nil)
        }
        
        // Create AXUIElement for the application
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)
        
        // Get windows to process
        let windows: [Element]
        
        if let windowTitle = windowTitle {
            // Find specific window by title
            windows = appElement.windows()?.filter { element in
                element.title() == windowTitle
            } ?? []
        } else {
            // Process only the frontmost window to match screenshot
            if let frontWindow = appElement.windows()?.first {
                windows = [frontWindow]
            } else {
                windows = []
            }
        }
        
        // Capture window information for the first window
        var windowInfo: WindowInfo?
        if let firstWindow = windows.first {
            // Get CGWindowID using WindowIdentityService
            let windowIdentityService = WindowIdentityService()
            let windowID = windowIdentityService.getWindowID(from: firstWindow)
            
            windowInfo = WindowInfo(
                windowID: windowID,
                axIdentifier: firstWindow.identifier(),
                title: firstWindow.title(),
                bounds: windowBounds
            )
        }
        
        // Process each window
        for window in windows {
            await processElement(
                window,
                roleCounters: &roleCounters,
                buttons: &buttons,
                textFields: &textFields,
                links: &links,
                images: &images,
                groups: &groups,
                sliders: &sliders,
                checkboxes: &checkboxes,
                menus: &menus,
                other: &other,
                windowBounds: windowBounds
            )
        }
        
        let elements = DetectedElements(
            buttons: buttons,
            textFields: textFields,
            links: links,
            images: images,
            groups: groups,
            sliders: sliders,
            checkboxes: checkboxes,
            menus: menus,
            other: other
        )
        
        return (elements, windowInfo)
    }
    
    // Window information structure
    private struct WindowInfo {
        let windowID: CGWindowID?
        let axIdentifier: String?
        let title: String?
        let bounds: CGRect?
    }
    
    /// Recursively process an element and its children
    @MainActor
    private func processElement(
        _ element: Element,
        roleCounters: inout [String: Int],
        buttons: inout [DetectedElement],
        textFields: inout [DetectedElement],
        links: inout [DetectedElement],
        images: inout [DetectedElement],
        groups: inout [DetectedElement],
        sliders: inout [DetectedElement],
        checkboxes: inout [DetectedElement],
        menus: inout [DetectedElement],
        other: inout [DetectedElement],
        windowBounds: CGRect?
    ) async {
        // Get element properties
        let role = element.role() ?? "AXGroup"
        let title = element.title()
        let label = element.descriptionText() // AXorcist doesn't have label(), use descriptionText()
        let value = element.value() as? String
        let description = element.help() // Use help() for additional description
        let identifier = element.identifier()
        let isEnabled = element.isEnabled() ?? true
        // Use computedName for better label extraction
        let computedName = element.computedName()
        
        // Get element bounds
        guard let position = element.position(),
              let size = element.size(),
              size.width > 0,
              size.height > 0 else {
            // Skip elements without valid bounds
            return
        }
        
        var frame = CGRect(x: position.x, y: position.y, width: size.width, height: size.height)
        
        // Transform screen coordinates to window-relative coordinates if windowBounds is provided
        if let windowBounds = windowBounds {
            frame.origin.x -= windowBounds.origin.x
            frame.origin.y -= windowBounds.origin.y
        }
        
        // Determine element type
        let elementType = elementTypeFromRole(role)
        
        // Generate ID
        let prefix = idPrefixForType(elementType)
        let counter = (roleCounters[prefix] ?? 0) + 1
        roleCounters[prefix] = counter
        let elementId = "\(prefix)\(counter)"
        
        // Build attributes
        var attributes: [String: String] = [:]
        if let title = title { attributes["title"] = title }
        if let description = description { attributes["description"] = description }
        if let identifier = identifier { attributes["identifier"] = identifier }
        
        // Detect keyboard shortcut
        if let shortcut = detectKeyboardShortcut(
            role: role,
            title: title,
            label: label,
            description: description
        ) {
            attributes["keyboardShortcut"] = shortcut
        }
        
        // Try to extract better label for buttons by looking at children
        var enhancedLabel = label ?? title ?? value ?? computedName
        var isTabElement = false
        
        if elementType == .button && enhancedLabel == nil {
            // Look for static text children within the button
            if let children = element.children() {
                for child in children {
                    if let childRole = child.role(), childRole == "AXStaticText" {
                        if let childValue = child.value() as? String, !childValue.isEmpty {
                            enhancedLabel = childValue
                            break
                        } else if let childTitle = child.title(), !childTitle.isEmpty {
                            enhancedLabel = childTitle
                            break
                        }
                    }
                }
            }
        }
        
        // Enhanced tab detection for browser applications
        isTabElement = await detectBrowserTab(
            element: element,
            role: role,
            title: title,
            label: enhancedLabel,
            attributes: &attributes
        )
        
        // Update label and attributes for tab elements
        if isTabElement {
            attributes["elementCategory"] = "tab"
            // Prefer title over other labels for tabs
            if let tabTitle = title, !tabTitle.isEmpty {
                enhancedLabel = tabTitle
            }
        }
        
        // Create detected element
        let detectedElement = DetectedElement(
            id: elementId,
            type: elementType,
            label: enhancedLabel,
            value: value,
            bounds: frame,
            isEnabled: isEnabled && isActionableRole(role),
            isSelected: nil,
            attributes: attributes
        )
        
        // Add to appropriate array
        switch elementType {
        case .button:
            buttons.append(detectedElement)
        case .textField:
            textFields.append(detectedElement)
        case .link:
            links.append(detectedElement)
        case .image:
            images.append(detectedElement)
        case .group:
            groups.append(detectedElement)
        case .slider:
            sliders.append(detectedElement)
        case .checkbox:
            checkboxes.append(detectedElement)
        case .menu:
            menus.append(detectedElement)
        case .other:
            other.append(detectedElement)
        }
        
        // Process children recursively
        if let children = element.children() {
            for child in children {
                await processElement(
                    child,
                    roleCounters: &roleCounters,
                    buttons: &buttons,
                    textFields: &textFields,
                    links: &links,
                    images: &images,
                    groups: &groups,
                    sliders: &sliders,
                    checkboxes: &checkboxes,
                    menus: &menus,
                    other: &other,
                    windowBounds: windowBounds
                )
            }
        }
    }
    
    /// Map AX role to element type
    private func elementTypeFromRole(_ role: String) -> ElementType {
        switch role {
        case "AXButton":
            return .button
        case "AXRadioButton":
            return .button  // Treat radio buttons as buttons for UI automation
        case "AXTextField", "AXTextArea":
            return .textField
        case "AXLink":
            return .link
        case "AXImage":
            return .image
        case "AXGroup":
            return .group
        case "AXSlider":
            return .slider
        case "AXCheckBox":
            return .checkbox
        case "AXMenu", "AXMenuItem":
            return .menu
        default:
            return .other
        }
    }
    
    /// Get ID prefix for element type
    private func idPrefixForType(_ type: ElementType) -> String {
        switch type {
        case .button: return "B"
        case .textField: return "T"
        case .link: return "L"
        case .image: return "I"
        case .group: return "G"
        case .slider: return "S"
        case .checkbox: return "C"
        case .menu: return "M"
        case .other: return "O"
        }
    }
    
    /// Check if a role is actionable
    private func isActionableRole(_ role: String) -> Bool {
        let actionableRoles = [
            "AXButton",
            "AXTextField",
            "AXTextArea",
            "AXCheckBox",
            "AXRadioButton",
            "AXPopUpButton",
            "AXLink",
            "AXMenuItem",
            "AXSlider",
            "AXComboBox",
            "AXSegmentedControl"
        ]
        return actionableRoles.contains(role)
    }
    
    /// Detect keyboard shortcut for common UI elements
    private func detectKeyboardShortcut(
        role: String,
        title: String?,
        label: String?,
        description: String?
    ) -> String? {
        // Check for common formatting buttons
        let allText = [title, label, description]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        
        // Common text formatting shortcuts
        if allText.contains("bold") {
            return "cmd+b"
        } else if allText.contains("italic") {
            return "cmd+i"
        } else if allText.contains("underline") {
            return "cmd+u"
        } else if allText.contains("strikethrough") {
            return "cmd+shift+x"
        }
        
        // Common app shortcuts
        if allText.contains("save") && !allText.contains("save as") {
            return "cmd+s"
        } else if allText.contains("save as") {
            return "cmd+shift+s"
        } else if allText.contains("open") {
            return "cmd+o"
        } else if allText.contains("new") {
            return "cmd+n"
        } else if allText.contains("close") {
            return "cmd+w"
        } else if allText.contains("quit") {
            return "cmd+q"
        } else if allText.contains("print") {
            return "cmd+p"
        }
        
        // Edit menu shortcuts
        if allText.contains("copy") {
            return "cmd+c"
        } else if allText.contains("cut") {
            return "cmd+x"
        } else if allText.contains("paste") {
            return "cmd+v"
        } else if allText.contains("undo") {
            return "cmd+z"
        } else if allText.contains("redo") {
            return "cmd+shift+z"
        }
        
        return nil
    }
    
    /// Build metadata warnings array with window information
    private func buildMetadataWarnings(
        applicationName: String?,
        windowTitle: String?,
        windowBounds: CGRect?
    ) -> [String] {
        var warnings: [String] = []
        
        // Store metadata in warnings array (temporary until service layer is enhanced)
        if let app = applicationName {
            warnings.append("APP:\(app)")
        }
        if let window = windowTitle {
            warnings.append("WINDOW:\(window)")
        }
        if let bounds = windowBounds,
           let boundsData = try? JSONCoding.encoder.encode(bounds),
           let boundsString = String(data: boundsData, encoding: .utf8) {
            warnings.append("BOUNDS:\(boundsString)")
        }
        
        return warnings
    }
    
    // MARK: - Browser Tab Detection
    
    /// Detect if element is a browser tab
    @MainActor
    private func detectBrowserTab(
        element: Element,
        role: String,
        title: String?,
        label: String?,
        attributes: inout [String: String]
    ) async -> Bool {
        // Check if this is a button or radio button that could be a tab
        guard role == "AXButton" || role == "AXRadioButton" else { return false }
        
        // Check if parent hierarchy suggests this is a tab
        let isInTabGroup = await isElementInTabGroup(element)
        
        // Check for tab-like characteristics
        let hasTabKeywords = hasTabIndicators(title: title, label: label)
        
        // Check for browser-specific patterns
        let isBrowserTab = await isBrowserTabElement(element, title: title, label: label)
        
        let isTab = isInTabGroup || hasTabKeywords || isBrowserTab
        
        if isTab {
            // Add additional tab-specific attributes
            if let tabTitle = title, !tabTitle.isEmpty {
                attributes["tabTitle"] = tabTitle
            }
            
            // Check if this tab is selected/active
            if let isSelected = element.value() as? Bool {
                attributes["isSelected"] = String(isSelected)
            }
            
            // Try to detect if it's closeable (has close button)
            if await hasCloseButton(element) {
                attributes["hasCloseButton"] = "true"
            }
            
            // Add accessibility identifiers if available
            if let identifier = element.identifier() {
                attributes["accessibilityIdentifier"] = identifier
            }
        }
        
        return isTab
    }
    
    /// Check if element is within a tab group structure
    @MainActor
    private func isElementInTabGroup(_ element: Element) async -> Bool {
        var current: Element? = element.parent()
        var depth = 0
        
        while let parent = current, depth < 10 { // Limit depth to avoid infinite loops
            if let role = parent.role() {
                // Look for tab-related parent roles
                if role == "AXTabGroup" || role == "AXTabList" {
                    return true
                }
                
                // Browser-specific patterns
                if let description = parent.descriptionText(),
                   description.lowercased().contains("tab") {
                    return true
                }
            }
            
            current = parent.parent()
            depth += 1
        }
        
        return false
    }
    
    /// Check for tab indicator keywords in title or label
    private func hasTabIndicators(title: String?, label: String?) -> Bool {
        let allText = [title, label]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        
        // Common tab indicators (be careful not to match regular buttons)
        let tabKeywords = [
            "tab ", " tab", "new tab", "close tab",
            "reload tab", "refresh tab", "pin tab"
        ]
        
        return tabKeywords.contains { keyword in
            allText.contains(keyword)
        }
    }
    
    /// Check for browser-specific tab patterns
    @MainActor
    private func isBrowserTabElement(_ element: Element, title: String?, label: String?) async -> Bool {
        // Get app name to check if we're in a browser
        guard let app = await getApplicationForElement(element) else { return false }
        
        let browserApps = ["Google Chrome", "Safari", "Firefox", "Microsoft Edge", "Opera", "Arc"]
        guard browserApps.contains(where: { app.lowercased().contains($0.lowercased()) }) else {
            return false
        }
        
        // In browsers, tabs often have:
        // 1. A title that's not a typical button label
        // 2. Specific positioning in the UI (top area)
        // 3. Small height but wider width
        
        if let position = element.position(),
           let size = element.size() {
            
            // Tabs are typically in the upper part of the window
            let isInUpperArea = position.y < 150
            
            // Tabs have a specific size ratio (wider than tall)
            let aspectRatio = size.width / size.height
            let hasTabAspectRatio = aspectRatio > 2.0 && aspectRatio < 10.0
            
            // Tabs have reasonable minimum dimensions
            let hasReasonableSize = size.width > 50 && size.height > 20 && size.height < 60
            
            if isInUpperArea && hasTabAspectRatio && hasReasonableSize {
                // Additional checks for title patterns
                if let title = title, !title.isEmpty {
                    // Tabs often have domain names or page titles
                    let hasURL = title.contains(".") || title.contains("/")
                    let isNotTypicalButton = !["OK", "Cancel", "Save", "Open", "Close", "Yes", "No"].contains(title)
                    
                    return hasURL || (isNotTypicalButton && title.count > 3)
                }
            }
        }
        
        return false
    }
    
    /// Check if element has a close button (indicating it's a closeable tab)
    @MainActor
    private func hasCloseButton(_ element: Element) async -> Bool {
        guard let children = element.children() else { return false }
        
        for child in children {
            if let role = child.role(), role == "AXButton" {
                if let title = child.title()?.lowercased() {
                    if title.contains("close") || title == "×" || title == "✕" {
                        return true
                    }
                }
                
                // Check for small square buttons (typical close button)
                if let size = child.size(),
                   size.width < 30 && size.height < 30 && abs(size.width - size.height) < 10 {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Get application name for an element
    @MainActor
    private func getApplicationForElement(_ element: Element) async -> String? {
        // Walk up to find the application element
        var current: Element? = element
        
        while let el = current {
            if let role = el.role(), role == "AXApplication" {
                return el.title()
            }
            current = el.parent()
        }
        
        return nil
    }
}

// MARK: - Menu Bar Extraction (Future Enhancement)

public extension UIAutomationService {
    
    /// Extract menu bar information for an application
    @MainActor
    func extractMenuBar(for applicationName: String) async throws -> MenuBarInfo? {
        // Find the application
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName == applicationName || $0.bundleIdentifier == applicationName
        }) else {
            return nil
        }
        
        // Create AXUIElement for the application
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)
        
        // Get the menu bar
        guard let menuBar = appElement.menuBar() else {
            return nil
        }
        
        // Get all top-level menus
        let topLevelMenus = menuBar.children() ?? []
        var menus: [MenuInfo] = []
        
        for menuElement in topLevelMenus {
            // Get menu title
            guard let menuTitle = menuElement.title() else { continue }
            
            // Skip the Apple menu (first menu)
            if menuTitle.isEmpty { continue }
            
            let isEnabled = menuElement.isEnabled() ?? true
            
            // Note: We can't get submenu items without opening the menu
            // which would be visually disruptive
            let menu = MenuInfo(
                title: menuTitle,
                enabled: isEnabled,
                itemCount: 0 // Would need to open menu to count
            )
            menus.append(menu)
        }
        
        return MenuBarInfo(menus: menus)
    }
}

/// Menu bar information
public struct MenuBarInfo: Sendable {
    public let menus: [MenuInfo]
    
    public init(menus: [MenuInfo]) {
        self.menus = menus
    }
}

/// Individual menu information
public struct MenuInfo: Sendable {
    public let title: String
    public let enabled: Bool
    public let itemCount: Int
    
    public init(title: String, enabled: Bool, itemCount: Int) {
        self.title = title
        self.enabled = enabled
        self.itemCount = itemCount
    }
}