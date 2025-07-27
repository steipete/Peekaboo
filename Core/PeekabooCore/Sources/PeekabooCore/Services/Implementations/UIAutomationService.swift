import Foundation
import CoreGraphics
@preconcurrency import AXorcist
import AppKit
import ApplicationServices
import os.log

/// Default implementation of UI automation operations using AXorcist
public final class UIAutomationService: UIAutomationServiceProtocol {
    
    private let logger = Logger(subsystem: "com.steipete.PeekabooCore", category: "UIAutomationService")
    let sessionManager: SessionManagerProtocol
    
    public init(sessionManager: SessionManagerProtocol? = nil) {
        self.sessionManager = sessionManager ?? SessionManager()
    }
    
    public func detectElements(in imageData: Data, sessionId: String?) async throws -> ElementDetectionResult {
        // Use the enhanced implementation
        return try await detectElementsEnhanced(
            in: imageData,
            sessionId: sessionId,
            applicationName: nil,
            windowTitle: nil,
            windowBounds: nil
        )
    }
    
    public func click(target: ClickTarget, clickType: ClickType, sessionId: String?) async throws {
        do {
            switch target {
            case .elementId(let id):
                // Get element from session
                if let sessionId = sessionId,
                    let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId),
                    let element = detectionResult.elements.findById(id) {
                    // Click at element center
                    let center = CGPoint(x: element.bounds.midX, y: element.bounds.midY)
                    try await performClick(at: center, clickType: clickType)
                } else {
                    throw NotFoundError.element(id)
                }
                
            case .coordinates(let point):
                // Direct coordinate click
                try await performClick(at: point, clickType: clickType)
                
            case .query(let query):
                // Find element by text/label and click
                let elementInfo = await MainActor.run { () -> (found: Bool, frame: CGRect?) in
                    if let element = findElementByQuery(query) {
                        return (true, element.frame())
                    }
                    return (false, nil)
                }
                
                if elementInfo.found {
                    if let frame = elementInfo.frame {
                        let center = CGPoint(x: frame.midX, y: frame.midY)
                        try await performClick(at: center, clickType: clickType)
                    } else {
                        throw OperationError.interactionFailed(
                            action: "click",
                            reason: "Element has no frame"
                        )
                    }
                } else {
                    throw NotFoundError.element(query)
                }
            }
        } catch {
            // Re-throw as our error type
            if let uiError = error as? UIAutomationError {
                throw uiError
            } else {
                throw OperationError.interactionFailed(
                    action: "click",
                    reason: error.localizedDescription
                )
            }
        }
    }
    
    public func type(text: String, target: String?, clearExisting: Bool, typingDelay: Int, sessionId: String?) async throws {
        do {
            // If target specified, find and focus element first
            if let target = target {
                var elementFound = false
                var elementFrame: CGRect?
                
                // First check if target is an element ID from session
                if let sessionId = sessionId,
                   target.count >= 2,
                   target.first?.isLetter == true,
                   target.dropFirst().allSatisfy({ $0.isNumber || $0 == "_" }) {
                    // This looks like an element ID (e.g., "B1", "Window1_T2")
                    if let uiElement = try? await sessionManager.getElement(sessionId: sessionId, elementId: target) {
                        elementFrame = uiElement.frame
                        
                        // Click on the element to focus it
                        let center = CGPoint(x: elementFrame!.midX, y: elementFrame!.midY)
                        try await performClick(at: center, clickType: .single)
                        elementFound = true
                    }
                }
                
                // If not found as ID, try as query
                if !elementFound {
                    elementFound = await MainActor.run { () -> Bool in
                        if let element = findElementByQuery(target) {
                            // Focus the element
                            _ = element.setValue(true, forAttribute: AXAttributeNames.kAXFocusedAttribute)
                            return true
                        }
                        return false
                    }
                }
                
                if elementFound {
                    try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
                    
                    if clearExisting {
                        // Clear existing text
                        await MainActor.run {
                            if let event = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: true) {
                                event.flags = .maskCommand
                                event.post(tap: .cghidEventTap)
                            }
                        }
                        try await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000))
                        
                        await MainActor.run {
                            if let deleteEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: true) { // Delete key
                                deleteEvent.post(tap: .cghidEventTap)
                            }
                        }
                        try await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000))
                    }
                    
                    // Type the text
                    try await typeTextWithDelay(text, delay: TimeInterval(typingDelay) / 1000.0)
                } else {
                    throw NotFoundError.element(target)
                }
            } else {
                // Type at current focus
                if clearExisting {
                    // Clear current field
                    await MainActor.run {
                        if let event = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: true) {
                            event.flags = .maskCommand
                            event.post(tap: .cghidEventTap)
                        }
                    }
                    try await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000))
                    
                    await MainActor.run {
                        if let deleteEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: true) { // Delete key
                            deleteEvent.post(tap: .cghidEventTap)
                        }
                    }
                    try await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000))
                }
                
                try await typeTextWithDelay(text, delay: TimeInterval(typingDelay) / 1000.0)
            }
        } catch {
            if let uiError = error as? UIAutomationError {
                throw uiError
            } else {
                throw OperationError.interactionFailed(
                    action: "type",
                    reason: error.localizedDescription
                )
            }
        }
    }
    
    public func scroll(direction: ScrollDirection, amount: Int, target: String?, smooth: Bool, delay: Int, sessionId: String?) async throws {
        do {
            let scrollPoint: CGPoint
            
            if let target = target {
                // Scroll on specific element
                var elementFrame: CGRect?
                
                // Check if target is an element ID from session
                if let sessionId = sessionId,
                   target.count >= 2 && target.first?.isLetter == true && target.dropFirst().allSatisfy({ $0.isNumber }) {
                    // Get element from session
                    if let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId),
                       let element = detectionResult.elements.findById(target) {
                        elementFrame = element.bounds
                    }
                } else {
                    // Try to find element by query
                    elementFrame = await MainActor.run { () -> CGRect? in
                        if let element = findElementByQuery(target) {
                            return element.frame()
                        }
                        return nil
                    }
                }
                
                if let frame = elementFrame {
                    scrollPoint = CGPoint(x: frame.midX, y: frame.midY)
                } else {
                    throw OperationError.interactionFailed(
                        action: "scroll",
                        reason: "Element not found or has no frame"
                    )
                }
            } else {
                // Scroll at current mouse position
                let mouseLocation = await MainActor.run { CGEvent(source: nil)?.location ?? CGPoint.zero }
                scrollPoint = mouseLocation
            }
            
            // Calculate scroll deltas (matching original ScrollCommand behavior)
            let (deltaX, deltaY) = getScrollDeltas(for: direction)
            
            // Determine tick count and size
            // For large amounts, use fewer but larger ticks to reduce total time
            let (tickCount, tickSize): (Int, Int) = if smooth {
                (amount * 3, 1)
            } else if amount > 10 {
                // For large scroll amounts, use bigger chunks
                (min(amount / 2, 20), 6)
            } else {
                (amount, 3)
            }
            
            for i in 0..<tickCount {
                // Create scroll event using the same API as original
                await MainActor.run {
                    let scrollEvent = CGEvent(
                        scrollWheelEvent2Source: nil,
                        units: .line,
                        wheelCount: 1,
                        wheel1: Int32(deltaY * tickSize),
                        wheel2: Int32(deltaX * tickSize),
                        wheel3: 0)
                    
                    // Set the location for the scroll event
                    scrollEvent?.location = scrollPoint
                    
                    // Post the event
                    scrollEvent?.post(tap: .cghidEventTap)
                }
                
                // Delay between ticks (skip delay for last tick)
                if delay > 0 && i < tickCount - 1 {
                    try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
                }
            }
        } catch {
            if let uiError = error as? UIAutomationError {
                throw uiError
            } else {
                throw OperationError.interactionFailed(
                    action: "scroll",
                    reason: error.localizedDescription
                )
            }
        }
    }
    
    private func getScrollDeltas(for direction: ScrollDirection) -> (deltaX: Int, deltaY: Int) {
        switch direction {
        case .up:
            (0, 5) // Positive Y scrolls up
        case .down:
            (0, -5) // Negative Y scrolls down
        case .left:
            (5, 0) // Positive X scrolls left
        case .right:
            (-5, 0) // Negative X scrolls right
        }
    }
    
    public func hotkey(keys: String, holdDuration: Int) async throws {
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
                let virtualKey = await MainActor.run { mapKeyToVirtualCode(firstKey) }
                
                await MainActor.run {
                    if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: true) {
                        keyDown.flags = modifierFlags
                        keyDown.post(tap: .cghidEventTap)
                    }
                }
                
                // Hold duration
                try await Task.sleep(nanoseconds: UInt64(TimeInterval(holdDuration) / 1000.0 * 1_000_000_000))
                
                await MainActor.run {
                    if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: false) {
                        keyUp.flags = modifierFlags
                        keyUp.post(tap: .cghidEventTap)
                    }
                }
            } else {
                // Just modifier keys
                await MainActor.run {
                    if let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
                        event.flags = modifierFlags
                        event.post(tap: .cghidEventTap)
                    }
                }
                
                try await Task.sleep(nanoseconds: UInt64(TimeInterval(holdDuration) / 1000.0 * 1_000_000_000))
                
                await MainActor.run {
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
                throw OperationError.interactionFailed(
                    action: "hotkey",
                    reason: error.localizedDescription
                )
            }
        }
    }
    
    public func swipe(from: CGPoint, to: CGPoint, duration: Int, steps: Int) async throws {
        do {
            // Create and post mouse down event at start point
            await MainActor.run {
                guard let mouseDown = CGEvent(
                    mouseEventSource: nil,
                    mouseType: .leftMouseDown,
                    mouseCursorPosition: from,
                    mouseButton: .left
                ) else {
                    return
                }
                mouseDown.post(tap: .cghidEventTap)
            }
            
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
                
                await MainActor.run {
                    guard let dragEvent = CGEvent(
                        mouseEventSource: nil,
                        mouseType: .leftMouseDragged,
                        mouseCursorPosition: currentPoint,
                        mouseButton: .left
                    ) else {
                        return
                    }
                    dragEvent.post(tap: .cghidEventTap)
                }
                
                try await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            }
            
            // Create and post mouse up event at end point
            await MainActor.run {
                guard let mouseUp = CGEvent(
                    mouseEventSource: nil,
                    mouseType: .leftMouseUp,
                    mouseCursorPosition: to,
                    mouseButton: .left
                ) else {
                    return
                }
                mouseUp.post(tap: .cghidEventTap)
            }
            
            logger.info("Swipe operation completed successfully")
        } catch {
            if let uiError = error as? UIAutomationError {
                throw uiError
            } else {
                throw OperationError.interactionFailed(
                    action: "swipe",
                    reason: error.localizedDescription
                )
            }
        }
    }
    
    public func hasAccessibilityPermission() async -> Bool {
        return AXIsProcessTrusted()
    }
    
    public func typeActions(_ actions: [TypeAction], typingDelay: Int, sessionId: String?) async throws -> TypeResult {
        var totalChars = 0
        var keyPresses = 0
        
        for action in actions {
            switch action {
            case .text(let string):
                // Type the string using CoreGraphics events
                let delaySeconds = Double(typingDelay) / 1000.0
                for character in string {
                    await MainActor.run {
                        if let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
                            event.keyboardSetUnicodeString(stringLength: 1, unicodeString: [character.utf16.first ?? 0])
                            event.post(tap: .cghidEventTap)
                            
                            if let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
                                upEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: [character.utf16.first ?? 0])
                                upEvent.post(tap: .cghidEventTap)
                            }
                        }
                    }
                    
                    if delaySeconds > 0 {
                        try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                    }
                }
                totalChars += string.count
                
            case .key(let key):
                // Type special key
                let virtualKey = await MainActor.run { mapSpecialKeyToVirtualCode(key) }
                
                await MainActor.run {
                    if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: true) {
                        keyDown.post(tap: .cghidEventTap)
                    }
                }
                
                try await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000)) // Small delay between down and up
                
                await MainActor.run {
                    if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: false) {
                        keyUp.post(tap: .cghidEventTap)
                    }
                }
                
                keyPresses += 1
                
                if typingDelay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(Double(typingDelay) / 1000.0 * 1_000_000_000))
                }
                
            case .clear:
                // Clear field by selecting all (Cmd+A) and deleting
                await MainActor.run {
                    if let event = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: true) {
                        event.flags = .maskCommand
                        event.post(tap: .cghidEventTap)
                    }
                    
                    if let event = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: false) {
                        event.flags = .maskCommand
                        event.post(tap: .cghidEventTap)
                    }
                }
                
                try await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000))
                
                // Press delete
                await MainActor.run {
                    if let deleteEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: true) {
                        deleteEvent.post(tap: .cghidEventTap)
                    }
                    
                    if let deleteUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x33, keyDown: false) {
                        deleteUpEvent.post(tap: .cghidEventTap)
                    }
                }
                
                keyPresses += 2 // Cmd+A and Delete
                
                if typingDelay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(Double(typingDelay) / 1000.0 * 1_000_000_000))
                }
            }
        }
        
        return TypeResult(totalCharacters: totalChars, keyPresses: keyPresses)
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
                        // For session-based elements, trust the stored data
                        // The element was already verified when the session was created
                        if element.isEnabled {
                            return WaitForElementResult(
                                found: true,
                                element: element,
                                waitTime: Date().timeIntervalSince(startTime)
                            )
                        }
                    }
                    
                case .query(let query):
                    let elementInfo = await MainActor.run { () -> (element: Element, frame: CGRect, label: String?)? in
                        if let element = findElementByQuery(query) {
                            let frame = element.frame() ?? .zero
                            let label = element.title() ?? element.roleDescription() ?? element.descriptionText()
                            return (element, frame, label)
                        }
                        return nil
                    }
                    
                    if let info = elementInfo, await isElementActionable(info.element) {
                        let detectedElement = DetectedElement(
                            id: "Q\(abs(query.hashValue))",
                            type: .other,
                            label: info.label,
                            value: await MainActor.run { info.element.value() as? String },
                            bounds: info.frame,
                            isEnabled: true
                        )
                        return WaitForElementResult(
                            found: true,
                            element: detectedElement,
                            waitTime: Date().timeIntervalSince(startTime)
                        )
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
        throw OperationError.timeout(
            operation: "waitForElement",
            duration: timeout
        )
    }
    
    public func drag(from: CGPoint, to: CGPoint, duration: Int, steps: Int, modifiers: String?) async throws {
        do {
            // Parse modifiers
            let eventFlags = parseModifierKeys(modifiers)
            
            // Calculate step increments
            let deltaX = to.x - from.x
            let deltaY = to.y - from.y
            let stepDuration = duration / steps
            let stepDelayNanos = UInt64(stepDuration) * 1_000_000 // Convert milliseconds to nanoseconds
            
            // Mouse down at start point
            await MainActor.run {
                guard let mouseDown = CGEvent(
                    mouseEventSource: nil,
                    mouseType: .leftMouseDown,
                    mouseCursorPosition: from,
                    mouseButton: .left
                ) else {
                    return
                }
                mouseDown.flags = eventFlags
                mouseDown.post(tap: .cghidEventTap)
            }
            
            // Drag through intermediate points
            for i in 1...steps {
                let progress = Double(i) / Double(steps)
                let currentX = from.x + (deltaX * progress)
                let currentY = from.y + (deltaY * progress)
                let currentPoint = CGPoint(x: currentX, y: currentY)
                
                await MainActor.run {
                    guard let dragEvent = CGEvent(
                        mouseEventSource: nil,
                        mouseType: .leftMouseDragged,
                        mouseCursorPosition: currentPoint,
                        mouseButton: .left
                    ) else {
                        return
                    }
                    dragEvent.flags = eventFlags
                    dragEvent.post(tap: .cghidEventTap)
                }
                
                if stepDelayNanos > 0 {
                    try await Task.sleep(nanoseconds: stepDelayNanos)
                }
            }
            
            // Mouse up at end point
            await MainActor.run {
                guard let mouseUp = CGEvent(
                    mouseEventSource: nil,
                    mouseType: .leftMouseUp,
                    mouseCursorPosition: to,
                    mouseButton: .left
                ) else {
                    return
                }
                mouseUp.flags = eventFlags
                mouseUp.post(tap: .cghidEventTap)
            }
        } catch {
            if let uiError = error as? UIAutomationError {
                throw uiError
            } else {
                throw OperationError.interactionFailed(
                    action: "drag",
                    reason: error.localizedDescription
                )
            }
        }
    }
    
    public func moveMouse(to: CGPoint, duration: Int, steps: Int) async throws {
        if duration == 0 || steps <= 1 {
            // Instant movement
            await MainActor.run {
                guard let moveEvent = CGEvent(
                    mouseEventSource: nil,
                    mouseType: .mouseMoved,
                    mouseCursorPosition: to,
                    mouseButton: .left
                ) else {
                    return
                }
                moveEvent.post(tap: .cghidEventTap)
            }
        } else {
            // Smooth movement with intermediate steps
            let currentLocation = await MainActor.run { CGEvent(source: nil)?.location ?? CGPoint.zero }
            let deltaX = to.x - currentLocation.x
            let deltaY = to.y - currentLocation.y
            let stepDuration = duration / steps
            let stepDelayNanos = UInt64(stepDuration) * 1_000_000 // Convert milliseconds to nanoseconds
            
            for i in 1...steps {
                let progress = Double(i) / Double(steps)
                let currentX = currentLocation.x + (deltaX * progress)
                let currentY = currentLocation.y + (deltaY * progress)
                let currentPoint = CGPoint(x: currentX, y: currentY)
                
                await MainActor.run {
                    guard let moveEvent = CGEvent(
                        mouseEventSource: nil,
                        mouseType: .mouseMoved,
                        mouseCursorPosition: currentPoint,
                        mouseButton: .left
                    ) else {
                        return
                    }
                    moveEvent.post(tap: .cghidEventTap)
                }
                
                if i < steps && stepDelayNanos > 0 {
                    try await Task.sleep(nanoseconds: stepDelayNanos)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func parseModifierKeys(_ modifierString: String?) -> CGEventFlags {
        guard let modString = modifierString else { return [] }
        
        var flags: CGEventFlags = []
        let modifiers = modString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        
        for modifier in modifiers {
            switch modifier {
            case "cmd", "command":
                flags.insert(.maskCommand)
            case "shift":
                flags.insert(.maskShift)
            case "option", "opt", "alt":
                flags.insert(.maskAlternate)
            case "ctrl", "control":
                flags.insert(.maskControl)
            default:
                break
            }
        }
        
        return flags
    }
    
    @MainActor
    private func typeTextWithDelay(_ text: String, delay: TimeInterval) async throws {
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
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
    
    /// Get information about the currently focused UI element
    @MainActor
    public func getFocusedElement() -> FocusInfo? {
        // Get the currently focused element across all applications
        let systemWideElement = AXUIElementCreateSystemWide()
        let focusedElement = Element(systemWideElement).focusedUIElement()
        
        guard let focused = focusedElement else {
            logger.debug("No focused UI element found")
            return nil
        }
        
        // Find the application that owns this element by checking all applications
        var owningApp: NSRunningApplication?
        var pid: pid_t = 0
        
        // Try to get PID from the element directly
        if let elementPid = focused.pid() {
            pid = elementPid
            owningApp = NSWorkspace.shared.runningApplications.first { $0.processIdentifier == pid }
        } else {
            // Fall back to checking all applications
            for app in NSWorkspace.shared.runningApplications {
                let axApp = AXUIElementCreateApplication(app.processIdentifier)
                let appElement = Element(axApp)
                
                // Check if this app's focused element matches our element
                if let focusedInApp = appElement.focusedUIElement() {
                    // Compare by position and role since we can't access the raw element
                    if let pos1 = focusedInApp.position(), let pos2 = focused.position(),
                       let size1 = focusedInApp.size(), let size2 = focused.size(),
                       pos1 == pos2 && size1 == size2 &&
                       focusedInApp.role() == focused.role() {
                        owningApp = app
                        pid = app.processIdentifier
                        break
                    }
                }
            }
        }
        
        let appName = owningApp?.localizedName ?? "Unknown"
        let bundleId = owningApp?.bundleIdentifier
        
        // Extract element information
        let role = focused.role() ?? "AXUnknown"
        let title = focused.title()
        let value = focused.value() as? String
        let bounds = focused.frame() ?? .zero
        let isEnabled = focused.isEnabled() ?? false
        let isVisible = !(focused.isHidden() ?? false)
        let subrole = focused.subrole()
        let description = focused.descriptionText()
        
        let elementInfo = ElementInfo(
            role: role,
            title: title,
            value: value,
            bounds: bounds,
            isEnabled: isEnabled,
            isVisible: isVisible,
            subrole: subrole,
            description: description
        )
        
        let focusInfo = FocusInfo(
            app: appName,
            bundleId: bundleId,
            processId: Int(pid),
            element: elementInfo
        )
        
        logger.debug("Found focused element: \(focusInfo.humanDescription)")
        return focusInfo
    }
    
    @MainActor
    private func mapSpecialKeyToVirtualCode(_ key: SpecialKey) -> CGKeyCode {
        switch key {
        case .return: return 0x24
        case .tab: return 0x30
        case .escape: return 0x35
        case .delete: return 0x33
        case .space: return 0x31
        case .leftArrow: return 0x7B
        case .rightArrow: return 0x7C
        case .upArrow: return 0x7E
        case .downArrow: return 0x7D
        case .pageUp: return 0x74
        case .pageDown: return 0x79
        case .home: return 0x73
        case .end: return 0x77
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
    private func performClick(at point: CGPoint, clickType: ClickType) async throws {
        // Use CoreGraphics events for clicking
        let mouseButton = clickType.mouseButton == .right ? CGMouseButton.right : CGMouseButton.left
        let clickCount = clickType.clickCount
        
        // Move to position first
        let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: mouseButton)
        moveEvent?.post(tap: .cghidEventTap)
        
        // Small delay to ensure position is registered
        try await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000))
        
        // Perform click(s)
        for _ in 0..<clickCount {
            // Mouse down
            let downEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: mouseButton == .right ? .rightMouseDown : .leftMouseDown,
                mouseCursorPosition: point,
                mouseButton: mouseButton
            )
            downEvent?.post(tap: .cghidEventTap)
            
            // Small delay
            try await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000))
            
            // Mouse up
            let upEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: mouseButton == .right ? .rightMouseUp : .leftMouseUp,
                mouseCursorPosition: point,
                mouseButton: mouseButton
            )
            upEvent?.post(tap: .cghidEventTap)
            
            // Delay between clicks for double-click
            if clickCount > 1 {
                try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
            }
        }
    }
    
    private func findElementAtLocation(
        frame: CGRect,
        role: String
    ) async -> Element? {
        // Get element at the center of the frame
        let centerPoint = CGPoint(x: frame.midX, y: frame.midY)
        
        // Try to find element at this point using AXorcist's static method
        // We need to find which app owns this location first
        return await MainActor.run {
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
        return findMatchingElementInTree(element: element, query: query, depth: 0, visitedElements: Set())
    }
    
    @MainActor
    private func findMatchingElementInTree(element: Element, query: String, depth: Int, visitedElements: Set<Element>) -> Element? {
        // Prevent infinite recursion with depth limit
        let maxDepth = 50
        guard depth < maxDepth else {
            logger.warning("Reached maximum depth (\(maxDepth)) while searching for '\(query)'")
            return nil
        }
        
        // Prevent circular references
        var newVisitedElements = visitedElements
        guard !newVisitedElements.contains(element) else {
            logger.debug("Circular reference detected in UI tree")
            return nil
        }
        newVisitedElements.insert(element)
        
        // Check if current element matches
        if let title = element.title(), title.localizedCaseInsensitiveContains(query) {
            return element
        }
        
        if let description = element.descriptionText(), description.localizedCaseInsensitiveContains(query) {
            return element
        }
        
        if let value = element.value() as? String, value.localizedCaseInsensitiveContains(query) {
            return element
        }
        
        // Recursively search children with depth tracking
        if let children = element.children() {
            for child in children {
                if let match = findMatchingElementInTree(element: child, query: query, depth: depth + 1, visitedElements: newVisitedElements) {
                    return match
                }
            }
        }
        
        return nil
    }
    
    private func convertElementTypeToAXRole(_ type: ElementType) -> String {
        switch type {
        case .button: return "AXButton"
        case .textField: return "AXTextField"
        case .link: return "AXLink"
        case .image: return "AXImage"
        case .group: return "AXGroup"
        case .slider: return "AXSlider"
        case .checkbox: return "AXCheckBox"
        case .menu: return "AXMenu"
        case .other: return "AXUnknown"
        }
    }
    
}

// MARK: - UI Automation Errors


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
        case .button: return "AXButton"
        case .textField: return "AXTextField"
        case .link: return "AXLink"
        case .image: return "AXImage"
        case .group: return "AXGroup"
        case .slider: return "AXSlider"
        case .checkbox: return "AXCheckBox"
        case .menu: return "AXMenu"
        default: return nil
        }
    }
}