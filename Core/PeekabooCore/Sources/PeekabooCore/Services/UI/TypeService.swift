import Foundation
import CoreGraphics
@preconcurrency import AXorcist
import AppKit
import os.log

/// Service for handling typing and text input operations
@MainActor
public final class TypeService: Sendable {
    
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "TypeService")
    private let sessionManager: SessionManagerProtocol
    private let clickService: ClickService
    
    public init(sessionManager: SessionManagerProtocol? = nil, clickService: ClickService? = nil) {
        let manager = sessionManager ?? SessionManager()
        self.sessionManager = manager
        self.clickService = clickService ?? ClickService(sessionManager: manager)
    }
    
    /// Type text with optional target and settings
    @MainActor
    public func type(text: String, target: String?, clearExisting: Bool, typingDelay: Int, sessionId: String?) async throws {
        logger.debug("Type requested - text: '\(text)', target: \(target ?? "current focus"), clear: \(clearExisting)")
        
        // If target specified, click on it first
        if let target = target {
            var elementFound = false
            var elementFrame: CGRect?
            
            // Try to find element by ID first
            if let sessionId = sessionId,
               let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId),
               let element = detectionResult.elements.findById(target) {
                elementFound = true
                elementFrame = element.bounds
            }
            
            // If not found by ID, search by query
            if !elementFound {
                let searchResult = try await findAndClickElement(query: target, sessionId: sessionId)
                elementFound = searchResult.found
                elementFrame = searchResult.frame
            }
            
            if elementFound, let frame = elementFrame {
                // Click on the element to focus it
                let center = CGPoint(x: frame.midX, y: frame.midY)
                try await clickService.click(target: .coordinates(center), clickType: .single, sessionId: sessionId)
                
                // Small delay after click
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            } else {
                throw NotFoundError.element(target)
            }
        }
        
        // Clear existing text if requested
        if clearExisting {
            try await clearCurrentField()
        }
        
        // Type the text
        try await typeTextWithDelay(text, delay: TimeInterval(typingDelay) / 1000.0)
        
        logger.debug("Successfully typed \(text.count) characters")
    }
    
    /// Type actions (advanced typing with special keys)
    public func typeActions(_ actions: [TypeAction], typingDelay: Int, sessionId: String?) async throws -> TypeResult {
        var totalChars = 0
        var keyPresses = 0
        
        logger.debug("Processing \(actions.count) type actions")
        
        for action in actions {
            switch action {
            case .text(let text):
                let delaySeconds = Double(typingDelay) / 1000.0
                try await typeTextWithDelay(text, delay: delaySeconds)
                totalChars += text.count
                keyPresses += text.count
                
            case .key(let key):
                try await typeSpecialKey(key.rawValue)
                keyPresses += 1
                
            case .clear:
                try await clearCurrentField()
                keyPresses += 2 // Cmd+A and Delete
            }
        }
        
        return TypeResult(
            totalCharacters: totalChars,
            keyPresses: keyPresses
        )
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func findAndClickElement(query: String, sessionId: String?) async throws -> (found: Bool, frame: CGRect?) {
        // Search in session first
        if let sessionId = sessionId,
           let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId) {
            let queryLower = query.lowercased()
            
            for element in detectionResult.elements.all {
                let matches = element.label?.lowercased().contains(queryLower) ?? false ||
                             element.value?.lowercased().contains(queryLower) ?? false ||
                             element.type == .textField  // Prioritize text fields
                
                if matches && element.isEnabled {
                    return (true, element.bounds)
                }
            }
        }
        
        // Fall back to AX search
        if let element = findTextFieldByQuery(query) {
            return (true, element.frame())
        }
        
        return (false, nil)
    }
    
    @MainActor
    private func findTextFieldByQuery(_ query: String) -> Element? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        
        let axApp = AXUIElementCreateApplication(frontApp.processIdentifier)
        let appElement = Element(axApp)
        
        return searchTextFields(in: appElement, matching: query.lowercased())
    }
    
    @MainActor
    private func searchTextFields(in element: Element, matching query: String) -> Element? {
        let role = element.role()?.lowercased() ?? ""
        
        // Check if this is a text field
        if role.contains("textfield") || role.contains("textarea") || role.contains("searchfield") {
            let title = element.title()?.lowercased() ?? ""
            let label = element.label()?.lowercased() ?? ""
            let placeholder = element.placeholderValue()?.lowercased() ?? ""
            
            if title.contains(query) || label.contains(query) || placeholder.contains(query) {
                return element
            }
        }
        
        // Search children
        if let children = element.children() {
            for child in children {
                if let found = searchTextFields(in: child, matching: query) {
                    return found
                }
            }
        }
        
        return nil
    }
    
    private func clearCurrentField() async throws {
        logger.debug("Clearing current field")
        
        // Select all (Cmd+A)
        try await pressKey(code: kVK_ANSI_A, flags: .maskCommand)
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Delete
        try await pressKey(code: kVK_Delete, flags: [])
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }
    
    private func typeTextWithDelay(_ text: String, delay: TimeInterval) async throws {
        for char in text {
            try await typeCharacter(char)
            
            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
    
    private func typeCharacter(_ char: Character) async throws {
        let string = String(char)
        
        // Create keyboard event
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }
        
        // Set the character
        var unicodeChars = Array(string.utf16)
        keyDownEvent.keyboardSetUnicodeString(stringLength: unicodeChars.count, unicodeString: &unicodeChars)
        
        // Post key down
        keyDownEvent.post(tap: .cghidEventTap)
        
        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }
        
        keyUpEvent.keyboardSetUnicodeString(stringLength: unicodeChars.count, unicodeString: &unicodeChars)
        keyUpEvent.post(tap: .cghidEventTap)
    }
    
    private func typeSpecialKey(_ key: String) async throws {
        let virtualKey = mapSpecialKeyToVirtualCode(key)
        
        if virtualKey == 0xFFFF {
            throw PeekabooError.invalidInput("Unknown special key: '\(key)'")
        }
        
        try await pressKey(code: virtualKey, flags: [])
    }
    
    private func pressKey(code: CGKeyCode, flags: CGEventFlags) async throws {
        // Key down
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true) else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }
        keyDownEvent.flags = flags
        keyDownEvent.post(tap: .cghidEventTap)
        
        // Small delay
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Key up
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }
        keyUpEvent.flags = flags
        keyUpEvent.post(tap: .cghidEventTap)
    }
    
    private func mapSpecialKeyToVirtualCode(_ key: String) -> CGKeyCode {
        switch key.lowercased() {
        case "return", "enter":
            return CGKeyCode(kVK_Return)
        case "tab":
            return CGKeyCode(kVK_Tab)
        case "delete", "backspace":
            return CGKeyCode(kVK_Delete)
        case "escape", "esc":
            return CGKeyCode(kVK_Escape)
        case "space":
            return CGKeyCode(kVK_Space)
        case "up", "arrow_up":
            return CGKeyCode(kVK_UpArrow)
        case "down", "arrow_down":
            return CGKeyCode(kVK_DownArrow)
        case "left", "arrow_left":
            return CGKeyCode(kVK_LeftArrow)
        case "right", "arrow_right":
            return CGKeyCode(kVK_RightArrow)
        case "home":
            return CGKeyCode(kVK_Home)
        case "end":
            return CGKeyCode(kVK_End)
        case "pageup", "page_up":
            return CGKeyCode(kVK_PageUp)
        case "pagedown", "page_down":
            return CGKeyCode(kVK_PageDown)
        case "f1":
            return CGKeyCode(kVK_F1)
        case "f2":
            return CGKeyCode(kVK_F2)
        case "f3":
            return CGKeyCode(kVK_F3)
        case "f4":
            return CGKeyCode(kVK_F4)
        case "f5":
            return CGKeyCode(kVK_F5)
        case "f6":
            return CGKeyCode(kVK_F6)
        case "f7":
            return CGKeyCode(kVK_F7)
        case "f8":
            return CGKeyCode(kVK_F8)
        case "f9":
            return CGKeyCode(kVK_F9)
        case "f10":
            return CGKeyCode(kVK_F10)
        case "f11":
            return CGKeyCode(kVK_F11)
        case "f12":
            return CGKeyCode(kVK_F12)
        default:
            return 0xFFFF // Invalid
        }
    }
}

