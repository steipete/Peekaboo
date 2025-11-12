//
//  OverlayManager.swift
//  PeekabooUICore
//
//  Manages visual overlays for UI element inspection
//

import AppKit
import AXorcist
import Observation
import os.log
import PeekabooCore
import SwiftUI

/// Protocol for customizing overlay manager behavior
public protocol OverlayManagerDelegate: AnyObject {
    func overlayManager(_ manager: OverlayManager, shouldShowElement element: OverlayManager.UIElement) -> Bool
    func overlayManager(_ manager: OverlayManager, didSelectElement element: OverlayManager.UIElement)
    func overlayManager(_ manager: OverlayManager, didHoverElement element: OverlayManager.UIElement?)
}

/// Manages visual overlays for UI element inspection
@MainActor
@Observable
public final class OverlayManager {
    @ObservationIgnored
    private let logger = Logger(subsystem: "boo.peekaboo.ui", category: "OverlayManager")

    // MARK: - Public Properties

    public var hoveredElement: UIElement?
    public var selectedElement: UIElement?
    public var applications: [ApplicationInfo] = []
    public var isOverlayActive: Bool = false
    public var currentMouseLocation: CGPoint = .zero
    public var selectedAppMode: AppSelectionMode = .all
    public var selectedAppBundleID: String?
    public var detailLevel: DetailLevel = .moderate

    @ObservationIgnored
    public weak var delegate: (any OverlayManagerDelegate)?

    // MARK: - Types

    public enum AppSelectionMode {
        case all
        case single
    }

    public enum DetailLevel {
        case essential // Only buttons, links, inputs
        case moderate // Include rows, cells
        case all // Everything
    }

    public struct ApplicationInfo: Identifiable {
        public let id = UUID()
        public let bundleIdentifier: String
        public let name: String
        public let processID: pid_t
        public let icon: NSImage?
        public var elements: [UIElement] = []
        public var windows: [WindowInfo] = []

        public init(bundleIdentifier: String, name: String, processID: pid_t, icon: NSImage?) {
            self.bundleIdentifier = bundleIdentifier
            self.name = name
            self.processID = processID
            self.icon = icon
        }
    }

    public struct WindowInfo: Identifiable {
        public let id = UUID()
        public let title: String?
        public let frame: CGRect
        public let axWindow: Element

        public init(title: String?, frame: CGRect, axWindow: Element) {
            self.title = title
            self.frame = frame
            self.axWindow = axWindow
        }
    }

    public struct UIElement: Identifiable {
        public let id = UUID()
        public let role: String
        public let title: String?
        public let label: String?
        public let value: String?
        public let frame: CGRect
        public let isActionable: Bool
        public let elementID: String
        public let appBundleID: String

        // Additional properties
        public let roleDescription: String?
        public let help: String?
        public let isEnabled: Bool
        public let isFocused: Bool
        public let children: [UUID]
        public let parentID: UUID?
        public let className: String?
        public let identifier: String?
        public let selectedText: String?
        public let numberOfCharacters: Int?

        public var displayName: String {
            self.title ?? self.label ?? self.value ?? self.role
        }

        @MainActor
        public var color: Color {
            let category = self.roleToElementCategory(self.role)
            let style = InspectorVisualizationPreset().style(for: category, state: self.isEnabled ? .normal : .disabled)
            return Color(cgColor: style.primaryColor)
        }

        private func roleToElementCategory(_ role: String) -> ElementCategory {
            switch role {
            case "AXButton", "AXPopUpButton":
                .button
            case "AXTextField", "AXTextArea":
                .textInput
            case "AXLink":
                .link
            case "AXStaticText":
                .text
            case "AXGroup":
                .container
            case "AXSlider":
                .slider
            case "AXCheckBox":
                .checkbox
            case "AXRadioButton":
                .radioButton
            case "AXMenu", "AXMenuItem", "AXMenuBar":
                .menu
            case "AXTable", "AXOutline", "AXScrollArea":
                .container
            default:
                .text
            }
        }
    }

    // MARK: - Private Properties

    @ObservationIgnored
    private var eventMonitor: Any?
    @ObservationIgnored
    private var updateTimer: Timer?
    @ObservationIgnored
    private var overlayWindows: [String: NSWindow] = [:] // Bundle ID -> Window
    @ObservationIgnored
    private let idGenerator = ElementIDGenerator()

    // MARK: - Initialization

    public init(enableMonitoring: Bool = true) {
        if enableMonitoring {
            self.setupEventMonitoring()
        }
    }

    deinit {
        // Cleanup is handled by the cleanup() method
    }

