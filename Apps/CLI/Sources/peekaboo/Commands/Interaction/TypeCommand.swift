import ArgumentParser
import Foundation
import PeekabooCore

/// Types text into focused elements or sends keyboard input using the UIAutomationService.
@available(macOS 14.0, *)
struct TypeCommand: AsyncParsableCommand, ErrorHandlingCommand, OutputFormattable {
    static let configuration = CommandConfiguration(
        commandName: "type",
        abstract: "Type text or send keyboard input",
        discussion: """
            The 'type' command sends keyboard input to the focused element.
            It can type regular text or send special key combinations.

            EXAMPLES:
              peekaboo type "Hello World"           # Type text (default: 5ms delay)
              peekaboo type "user@example.com"      # Type email
              peekaboo type "text" --delay 0        # Type at maximum speed
              peekaboo type "text" --delay 50       # Type slower (50ms between keys)
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
    var delay: Int = 2

    @Flag(name: .long, help: "Press return/enter after typing")
    var pressReturn = false

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

    @Option(name: .long, help: "Target application to focus before typing")
    var app: String?

    @OptionGroup var focusOptions: FocusOptions

    mutating func run() async throws {
        let startTime = Date()
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        do {
            var actions: [TypeAction] = []

            // Build action sequence
            if self.clear {
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

            if self.escape {
                actions.append(.key(.escape))
            }

            if self.delete {
                actions.append(.key(.delete))
            }

            if self.pressReturn {
                actions.append(.key(.return))
            }

            // Validate we have something to do
            guard !actions.isEmpty else {
                throw ArgumentParser.ValidationError("No input specified. Provide text or key flags.")
            }

            // Get session if available
            let sessionId: String? = if let providedSession = session {
                providedSession
            } else {
                await PeekabooServices.shared.sessions.getMostRecentSession()
            }

            // Ensure window is focused before typing
            try await self.ensureFocused(
                sessionId: sessionId,
                applicationName: self.app,
                options: self.focusOptions
            )

            // Execute type actions using the service
            let typeResult = try await PeekabooServices.shared.automation.typeActions(
                actions,
                typingDelay: self.delay,
                sessionId: self.session
            )

            // Output results
            let result = TypeCommandResult(
                success: true,
                typedText: text,
                keyPresses: typeResult.keyPresses,
                totalCharacters: typeResult.totalCharacters,
                executionTime: Date().timeIntervalSince(startTime)
            )

            output(result) {
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
            self.handleError(error)
            throw ExitCode.failure
        }
    }

    // Error handling is provided by ErrorHandlingCommand protocol
}

// MARK: - JSON Output Structure

struct TypeCommandResult: Codable {
    let success: Bool
    let typedText: String?
    let keyPresses: Int
    let totalCharacters: Int
    let executionTime: TimeInterval
}