// MARK: - Key codes from Carbon

private let kVK_ANSI_A: CGKeyCode = 0x00
private let kVK_ANSI_S: CGKeyCode = 0x01
private let kVK_ANSI_D: CGKeyCode = 0x02
private let kVK_ANSI_F: CGKeyCode = 0x03
private let kVK_ANSI_H: CGKeyCode = 0x04
private let kVK_ANSI_G: CGKeyCode = 0x05
private let kVK_ANSI_Z: CGKeyCode = 0x06
private let kVK_ANSI_X: CGKeyCode = 0x07
private let kVK_ANSI_C: CGKeyCode = 0x08
private let kVK_ANSI_V: CGKeyCode = 0x09
private let kVK_ANSI_B: CGKeyCode = 0x0B
private let kVK_ANSI_Q: CGKeyCode = 0x0C
private let kVK_ANSI_W: CGKeyCode = 0x0D
private let kVK_ANSI_E: CGKeyCode = 0x0E
private let kVK_ANSI_R: CGKeyCode = 0x0F
private let kVK_ANSI_Y: CGKeyCode = 0x10
private let kVK_ANSI_T: CGKeyCode = 0x11
private let kVK_Return: CGKeyCode = 0x24
private let kVK_Tab: CGKeyCode = 0x30
private let kVK_Space: CGKeyCode = 0x31
private let kVK_Delete: CGKeyCode = 0x33
private let kVK_Escape: CGKeyCode = 0x35
private let kVK_Command: CGKeyCode = 0x37
private let kVK_Shift: CGKeyCode = 0x38
private let kVK_CapsLock: CGKeyCode = 0x39
private let kVK_Option: CGKeyCode = 0x3A
private let kVK_Control: CGKeyCode = 0x3B
private let kVK_F1: CGKeyCode = 0x7A
private let kVK_F2: CGKeyCode = 0x78
private let kVK_F3: CGKeyCode = 0x63
private let kVK_F4: CGKeyCode = 0x76
private let kVK_F5: CGKeyCode = 0x60
private let kVK_F6: CGKeyCode = 0x61
private let kVK_F7: CGKeyCode = 0x62
private let kVK_F8: CGKeyCode = 0x64
private let kVK_F9: CGKeyCode = 0x65
private let kVK_F10: CGKeyCode = 0x6D
private let kVK_F11: CGKeyCode = 0x67
private let kVK_F12: CGKeyCode = 0x6F
private let kVK_Home: CGKeyCode = 0x73
private let kVK_PageUp: CGKeyCode = 0x74
private let kVK_End: CGKeyCode = 0x77
private let kVK_PageDown: CGKeyCode = 0x79
private let kVK_LeftArrow: CGKeyCode = 0x7B
private let kVK_RightArrow: CGKeyCode = 0x7C
private let kVK_DownArrow: CGKeyCode = 0x7D
private let kVK_UpArrow: CGKeyCode = 0x7E