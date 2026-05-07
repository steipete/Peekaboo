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
 * - Snapshot-based element caching
 *
 * ## Usage Example
 * ```swift
 * let detectionService = ElementDetectionService(snapshotManager: snapshotManager)
 *
 * let result = try await detectionService.detectElements(
 *     in: screenshotData,
 *     snapshotId: "snapshot_123",
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
    private let snapshotManager: any SnapshotManagerProtocol
    private let applicationService: ApplicationService
    private let windowIdentityService = WindowIdentityService()
    private let windowManagementService = WindowManagementService()
    private let axTreeCache = ElementDetectionCache()
    private let webFocusFallback = WebFocusFallback()
    private let menuBarElementCollector = MenuBarElementCollector()

    public init(
        snapshotManager: (any SnapshotManagerProtocol)? = nil,
        applicationService: ApplicationService? = nil)
    {
        self.snapshotManager = snapshotManager ?? SnapshotManager()
        self.applicationService = applicationService ?? ApplicationService()
    }

    /// Detect UI elements in a screenshot
    public func detectElements(
        in imageData: Data,
        snapshotId: String?,
        windowContext: WindowContext?) async throws -> ElementDetectionResult
    {
        self.logger.info("Starting element detection")

        let effectiveSnapshotId = snapshotId ?? UUID().uuidString

        let targetApp = try await self.resolveApplication(windowContext: windowContext)
        let windowResolution = try await self.resolveWindow(for: targetApp, context: windowContext)
        let windowName = windowResolution.window.title() ?? "Untitled"
        self.logger.debug("Found \(windowResolution.windowTypeDescription): \(windowName)")

        let resolvedWindowID = self.windowIdentityService.getWindowID(from: windowResolution.window).map { Int($0) } ??
            windowContext?.windowID

        let resolvedWindowContext = WindowContext(
            applicationName: windowContext?.applicationName ?? targetApp.localizedName,
            applicationBundleId: windowContext?.applicationBundleId ?? targetApp.bundleIdentifier,
            applicationProcessId: windowContext?.applicationProcessId ?? targetApp.processIdentifier,
            windowTitle: windowName,
            windowID: resolvedWindowID,
            windowBounds: windowContext?.windowBounds,
            shouldFocusWebContent: windowContext?.shouldFocusWebContent)

        var elementIdMap: [String: DetectedElement] = [:]
        let allowWebFocus = windowContext?.shouldFocusWebContent ?? true
        let detectedElements: [DetectedElement]
        let usedCache: Bool
        let cacheKey = self.axTreeCache.key(
            windowID: resolvedWindowID,
            processID: targetApp.processIdentifier,
            allowWebFocus: allowWebFocus)
        if let cacheKey, let cached = self.axTreeCache.elements(for: cacheKey) {
            self.logger.debug("Using cached AX tree for window \(cacheKey.windowID)")
            detectedElements = cached
            usedCache = true
        } else {
            detectedElements = try await self.collectElementsWithTimeout(
                window: windowResolution.window,
                appElement: windowResolution.appElement,
                appIsActive: targetApp.isActive,
                allowWebFocus: allowWebFocus,
                elementIdMap: &elementIdMap)
            if let cacheKey {
                self.axTreeCache.store(detectedElements, for: cacheKey)
            }
            usedCache = false
        }

        // Note: Parent-child relationships are not directly supported in the protocol's DetectedElement struct

        self.logger.info("Detected \(detectedElements.count) elements")

        let result = ElementDetectionResultBuilder.makeResult(
            snapshotId: effectiveSnapshotId,
            elements: detectedElements,
            usedCache: usedCache,
            windowContext: resolvedWindowContext,
            isDialog: windowResolution.isDialog)

        if snapshotId != nil {
            try await self.snapshotManager.storeDetectionResult(snapshotId: effectiveSnapshotId, result: result)
        }

        return result
    }
}

extension ElementDetectionService {
    private func collectElementsWithTimeout(
        window: Element,
        appElement: Element,
        appIsActive: Bool,
        allowWebFocus: Bool,
        elementIdMap: inout [String: DetectedElement],
        timeoutSeconds: Double = 20.0) async throws -> [DetectedElement]
    {
        let (elements, map) = try await ElementDetectionTimeoutRunner.run(seconds: timeoutSeconds) {
            let deadline = Date().addingTimeInterval(timeoutSeconds)
            var localMap: [String: DetectedElement] = [:]
            let elements = await self.collectElements(
                window: window,
                appElement: appElement,
                appIsActive: appIsActive,
                allowWebFocus: allowWebFocus,
                deadline: deadline,
                elementIdMap: &localMap)
            return (elements, localMap)
        }
        elementIdMap = map
        return elements
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
    private func resolveApplication(windowContext: WindowContext?) async throws -> NSRunningApplication {
        if let pid = windowContext?.applicationProcessId {
            if let runningApp = NSRunningApplication(processIdentifier: pid) {
                self.logger.debug("Resolved application via PID: \(pid)")
                return runningApp
            }
            self.logger.error("Could not resolve NSRunningApplication for PID: \(pid)")
            throw PeekabooError.appNotFound("PID:\(pid)")
        }

        if let bundleId = windowContext?.applicationBundleId {
            self.logger.debug("Looking for application via bundle ID: \(bundleId)")

            let appInfo = try await self.applicationService.findApplication(identifier: bundleId)

            guard let runningApp = NSRunningApplication(processIdentifier: appInfo.processIdentifier) else {
                self.logger.error("Could not get NSRunningApplication for PID: \(appInfo.processIdentifier)")
                throw PeekabooError.appNotFound(bundleId)
            }

            self.logger.debug("Resolved application: \(runningApp.localizedName ?? "unknown")")
            return runningApp
        }

        if let appName = windowContext?.applicationName {
            self.logger.debug("Looking for application via ApplicationService: \(appName)")

            // Use ApplicationService for consistent app resolution across the codebase
            let appInfo = try await self.applicationService.findApplication(identifier: appName)

            // Look up the NSRunningApplication by PID
            guard let runningApp = NSRunningApplication(processIdentifier: appInfo.processIdentifier) else {
                self.logger.error("Could not get NSRunningApplication for PID: \(appInfo.processIdentifier)")
                throw PeekabooError.appNotFound(appName)
            }

            self.logger.debug("Resolved application: \(runningApp.localizedName ?? "unknown")")
            return runningApp
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

        if let windowID = context?.windowID {
            let cgWindowID = CGWindowID(windowID)
            if let handle = self.windowIdentityService.findWindow(byID: cgWindowID, in: app) ??
                self.windowIdentityService.findWindow(byID: cgWindowID)
            {
                let title = handle.element.title() ?? "Untitled"
                let identifier = app.localizedName ?? app.bundleIdentifier ?? "PID:\(app.processIdentifier)"
                self.logger.notice("Resolved window via CGWindowID \(windowID): '\(title)' for \(identifier)")

                let window: Element
                if let focused = self.focusedWindowIfMatches(app: app),
                   self.windowIdentityService.getWindowID(from: focused).map(Int.init) == windowID
                {
                    window = focused
                } else {
                    await self.focusWindow(withID: windowID, appName: identifier)
                    window = self.focusedWindowIfMatches(app: app) ?? handle.element
                }

                let subrole = window.subrole() ?? ""
                let isDialogRole = ["AXDialog", "AXSystemDialog", "AXSheet"].contains(subrole)
                let isFileDialog = self.isFileDialogTitle(window.title() ?? "")
                let isDialog = isDialogRole || isFileDialog

                return WindowResolution(appElement: appElement, window: window, isDialog: isDialog)
            }

            self.logger.warning(
                "Could not resolve window via CGWindowID \(windowID); falling back to title-based selection")
        }

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

    /// Fallback #3: ask the window-management service (which already talks to CG+AX) for candidates
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

    // swiftlint:disable function_parameter_count
    private func collectElements(
        window: Element,
        appElement: Element,
        appIsActive: Bool,
        allowWebFocus: Bool,
        deadline: Date,
        elementIdMap: inout [String: DetectedElement]) async -> [DetectedElement]
    {
        var detectedElements: [DetectedElement] = []
        var attempt = 0

        repeat {
            elementIdMap.removeAll(keepingCapacity: true)
            detectedElements.removeAll(keepingCapacity: true)

            var visitedElements = Set<Element>()
            // Traverse only the captured window. Walking the app root also visits sibling windows,
            // which makes `see --app` slower and returns elements outside the screenshot.
            self.processElement(
                window,
                depth: 0,
                deadline: deadline,
                detectedElements: &detectedElements,
                elementIdMap: &elementIdMap,
                visitedElements: &visitedElements)

            if appIsActive, let menuBar = appElement.menuBar() {
                self.menuBarElementCollector.appendMenuBar(
                    menuBar,
                    elements: &detectedElements,
                    elementIdMap: &elementIdMap)
            }

            let hasTextField = detectedElements.contains(where: { $0.type == .textField })

            // Web focus fallback walks the AX tree looking for AXWebArea. Only pay that cost when
            // the first pass is sparse enough to suggest hidden Chromium/Tauri content.
            guard AXTraversalPolicy.shouldAttemptWebFocusFallback(
                attempt: attempt,
                allowWebFocus: allowWebFocus,
                detectedElementCount: detectedElements.count,
                hasTextField: hasTextField),
                self.webFocusFallback.focusIfNeeded(window: window, appElement: appElement)
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
        deadline: Date,
        detectedElements: inout [DetectedElement],
        elementIdMap: inout [String: DetectedElement],
        visitedElements: inout Set<Element>)
    {
        guard depth < AXTraversalPolicy.maxTraversalDepth else { return }
        guard !Task.isCancelled else { return }
        guard Date() < deadline else { return }
        guard detectedElements.count < AXTraversalPolicy.maxElementCount else { return }
        guard visitedElements.insert(element).inserted else { return }
        guard let descriptor = AXDescriptorReader.describe(element) else { return }

        self.logButtonDebugInfoIfNeeded(descriptor)

        let elementId = "elem_\(detectedElements.count)"
        let baseType = ElementClassifier.elementType(for: descriptor.role)
        let elementType = self.adjustedElementType(element: element, descriptor: descriptor, baseType: baseType)
        let isActionable = self.isElementActionable(element, role: descriptor.role)
        let keyboardShortcut = isActionable ? self.extractKeyboardShortcut(element, role: descriptor.role) : nil
        let label = self.effectiveLabel(for: element, descriptor: descriptor)

        let attributes = ElementClassifier.attributes(
            from: ElementClassifier.AttributeInput(
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
            deadline: deadline,
            detectedElements: &detectedElements,
            elementIdMap: &elementIdMap,
            visitedElements: &visitedElements)
    }

    private func processChildren(
        of element: Element,
        depth: Int,
        deadline: Date,
        detectedElements: inout [DetectedElement],
        elementIdMap: inout [String: DetectedElement],
        visitedElements: inout Set<Element>)
    {
        guard !Task.isCancelled else { return }
        guard let children = element.children() else { return }
        let limitedChildren = children.prefix(AXTraversalPolicy.maxChildrenPerNode)
        for child in limitedChildren {
            guard detectedElements.count < AXTraversalPolicy.maxElementCount else { break }
            self.processElement(
                child,
                depth: depth,
                deadline: deadline,
                detectedElements: &detectedElements,
                elementIdMap: &elementIdMap,
                visitedElements: &visitedElements)
        }
    }

    // swiftlint:enable function_parameter_count

    private func logButtonDebugInfoIfNeeded(_ descriptor: AXDescriptorReader.Descriptor) {
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

    private func effectiveLabel(for element: Element, descriptor: AXDescriptorReader.Descriptor) -> String? {
        let info = ElementLabelInfo(
            role: descriptor.role,
            label: descriptor.label,
            title: descriptor.title,
            value: descriptor.value,
            roleDescription: descriptor.roleDescription,
            description: descriptor.description,
            identifier: descriptor.identifier,
            placeholder: descriptor.placeholder)

        let childTexts = ElementLabelResolver.needsChildTexts(info: info)
            ? self.textualDescendants(of: element)
            : []
        return ElementLabelResolver.resolve(
            info: info,
            childTexts: childTexts,
            identifierCleaner: self.cleanedIdentifier)
    }

    private func textualDescendants(of element: Element, depth: Int = 0, limit: Int = 4) -> [String] {
        guard depth < 3, limit > 0, !Task.isCancelled,
              let children = element.children(), !children.isEmpty
        else {
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
        descriptor: AXDescriptorReader.Descriptor,
        baseType: ElementType) -> ElementType
    {
        let input = ElementTypeAdjustmentInput(
            role: descriptor.role,
            roleDescription: descriptor.roleDescription,
            title: descriptor.title,
            label: descriptor.label,
            placeholder: descriptor.placeholder,
            isEditable: baseType == .group && element.isEditable() == true)
        let hasTextFieldDescendant = ElementTypeAdjuster.shouldScanForTextFieldDescendant(
            baseType: baseType,
            input: input) && self.containsTextFieldDescendant(element, depth: 0, remainingDepth: 2)

        return ElementTypeAdjuster.resolve(
            baseType: baseType,
            input: input,
            hasTextFieldDescendant: hasTextFieldDescendant)
    }

    private func containsTextFieldDescendant(
        _ element: Element,
        depth: Int,
        remainingDepth: Int) -> Bool
    {
        guard !Task.isCancelled else { return false }
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

    private func isElementActionable(_ element: Element, role: String) -> Bool {
        if ElementClassifier.roleIsActionable(role) {
            return true
        }

        guard ElementClassifier.shouldLookupActions(for: role) else {
            return false
        }

        // Action lookup is another AX round-trip; only pay it for container-ish roles that can hide AXPress.
        return element.supportedActions()?.contains("AXPress") == true
    }

    @MainActor
    private func extractKeyboardShortcut(_ element: Element, role: String) -> String? {
        guard ElementClassifier.supportsKeyboardShortcut(for: role) else {
            return nil
        }

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

extension CGSize {
    fileprivate var area: CGFloat {
        width * height
    }
}
