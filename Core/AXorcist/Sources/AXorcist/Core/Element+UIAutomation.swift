import AppKit
import ApplicationServices

// MARK: - Mouse Button Types

public enum MouseButton: String, Sendable {
    case left
    case right
    case middle
}

// MARK: - Click Operations

public extension Element {

    /// Click on this element
    @MainActor func click(button: MouseButton = .left, clickCount: Int = 1) throws {
        // Ensure element is actionable
        guard isEnabled() ?? true else {
            throw UIAutomationError.elementNotEnabled
        }

        // Get element center
        guard let frame = frame() else {
            throw UIAutomationError.missingFrame
        }

        let center = CGPoint(x: frame.midX, y: frame.midY)

        // Perform click at center
        try Element.clickAt(center, button: button, clickCount: clickCount)
    }

    /// Click at a specific point on screen
    @MainActor static func clickAt(_ point: CGPoint, button: MouseButton = .left, clickCount: Int = 1) throws {
        // Create mouse down event
        guard let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: button == .left ? .leftMouseDown : .rightMouseDown,
            mouseCursorPosition: point,
            mouseButton: button == .left ? .left : .right
        ) else {
            throw UIAutomationError.failedToCreateEvent
        }

        // Set click count
        mouseDown.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))

        // Create mouse up event
        guard let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: button == .left ? .leftMouseUp : .rightMouseUp,
            mouseCursorPosition: point,
            mouseButton: button == .left ? .left : .right
        ) else {
            throw UIAutomationError.failedToCreateEvent
        }

        // Set click count
        mouseUp.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))

        // Post events
        mouseDown.post(tap: .cghidEventTap)

        // Small delay between down and up
        Thread.sleep(forTimeInterval: 0.01)

        mouseUp.post(tap: .cghidEventTap)

        // Note: clickCount=2 events are automatically handled by the system
        // No need to post additional events for double clicks
    }

    /// Wait for this element to become actionable
    @MainActor func waitUntilActionable(
        timeout: TimeInterval = 5.0,
        pollInterval: TimeInterval = 0.1) async throws -> Element
    {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            // Check if element is actionable
            if isActionable() {
                return self
            }

            // Wait before next check
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }

        throw UIAutomationError.elementNotActionable(timeout: timeout)
    }

    /// Check if element is actionable (enabled, visible, on screen)
    @MainActor func isActionable() -> Bool {
        // Must be enabled
        guard isEnabled() ?? true else { return false }

        // Must have a frame
        guard let frame = frame() else { return false }

        // Must be on screen
        guard frame.width > 0 && frame.height > 0 else { return false }

        // Check if on any screen
        return NSScreen.screens.contains { screen in
            screen.frame.intersects(frame)
        }
    }
}

// MARK: - Keyboard Operations

public extension Element {

    /// Type text into this element
    @MainActor func typeText(_ text: String, delay: TimeInterval = 0.005, clearFirst: Bool = false) throws {
        // Focus the element first
        if attribute(Attribute<Bool>.focused) != true {
            // Try to focus the element
            _ = setValue(true, forAttribute: Attribute<Bool>.focused.rawValue)
            // Some elements can't be focused directly, that's OK
        }

        // Clear existing text if requested
        if clearFirst {
            try clearField()
        }

        // Type the text
        try Element.typeText(text, delay: delay)
    }

    /// Clear the text field
    @MainActor func clearField() throws {
        // Select all with Cmd+A
        try Element.performHotkey(keys: ["cmd", "a"])
        Thread.sleep(forTimeInterval: 0.05)

        // Delete
        try Element.typeKey(.delete)
    }

    /// Type text at current focus
    @MainActor static func typeText(_ text: String, delay: TimeInterval = 0.005) throws {
        for character in text {
            if character == "\n" {
                try typeKey(.return)
            } else if character == "\t" {
                try typeKey(.tab)
            } else {
                try typeCharacter(character)
            }

            if delay > 0 {
                Thread.sleep(forTimeInterval: delay)
            }
        }
    }

    /// Type a single character
    @MainActor static func typeCharacter(_ character: Character) throws {
        let string = String(character)

        // Create keyboard event
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
            throw UIAutomationError.failedToCreateEvent
        }

