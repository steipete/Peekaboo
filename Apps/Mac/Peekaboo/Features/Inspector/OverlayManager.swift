import AppKit
import AXorcist
import Combine
import os.log
import SwiftUI
import PeekabooCore

/// Manages visual overlays for the Peekaboo Inspector feature.
///
/// `OverlayManager` coordinates the display of transparent overlay windows that highlight
/// UI elements across all applications. It handles mouse tracking, element detection,
/// and rendering of visual feedback for both hovering and selection states.
///
/// ## Overview
///
/// The overlay system works by:
/// - Creating transparent windows that float above all applications
/// - Detecting UI elements under the mouse cursor using accessibility APIs
/// - Drawing visual highlights around detected elements
/// - Managing selection state for automation targeting
///
/// ## Topics
///
/// ### State Management
///
/// - ``hoveredElement``
/// - ``selectedElement``
/// - ``isOverlayActive``
/// - ``currentMouseLocation``
///
/// ### Application Filtering
///
/// - ``applications``
/// - ``selectedAppMode``
/// - ``selectedAppBundleID``
/// - ``AppSelectionMode``
///
/// ### Detail Control
///
/// - ``detailLevel``
/// - ``DetailLevel``
///
/// ### Overlay Control
///
/// - ``startOverlay()``
/// - ``stopOverlay()``
/// - ``refreshApplications()``
@MainActor
class OverlayManager: ObservableObject {
    private let logger = Logger(subsystem: "boo.peekaboo.app", category: "OverlayManager")

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
    private var animationWindows: [UUID: NSWindow] = [:] // Animation ID -> Window
    private var animationCleanupTimers: [UUID: Timer] = [:] // Animation ID -> Cleanup Timer

    enum AppSelectionMode {
        case all
        case single
    }

    enum DetailLevel {
        case essential // Only buttons, links, inputs
        case moderate // Include rows, cells
        case all // Everything
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
            self.title ?? self.label ?? self.value ?? self.role
        }

        var color: Color {
            // Use core visualization system colors
            let category = roleToElementCategory(self.role)
            let styleProvider = InspectorVisualizationPreset()
            let style = styleProvider.style(for: category, state: self.isEnabled ? .normal : .disabled)
            return Color(cgColor: style.primaryColor)
        }
        
