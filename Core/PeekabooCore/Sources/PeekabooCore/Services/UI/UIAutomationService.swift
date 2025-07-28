import Foundation
import CoreGraphics
@preconcurrency import AXorcist
import AppKit
import ApplicationServices
import os.log

/// Default implementation of UI automation operations using specialized services
@MainActor
public final class UIAutomationService: UIAutomationServiceProtocol {
    
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "UIAutomationService")
    private let sessionManager: SessionManagerProtocol
    
    // Specialized services
    private let elementDetectionService: ElementDetectionService
    private let clickService: ClickService
    private let typeService: TypeService
    private let scrollService: ScrollService
    private let hotkeyService: HotkeyService
    private let gestureService: GestureService
    
    public init(sessionManager: SessionManagerProtocol? = nil) {
        let manager = sessionManager ?? SessionManager()
        self.sessionManager = manager
        
        // Initialize specialized services
        self.elementDetectionService = ElementDetectionService(sessionManager: manager)
        self.clickService = ClickService(sessionManager: manager)
        self.typeService = TypeService(sessionManager: manager, clickService: nil)
        self.scrollService = ScrollService(sessionManager: manager, clickService: nil)
        self.hotkeyService = HotkeyService()
        self.gestureService = GestureService()
    }
    
    // MARK: - Element Detection
    
    public func detectElements(in imageData: Data, sessionId: String?, windowContext: WindowContext?) async throws -> ElementDetectionResult {
        logger.debug("Delegating element detection to ElementDetectionService")
        return try await elementDetectionService.detectElements(in: imageData, sessionId: sessionId, windowContext: windowContext)
    }
    
    // MARK: - Click Operations
    
    public func click(target: ClickTarget, clickType: ClickType, sessionId: String?) async throws {
        logger.debug("Delegating click to ClickService")
        try await clickService.click(target: target, clickType: clickType, sessionId: sessionId)
    }
    
    // MARK: - Typing Operations
    
    public func type(text: String, target: String?, clearExisting: Bool, typingDelay: Int, sessionId: String?) async throws {
        logger.debug("Delegating type to TypeService")
        try await typeService.type(
            text: text,
            target: target,
            clearExisting: clearExisting,
            typingDelay: typingDelay,
            sessionId: sessionId
        )
    }
    
    public func typeActions(_ actions: [TypeAction], typingDelay: Int, sessionId: String?) async throws -> TypeResult {
        logger.debug("Delegating typeActions to TypeService")
        return try await typeService.typeActions(actions, typingDelay: typingDelay, sessionId: sessionId)
    }
    
    // MARK: - Scroll Operations
    
    public func scroll(direction: ScrollDirection, amount: Int, target: String?, smooth: Bool, delay: Int, sessionId: String?) async throws {
        logger.debug("Delegating scroll to ScrollService")
        try await scrollService.scroll(
            direction: direction,
            amount: amount,
            target: target,
            smooth: smooth,
            delay: delay,
            sessionId: sessionId
        )
    }
    
    // MARK: - Hotkey Operations
    
    public func hotkey(keys: String, holdDuration: Int) async throws {
        logger.debug("Delegating hotkey to HotkeyService")
        try await hotkeyService.hotkey(keys: keys, holdDuration: holdDuration)
    }
    
    // MARK: - Gesture Operations
    
    public func swipe(from: CGPoint, to: CGPoint, duration: Int, steps: Int) async throws {
        logger.debug("Delegating swipe to GestureService")
        try await gestureService.swipe(from: from, to: to, duration: duration, steps: steps)
    }
    
    public func drag(from: CGPoint, to: CGPoint, duration: Int, steps: Int, modifiers: String?) async throws {
        logger.debug("Delegating drag to GestureService")
        try await gestureService.drag(
            from: from,
            to: to,
            duration: duration,
            steps: steps,
            modifiers: modifiers
        )
    }
    
    public func moveMouse(to: CGPoint, duration: Int, steps: Int) async throws {
        logger.debug("Delegating moveMouse to GestureService")
        try await gestureService.moveMouse(to: to, duration: duration, steps: steps)
    }
    
    // MARK: - Accessibility and Focus
    
    public func hasAccessibilityPermission() async -> Bool {
        logger.debug("Checking accessibility permission")
        return await MainActor.run {
            AXIsProcessTrusted()
        }
    }
    
    @MainActor
    public func getFocusedElement() -> UIFocusInfo? {
        logger.debug("Getting focused element")
        
        // Get the system-wide focused element
        let systemWide = AXUIElementCreateSystemWide()
        
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard result == .success,
              let element = focusedElement else {
            logger.debug("No focused element found")
            return nil
        }
        
        let axElement = element as! AXUIElement
        let wrappedElement = Element(axElement)
        
        // Get element properties
        let role = wrappedElement.role() ?? "Unknown"
        let title = wrappedElement.title()
        let value = wrappedElement.stringValue()
        let frame = wrappedElement.frame() ?? .zero
        
        // Get application info
        var pid: pid_t = 0
        AXUIElementGetPid(axElement, &pid)
        
        let app = NSRunningApplication(processIdentifier: pid)
        let appName = app?.localizedName ?? "Unknown"
        let bundleId = app?.bundleIdentifier ?? "Unknown"
        
        return UIFocusInfo(
            role: role,
            title: title,
            value: value,
            frame: frame,
            applicationName: appName,
            bundleIdentifier: bundleId,
            processId: Int(pid)
        )
    }
    
    // MARK: - Wait for Element
    
    public func waitForElement(
        target: ClickTarget,
        timeout: TimeInterval,
        sessionId: String?
    ) async throws -> WaitForElementResult {
        logger.debug("Waiting for element - target: \(String(describing: target)), timeout: \(timeout)s")
        
        let startTime = Date()
        let deadline = startTime.addingTimeInterval(timeout)
        let retryInterval: UInt64 = 100_000_000 // 100ms in nanoseconds
        
        while Date() < deadline {
            // Check if element exists
            switch target {
            case .elementId(let id):
                if let sessionId = sessionId,
                   let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId),
                   let element = detectionResult.elements.findById(id) {
                    let waitTime = Date().timeIntervalSince(startTime)
                    logger.debug("Found element \(id) after \(waitTime)s")
                    return WaitForElementResult(found: true, element: element, waitTime: waitTime)
                }
                
            case .query(let query):
                // Try to find in session first
                if let sessionId = sessionId,
                   let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId) {
                    let queryLower = query.lowercased()
                    for element in detectionResult.elements.all {
                        let matches = element.label?.lowercased().contains(queryLower) ?? false ||
                                     element.value?.lowercased().contains(queryLower) ?? false
                        
                        if matches && element.isEnabled {
                            let waitTime = Date().timeIntervalSince(startTime)
                            logger.debug("Found element matching '\(query)' after \(waitTime)s")
                            return WaitForElementResult(found: true, element: element, waitTime: waitTime)
                        }
                    }
                }
                
                // Try direct AX search
                let elementInfo = await MainActor.run { () -> (element: Element, frame: CGRect, label: String?)? in
                    findElementByAccessibility(matching: query)
                }
                
                if elementInfo != nil {
                    let waitTime = Date().timeIntervalSince(startTime)
                    let detectedElement = DetectedElement(
                        id: "wait_found",
                        type: .other,
                        label: elementInfo?.label ?? query,
                        value: nil,
                        bounds: elementInfo?.frame ?? .zero,
                        isEnabled: true,
                        isSelected: nil,
                        attributes: [:]
                    )
                    
                    logger.debug("Found element via AX matching '\(query)' after \(waitTime)s")
                    return WaitForElementResult(found: true, element: detectedElement, waitTime: waitTime)
                }
                
            case .coordinates:
                // Coordinates don't need waiting
                let waitTime = Date().timeIntervalSince(startTime)
                return WaitForElementResult(found: true, element: nil, waitTime: waitTime)
            }
            
            // Wait before retry
            try await Task.sleep(nanoseconds: retryInterval)
        }
        
        // Timeout reached
        let waitTime = timeout
        logger.debug("Element not found after \(waitTime)s timeout")
        return WaitForElementResult(found: false, element: nil, waitTime: waitTime)
    }
    
    // MARK: - Private Helpers
    
    @MainActor
    private func findElementByAccessibility(matching query: String) -> (element: Element, frame: CGRect, label: String?)? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        
        let axApp = AXUIElementCreateApplication(frontApp.processIdentifier)
        let appElement = Element(axApp)
        
        return searchElementRecursively(in: appElement, matching: query.lowercased())
    }
    
    @MainActor
    private func searchElementRecursively(in element: Element, matching query: String) -> (element: Element, frame: CGRect, label: String?)? {
        // Check current element
        let title = element.title()?.lowercased() ?? ""
        let label = element.label()?.lowercased() ?? ""
        let value = element.stringValue()?.lowercased() ?? ""
        let roleDescription = element.roleDescription()?.lowercased() ?? ""
        
        if title.contains(query) || label.contains(query) || 
           value.contains(query) || roleDescription.contains(query) {
            if let frame = element.frame() {
                let displayLabel = element.title() ?? element.label() ?? element.roleDescription()
                return (element, frame, displayLabel)
            }
        }
        
        // Search children
        if let children = element.children() {
            for child in children {
                if let found = searchElementRecursively(in: child, matching: query) {
                    return found
                }
            }
        }
        
        return nil
    }
}

// MARK: - Supporting Types

/// Information about a focused UI element for automation
public struct UIFocusInfo: Sendable {
    public let role: String
    public let title: String?
    public let value: String?
    public let frame: CGRect
    public let applicationName: String
    public let bundleIdentifier: String
    public let processId: Int
    
    public init(
        role: String,
        title: String?,
        value: String?,
        frame: CGRect,
        applicationName: String,
        bundleIdentifier: String,
        processId: Int
    ) {
        self.role = role
        self.title = title
        self.value = value
        self.frame = frame
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.processId = processId
    }
}