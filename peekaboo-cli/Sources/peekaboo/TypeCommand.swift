import ArgumentParser
import AXorcist
import CoreGraphics
import Foundation

/// Types text into focused elements or sends keyboard input.
/// Supports both text input and special key combinations.
@available(macOS 14.0, *)
struct TypeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "type",
        abstract: "Type text or send keyboard input",
        discussion: """
            The 'type' command sends keyboard input to the focused element.
            It can type regular text or send special key combinations.

            EXAMPLES:
              peekaboo type "Hello World"           # Type text
              peekaboo type "user@example.com"      # Type email
              peekaboo type --delay 100             # Type with 100ms between keys
              peekaboo type "password" --return     # Type and press return
              peekaboo type --tab 3                 # Press tab 3 times
              peekaboo type "text" --clear          # Clear field first

            SPECIAL KEYS:
              Use flags for special keys:
              --return    Press return/enter
              --tab       Press tab (with optional count)
              --escape    Press escape
              --delete    Press delete
              --clear     Clear current field (Cmd+A, Delete)

            FOCUS MANAGEMENT:
              The command assumes an element is already focused.
              Use 'click' to focus an input field first.
        """
    )

    @Argument(help: "Text to type")
    var text: String?

    @Option(help: "Session ID (uses latest if not specified)")
    var session: String?

    @Option(help: "Delay between keystrokes in milliseconds")
    var delay: Int = 50

    @Flag(help: "Press return/enter after typing")
    var `return` = false

    @Option(help: "Press tab N times")
    var tab: Int?

    @Flag(help: "Press escape")
    var escape = false

    @Flag(help: "Press delete/backspace")
    var delete = false

    @Flag(help: "Clear the field before typing (Cmd+A, Delete)")
    var clear = false

    @Flag(help: "Output in JSON format")
    var jsonOutput = false

    mutating func run() async throws {
        let startTime = Date()

        do {
            var actions: [TypeAction] = []

            // Build action sequence
            if clear {
                actions.append(.clear)
            }

            if let textToType = text {
                actions.append(.text(textToType))
            }

            if let tabCount = tab {
                for _ in 0..<tabCount {
                    actions.append(.key(.tab))
                }
            }

            if escape {
                actions.append(.key(.escape))
            }

            if delete {
                actions.append(.key(.delete))
            }

            if `return` {
                actions.append(.key(.return))
            }

            // Validate we have something to do
            guard !actions.isEmpty else {
                throw ValidationError("No input specified. Provide text or key flags.")
            }

            // Execute type actions
            let typeResult = try await performTypeActions(
                actions: actions,
                delayMs: delay
            )

            // Output results
            if jsonOutput {
                let output = TypeResult(
                    success: true,
                    typedText: text,
                    keyPresses: typeResult.keyPresses,
                    totalCharacters: typeResult.totalCharacters,
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output)
            } else {
                print("✅ Typing completed")
                if let typed = text {
                    print("⌨️  Typed: \"\(typed)\"")
                }
                if typeResult.keyPresses > 0 {
                    print("🔑 Special keys: \(typeResult.keyPresses)")
                }
                print("📊 Total characters: \(typeResult.totalCharacters)")
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            if jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .INTERNAL_SWIFT_ERROR
                )
            } else {
                var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
                print("Error: \(error.localizedDescription)", to: &localStandardErrorStream)
            }
            throw ExitCode.failure
        }
    }

    private func performTypeActions(actions: [TypeAction], delayMs: Int) async throws -> InternalTypeResult {
        var totalChars = 0
        var keyPresses = 0

        for action in actions {
            switch action {
            case let .text(string):
                // Type the string using CoreGraphics events
                let delaySeconds = Double(delayMs) / 1000.0
                try InputEvents.typeString(string, delay: delaySeconds)
                totalChars += string.count

            case let .key(key):
                // Type special key
                let specialKey = key.toInputEventKey()
                try InputEvents.pressKey(specialKey)
                keyPresses += 1

                if delayMs > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                }

            case .clear:
                // Clear field by selecting all (Cmd+A) and deleting
                try InputEvents.performHotkey(keys: ["cmd", "a"])
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                try InputEvents.pressKey(.delete)
                keyPresses += 2

                if delayMs > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                }
            }
        }

        return InternalTypeResult(
            totalCharacters: totalChars,
            keyPresses: keyPresses
        )
    }

    private func typeSpecialKey(_ key: SpecialKey) async throws {
        // TODO: Implement special key handling using AXorcist
        // For now, this is a placeholder
    }
}

// MARK: - Supporting Types

private enum TypeAction {
    case text(String)
    case key(SpecialKey)
    case clear
}

private enum SpecialKey {
    case `return`
    case tab
    case escape
    case delete

    func toInputEventKey() -> InputEvents.SpecialKey {
        switch self {
        case .return: .return
        case .tab: .tab
        case .escape: .escape
        case .delete: .delete
        }
    }
}

private struct InternalTypeResult {
    let totalCharacters: Int
    let keyPresses: Int
}

// MARK: - JSON Output Structure

struct TypeResult: Codable {
    let success: Bool
    let typedText: String?
    let keyPresses: Int
    let totalCharacters: Int
    let executionTime: TimeInterval
}

// MARK: - AXorcist Extensions

// TODO: These extensions need to be implemented in AXorcist
/*
 extension AXorcist {
     /// Type a single character
     func typeCharacter(_ char: Character) async throws {
         let string = String(char)
         try await self.typeString(string)
     }

     /// Press a key with optional modifiers
     func keyPress(_ key: KeyCode, modifiers: CGEventFlags = []) async throws {
         let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: key.rawValue, keyDown: true)
         let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: key.rawValue, keyDown: false)

         keyDown?.flags = modifiers
         keyUp?.flags = modifiers

         keyDown?.post(tap: .cghidEventTap)
         keyUp?.post(tap: .cghidEventTap)
     }
 }

 // Key codes for common keys
 private enum KeyCode: UInt16 {
     case a = 0x00
     case delete = 0x33
     case tab = 0x30
     case `return` = 0x24
     case escape = 0x35
 }
 */
