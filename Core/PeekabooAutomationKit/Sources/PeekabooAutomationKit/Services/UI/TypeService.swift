@preconcurrency import AXorcist
import CoreGraphics
import Foundation
import os.log
import PeekabooFoundation

/// Service for handling typing and text input operations
@MainActor
public final class TypeService {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "TypeService")
    let snapshotManager: any SnapshotManagerProtocol
    private let clickService: ClickService
    let cadenceRandom: any TypingCadenceRandomSource

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
                try self.typeSpecialKey(key)
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

    // MARK: - Input Helpers

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

    private func typeCharacter(_ char: Character) async throws {
        try InputDriver.type(String(char), delayPerCharacter: 0)
    }
}
