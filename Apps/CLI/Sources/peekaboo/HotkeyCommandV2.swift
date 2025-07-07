import ArgumentParser
import Foundation
import PeekabooCore

/// Refactored HotkeyCommand using PeekabooCore services
/// Presses key combinations like Cmd+C, Ctrl+A, etc. using the UIAutomationService.
@available(macOS 14.0, *)
struct HotkeyCommandV2: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hotkey-v2",
        abstract: "Press keyboard shortcuts and key combinations using PeekabooCore services",
        discussion: """
            This is a refactored version of the hotkey command that uses PeekabooCore services
            instead of direct implementation. It maintains the same interface but delegates
            all operations to the service layer.
            
            The 'hotkey' command simulates keyboard shortcuts by pressing
            multiple keys simultaneously, like Cmd+C for copy or Cmd+Shift+T.

            EXAMPLES:
              peekaboo hotkey-v2 --keys "cmd,c"          # Copy (comma-separated)
              peekaboo hotkey-v2 --keys "cmd c"          # Copy (space-separated)
              peekaboo hotkey-v2 --keys "cmd,v"          # Paste
              peekaboo hotkey-v2 --keys "cmd a"          # Select all
              peekaboo hotkey-v2 --keys "cmd,shift,t"    # Reopen closed tab
              peekaboo hotkey-v2 --keys "cmd space"      # Spotlight

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

    private let services = PeekabooServices.shared

    mutating func run() async throws {
        let startTime = Date()
        Logger.shared.setJsonOutputMode(jsonOutput)

        do {
            // Parse key names - support both comma-separated and space-separated
            let keyNames: [String]
            if self.keys.contains(",") {
                // Comma-separated format: "cmd,c" or "cmd, c"
                keyNames = self.keys.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            } else {
                // Space-separated format: "cmd c" or "cmd a"
                keyNames = self.keys.split(separator: " ").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            }

            guard !keyNames.isEmpty else {
                throw ValidationError("No keys specified")
            }

            // Convert key names to comma-separated format for the service
            let keysString = keyNames.joined(separator: ",")

            // Perform hotkey using the automation service
            try await services.automation.hotkey(
                keys: keysString,
                holdDuration: self.holdDuration
            )

            // Output results
            if self.jsonOutput {
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
            handleError(error)
            throw ExitCode.failure
        }
    }

    private func handleError(_ error: Error) {
        if jsonOutput {
            let errorCode: ErrorCode
            if error is PeekabooError {
                switch error as? PeekabooError {
                case .interactionFailed:
                    errorCode = .INTERACTION_FAILED
                case .permissionDenied:
                    errorCode = .PERMISSION_DENIED_ACCESSIBILITY
                default:
                    errorCode = .INTERNAL_SWIFT_ERROR
                }
            } else if error is ValidationError {
                errorCode = .INVALID_ARGUMENT
            } else {
                errorCode = .INTERNAL_SWIFT_ERROR
            }
            
            outputError(
                message: error.localizedDescription,
                code: errorCode
            )
        } else {
            var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
            print("Error: \(error.localizedDescription)", to: &localStandardErrorStream)
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