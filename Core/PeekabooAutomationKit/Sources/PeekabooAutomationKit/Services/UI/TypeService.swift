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
    private let snapshotManager: any SnapshotManagerProtocol
    private let clickService: ClickService
    private let cadenceRandom: any TypingCadenceRandomSource

    public convenience init(
        snapshotManager: (any SnapshotManagerProtocol)? = nil,
        clickService: ClickService? = nil)
    {
        self.init(
            snapshotManager: snapshotManager,
            clickService: clickService,
            randomSource: SystemTypingCadenceRandomSource())
    }

    init(
        snapshotManager: (any SnapshotManagerProtocol)? = nil,
        clickService: ClickService? = nil,
        randomSource: any TypingCadenceRandomSource)
    {
        let manager = snapshotManager ?? SnapshotManager()
        self.snapshotManager = manager
        self.clickService = clickService ?? ClickService(snapshotManager: manager)
        self.cadenceRandom = randomSource
    }

    /// Type text with optional target and settings
    @MainActor
    public func type(
        text: String,
        target: String?,
        clearExisting: Bool,
        typingDelay: Int,
        snapshotId: String?) async throws
    {
        self.logger
            .debug("Type requested - text: '\(text)', target: \(target ?? "current focus"), clear: \(clearExisting)")

        // If target specified, click on it first
        if let target {
            var elementFound = false
            var elementFrame: CGRect?
            var elementId: String?

            // Try to find element by ID first
            if let snapshotId,
               let detectionResult = try? await snapshotManager.getDetectionResult(snapshotId: snapshotId),
               let element = detectionResult.elements.findById(target)
            {
                elementFound = true
                elementFrame = element.bounds
                elementId = element.id
            }

            // If not found by ID, search by query
            if !elementFound {
                let searchResult = try await findAndClickElement(query: target, snapshotId: snapshotId)
                elementFound = searchResult.found
                elementFrame = searchResult.frame
            }

            if elementFound {
                if let elementId {
                    try await self.clickService.click(
                        target: .elementId(elementId),
                        clickType: .single,
                        snapshotId: snapshotId)
                } else if let frame = elementFrame {
                    let center = CGPoint(x: frame.midX, y: frame.midY)
                    let adjusted = try await self.resolveAdjustedPoint(center, snapshotId: snapshotId)
                    try await self.clickService.click(
                        target: .coordinates(adjusted),
                        clickType: .single,
                        snapshotId: snapshotId)
                }

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
    public func typeActions(
        _ actions: [TypeAction],
        cadence: TypingCadence,
        snapshotId: String?) async throws -> TypeResult
    {
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
    private func findAndClickElement(query: String, snapshotId: String?) async throws -> (found: Bool, frame: CGRect?) {
        // Search in snapshot first
        if let snapshotId,
           let detectionResult = try? await snapshotManager.getDetectionResult(snapshotId: snapshotId)
        {
            if let match = Self.resolveTargetElement(query: query, in: detectionResult) {
                return (true, match.bounds)
            }
        }

        // Fall back to AX search
        if let element = findTextFieldByQuery(query) {
            return (true, element.frame())
        }

        return (false, nil)
    }

    private func resolveAdjustedPoint(_ point: CGPoint, snapshotId: String?) async throws -> CGPoint {
        guard let snapshotId,
              let snapshot = try? await self.snapshotManager.getUIAutomationSnapshot(snapshotId: snapshotId)
        else {
            return point
        }

        switch WindowMovementTracking.adjustPoint(point, snapshot: snapshot) {
        case let .unchanged(original):
            return original
        case let .adjusted(adjusted, _):
            return adjusted
        case let .stale(message):
            throw PeekabooError.snapshotStale(message)
        }
    }

    @MainActor
    static func resolveTargetElement(query: String, in detectionResult: ElementDetectionResult) -> DetectedElement? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let queryLower = trimmed.lowercased()
        guard !queryLower.isEmpty else { return nil }

        var bestMatch: DetectedElement?
        var bestScore = Int.min

        for element in detectionResult.elements.all where element.isEnabled {
            let label = element.label?.lowercased()
            let value = element.value?.lowercased()
            let identifier = element.attributes["identifier"]?.lowercased()
            let description = element.attributes["description"]?.lowercased()
            let placeholder = element.attributes["placeholder"]?.lowercased()

            let candidates = [label, value, identifier, description, placeholder].compactMap(\.self)
            guard candidates.contains(where: { $0.contains(queryLower) }) else { continue }

            var score = 0
            if identifier == queryLower { score += 400 }
            if label == queryLower { score += 300 }
            if value == queryLower { score += 200 }

            if identifier?.contains(queryLower) == true { score += 200 }
            if label?.contains(queryLower) == true { score += 150 }
            if value?.contains(queryLower) == true { score += 100 }
            if description?.contains(queryLower) == true { score += 60 }
            if placeholder?.contains(queryLower) == true { score += 40 }

            if element.type == .textField { score += 25 }

            if score > bestScore {
                bestScore = score
                bestMatch = element
            } else if score == bestScore, let currentBest = bestMatch {
                // Deterministic tie-break: prefer lower (smaller y) matches.
                // This helps when SwiftUI reports multiple nodes with the same identifier.
                if element.bounds.origin.y < currentBest.bounds.origin.y {
                    bestMatch = element
                }
            }
        }

        return bestMatch
    }

    @MainActor
    private func findTextFieldByQuery(_ query: String) -> Element? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXApp(frontApp).element

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

        try InputDriver.hotkey(keys: ["cmd", "a"])
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        try InputDriver.tapKey(.delete)
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
        try InputDriver.type(String(char), delayPerCharacter: 0)
    }

    private func typeSpecialKey(_ key: String) async throws {
        guard let hotkey = self.mapSpecialKey(key) else {
            throw PeekabooError.invalidInput("Unknown special key: '\(key)'")
        }
        try InputDriver.hotkey(keys: [hotkey])
    }

    private func mapSpecialKey(_ key: String) -> String? {
        let normalized = key.lowercased()
        let mapping: [String: String] = [
            "return": "return",
            "enter": "return",
            "escape": "escape",
            "esc": "escape",
            "tab": "tab",
            "space": "space",
            "spacebar": "space",
            "delete": "delete",
            "backspace": "delete",
            "forwarddelete": "forwarddelete",
            "up": "up",
            "down": "down",
            "left": "left",
            "right": "right",
            "pageup": "pageup",
            "pagedown": "pagedown",
            "home": "home",
            "end": "end",
            "f1": "f1",
            "f2": "f2",
            "f3": "f3",
            "f4": "f4",
            "f5": "f5",
            "f6": "f6",
            "f7": "f7",
            "f8": "f8",
            "f9": "f9",
            "f10": "f10",
            "f11": "f11",
            "f12": "f12",
        ]
        return mapping[normalized]
    }
}

extension TypingCadence {
    fileprivate var logDescription: String {
        switch self {
        case let .fixed(milliseconds):
            "fixed(\(milliseconds)ms)"
        case let .human(wordsPerMinute):
            "human(\(wordsPerMinute) WPM)"
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

extension Character {
    fileprivate var isPunctuationLike: Bool {
        self.unicodeScalars.allSatisfy { CharacterSet.punctuationCharacters.contains($0) }
    }

    fileprivate var isWordCharacter: Bool {
        self.isLetter || self.isNumber
    }

    fileprivate var isWhitespaceLike: Bool {
        self.isWhitespace || self == "\n" || self == "\t"
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
