import ArgumentParser
import Foundation
import PeekabooCore

/// Presses key combinations like Cmd+C, Ctrl+A, etc. using the UIAutomationService.
@available(macOS 14.0, *)
struct HotkeyCommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "hotkey",
        abstract: "Press keyboard shortcuts and key combinations",
        discussion: """
            The 'hotkey' command simulates keyboard shortcuts by pressing
            multiple keys simultaneously, like Cmd+C for copy or Cmd+Shift+T.

            EXAMPLES:
              peekaboo hotkey --keys "cmd,c"          # Copy (comma-separated)
              peekaboo hotkey --keys "cmd c"          # Copy (space-separated)
              peekaboo hotkey --keys "cmd,v"          # Paste
              peekaboo hotkey --keys "cmd a"          # Select all
              peekaboo hotkey --keys "cmd,shift,t"    # Reopen closed tab
              peekaboo hotkey --keys "cmd space"      # Spotlight

            KEY NAMES:
              Modifiers: cmd, shift, alt/option, ctrl, fn
              Letters: a-z
              Numbers: 0-9
              Special: space, return, tab, escape, delete, arrow_up, arrow_down, arrow_left, arrow_right
              Function: f1-f12

            The keys are pressed in the order given and released in reverse order.
        """)

    @Option(help: "Keys to press (comma-separated or space-separated)")
    var keys: String

    @Option(help: "Delay between key press and release in milliseconds")
    var holdDuration: Int = 50

    @Option(help: "Session ID (uses latest if not specified)")
    var session: String?

    @Flag(help: "Output in JSON format")
    var jsonOutput = false
    
    @OptionGroup var focusOptions: FocusOptions

    mutating func run() async throws {
        let startTime = Date()
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            // Parse key names - support both comma-separated and space-separated
            let keyNames: [String] = if self.keys.contains(",") {
                // Comma-separated format: "cmd,c" or "cmd, c"
                self.keys.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            } else {
                // Space-separated format: "cmd c" or "cmd a"
                self.keys.split(separator: " ").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            }

            guard !keyNames.isEmpty else {
                throw ArgumentParser.ValidationError("No keys specified")
            }

            // Convert key names to comma-separated format for the service
            let keysString = keyNames.joined(separator: ",")
            
            // Get session if available
            let sessionId: String? = if let providedSession = session {
                providedSession
            } else {
                await PeekabooServices.shared.sessions.getMostRecentSession()
            }
            
            // Ensure window is focused before pressing hotkey (if we have a session and auto-focus is enabled)
            if let sessionId = sessionId {
                try await self.ensureFocused(
                    sessionId: sessionId,
                    options: focusOptions
                )
            }

            // Perform hotkey using the automation service
            try await PeekabooServices.shared.automation.hotkey(
                keys: keysString,
                holdDuration: self.holdDuration)

            // Output results
            let result = HotkeyResult(
                success: true,
                keys: keyNames,
                keyCount: keyNames.count,
                executionTime: Date().timeIntervalSince(startTime))
                
            output(result) {
                print("✅ Hotkey pressed")
                print("🎹 Keys: \(keyNames.joined(separator: " + "))")
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            self.handleError(error)
            throw ExitCode.failure
        }
    }

    // Error handling is provided by ErrorHandlingCommand protocol
}

// MARK: - JSON Output Structure

struct HotkeyResult: Codable {
    let success: Bool
    let keys: [String]
    let keyCount: Int
    let executionTime: TimeInterval
}
