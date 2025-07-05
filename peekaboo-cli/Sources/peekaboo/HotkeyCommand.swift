import ArgumentParser
import AXorcist
import CoreGraphics
import Foundation

/// Presses key combinations like Cmd+C, Ctrl+A, etc.
/// Supports modifier keys and special keys.
@available(macOS 14.0, *)
struct HotkeyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hotkey",
        abstract: "Press keyboard shortcuts and key combinations",
        discussion: """
            The 'hotkey' command simulates keyboard shortcuts by pressing
            multiple keys simultaneously, like Cmd+C for copy or Cmd+Shift+T.

            EXAMPLES:
              peekaboo hotkey --keys "cmd,c"          # Copy
              peekaboo hotkey --keys "cmd,v"          # Paste
              peekaboo hotkey --keys "cmd,shift,t"    # Reopen closed tab
              peekaboo hotkey --keys "cmd,space"      # Spotlight
              peekaboo hotkey --keys "ctrl,a"         # Select all (in terminal)

            KEY NAMES:
              Modifiers: cmd, shift, alt/option, ctrl, fn
              Letters: a-z
              Numbers: 0-9
              Special: space, return, tab, escape, delete, arrow_up, arrow_down, arrow_left, arrow_right
              Function: f1-f12

            The keys are pressed in the order given and released in reverse order.
        """
    )

    @Option(help: "Comma-separated list of keys to press")
    var keys: String

    @Option(help: "Delay between key press and release in milliseconds")
    var holdDuration: Int = 50

    @Flag(help: "Output in JSON format")
    var jsonOutput = false

    mutating func run() async throws {
        let startTime = Date()

        do {
            // Parse key names
            let keyNames = keys.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

            guard !keyNames.isEmpty else {
                throw ValidationError("No keys specified")
            }

            // Perform hotkey using InputEvents utility
            try InputEvents.performHotkey(
                keys: keyNames,
                holdDuration: Double(holdDuration) / 1000.0
            )

            // Output results
            if jsonOutput {
                let output = HotkeyResult(
                    success: true,
                    keys: keyNames,
                    keyCount: keyNames.count,
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output)
            } else {
                print("✅ Hotkey pressed")
                print("🎹 Keys: \(keyNames.joined(separator: " + "))")
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            if jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .INVALID_ARGUMENT
                )
            } else {
                var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
                print("Error: \(error.localizedDescription)", to: &localStandardErrorStream)
            }
            throw ExitCode.failure
        }
    }
}

// MARK: - JSON Output Structure

struct HotkeyResult: Codable {
    let success: Bool
    let keys: [String]
    let keyCount: Int
    let executionTime: TimeInterval
}