        // Set the character
        let chars = Array(string.utf16)
        chars.withUnsafeBufferPointer { buffer in
            keyDown.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: buffer.baseAddress!)
        }

        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
            throw UIAutomationError.failedToCreateEvent
        }
        chars.withUnsafeBufferPointer { buffer in
            keyUp.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: buffer.baseAddress!)
        }

        // Post events
        keyDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.001)
        keyUp.post(tap: .cghidEventTap)
    }

    /// Type a special key
    @MainActor static func typeKey(_ key: SpecialKey, modifiers: CGEventFlags = []) throws {
        guard let keyCode = key.keyCode else {
            throw UIAutomationError.unsupportedKey(key.rawValue)
        }

        // Create key down event
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            throw UIAutomationError.failedToCreateEvent
        }
        keyDown.flags = modifiers

        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw UIAutomationError.failedToCreateEvent
        }
        keyUp.flags = modifiers

        // Post events
        keyDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.001)
        keyUp.post(tap: .cghidEventTap)
    }

    /// Perform a hotkey combination
    @MainActor static func performHotkey(keys: [String], holdDuration: TimeInterval = 0.1) throws {
        var modifiers: CGEventFlags = []
        var mainKey: SpecialKey?

        // Parse keys
        for key in keys {
            switch key.lowercased() {
            case "cmd", "command":
                modifiers.insert(.maskCommand)
            case "shift":
                modifiers.insert(.maskShift)
            case "option", "opt", "alt":
                modifiers.insert(.maskAlternate)
            case "ctrl", "control":
                modifiers.insert(.maskControl)
            case "fn", "function":
                modifiers.insert(.maskSecondaryFn)
            default:
                // Try to parse as special key
                if let special = SpecialKey(rawValue: key.lowercased()) {
                    mainKey = special
                } else if key.count == 1 {
                    // Single character key
                    let char = key.lowercased().first!
                    mainKey = SpecialKey(character: char)
                }
            }
        }

        // Must have a main key
        guard let key = mainKey else {
            throw UIAutomationError.invalidHotkey(keys.joined(separator: "+"))
        }

        // Type the key with modifiers
        try typeKey(key, modifiers: modifiers)

        // Hold for specified duration
        Thread.sleep(forTimeInterval: holdDuration)
    }
}

// MARK: - Special Keys

public enum SpecialKey: String {
    case escape
    case tab
    case space
    case delete
    case forwardDelete = "forwarddelete"
    case `return`
    case enter
    case up
    case down
    case left
    case right
    case pageUp = "pageup"
    case pageDown = "pagedown"
    case home
    case end
    case f1
    case f2
    case f3
    case f4
    case f5
    case f6
    case f7
    case f8
    case f9
    case f10
    case f11
    case f12

    // Single character keys
    case a
    case b
    case c
    case d
    case e
    case f
    case g
    case h
    case i
    case j
    case k
    case l
    case m
    case n
    case o
    case p
    case q
    case r
    case s
    case t
    case u
    case v
    case w
    case x
    case y
    case z

    init?(character: Character) {
        if let special = SpecialKey(rawValue: String(character).lowercased()) {
            self = special
        } else {
            return nil
        }
    }

    var keyCode: CGKeyCode? {
        switch self {
        case .escape: return 53
        case .tab: return 48
        case .space: return 49
        case .delete: return 51
        case .forwardDelete: return 117
        case .return, .enter: return 36
        case .up: return 126
        case .down: return 125
        case .left: return 123
        case .right: return 124
        case .pageUp: return 116
        case .pageDown: return 121
        case .home: return 115
        case .end: return 119
        case .f1: return 122
        case .f2: return 120
        case .f3: return 99
        case .f4: return 118
        case .f5: return 96
        case .f6: return 97
        case .f7: return 98
        case .f8: return 100
        case .f9: return 101
        case .f10: return 109
        case .f11: return 103
        case .f12: return 111
        case .a: return 0
        case .b: return 11
        case .c: return 8
        case .d: return 2
        case .e: return 14
        case .f: return 3
        case .g: return 5
        case .h: return 4
        case .i: return 34
        case .j: return 38
        case .k: return 40
        case .l: return 37
        case .m: return 46
        case .n: return 45
        case .o: return 31
        case .p: return 35
        case .q: return 12
        case .r: return 15
        case .s: return 1
        case .t: return 17
        case .u: return 32
        case .v: return 9
        case .w: return 13
        case .x: return 7
        case .y: return 16
        case .z: return 6
        }
    }
}

// MARK: - Scroll Operations

public enum ScrollDirection: String, Sendable {
    case up
    case down
    case left
    case right
}

public extension Element {

