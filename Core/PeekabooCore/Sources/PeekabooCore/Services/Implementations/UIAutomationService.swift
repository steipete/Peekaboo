import Foundation
import CoreGraphics
import AXorcist
import AppKit

/// Default implementation of UI automation operations using AXorcist
public final class UIAutomationService: UIAutomationServiceProtocol {
    
    private let sessionManager: SessionManagerProtocol
    
    public init(sessionManager: SessionManagerProtocol? = nil) {
        self.sessionManager = sessionManager ?? SessionManager()
    }
    
    public func detectElements(in imageData: Data, sessionId: String?) async throws -> ElementDetectionResult {
        // Create or use existing session
        let session = sessionId ?? (try await sessionManager.createSession())
        
        // TODO: This is a placeholder - actual implementation would:
        // 1. Save the screenshot
        // 2. Use AXorcist to build UI tree
        // 3. Map UI elements to screen coordinates
        // 4. Generate element IDs and annotations
        
        // For now, return empty result
        return ElementDetectionResult(
            sessionId: session,
            screenshotPath: "/tmp/screenshot.png",
            elements: DetectedElements(),
            metadata: DetectionMetadata(
                detectionTime: 0.1,
                elementCount: 0,
                method: "AXorcist"
            )
        )
    }
    
    public func click(target: ClickTarget, clickType: ClickType, sessionId: String?) async throws {
        try await MainActor.run {
            do {
                switch target {
                case .elementId(let id):
                    // Get element from session
                    if let sessionId = sessionId,
                        let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId),
                        let element = detectionResult.elements.findById(id) {
                        // Click at element center
                        let center = CGPoint(x: element.bounds.midX, y: element.bounds.midY)
                        try performClick(at: center, clickType: clickType)
                    } else {
                        throw UIAutomationError.elementNotFound(id)
                    }
                    
                case .coordinates(let point):
                    // Direct coordinate click
                    try performClick(at: point, clickType: clickType)
                    
                case .query(let query):
                    // Find element by text/label and click
                    if let element = findElementByQuery(query) {
                        if let frame = element.frame() {
                            let center = CGPoint(x: frame.midX, y: frame.midY)
                            try performClick(at: center, clickType: clickType)
                        } else {
                            throw UIAutomationError.clickFailed("Element has no frame")
                        }
                    } else {
                        throw UIAutomationError.elementNotFoundByQuery(query)
                    }
                }
            } catch {
                // Re-throw as our error type
                if let uiError = error as? UIAutomationError {
                    throw uiError
                } else {
                    throw UIAutomationError.clickFailed(error.localizedDescription)
                }
            }
        }
    }
    
    public func type(text: String, target: String?, clearExisting: Bool, typingDelay: Int, sessionId: String?) async throws {
        try await MainActor.run {
            do {
                // If target specified, find and focus element first
                if let target = target {
                    if let element = findElementByIdOrQuery(target, sessionId: sessionId) {
                        // Focus the element first
                        try element.setFocused(true)
                        Thread.sleep(forTimeInterval: 0.1)
                        
                        if clearExisting {
                            // Clear existing text
                            if let event = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: true) {
                                event.flags = .maskCommand
                                event.unicodeString = "a"
                                event.post(tap: .cghidEventTap)
                            }
                            Thread.sleep(forTimeInterval: 0.05)
                            
                            if let deleteEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: true) { // Delete key
                                deleteEvent.post(tap: .cghidEventTap)
                            }
                            Thread.sleep(forTimeInterval: 0.05)
                        }
                        
                        // Type the text
                        typeTextWithDelay(text, delay: TimeInterval(typingDelay) / 1000.0)
                    } else {
                        throw UIAutomationError.elementNotFound(target)
                    }
                } else {
                    // Type at current focus
                    if clearExisting {
                        // Clear current field
                        if let event = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: true) {
                            event.flags = .maskCommand
                            event.unicodeString = "a"
                            event.post(tap: .cghidEventTap)
                        }
                        Thread.sleep(forTimeInterval: 0.05)
                        
                        if let deleteEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: true) { // Delete key
                            deleteEvent.post(tap: .cghidEventTap)
                        }
                        Thread.sleep(forTimeInterval: 0.05)
                    }
                    
                    typeTextWithDelay(text, delay: TimeInterval(typingDelay) / 1000.0)
                }
            } catch {
                if let uiError = error as? UIAutomationError {
                    throw uiError
                } else {
                    throw UIAutomationError.typeFailed(error.localizedDescription)
                }
            }
        }
    }
    
    public func scroll(direction: ScrollDirection, amount: Int, target: String?, smooth: Bool, sessionId: String?) async throws {
        try await MainActor.run {
            do {
                let scrollPoint: CGPoint
                
                if let target = target {
                    // Scroll on specific element
                    if let element = findElementByIdOrQuery(target, sessionId: sessionId) {
                        if let frame = element.frame() {
                            scrollPoint = CGPoint(x: frame.midX, y: frame.midY)
                        } else {
                            throw UIAutomationError.scrollFailed("Element has no frame")
                        }
                    } else {
                        throw UIAutomationError.elementNotFound(target)
                    }
                } else {
                    // Scroll at current mouse position
                    let mouseLocation = NSEvent.mouseLocation
                    // Convert from NSScreen coordinates to Core Graphics coordinates
                    let screenHeight = NSScreen.main?.frame.height ?? 0
                    scrollPoint = CGPoint(x: mouseLocation.x, y: screenHeight - mouseLocation.y)
                }
                
                // Perform scroll using CGEvents
                let scrollAmount = smooth ? amount : amount * 10 // Adjust for smooth scrolling
                
                if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: 0, wheel2: 0, wheel3: 0) {
                    switch direction {
                    case .up:
                        scrollEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(scrollAmount))
                    case .down:
                        scrollEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(-scrollAmount))
                    case .left:
                        scrollEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(scrollAmount))
                    case .right:
                        scrollEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(-scrollAmount))
                    }
                    
                    scrollEvent.location = scrollPoint
                    scrollEvent.post(tap: .cghidEventTap)
                }
            } catch {
                if let uiError = error as? UIAutomationError {
                    throw uiError
                } else {
                    throw UIAutomationError.scrollFailed(error.localizedDescription)
                }
            }
        }
    }
    
    public func hotkey(keys: String, holdDuration: Int) async throws {
        try await MainActor.run {
            do {
                // Parse comma-separated keys
                let keyArray = keys.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                
                // Build modifier flags
                var modifierFlags = CGEventFlags()
                var regularKeys: [String] = []
                
                for key in keyArray {
                    switch key.lowercased() {
                    case "cmd", "command":
                        modifierFlags.insert(.maskCommand)
                    case "ctrl", "control":
                        modifierFlags.insert(.maskControl)
                    case "opt", "option", "alt":
                        modifierFlags.insert(.maskAlternate)
                    case "shift":
                        modifierFlags.insert(.maskShift)
                    case "fn", "function":
                        modifierFlags.insert(.maskSecondaryFn)
                    default:
                        regularKeys.append(key)
                    }
                }
                
                // Press the key combination
                if !regularKeys.isEmpty, let firstKey = regularKeys.first {
                    // Map common key names to virtual key codes
                    let virtualKey = mapKeyToVirtualCode(firstKey)
                    
                    if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: true) {
                        keyDown.flags = modifierFlags
                        keyDown.post(tap: .cghidEventTap)
                        
                        // Hold duration
                        Thread.sleep(forTimeInterval: TimeInterval(holdDuration) / 1000.0)
                        
                        if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: false) {
                            keyUp.flags = modifierFlags
                            keyUp.post(tap: .cghidEventTap)
                        }
                    }
                } else {
                    // Just modifier keys
                    if let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
                        event.flags = modifierFlags
                        event.post(tap: .cghidEventTap)
                        
                        Thread.sleep(forTimeInterval: TimeInterval(holdDuration) / 1000.0)
                        
                        if let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
                            upEvent.flags = []
                            upEvent.post(tap: .cghidEventTap)
                        }
                    }
                }
            } catch {
                if let uiError = error as? UIAutomationError {
                    throw uiError
                } else {
                    throw UIAutomationError.hotkeyFailed(error.localizedDescription)
                }
            }
        }
    }
    
    public func swipe(from: CGPoint, to: CGPoint, duration: Int, steps: Int) async throws {
        await MainActor.run {
            do {
                // Create mouse down event at start point
                guard let mouseDown = CGEvent(
                    mouseEventSource: nil,
                    mouseType: .leftMouseDown,
                    mouseCursorPosition: from,
                    mouseButton: .left
                ) else {
                    throw UIAutomationError.swipeFailed("Failed to create mouse down event")
                }
                
                // Post mouse down
                mouseDown.post(tap: .cghidEventTap)
                
                // Calculate step increments
                let deltaX = (to.x - from.x) / CGFloat(steps)
                let deltaY = (to.y - from.y) / CGFloat(steps)
                let stepDuration = TimeInterval(duration) / TimeInterval(steps) / 1000.0
                
                // Perform drag in steps
                for i in 1...steps {
                    let currentPoint = CGPoint(
                        x: from.x + (deltaX * CGFloat(i)),
                        y: from.y + (deltaY * CGFloat(i))
                    )
                    
                    guard let dragEvent = CGEvent(
                        mouseEventSource: nil,
                        mouseType: .leftMouseDragged,
                        mouseCursorPosition: currentPoint,
                        mouseButton: .left
                    ) else {
                        throw UIAutomationError.swipeFailed("Failed to create drag event")
                    }
                    
                    dragEvent.post(tap: .cghidEventTap)
                    Thread.sleep(forTimeInterval: stepDuration)
                }
                
                // Create mouse up event at end point
                guard let mouseUp = CGEvent(
                    mouseEventSource: nil,
                    mouseType: .leftMouseUp,
                    mouseCursorPosition: to,
                    mouseButton: .left
                ) else {
                    throw UIAutomationError.swipeFailed("Failed to create mouse up event")
                }
                
                mouseUp.post(tap: .cghidEventTap)
            } catch {
                if let uiError = error as? UIAutomationError {
                    throw uiError
                } else {
                    throw UIAutomationError.swipeFailed(error.localizedDescription)
                }
            }
        }
    }
    
    public func hasAccessibilityPermission() async -> Bool {
        return AXIsProcessTrusted()
    }
    
    /// Wait for an element to appear and become actionable
    public func waitForElement(
        target: ClickTarget,
        timeout: TimeInterval,
        sessionId: String?
    ) async throws -> WaitForElementResult {
        let startTime = Date()
        let deadline = startTime.addingTimeInterval(timeout)
        let retryInterval: UInt64 = 100_000_000 // 100ms in nanoseconds
        
        while Date() < deadline {
            do {
                // Try to find the element
                switch target {
                case .elementId(let id):
                    if let sessionId = sessionId,
                       let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId),
                       let element = detectionResult.elements.findById(id) {
                        // Verify element is still actionable at its location
                        if let liveElement = await findElementAtLocation(
                            frame: element.bounds,
                            role: element.type.axRole ?? ""
                        ) {
                            if await isElementActionable(liveElement) {
                                return WaitForElementResult(
                                    found: true,
                                    element: element,
                                    waitTime: Date().timeIntervalSince(startTime)
                                )
                            }
                        }
                    }
                    
                case .query(let query):
                    if let element = await MainActor.run(body: { findElementByQuery(query) }) {
                        if await isElementActionable(element) {
                            let frame = await MainActor.run { element.frame() } ?? .zero
                            let detectedElement = DetectedElement(
                                id: "Q\(abs(query.hashValue))",
                                type: .other,
                                label: await MainActor.run { element.title() ?? element.label() },
                                value: await MainActor.run { element.value() as? String },
                                bounds: frame,
                                isEnabled: true
                            )
                            return WaitForElementResult(
                                found: true,
                                element: detectedElement,
                                waitTime: Date().timeIntervalSince(startTime)
                            )
                        }
                    }
                    
                case .coordinates:
                    // Coordinates don't need waiting
                    return WaitForElementResult(
                        found: true,
                        element: nil,
                        waitTime: 0
                    )
                }
                
                // Wait before retrying
                try await Task.sleep(nanoseconds: retryInterval)
            } catch {
                // Continue retrying until timeout
                try await Task.sleep(nanoseconds: retryInterval)
            }
        }
        
        // Timeout reached
        throw UIAutomationError.elementNotFoundWithinTimeout(timeout)
    }
    
    // MARK: - Private Helpers
    
    @MainActor
    private func typeTextWithDelay(_ text: String, delay: TimeInterval) {
        for character in text {
            if let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
                event.keyboardSetUnicodeString(stringLength: 1, unicodeString: [character.utf16.first ?? 0])
                event.post(tap: .cghidEventTap)
                
                if let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
                    upEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: [character.utf16.first ?? 0])
                    upEvent.post(tap: .cghidEventTap)
                }
            }
            
            if delay > 0 {
                Thread.sleep(forTimeInterval: delay)
            }
        }
    }
    
    @MainActor
    private func mapKeyToVirtualCode(_ key: String) -> CGKeyCode {
        switch key.lowercased() {
        // Letters
        case "a": return 0x00
        case "b": return 0x0B
        case "c": return 0x08
        case "d": return 0x02
        case "e": return 0x0E
        case "f": return 0x03
        case "g": return 0x05
        case "h": return 0x04
        case "i": return 0x22
        case "j": return 0x26
        case "k": return 0x28
        case "l": return 0x25
        case "m": return 0x2E
        case "n": return 0x2D
        case "o": return 0x1F
        case "p": return 0x23
        case "q": return 0x0C
        case "r": return 0x0F
        case "s": return 0x01
        case "t": return 0x11
        case "u": return 0x20
        case "v": return 0x09
        case "w": return 0x0D
        case "x": return 0x07
        case "y": return 0x10
        case "z": return 0x06
            
        // Numbers
        case "0": return 0x1D
        case "1": return 0x12
        case "2": return 0x13
        case "3": return 0x14
        case "4": return 0x15
        case "5": return 0x17
        case "6": return 0x16
        case "7": return 0x1A
        case "8": return 0x1C
        case "9": return 0x19
            
        // Special keys
        case "return", "enter": return 0x24
        case "tab": return 0x30
        case "space": return 0x31
        case "delete", "backspace": return 0x33
        case "escape", "esc": return 0x35
        case "up": return 0x7E
        case "down": return 0x7D
        case "left": return 0x7B
        case "right": return 0x7C
        case "f1": return 0x7A
        case "f2": return 0x78
        case "f3": return 0x63
        case "f4": return 0x76
        case "f5": return 0x60
        case "f6": return 0x61
        case "f7": return 0x62
        case "f8": return 0x64
        case "f9": return 0x65
        case "f10": return 0x6D
        case "f11": return 0x67
        case "f12": return 0x6F
            
        default: return 0x00 // Default to 'a' if unknown
        }
    }
    
    @MainActor
    private func performClick(at point: CGPoint, clickType: ClickType) throws {
        // Use CoreGraphics events for clicking
        let mouseButton = clickType.mouseButton == .right ? CGMouseButton.right : CGMouseButton.left
        let clickCount = clickType.clickCount
        
        // Move to position first
        var moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: mouseButton)
        moveEvent?.post(tap: .cghidEventTap)
        
        // Small delay to ensure position is registered
        Thread.sleep(forTimeInterval: 0.05)
        
        // Perform click(s)
        for _ in 0..<clickCount {
            // Mouse down
            var downEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: mouseButton == .right ? .rightMouseDown : .leftMouseDown,
                mouseCursorPosition: point,
                mouseButton: mouseButton
            )
            downEvent?.post(tap: .cghidEventTap)
            
            // Small delay
            Thread.sleep(forTimeInterval: 0.05)
            
            // Mouse up
            var upEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: mouseButton == .right ? .rightMouseUp : .leftMouseUp,
                mouseCursorPosition: point,
                mouseButton: mouseButton
            )
            upEvent?.post(tap: .cghidEventTap)
            
            // Delay between clicks for double-click
            if clickCount > 1 {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
    
    @MainActor
    private func findElementAtLocation(
        frame: CGRect,
        role: String
    ) async -> Element? {
        // Get element at the center of the frame
        let centerPoint = CGPoint(x: frame.midX, y: frame.midY)
        
        // Try to find element at this point using AXorcist's static method
        // We need to find which app owns this location first
        for app in NSWorkspace.shared.runningApplications {
            if let foundElement = Element.elementAtPoint(centerPoint, pid: app.processIdentifier) {
                // Verify it's the right type of element
                if foundElement.role() == role {
                    return foundElement
                }
            }
        }
        
        return nil
    }
    
    @MainActor
    private func isElementActionable(_ element: Element) async -> Bool {
        // Check if element is enabled
        if !(element.isEnabled() ?? true) {
            return false
        }
        
        // Check if element is visible (not hidden)
        if element.isHidden() == true {
            return false
        }
        
        // Check frame validity
        guard let frame = element.frame() else {
            return false
        }
        if frame.width <= 0 || frame.height <= 0 {
            return false
        }
        
        // Check if element is on screen
        if let mainScreen = NSScreen.main {
            let screenBounds = mainScreen.frame
            if !screenBounds.intersects(frame) {
                return false
            }
        } else {
            return false
        }
        
        return true
    }
    
    @MainActor
    private func findElementByQuery(_ query: String) -> Element? {
        // Search through all applications
        for app in NSWorkspace.shared.runningApplications {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            let appElement = Element(axApp)
            
            // Search for matching element in this app
            if let match = findMatchingElementInTree(element: appElement, query: query) {
                return match
            }
        }
        
        return nil
    }
    
    @MainActor
    private func findMatchingElementInTree(element: Element, query: String) -> Element? {
        // Check if current element matches
        if let title = element.title(), title.localizedCaseInsensitiveContains(query) {
            return element
        }
        
        if let label = element.label(), label.localizedCaseInsensitiveContains(query) {
            return element
        }
        
        if let value = element.value() as? String, value.localizedCaseInsensitiveContains(query) {
            return element
        }
        
        if let description = element.descriptionText(), description.localizedCaseInsensitiveContains(query) {
            return element
        }
        
        // Recursively search children
        if let children = element.children() {
            for child in children {
                if let match = findMatchingElementInTree(element: child, query: query) {
                    return match
                }
            }
        }
        
        return nil
    }
    
    @MainActor
    private func findElementByIdOrQuery(_ target: String, sessionId: String?) -> Element? {
        // First try as element ID from session
        if let sessionId = sessionId {
            // This needs to be async but the function isn't async, so we'll handle it differently
            // For now, just try as query
            return findElementByQuery(target)
        }
        
        // Otherwise try as query
        return findElementByQuery(target)
    }
}

