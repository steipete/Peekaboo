@preconcurrency import ArgumentParser
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Press individual keys or key sequences
@available(macOS 14.0, *)
@MainActor
struct PressCommand: @MainActor MainActorAsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "press",
        abstract: "Press individual keys or key sequences",
        discussion: """
            The 'press' command sends individual key presses or sequences.
            It's designed for special keys and navigation, not for typing text.

            EXAMPLES:
              peekaboo press return                # Press Enter/Return
              peekaboo press tab --count 3         # Press Tab 3 times
              peekaboo press escape                # Press Escape
              peekaboo press delete                # Press Backspace/Delete
              peekaboo press forward_delete        # Press Forward Delete (fn+delete)
              peekaboo press up down left right    # Arrow key sequence
              peekaboo press f1                    # Press F1 function key
              peekaboo press space                 # Press spacebar
              peekaboo press enter                 # Numeric keypad Enter

            AVAILABLE KEYS:
              Navigation: up, down, left, right, home, end, pageup, pagedown
              Editing: delete (backspace), forward_delete, clear
              Control: return, enter, tab, escape, space
              Function: f1-f12
              Special: caps_lock, help

            KEY SEQUENCES:
              Multiple keys can be pressed in sequence with optional delay:
              peekaboo press tab tab return        # Tab twice then Enter
              peekaboo press down down return      # Navigate down and select

            TIMING:
              Use --delay to control timing between key presses (default: 100ms)
              Use --hold to control how long each key is held (default: 50ms)
        """
    )

    @Argument(help: "Key(s) to press")
    var keys: [String]

    @Option(help: "Repeat count for all keys")
    var count: Int = 1

    @Option(help: "Delay between key presses in milliseconds")
    var delay: Int = 100

    @Option(help: "Hold duration for each key in milliseconds")
    var hold: Int = 50

    @Option(help: "Session ID (uses latest if not specified)")
    var session: String?

    @Flag(help: "Output in JSON format")
    var jsonOutput = false

    @OptionGroup var focusOptions: FocusCommandOptions

    mutating func run() async throws {
        let startTime = Date()
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            // Get session if available
            let sessionId: String? = if let providedSession = session {
                providedSession
            } else {
                await PeekabooServices.shared.sessions.getMostRecentSession()
            }

            // Ensure window is focused before pressing keys
            if let sessionId {
                try await self.ensureFocused(
                    sessionId: sessionId,
                    options: self.focusOptions
                )
            }

            // Build actions - repeat each key sequence 'count' times
            var actions: [TypeAction] = []
            for _ in 0..<self.count {
                for (index, key) in self.keys.enumerated() {
                    if let specialKey = SpecialKey(rawValue: key.lowercased()) {
                        actions.append(.key(specialKey))
                    }

                    // Add delay between keys (but not after the last key of the last repetition)
                    let isLastKey = index == self.keys.count - 1
                    let isLastRepetition = self.count == 1
                    if !isLastKey || !isLastRepetition {
                        // We'll handle the delay in the service
                    }
                }
            }

            // Execute key presses
            let result = try await PeekabooServices.shared.automation.typeActions(
                actions,
                typingDelay: self.delay,
                sessionId: sessionId
            )

            // Output results
            let pressResult = PressResult(
                success: true,
                keys: keys,
                totalPresses: result.keyPresses,
                count: self.count,
                executionTime: Date().timeIntervalSince(startTime)
            )

            output(pressResult) {
                print("✅ Key press completed")
                print("🔑 Keys: \(self.keys.joined(separator: " → "))")
                if self.count > 1 {
                    print("🔢 Repeated: \(self.count) times")
                }
                print("📊 Total presses: \(result.keyPresses)")
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            self.handleError(error)
            throw ExitCode.failure
        }
    }

    // Error handling is provided by ErrorHandlingCommand protocol

    mutating func validate() throws {
        for key in self.keys {
            guard SpecialKey(rawValue: key.lowercased()) != nil else {
                throw ArgumentParser
                    .ValidationError("Unknown key: '\(key)'. Run 'peekaboo press --help' for available keys.")
            }
        }
    }
}

// MARK: - JSON Output Structure

struct PressResult: Codable {
    let success: Bool
    let keys: [String]
    let totalPresses: Int
    let count: Int
    let executionTime: TimeInterval
}