    /// Scroll this element in a specific direction
    @MainActor func scroll(direction: ScrollDirection, amount: Int = 3, smooth: Bool = false) throws {
        // Get element bounds for scroll location
        guard let frame = frame() else {
            throw UIAutomationError.missingFrame
        }

        let center = CGPoint(x: frame.midX, y: frame.midY)

        // Perform scroll at element center
        try Element.scrollAt(center, direction: direction, amount: amount, smooth: smooth)
    }

    /// Scroll at a specific point
    @MainActor static func scrollAt(
        _ point: CGPoint,
        direction: ScrollDirection,
        amount: Int = 3,
        smooth: Bool = false) throws
    {
        let scrollAmount = smooth ? 1 : amount
        let iterations = smooth ? amount : 1
        let delay = smooth ? 0.01 : 0.05

        for _ in 0..<iterations {
            // Create scroll event
            guard let scrollEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 2,
                wheel1: direction == .up || direction == .down ? Int32(scrollAmount) : 0,
                wheel2: direction == .left || direction == .right ? Int32(scrollAmount) : 0,
                wheel3: 0
            ) else {
                throw UIAutomationError.failedToCreateEvent
            }

            // Set scroll direction
            switch direction {
            case .up:
                scrollEvent.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(scrollAmount))
            case .down:
                scrollEvent.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -Int64(scrollAmount))
            case .left:
                scrollEvent.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(scrollAmount))
            case .right:
                scrollEvent.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -Int64(scrollAmount))
            }

            // Set location
            scrollEvent.location = point

            // Post event
            scrollEvent.post(tap: .cghidEventTap)

            // Delay between scrolls
            if iterations > 1 {
                Thread.sleep(forTimeInterval: delay)
            }
        }
    }
}

// MARK: - Element Finding

public extension Element {

    /// Find element at a specific screen location
    @MainActor static func elementAt(_ point: CGPoint, role: String? = nil) -> Element? {
        // Get element at point
        let element = Element.elementAtPoint(point)

        // If role specified, check if matches
        if let role = role, let found = element {
            if found.role() != role {
                // Try to find parent with matching role
                var current: Element? = found
                while let parent = current?.parent() {
                    if parent.role() == role {
                        return parent
                    }
                    current = parent
                }
                return nil
            }
        }

        return element
    }

    /// Find elements matching specific criteria
    @MainActor func findElements(
        role: String? = nil,
        title: String? = nil,
        label: String? = nil,
        value: String? = nil,
        identifier: String? = nil,
        maxDepth: Int = 10
    ) -> [Element] {
        var results: [Element] = []

        // Check self
        if matchesCriteria(role: role, title: title, label: label, value: value, identifier: identifier) {
            results.append(self)
        }

        // Check children recursively
        if maxDepth > 0 {
            if let children = children() {
                for child in children {
                    results.append(contentsOf: child.findElements(
                        role: role,
                        title: title,
                        label: label,
                        value: value,
                        identifier: identifier,
                        maxDepth: maxDepth - 1
                    ))
                }
            }
        }

        return results
    }

    /// Check if element matches criteria
    @MainActor private func matchesCriteria(
        role: String? = nil,
        title: String? = nil,
        label: String? = nil,
        value: String? = nil,
        identifier: String? = nil
    ) -> Bool {
        // Check role
        if let role = role, self.role() != role {
            return false
        }

        // Check title
        if let title = title, self.title() != title {
            return false
        }

        // Check label (using description as label)
        if let label = label, self.descriptionText() != label {
            return false
        }

        // Check value
        if let value = value, self.value() as? String != value {
            return false
        }

        // Check identifier
        if let identifier = identifier, self.identifier() != identifier {
            return false
        }

        return true
    }
}

// MARK: - UI Automation Errors

public enum UIAutomationError: Error, LocalizedError {
    case failedToCreateEvent
    case elementNotEnabled
    case elementNotActionable(timeout: TimeInterval)
    case unsupportedKey(String)
    case invalidHotkey(String)
    case missingFrame

    public var errorDescription: String? {
        switch self {
        case .failedToCreateEvent:
            return "Failed to create system event"
        case .elementNotEnabled:
            return "Element is not enabled"
        case .elementNotActionable(let timeout):
            return "Element did not become actionable within \(timeout) seconds"
        case .unsupportedKey(let key):
            return "Unsupported key: \(key)"
        case .invalidHotkey(let keys):
            return "Invalid hotkey combination: \(keys)"
        case .missingFrame:
            return "Element has no frame attribute"
        }
    }
}