        private func roleToElementCategory(_ role: String) -> ElementCategory {
            switch role {
            case "AXButton", "AXPopUpButton":
                return .button
            case "AXTextField", "AXTextArea":
                return .textField
            case "AXLink":
                return .link
            case "AXStaticText":
                return .staticText
            case "AXGroup":
                return .group
            case "AXSlider":
                return .slider
            case "AXCheckBox":
                return .checkbox
            case "AXRadioButton":
                return .radioButton
            case "AXMenuItem":
                return .menu
            case "AXComboBox":
                return .popUpButton
            case "AXRow", "AXCell", "AXOutline", "AXList", "AXTable":
                return .tableView
            case "AXImage":
                return .image
            default:
                return .other
            }
        }
    }

    init() {
        self.startMonitoring()
    }

    deinit {
        logger.info("OverlayManager deinit - cleaning up")
        // Can't call MainActor methods from deinit
        // Windows will be cleaned up by ARC
    }

    func toggleOverlay() {
        self.isOverlayActive.toggle()
        if self.isOverlayActive {
            self.refreshAllApplications()
            // Overlay windows will be created after refresh completes
        } else {
            self.removeAllOverlayWindows()
        }
    }

    func setAppSelectionMode(_ mode: AppSelectionMode, bundleID: String? = nil) {
        self.selectedAppMode = mode
        self.selectedAppBundleID = bundleID
        if self.isOverlayActive {
            self.refreshAllApplications()
            self.updateOverlayWindows()
        }
    }

    func setDetailLevel(_ level: DetailLevel) {
        self.detailLevel = level
        if self.isOverlayActive {
            // Force a redraw of the overlay view
            objectWillChange.send()
        }
    }

    func startMonitoring() {
        self.eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor in
                self?.currentMouseLocation = NSEvent.mouseLocation
                self?.updateHoveredElement()
            }
        }

        self.updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
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
            self.eventMonitor = nil
        }

        self.updateTimer?.invalidate()
        self.updateTimer = nil
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
            let appsToProcess = if self.selectedAppMode == .single,
                                   let selectedID = selectedAppBundleID
            {
                runningApps.filter { $0.bundleIdentifier == selectedID }
            } else {
                // In all apps mode, process all running apps
                runningApps
            }

            for app in appsToProcess {
                guard let bundleID = app.bundleIdentifier else { continue }

                // Skip if we're in single app mode and this isn't the selected app
                if self.selectedAppMode == .single, bundleID != self.selectedAppBundleID {
                    continue
                }

                var appInfo = ApplicationInfo(
                    bundleIdentifier: bundleID,
                    name: app.localizedName ?? "Unknown",
                    processID: app.processIdentifier,
                    icon: app.icon)

                // Get accessibility elements for this app
                let axApp = AXUIElementCreateApplication(app.processIdentifier)
                let appElement = Element(axApp)

                // Get all windows for this app
                if let windows = appElement.windows() {
                    for window in windows {
                        if let windowTitle = window.title(),
                           let position = window.position(),
                           let size = window.size()
                        {
                            let windowInfo = WindowInfo(
                                title: windowTitle,
                                frame: CGRect(x: position.x, y: position.y, width: size.width, height: size.height),
                                axWindow: window)
                            appInfo.windows.append(windowInfo)

                            // Process elements within this window
                            var windowElements: [UIElement] = []
                            self.processElement(
                                window,
                                into: &windowElements,
                                appBundleID: bundleID,
                                depth: 0,
                                maxDepth: 10)
                            appInfo.elements.append(contentsOf: windowElements)

                            // For Console, also check if we missed the sidebar
                            if bundleID == "com.apple.Console" {
                                self.logger.debug("Console window has \(windowElements.count) elements detected")
                            }
                        }
                    }
                }

                allApps.append(appInfo)
            }

            self.applications = allApps
            self.logger
                .info(
                    "Refreshed applications: found \(allApps.count) apps with \(allApps.reduce(0) { $0 + $1.elements.count }) total elements")

            // Create overlay windows after applications are loaded
            if self.isOverlayActive, !allApps.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.createOverlayWindows()
                    self?.logger.info("Creating overlay windows for \(allApps.count) applications")
                }
            }
        }
    }

    private func processElement(
        _ element: Element,
        into elements: inout [UIElement],
        appBundleID: String,
        depth: Int,
        maxDepth: Int,
        parentID: UUID? = nil)
    {
        // Prevent infinite recursion
        guard depth < maxDepth else { return }

        // Skip processing if we already have too many elements (performance optimization)
        let elementCount = elements.count
        guard elementCount < 500 else {
            if appBundleID == "com.apple.Console" {
                self.logger.debug("Console hit element limit at \(elementCount) elements")
            }
            return
        }

        // Get element properties using AXorcist
        let role = element.role() ?? "AXGroup"

        // Log Console app elements for debugging
        if appBundleID == "com.apple.Console", depth < 3 {
            self.logger.debug("Console element: role=\(role), depth=\(depth)")
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
        if frame != .zero, frame.width > 0, frame.height > 0, frame.width < 10000, frame.height < 10000 {
            // Use the most descriptive property as the label
            let label = description ?? help ?? title

            let isActionable = self.isActionableRole(role)

            // Log Console sidebar elements
            if appBundleID == "com.apple.Console", role == "AXRow" || role == "AXCell" || role == "AXStaticText" {
                self.logger
                    .debug(
                        "Console sidebar element: role=\(role), title=\(title ?? "nil"), label=\(label ?? "nil"), isActionable=\(isActionable)")
            }

            let category = roleToElementCategory(role)
            let elementID = ElementIDGenerator.shared.generateID(for: category, index: elements.count)
            
            let uiElement = UIElement(
                role: role,
                title: title,
                label: label,
                value: value,
                frame: frame,
                isActionable: isActionable,
                elementID: elementID,
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
                numberOfCharacters: numberOfCharacters)

            elements.append(uiElement)
        }

        // Process children recursively with depth tracking
        if let children = element.children() {
            for child in children {
                self.processElement(
                    child,
                    into: &elements,
                    appBundleID: appBundleID,
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    parentID: elementId)
            }
        }
    }

    private func updateHoveredElement() {
        let mouseLocation = self.currentMouseLocation

        // Early exit if no applications
        guard !self.applications.isEmpty else {
            self.hoveredElement = nil
            return
        }

        // Check only visible elements, starting with the most likely candidates
        for app in self.applications {
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
                    if self.hoveredElement?.id != element.id {
                        self.hoveredElement = element
                    }
                    return
                }
            }
        }

        self.hoveredElement = nil
    }

    private func isActionableRole(_ role: String) -> Bool {
        let actionableRoles = [
            "AXButton", "AXLink", "AXTextField", "AXTextArea",
            "AXCheckBox", "AXRadioButton", "AXPopUpButton",
            "AXComboBox", "AXSlider", "AXMenuItem",
            "AXRow", "AXCell", "AXStaticText", "AXOutline",
            "AXList", "AXTable", "AXGroup",
        ]
        return actionableRoles.contains(role)
    }

    /// Convert role to ElementCategory
    private func roleToElementCategory(_ role: String) -> ElementCategory {
        switch role {
        case "AXButton", "AXPopUpButton":
            return .button
        case "AXTextField", "AXTextArea":
            return .textField
        case "AXLink":
            return .link
        case "AXStaticText":
            return .staticText
        case "AXGroup":
            return .group
        case "AXSlider":
            return .slider
        case "AXCheckBox":
            return .checkbox
        case "AXRadioButton":
            return .radioButton
        case "AXMenuItem":
            return .menu
        case "AXComboBox":
            return .popUpButton
        case "AXRow", "AXCell", "AXOutline", "AXList", "AXTable":
            return .tableView
        case "AXImage":
            return .image
        default:
            return .other
        }
    }

    // MARK: - Overlay Window Management

    private func createOverlayWindows() {
        // Only create if window doesn't exist
        if self.overlayWindows["main"] != nil {
            self.logger.debug("Overlay window already exists, skipping creation")
            return
        }

        self.logger.info("Creating single overlay window for all \(self.applications.count) apps")

        // Create a single overlay window that shows all apps
        guard let screen = NSScreen.main else { return }
        let windowFrame = screen.frame

        let window = NSWindow(
            contentRect: windowFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false)

        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        // Use the highest possible window level
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.animationBehavior = .none
        // Make window stay on top
        window.hidesOnDeactivate = false

        // Create a view that shows overlays for ALL apps
        let allAppsOverlayView = AllAppsOverlayView(overlayManager: self)
        let hostingView = NSHostingView(rootView: allAppsOverlayView)
        hostingView.frame = window.contentRect(forFrameRect: windowFrame)
        window.contentView = hostingView

        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.endGrouping()

        // Force window to front using additional method
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))

        self.overlayWindows["main"] = window
        self.logger.info("Created single overlay window at maximum level showing elements from all apps")
    }

    // This method is no longer used - we create a single window for all apps
    // Keeping for reference but marked as deprecated
    @available(*, deprecated, message: "Use createOverlayWindows() instead")
    private func createOverlayWindow(for app: ApplicationInfo) {
        // Implementation removed - see createOverlayWindows()
    }

    private func updateOverlayWindows() {
        self.createOverlayWindows()
    }

    private func removeAllOverlayWindows() {
        guard !self.overlayWindows.isEmpty else { return }

        self.logger.debug("Removing \(self.overlayWindows.count) overlay windows")

        // Close windows without animation to prevent crashes
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0

        for (id, window) in self.overlayWindows {
            // Make sure window is valid before trying to close it
            if window.isVisible {
                window.orderOut(nil)
            }
            // Don't set contentView to nil - let ARC handle it
            window.close()
            self.logger.debug("Closed overlay window: \(id)")
        }

        NSAnimationContext.endGrouping()
        self.overlayWindows.removeAll()
    }

    // MARK: - Animation Window Management

    /// Creates an animation window at the specified rect
    func createAnimationWindow(at rect: CGRect, ignoresMouse: Bool = true) -> (UUID, NSWindow) {
        let animationID = UUID()

        let window = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = ignoresMouse
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.hasShadow = false
        window.animationBehavior = .none

        self.animationWindows[animationID] = window

        self.logger.debug("Created animation window \(animationID.uuidString) at \(rect.debugDescription)")

        return (animationID, window)
    }
    
    /// Creates a full-screen animation window that spans all displays
    func createFullScreenAnimationWindow(ignoresMouse: Bool = true) -> (UUID, NSWindow) {
        let animationID = UUID()
        
        // Calculate the combined bounds of all screens
        var combinedRect = CGRect.zero
        for screen in NSScreen.screens {
            if combinedRect == .zero {
                combinedRect = screen.frame
            } else {
                combinedRect = combinedRect.union(screen.frame)
            }
        }
        
        let window = NSWindow(
            contentRect: combinedRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) - 1) // Just below maximum
        window.ignoresMouseEvents = ignoresMouse
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.hasShadow = false
        window.animationBehavior = .none
        window.hidesOnDeactivate = false
        
        self.animationWindows[animationID] = window
        
        self.logger.debug("Created full-screen animation window \(animationID.uuidString) spanning \(combinedRect.debugDescription)")
        
        return (animationID, window)
    }

    /// Shows an animation window with SwiftUI content
    func showAnimation(
        at rect: CGRect,
        content: some View,
        duration: TimeInterval,
        fadeOut: Bool = true) -> UUID
    {
        // Create a full-screen window instead of rect-sized
        let (animationID, window) = self.createFullScreenAnimationWindow()

        // Wrap content in a positioned view
        let positionedContent = PositionedAnimationView(
            targetRect: rect,
            content: { content }
        )
        
        // Set up the SwiftUI content
        let hostingView = NSHostingView(rootView: positionedContent)
        window.contentView = hostingView

        // Show the window
        window.orderFront(nil)

        // Schedule cleanup
        self.scheduleAnimationCleanup(animationID: animationID, window: window, duration: duration, fadeOut: fadeOut)

        return animationID
    }

    /// Removes an animation window immediately
    func removeAnimationWindow(_ animationID: UUID) {
        // Cancel any pending cleanup timer
        self.animationCleanupTimers[animationID]?.invalidate()
        self.animationCleanupTimers.removeValue(forKey: animationID)

        // Remove the window
        if let window = animationWindows[animationID] {
            window.orderOut(nil)
            window.close()
            self.animationWindows.removeValue(forKey: animationID)

            self.logger.debug("Removed animation window \(animationID.uuidString)")
        }
    }

    /// Schedules automatic cleanup of an animation window
    private func scheduleAnimationCleanup(
        animationID: UUID,
        window: NSWindow,
        duration: TimeInterval,
        fadeOut: Bool)
    {
        let cleanupTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }

                if fadeOut {
                    // Fade out animation
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.3
                        window.animator().alphaValue = 0
                    }) { [weak self] in
                        self?.removeAnimationWindow(animationID)
                    }
                } else {
                    // Remove immediately
                    self.removeAnimationWindow(animationID)
                }
            }
        }

        self.animationCleanupTimers[animationID] = cleanupTimer
    }

    /// Removes all animation windows
    func removeAllAnimationWindows() {
        self.logger.debug("Removing all \(self.animationWindows.count) animation windows")

        // Cancel all timers
        for timer in self.animationCleanupTimers.values {
            timer.invalidate()
        }
        self.animationCleanupTimers.removeAll()

        // Close all windows
        for (id, window) in self.animationWindows {
            window.orderOut(nil)
            window.close()
        }
        self.animationWindows.removeAll()
    }
}
