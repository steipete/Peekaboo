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
        await MainActor.run {
            do {
                switch target {
                case .elementId(let id):
                    // Get element from session
                    if let sessionId = sessionId,
                        let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId),
                        let element = detectionResult.elements.findById(id) {
                        // Click at element center
                        let center = CGPoint(x: element.bounds.midX, y: element.bounds.midY)
                        try Element.clickAt(center, button: clickType.mouseButton, clickCount: clickType.clickCount)
                    } else {
                        throw UIAutomationError.elementNotFound(id)
                    }
                    
                case .coordinates(let point):
                    // Direct coordinate click
                    try Element.clickAt(point, button: clickType.mouseButton, clickCount: clickType.clickCount)
                    
                case .query(let query):
                    // Find element by text/label and click
                    if let element = findElementByQuery(query) {
                        try element.click(button: clickType.mouseButton, clickCount: clickType.clickCount)
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
        await MainActor.run {
            do {
                // If target specified, find and focus element first
                if let target = target {
                    if let element = findElementByIdOrQuery(target, sessionId: sessionId) {
                        try element.typeText(text, delay: TimeInterval(typingDelay) / 1000.0, clearFirst: clearExisting)
                    } else {
                        throw UIAutomationError.elementNotFound(target)
                    }
                } else {
                    // Type at current focus
                    if clearExisting {
                        // Clear current field
                        try Element.performHotkey(keys: ["cmd", "a"])
                        Thread.sleep(forTimeInterval: 0.05)
                        try Element.typeKey(.delete)
                        Thread.sleep(forTimeInterval: 0.05)
                    }
                    
                    try Element.typeText(text, delay: TimeInterval(typingDelay) / 1000.0)
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
        await MainActor.run {
            do {
                if let target = target {
                    // Scroll on specific element
                    if let element = findElementByIdOrQuery(target, sessionId: sessionId) {
                        try element.scroll(direction: direction.axorcistDirection, amount: amount, smooth: smooth)
                    } else {
                        throw UIAutomationError.elementNotFound(target)
                    }
                } else {
                    // Scroll at current mouse position
                    let mouseLocation = NSEvent.mouseLocation
                    // Convert from NSScreen coordinates to Core Graphics coordinates
                    let screenHeight = NSScreen.main?.frame.height ?? 0
                    let cgPoint = CGPoint(x: mouseLocation.x, y: screenHeight - mouseLocation.y)
                    
                    try Element.scrollAt(cgPoint, direction: direction.axorcistDirection, amount: amount, smooth: smooth)
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
        await MainActor.run {
            do {
                // Parse comma-separated keys
                let keyArray = keys.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                
                try Element.performHotkey(keys: keyArray, holdDuration: TimeInterval(holdDuration) / 1000.0)
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
    
    // MARK: - Private Helpers
    
    @MainActor
    private func findElementByQuery(_ query: String) -> Element? {
        // Get system-wide element
        guard let systemWide = Element.systemWide() else { return nil }
        
        // Search for elements with matching text
        let elements = systemWide.findElements(
            title: query,
            maxDepth: 10
        )
        
        if !elements.isEmpty {
            return elements.first
        }
        
        // Try label
        let labelElements = systemWide.findElements(
            label: query,
            maxDepth: 10
        )
        
        if !labelElements.isEmpty {
            return labelElements.first
        }
        
        // Try value
        let valueElements = systemWide.findElements(
            value: query,
            maxDepth: 10
        )
        
        return valueElements.first
    }
    
    @MainActor
    private func findElementByIdOrQuery(_ target: String, sessionId: String?) -> Element? {
        // First try as element ID from session
        if let sessionId = sessionId,
           let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId),
           let element = detectionResult.elements.findById(target) {
            // Convert to actual element at coordinates
            let center = CGPoint(x: element.bounds.midX, y: element.bounds.midY)
            return Element.elementAt(center, role: element.type.axRole)
        }
        
        // Otherwise try as query
        return findElementByQuery(target)
    }
}

// MARK: - UI Automation Errors

public enum UIAutomationError: LocalizedError {
    case elementNotFound(String)
    case elementNotFoundByQuery(String)
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

extension ScrollDirection {
    var axorcistDirection: AXorcist.ScrollDirection {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        }
    }
}

extension ClickType {
    var mouseButton: MouseButton {
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