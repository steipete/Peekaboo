import AppKit
@preconcurrency import AXorcist
import CoreGraphics
import Foundation
import os.log
import PeekabooFoundation

/// Service for handling typing and text input operations
@MainActor
public final class TypeService {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "TypeService")
    private let sessionManager: any SessionManagerProtocol
    private let clickService: ClickService
    private let cadenceRandom: any TypingCadenceRandomSource

    public convenience init(
        sessionManager: (any SessionManagerProtocol)? = nil,
        clickService: ClickService? = nil)
    {
        self.init(
            sessionManager: sessionManager,
            clickService: clickService,
            randomSource: SystemTypingCadenceRandomSource())
    }

    init(
        sessionManager: (any SessionManagerProtocol)? = nil,
        clickService: ClickService? = nil,
        randomSource: any TypingCadenceRandomSource)
    {
        let manager = sessionManager ?? SessionManager()
        self.sessionManager = manager
        self.clickService = clickService ?? ClickService(sessionManager: manager)
        self.cadenceRandom = randomSource
    }

    /// Type text with optional target and settings
    @MainActor
    public func type(
        text: String,
        target: String?,
        clearExisting: Bool,
        typingDelay: Int,
        sessionId: String?) async throws
    {
        self.logger
            .debug("Type requested - text: '\(text)', target: \(target ?? "current focus"), clear: \(clearExisting)")

        // If target specified, click on it first
        if let target {
            var elementFound = false
            var elementFrame: CGRect?

            // Try to find element by ID first
            if let sessionId,
               let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId),
               let element = detectionResult.elements.findById(target)
            {
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
                try await self.clickService.click(
                    target: .coordinates(center),
                    clickType: .single,
                    sessionId: sessionId)

                // Small delay after click
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            } else {
                throw NotFoundError.element(target)
            }
        }

        // Clear existing text if requested
        if clearExisting {
            try await self.clearCurrentField()
        }

        // Type the text
        try await self.typeTextWithDelay(text, delay: TimeInterval(typingDelay) / 1000.0)

        self.logger.debug("Successfully typed \(text.count) characters")
    }

    /// Type actions (advanced typing with special keys)
    public func typeActions(_ actions: [TypeAction], cadence: TypingCadence, sessionId: String?) async throws -> TypeResult {
        var totalChars = 0
        var keyPresses = 0
        var humanContext: HumanTypingContext?
        let fixedDelay = self.fixedDelaySeconds(for: cadence)

        self.logger.debug("Processing \(actions.count) type actions with cadence: \(cadence.logDescription)")

        for action in actions {
            switch action {
            case let .text(text):
                for character in text {
                    try await self.typeCharacter(character)
                    totalChars += 1
                    keyPresses += 1
                    try await self.sleepAfterKeystroke(
                        typedCharacter: character,
                        cadence: cadence,
                        fixedDelaySeconds: fixedDelay,
                        humanContext: &humanContext)
                }

            case let .key(key):
                try await self.typeSpecialKey(key.rawValue)
                keyPresses += 1
                try await self.sleepAfterKeystroke(
                    typedCharacter: nil,
                    cadence: cadence,
                    fixedDelaySeconds: fixedDelay,
                    humanContext: &humanContext)

            case .clear:
                try await self.clearCurrentField()
                keyPresses += 2 // Cmd+A and Delete
                try await self.sleepAfterKeystroke(
                    typedCharacter: nil,
                    cadence: cadence,
                    fixedDelaySeconds: fixedDelay,
                    humanContext: &humanContext)
            }
        }

        return TypeResult(
            totalCharacters: totalChars,
            keyPresses: keyPresses)
    }

    // MARK: - Private Methods

    @MainActor
    private func findAndClickElement(query: String, sessionId: String?) async throws -> (found: Bool, frame: CGRect?) {
        // Search in session first
        if let sessionId,
           let detectionResult = try? await sessionManager.getDetectionResult(sessionId: sessionId)
        {
            let queryLower = query.lowercased()

            for element in detectionResult.elements.all {
                let matches = element.label?.lowercased().contains(queryLower) ?? false ||
                    element.value?.lowercased().contains(queryLower) ?? false ||
                    element.type == .textField // Prioritize text fields

                if matches, element.isEnabled {
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

        return self.searchTextFields(in: appElement, matching: query.lowercased())
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
        self.logger.debug("Clearing current field")

        // Select all (Cmd+A)
        try await self.pressKey(code: kVK_ANSI_A, flags: .maskCommand)
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Delete
        try await self.pressKey(code: kVK_Delete, flags: [])
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }

    private func typeTextWithDelay(_ text: String, delay: TimeInterval) async throws {
        for char in text {
            try await self.typeCharacter(char)

            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    private func sleepAfterKeystroke(
        typedCharacter: Character?,
        cadence: TypingCadence,
        fixedDelaySeconds: TimeInterval,
        humanContext: inout HumanTypingContext?) async throws
    {
        let delaySeconds: TimeInterval
        switch cadence {
        case .fixed:
            delaySeconds = fixedDelaySeconds
        case let .human(wordsPerMinute):
            if humanContext == nil {
                humanContext = HumanTypingContext(wordsPerMinute: wordsPerMinute, random: self.cadenceRandom)
            }
            delaySeconds = humanContext?.nextDelay(after: typedCharacter) ?? 0
        }

        guard delaySeconds > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
    }

    private func fixedDelaySeconds(for cadence: TypingCadence) -> TimeInterval {
        if case let .fixed(milliseconds) = cadence {
            return Double(max(0, milliseconds)) / 1000.0
        }
        return 0
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
        let virtualKey = self.mapSpecialKeyToVirtualCode(key)

        if virtualKey == 0xFFFF {
            throw PeekabooError.invalidInput("Unknown special key: '\(key)'")
        }

        try await self.pressKey(code: virtualKey, flags: [])
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
        SpecialKeyMapping.value(for: key)
    }
}

private extension TypingCadence {
    var logDescription: String {
        switch self {
        case let .fixed(milliseconds):
            return "fixed(\(milliseconds)ms)"
        case let .human(wordsPerMinute):
            return "human(\(wordsPerMinute) WPM)"
        }
    }
}

protocol TypingCadenceRandomSource: Sendable {
    func nextUnitInterval() -> Double
}

struct SystemTypingCadenceRandomSource: TypingCadenceRandomSource {
    func nextUnitInterval() -> Double {
        Double.random(in: Double.leastNonzeroMagnitude..<1.0)
    }
}

private struct HumanTypingContext {
    private enum Constants {
        static let logNormalSigma: Double = 0.35
        static let punctuationMultiplier: Double = 1.35
        static let digraphMultiplier: Double = 0.85
        static let thinkingWordInterval: Int = 12
        static let thinkingPauseRange: ClosedRange<Double> = 0.3...0.5
    }

    let baseDelay: TimeInterval
    let random: any TypingCadenceRandomSource
    var previousCharacter: Character?
    var charactersInCurrentWord = 0
    var wordsSincePause = 0

    init(wordsPerMinute: Int, random: any TypingCadenceRandomSource) {
        let normalizedWPM = max(wordsPerMinute, 40)
        self.baseDelay = 60.0 / (Double(normalizedWPM) * 5.0)
        self.random = random
    }

    mutating func nextDelay(after character: Character?) -> TimeInterval {
        var delay = self.sampleLogNormal()

        if let character {
            if character.isWhitespaceLike || character.isPunctuationLike {
                delay *= Constants.punctuationMultiplier
            }

            if let previous = self.previousCharacter,
               previous.isWordCharacter,
               character.isWordCharacter
            {
                delay *= Constants.digraphMultiplier
            }
        }

        delay = self.clamp(delay)

        if let pause = self.consumeWordBoundary(after: character) {
            delay += pause
        }

        self.previousCharacter = character
        return delay
    }

    private mutating func consumeWordBoundary(after character: Character?) -> TimeInterval? {
        guard let character else { return nil }

        if character.isWordCharacter {
            self.charactersInCurrentWord += 1
            return nil
        }

        if self.charactersInCurrentWord == 0 {
            return nil
        }

        self.charactersInCurrentWord = 0
        self.wordsSincePause += 1

        if self.wordsSincePause >= Constants.thinkingWordInterval {
            self.wordsSincePause = 0
            return self.randomThinkingPause()
        }

        return nil
    }

    private mutating func sampleLogNormal() -> TimeInterval {
        let sigma = Constants.logNormalSigma
        let mu = log(self.baseDelay) - 0.5 * sigma * sigma
        let gaussian = Self.generateGaussian(using: self.random)
        let value = exp(mu + sigma * gaussian)
        return max(value, self.baseDelay * 0.2)
    }

    private func clamp(_ value: TimeInterval) -> TimeInterval {
        let minValue = self.baseDelay * 0.25
        let maxValue = self.baseDelay * 3.5
        return min(max(value, minValue), maxValue)
    }

    private func randomThinkingPause() -> TimeInterval {
        let span = Constants.thinkingPauseRange.upperBound - Constants.thinkingPauseRange.lowerBound
        return Constants.thinkingPauseRange.lowerBound + span * self.random.nextUnitInterval()
    }

    private static func generateGaussian(using random: any TypingCadenceRandomSource) -> Double {
        let u1 = max(random.nextUnitInterval(), Double.leastNonzeroMagnitude)
        let u2 = random.nextUnitInterval()
        return sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
    }
}

private extension Character {
    var isPunctuationLike: Bool {
        self.unicodeScalars.allSatisfy { CharacterSet.punctuationCharacters.contains($0) }
    }

    var isWordCharacter: Bool {
        self.isLetter || self.isNumber
    }

    var isWhitespaceLike: Bool {
        self.isWhitespace || self == "\n" || self == "\t"
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
private let kVK_ForwardDelete: CGKeyCode = 0x75
private let kVK_Help: CGKeyCode = 0x72
private let kVK_ANSI_KeypadEnter: CGKeyCode = 0x4C
private let kVK_ANSI_KeypadClear: CGKeyCode = 0x47

private enum SpecialKeyMapping {
    private static let unknown: CGKeyCode = 0xFFFF

    private static let map: [String: CGKeyCode] = [
        "return": kVK_Return,
        "enter": kVK_ANSI_KeypadEnter,
        "tab": kVK_Tab,
        "delete": kVK_Delete,
        "backspace": kVK_Delete,
        "forward_delete": kVK_ForwardDelete,
        "forwarddelete": kVK_ForwardDelete,
        "escape": kVK_Escape,
        "esc": kVK_Escape,
        "space": kVK_Space,
        "up": kVK_UpArrow,
        "arrow_up": kVK_UpArrow,
        "down": kVK_DownArrow,
        "arrow_down": kVK_DownArrow,
        "left": kVK_LeftArrow,
        "arrow_left": kVK_LeftArrow,
        "right": kVK_RightArrow,
        "arrow_right": kVK_RightArrow,
        "home": kVK_Home,
        "end": kVK_End,
        "pageup": kVK_PageUp,
        "page_up": kVK_PageUp,
        "pagedown": kVK_PageDown,
        "page_down": kVK_PageDown,
        "f1": kVK_F1,
        "f2": kVK_F2,
        "f3": kVK_F3,
        "f4": kVK_F4,
        "f5": kVK_F5,
        "f6": kVK_F6,
        "f7": kVK_F7,
        "f8": kVK_F8,
        "f9": kVK_F9,
        "f10": kVK_F10,
        "f11": kVK_F11,
        "f12": kVK_F12,
        "caps_lock": kVK_CapsLock,
        "capslock": kVK_CapsLock,
        "clear": kVK_ANSI_KeypadClear,
        "help": kVK_Help,
    ]

    static func value(for key: String) -> CGKeyCode {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return self.map[normalized] ?? Self.unknown
    }
}
