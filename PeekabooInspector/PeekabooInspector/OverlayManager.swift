import SwiftUI
import AppKit
import AXorcist
import os.log

@MainActor
class OverlayManager: ObservableObject {
    private let logger = Logger(subsystem: "com.steipete.PeekabooInspector", category: "OverlayManager")
    
    @Published var hoveredElement: UIElement?
    @Published var selectedElement: UIElement?
    @Published var applications: [ApplicationInfo] = []
    @Published var isOverlayActive: Bool = false
    @Published var currentMouseLocation: CGPoint = .zero
    @Published var selectedAppMode: AppSelectionMode = .all
    @Published var selectedAppBundleID: String?
    @Published var detailLevel: DetailLevel = .moderate
    
    private var eventMonitor: Any?
    private var updateTimer: Timer?
    private var overlayWindows: [String: NSWindow] = [:] // Bundle ID -> Window
    
    enum AppSelectionMode {
        case all
        case single
    }
    
    enum DetailLevel {
        case essential  // Only buttons, links, inputs
        case moderate   // Include rows, cells
        case all        // Everything
    }
    
    struct ApplicationInfo: Identifiable {
        let id = UUID()
        let bundleIdentifier: String
        let name: String
        let processID: pid_t
        let icon: NSImage?
        var elements: [UIElement] = []
        var windows: [WindowInfo] = []
    }
    
    struct WindowInfo: Identifiable {
        let id = UUID()
        let title: String?
        let frame: CGRect
        let axWindow: Element
    }
    
    struct UIElement: Identifiable {
        let id = UUID()
        let role: String
        let title: String?
        let label: String?
        let value: String?
        let frame: CGRect
        let isActionable: Bool
        let elementID: String
        let appBundleID: String
        // Additional properties for detailed inspection
        let roleDescription: String?
        let help: String?
        let isEnabled: Bool
        let isFocused: Bool
        let children: [UUID]
        let parentID: UUID?
        let className: String?
        let identifier: String?
        let selectedText: String?
        let numberOfCharacters: Int?
        
        var displayName: String {
            title ?? label ?? value ?? role
        }
        
        var color: Color {
            switch role {
            case "AXButton", "AXLink", "AXPopUpButton":
                return Color(red: 0, green: 122/255, blue: 1)
            case "AXTextField", "AXTextArea":
                return Color(red: 52/255, green: 199/255, blue: 89/255)
            case "AXCheckBox", "AXRadioButton", "AXSlider":
                return Color(red: 142/255, green: 142/255, blue: 147/255)
            default:
                return Color(red: 255/255, green: 149/255, blue: 0)
            }
        }
    }
    
    init() {
        startMonitoring()
    }
    
    deinit {
        logger.info("OverlayManager deinit - cleaning up")
        // Can't call MainActor methods from deinit
        // Windows will be cleaned up by ARC
    }
    
    func toggleOverlay() {
        isOverlayActive.toggle()
        if isOverlayActive {
            refreshAllApplications()
            // Overlay windows will be created after refresh completes
        } else {
            removeAllOverlayWindows()
        }
    }
    
    func setAppSelectionMode(_ mode: AppSelectionMode, bundleID: String? = nil) {
        selectedAppMode = mode
        selectedAppBundleID = bundleID
        if isOverlayActive {
            refreshAllApplications()
            updateOverlayWindows()
        }
    }
    
    func setDetailLevel(_ level: DetailLevel) {
        detailLevel = level
        if isOverlayActive {
            // Force a redraw of the overlay view
            objectWillChange.send()
        }
    }
    