// MARK: - UI Automation Errors

public enum UIAutomationError: LocalizedError {
    case elementNotFound(String)
    case elementNotFoundByQuery(String)
    case elementNotFoundWithinTimeout(TimeInterval)
    case clickFailed(String)
    case typeFailed(String)
    case scrollFailed(String)
    case hotkeyFailed(String)
    case swipeFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .elementNotFound(let id):
            return "Element not found: \(id)"
        case .elementNotFoundByQuery(let query):
            return "No element found matching: \(query)"
        case .elementNotFoundWithinTimeout(let timeout):
            return "Element not found within \(String(format: "%.1f", timeout))s timeout"
        case .clickFailed(let reason):
            return "Click failed: \(reason)"
        case .typeFailed(let reason):
            return "Type failed: \(reason)"
        case .scrollFailed(let reason):
            return "Scroll failed: \(reason)"
        case .hotkeyFailed(let reason):
            return "Hotkey failed: \(reason)"
        case .swipeFailed(let reason):
            return "Swipe failed: \(reason)"
        }
    }
}

// MARK: - Extensions

extension ClickType {
    var mouseButton: CGMouseButton {
        switch self {
        case .single, .double: return .left
        case .right: return .right
        }
    }
    
    var clickCount: Int {
        switch self {
        case .single, .right: return 1
        case .double: return 2
        }
    }
}

extension ElementType {
    var axRole: String? {
        switch self {
        case .button: return kAXButtonRole
        case .textField: return kAXTextFieldRole
        case .link: return kAXLinkRole
        case .image: return kAXImageRole
        case .group: return kAXGroupRole
        case .slider: return kAXSliderRole
        case .checkbox: return kAXCheckBoxRole
        case .menu: return kAXMenuRole
        default: return nil
        }
    }
}