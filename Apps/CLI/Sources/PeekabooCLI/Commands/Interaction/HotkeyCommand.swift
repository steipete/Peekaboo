import Commander
import Foundation
import PeekabooCore

/// Presses key combinations like Cmd+C, Ctrl+A, etc. using the UIAutomationService.
@available(macOS 14.0, *)
@MainActor
struct HotkeyCommand: ErrorHandlingCommand, OutputFormattable {
    @Argument(help: "Keys to press (comma-separated or space-separated)")
    var keysArgument: String?

    @Option(name: .customLong("keys"), help: "Keys to press (comma-separated or space-separated)")
    var keysOption: String?

    @Option(help: "Delay between key press and release in milliseconds")
    var holdDuration: Int = 50

    @Option(help: "Snapshot ID (uses latest if not specified)")
    var snapshot: String?

    @OptionGroup var focusOptions: FocusCommandOptions
    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }
    /// Keys after resolving positional/option input and trimming whitespace. Nil when missing/empty.
    var resolvedKeys: String? {
        let raw = self.keysArgument ?? self.keysOption
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        let startTime = Date()
        self.logger.setJsonOutputMode(self.jsonOutput)

        do {
            // Parse key names - support both comma-separated and space-separated
            guard let keysString = self.resolvedKeys else {
                throw ValidationError("No keys specified")
            }

            let keyNames: [String] = if keysString.contains(",") {
                // Comma-separated format: "cmd,c" or "cmd, c"
                keysString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            } else {
                // Space-separated format: "cmd c" or "cmd a"
                keysString.split(separator: " ").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            }

            guard !keyNames.isEmpty else {
                throw ValidationError("No keys specified")
            }

            // Convert key names to comma-separated format for the service
            let keysCsv = keyNames.joined(separator: ",")

            // Get snapshot if available
            let snapshotId: String? = if let providedSnapshot = snapshot {
                providedSnapshot
            } else {
                await self.services.snapshots.getMostRecentSnapshot()
            }

            // Ensure window is focused before pressing hotkey (if we have a snapshot and auto-focus is enabled)
            if let snapshotId {
                try await ensureFocused(
                    snapshotId: snapshotId,
                    options: self.focusOptions,
                    services: self.services
                )
            }

            // Perform hotkey using the automation service
            try await AutomationServiceBridge.hotkey(
                automation: self.services.automation,
                keys: keysCsv,
                holdDuration: self.holdDuration
            )

            // Output results
            let result = HotkeyResult(
                success: true,
                keys: keyNames,
                keyCount: keyNames.count,
                executionTime: Date().timeIntervalSince(startTime)
            )

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

// MARK: - Conformances

@MainActor
extension HotkeyCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "hotkey",
                abstract: "Press keyboard shortcuts and key combinations",
                discussion: """
                    The 'hotkey' command simulates keyboard shortcuts by pressing
                    multiple keys simultaneously, like Cmd+C for copy or Cmd+Shift+T.

                    EXAMPLES:
                      peekaboo hotkey "cmd,c"               # Copy (comma-separated, positional)
                      peekaboo hotkey "cmd space"           # Spotlight (space-separated, positional)
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
                """,

                showHelpOnEmptyInvocation: true
            )
        }
    }
}

extension HotkeyCommand: AsyncRuntimeCommand {}

@MainActor
extension HotkeyCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.keysArgument = values.positional.first
        self.keysOption = values.singleOption("keys") ?? values.singleOption("keysOption")
        guard self.resolvedKeys != nil else {
            throw ValidationError("No keys specified. Provide keys like \"cmd,c\" or \"cmd c\".")
        }
        if let hold: Int = try values.decodeOption("holdDuration", as: Int.self) {
            self.holdDuration = hold
        }
        self.snapshot = values.singleOption("snapshot")
        self.focusOptions = try values.makeFocusOptions()
    }
}