    func startMonitoring() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            Task { @MainActor in
                self?.currentMouseLocation = NSEvent.mouseLocation
                self?.updateHoveredElement()
            }
        }
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if self?.isOverlayActive == true {
                    self?.refreshAllApplications()
                    // Overlay windows will be recreated after refresh
                }
            }
        }
    }
    
    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    func refreshAllApplications() {
        Task {
            var allApps: [ApplicationInfo] = []
            
            // Get all running applications
            let runningApps = NSWorkspace.shared.runningApplications
                .filter { app in
                    app.activationPolicy == .regular &&
                    app.bundleIdentifier != Bundle.main.bundleIdentifier
                }
            
            // When in single app mode, only process the selected app
            let appsToProcess = if selectedAppMode == .single,
                               let selectedID = selectedAppBundleID {
                runningApps.filter { $0.bundleIdentifier == selectedID }
            } else {
                // In all apps mode, process all running apps
                runningApps
            }
            
            for app in appsToProcess {
                guard let bundleID = app.bundleIdentifier else { continue }
                
                // Skip if we're in single app mode and this isn't the selected app
                if selectedAppMode == .single && bundleID != selectedAppBundleID {
                    continue
                }
                
                var appInfo = ApplicationInfo(
                    bundleIdentifier: bundleID,
                    name: app.localizedName ?? "Unknown",
                    processID: app.processIdentifier,
                    icon: app.icon
                )
                
                // Get accessibility elements for this app
                let axApp = AXUIElementCreateApplication(app.processIdentifier)
                let appElement = Element(axApp)
                
                // Get all windows for this app
                if let windows = appElement.windows() {
                    for window in windows {
                        if let windowTitle = window.title(),
                           let position = window.position(),
                           let size = window.size() {
                            
                            let windowInfo = WindowInfo(
                                title: windowTitle,
                                frame: CGRect(x: position.x, y: position.y, width: size.width, height: size.height),
                                axWindow: window
                            )
                            appInfo.windows.append(windowInfo)
                            
                            // Process elements within this window
                            var windowElements: [UIElement] = []
                            processElement(window, into: &windowElements, appBundleID: bundleID, depth: 0, maxDepth: 10)
                            appInfo.elements.append(contentsOf: windowElements)
                            
                            // For Console, also check if we missed the sidebar
                            if bundleID == "com.apple.Console" {
                                logger.debug("Console window has \(windowElements.count) elements detected")
                            }
                        }
                    }
                }
                
                allApps.append(appInfo)
            }
            
            self.applications = allApps
            
            // Create overlay windows after applications are loaded
            if isOverlayActive && !allApps.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.createOverlayWindows()
                }
            }
        }
    }
    
    private func processElement(_ element: Element, into elements: inout [UIElement], appBundleID: String, depth: Int, maxDepth: Int, parentID: UUID? = nil) {
        // Prevent infinite recursion
        guard depth < maxDepth else { return }
        
        // Skip processing if we already have too many elements (performance optimization)
        let elementCount = elements.count
        guard elementCount < 500 else { 
            if appBundleID == "com.apple.Console" {
                logger.debug("Console hit element limit at \(elementCount) elements")
            }
            return 
        }
        
        // Get element properties using AXorcist
        let role = element.role() ?? "AXGroup"
        
        // Log Console app elements for debugging
        if appBundleID == "com.apple.Console" && depth < 3 {
            logger.debug("Console element: role=\(role), depth=\(depth)")
        }
        
        // Get frame
        let position = element.position()
        let size = element.size()
        let frame: CGRect = if let pos = position, let sz = size {
            CGRect(x: pos.x, y: pos.y, width: sz.width, height: sz.height)
        } else {
            .zero
        }
        
        // Get other properties
        let title = element.title()
        let description = element.descriptionText()
        let help = element.help()
        let value = element.value() as? String
        let roleDescription = element.roleDescription()
        let isEnabled = element.isEnabled() ?? true
        let isFocused = element.isFocused() ?? false
        let identifier = element.identifier()
        let selectedText = element.selectedText()
        let numberOfCharacters = element.numberOfCharacters()
        
        let elementId = UUID()
        
        // Only process elements with valid frames and reasonable sizes
        if frame != .zero && frame.width > 0 && frame.height > 0 && frame.width < 10000 && frame.height < 10000 {
            // Use the most descriptive property as the label
            let label = description ?? help ?? title
            
            let isActionable = isActionableRole(role)
            
            // Log Console sidebar elements
            if appBundleID == "com.apple.Console" && (role == "AXRow" || role == "AXCell" || role == "AXStaticText") {
                logger.debug("Console sidebar element: role=\(role), title=\(title ?? "nil"), label=\(label ?? "nil"), isActionable=\(isActionable)")
            }
            
            let uiElement = UIElement(
                role: role,
                title: title,
                label: label,
                value: value,
                frame: frame,
                isActionable: isActionable,
                elementID: generateElementID(for: role, count: elements.count),
                appBundleID: appBundleID,
                roleDescription: roleDescription,
                help: help,
                isEnabled: isEnabled,
                isFocused: isFocused,
                children: [], // Will be populated when processing children
                parentID: parentID,
                className: nil, // AXorcist doesn't expose this directly
                identifier: identifier,
                selectedText: selectedText,
                numberOfCharacters: numberOfCharacters
            )
            
            elements.append(uiElement)
        }
        
        // Process children recursively with depth tracking
        if let children = element.children() {
            for child in children {
                processElement(child, into: &elements, appBundleID: appBundleID, depth: depth + 1, maxDepth: maxDepth, parentID: elementId)
            }
        }
    }
    
    private func updateHoveredElement() {
        let mouseLocation = currentMouseLocation
        
        // Early exit if no applications
        guard !applications.isEmpty else {
            hoveredElement = nil
            return
        }
        
        // Check only visible elements, starting with the most likely candidates
        for app in applications {
            // Skip apps with no elements
            guard !app.elements.isEmpty else { continue }
            
            // Check if any of the app's windows contain the mouse location
            let windowContainsMouse = app.windows.contains { window in
                window.frame.contains(mouseLocation)
            }
            
            // Skip this app if mouse is not in any of its windows
            guard windowContainsMouse else { continue }
            
            // Now check elements within this app
            for element in app.elements {
                let screenFrame = element.frame
                if screenFrame.contains(mouseLocation) {
                    if hoveredElement?.id != element.id {
                        hoveredElement = element
                    }
                    return
                }
            }
        }
        
        hoveredElement = nil
    }
    
    private func isActionableRole(_ role: String) -> Bool {
        let actionableRoles = [
            "AXButton", "AXLink", "AXTextField", "AXTextArea",
            "AXCheckBox", "AXRadioButton", "AXPopUpButton",
            "AXComboBox", "AXSlider", "AXMenuItem",
            "AXRow", "AXCell", "AXStaticText", "AXOutline",
            "AXList", "AXTable", "AXGroup"
        ]
        return actionableRoles.contains(role)
    }
    
    private func generateElementID(for role: String, count: Int) -> String {
        let prefix: String
        switch role {
        case "AXButton": prefix = "B"
        case "AXTextField", "AXTextArea": prefix = "T"
        case "AXLink": prefix = "L"
        case "AXStaticText": prefix = "St"
        case "AXCheckBox": prefix = "C"
        case "AXRadioButton": prefix = "R"
        case "AXPopUpButton", "AXComboBox": prefix = "P"
        case "AXSlider": prefix = "S"
        case "AXMenuItem": prefix = "M"
        case "AXRow": prefix = "Rw"
        case "AXCell": prefix = "Ce"
        case "AXOutline": prefix = "O"
        case "AXList": prefix = "Li"
        case "AXTable": prefix = "Ta"
        case "AXGroup": prefix = "G"
        default: prefix = "E"
        }
        return "\(prefix)\(count + 1)"
    }
    
    // MARK: - Overlay Window Management
    
    private func createOverlayWindows() {
        // Only create if window doesn't exist
        if overlayWindows["main"] != nil {
            logger.debug("Overlay window already exists, skipping creation")
            return
        }
        
        logger.info("Creating single overlay window for all \(self.applications.count) apps")
        
        // Create a single overlay window that shows all apps
        guard let screen = NSScreen.main else { return }
        let windowFrame = screen.frame
        
        let window = NSWindow(
            contentRect: windowFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isMovableByWindowBackground = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.animationBehavior = .none
        
        // Create a view that shows overlays for ALL apps
        let allAppsOverlayView = AllAppsOverlayView(overlayManager: self)
        let hostingView = NSHostingView(rootView: allAppsOverlayView)
        hostingView.frame = window.contentRect(forFrameRect: windowFrame)
        window.contentView = hostingView
        
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        window.orderFront(nil)
        NSAnimationContext.endGrouping()
        
        overlayWindows["main"] = window
        logger.info("Created single overlay window showing elements from all apps")
    }
    
    // This method is no longer used - we create a single window for all apps
    // Keeping for reference but marked as deprecated
    @available(*, deprecated, message: "Use createOverlayWindows() instead")
    private func createOverlayWindow(for app: ApplicationInfo) {
        // Implementation removed - see createOverlayWindows()
    }
    
    private func updateOverlayWindows() {
        createOverlayWindows()
    }
    
    private func removeAllOverlayWindows() {
        guard !overlayWindows.isEmpty else { return }
        
        logger.debug("Removing \(self.overlayWindows.count) overlay windows")
        
        // Close windows without animation to prevent crashes
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        
        for (id, window) in overlayWindows {
            // Make sure window is valid before trying to close it
            if window.isVisible {
                window.orderOut(nil)
            }
            // Don't set contentView to nil - let ARC handle it
            window.close()
            logger.debug("Closed overlay window: \(id)")
        }
        
        NSAnimationContext.endGrouping()
        overlayWindows.removeAll()
    }
}