    /// Clean up resources - must be called before releasing the manager
    public func cleanup() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            self.eventMonitor = nil
        }
        self.updateTimer?.invalidate()
        self.updateTimer = nil
    }

    // MARK: - Public Methods

    public func setAppSelectionMode(_ mode: AppSelectionMode, bundleID: String? = nil) {
        self.selectedAppMode = mode
        self.selectedAppBundleID = bundleID
        self.refreshAllApplications()
    }

    public func setDetailLevel(_ level: DetailLevel) {
        self.detailLevel = level
        self.refreshAllApplications()
    }

    public func refreshAllApplications() {
        Task {
            await self.updateApplicationList()
        }
    }

    // MARK: - Private Methods

    private func setupEventMonitoring() {
        self.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [
            .mouseMoved,
            .leftMouseDown,
        ]) { [weak self] event in
            // Process the event asynchronously
            Task { @MainActor in
                guard let self else { return }

                self.currentMouseLocation = event.locationInWindow

                if event.type == .mouseMoved, self.isOverlayActive {
                    await self.updateHoveredElement()
                } else if event.type == .leftMouseDown, self.isOverlayActive {
                    if let hovered = self.hoveredElement {
                        self.selectedElement = hovered
                        self.delegate?.overlayManager(self, didSelectElement: hovered)
                    }
                }
            }

            // Return the event unchanged to pass it through
            return event
        }

        // Start update timer
        self.updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isOverlayActive else { return }
                await self.updateApplicationList()
            }
        }
    }

    private func updateApplicationList() async {
        // Get running applications
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }

        var newApplications: [ApplicationInfo] = []

        for app in runningApps {
            guard let bundleID = app.bundleIdentifier else { continue }

            // Check if we should include this app
            if self.selectedAppMode == .single, bundleID != self.selectedAppBundleID {
                continue
            }

            var appInfo = ApplicationInfo(
                bundleIdentifier: bundleID,
                name: app.localizedName ?? "Unknown",
                processID: app.processIdentifier,
                icon: app.icon)

            // Get UI elements for this app
            if let axApp = Element.application(for: app.processIdentifier) {
                appInfo.elements = await self.detectElements(in: axApp, appBundleID: bundleID)
            }

            newApplications.append(appInfo)
        }

        self.applications = newApplications
    }

    private func detectElements(in app: Element, appBundleID: String) async -> [UIElement] {
        var elements: [UIElement] = []

        // Get windows
        if let windows = app.windows() {
            for window in windows {
                await self.collectElements(from: window, into: &elements, appBundleID: appBundleID)
            }
        }

        // Generate IDs
        for i in 0..<elements.count {
            let category = self.roleToElementCategory(elements[i].role)
            let id = self.idGenerator.generateID(for: category)

            elements[i] = UIElement(
                role: elements[i].role,
                title: elements[i].title,
                label: elements[i].label,
                value: elements[i].value,
                frame: elements[i].frame,
                isActionable: elements[i].isActionable,
                elementID: id,
                appBundleID: elements[i].appBundleID,
                roleDescription: elements[i].roleDescription,
                help: elements[i].help,
                isEnabled: elements[i].isEnabled,
                isFocused: elements[i].isFocused,
                children: elements[i].children,
                parentID: elements[i].parentID,
                className: elements[i].className,
                identifier: elements[i].identifier,
                selectedText: elements[i].selectedText,
                numberOfCharacters: elements[i].numberOfCharacters)
        }

        return elements
    }

    private func collectElements(
        from element: Element,
        into elements: inout [UIElement],
        appBundleID: String,
        parentID: UUID? = nil) async
    {
        // Check if we should include this element
        guard self.shouldIncludeElement(element) else { return }

        // Create UIElement
        let uiElement = self.createUIElement(from: element, appBundleID: appBundleID, parentID: parentID)

        // Check with delegate
        if let delegate, !delegate.overlayManager(self, shouldShowElement: uiElement) {
            return
        }

        elements.append(uiElement)

        // Recurse into children
        if let children = element.children() {
            for child in children {
                await self.collectElements(
                    from: child,
                    into: &elements,
                    appBundleID: appBundleID,
                    parentID: uiElement.id)
            }
        }
    }

    private func shouldIncludeElement(_ element: Element) -> Bool {
        guard let role = element.role() else { return false }

        switch self.detailLevel {
        case .essential:
            return ["AXButton", "AXTextField", "AXTextArea", "AXLink", "AXCheckBox", "AXRadioButton", "AXPopUpButton"]
                .contains(role)
        case .moderate:
            return !["AXGroup", "AXStaticText", "AXImage"].contains(role)
        case .all:
            return true
        }
    }

    private func createUIElement(from element: Element, appBundleID: String, parentID: UUID?) -> UIElement {
        let role = element.role() ?? "Unknown"
        let frame = element.frame() ?? .zero
        let isEnabled = element.isEnabled() ?? true

        return UIElement(
            role: role,
            title: element.title(),
            label: element.label(),
            value: element.value() as? String,
            frame: frame,
            isActionable: element.isActionSupported("AXPress"),
            elementID: "", // Will be set later
            appBundleID: appBundleID,
            roleDescription: element.roleDescription(),
            help: element.help(),
            isEnabled: isEnabled,
            isFocused: element.isFocused() ?? false,
            children: [],
            parentID: parentID,
            className: nil,
            identifier: element.identifier(),
            selectedText: element.selectedText(),
            numberOfCharacters: element.numberOfCharacters())
    }

    private func updateHoveredElement() async {
        let mouseLocation = NSEvent.mouseLocation

        // Find element at mouse location
        for app in self.applications {
            guard let element = app.elements.first(where: { $0.frame.contains(mouseLocation) }) else {
                continue
            }

            if self.hoveredElement?.id != element.id {
                self.hoveredElement = element
                self.delegate?.overlayManager(self, didHoverElement: element)
            }
            return
        }

        // No element found
        if self.hoveredElement != nil {
            self.hoveredElement = nil
            self.delegate?.overlayManager(self, didHoverElement: nil)
        }
    }

    private func roleToElementCategory(_ role: String) -> ElementCategory {
        switch role {
        case "AXButton", "AXPopUpButton":
            .button
        case "AXTextField", "AXTextArea":
            .textInput
        case "AXLink":
            .link
        case "AXStaticText":
            .text
        case "AXGroup":
            .container
        case "AXSlider":
            .slider
        case "AXCheckBox":
            .checkbox
        case "AXRadioButton":
            .radioButton
        case "AXMenu", "AXMenuItem", "AXMenuBar":
            .menu
        case "AXTable", "AXOutline", "AXScrollArea":
            .container
        default:
            .text
        }
    }
}

extension OverlayManager: ObservableObject {}
