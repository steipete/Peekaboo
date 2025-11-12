import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Types text into focused elements or sends keyboard input using the UIAutomationService.
@available(macOS 14.0, *)
@MainActor
struct TypeCommand: ErrorHandlingCommand, OutputFormattable, RuntimeOptionsConfigurable {
    @Argument(help: "Text to type")
    var text: String?

    @Option(help: "Session ID (uses latest if not specified)")
    var session: String?

    @Option(help: "Delay between keystrokes in milliseconds")
    var delay: Int = 2

    @Flag(names: [.customLong("return"), .long], help: "Press return/enter after typing")
    var pressReturn = false

    @Option(help: "Press tab N times")
    var tab: Int?

    @Flag(help: "Press escape")
    var escape = false

    @Flag(help: "Press delete/backspace")
    var delete = false

    @Flag(help: "Clear the field before typing (Cmd+A, Delete)")
    var clear = false

    @Option(name: .long, help: "Target application to focus before typing")
    var app: String?

    @OptionGroup var focusOptions: FocusCommandOptions
    @RuntimeStorage private var runtime: CommandRuntime?
    var runtimeOptions = CommandRuntimeOptions()

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: PeekabooServices { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        let startTime = Date()
        self.logger.setJsonOutputMode(self.jsonOutput)

        do {
            var actions: [TypeAction] = []

            // Build action sequence
            if self.clear {
                actions.append(.clear)
            }

            if let textToType = text {
                // Process escape sequences
                let processedActions = Self.processTextWithEscapes(textToType)
                actions.append(contentsOf: processedActions)
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
                throw ValidationError("No input specified. Provide text or key flags.")
            }

            // Get session if available
            let sessionId: String? = if let providedSession = session {
                providedSession
            } else {
                await self.services.sessions.getMostRecentSession()
            }

            if self.focusOptions.autoFocus, sessionId == nil, self.app == nil {
                self.logger.warn(
                    """
                    Typing without an associated --app or session. \
                    We'll inject keys blindly; run 'peekaboo see' or provide --app if you need focus guarantees.
                    """
                )
            }

            // Ensure window is focused before typing
            try await ensureFocused(
                sessionId: sessionId,
                applicationName: self.app,
                options: self.focusOptions,
                services: self.services
            )

            // Execute type actions using the service
            let typeResult = try await AutomationServiceBridge.typeActions(
                services: self.services,
                actions: actions,
                typingDelay: self.delay,
                sessionId: sessionId
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

    /// Process text with escape sequences like \n, \t, etc.
    static func processTextWithEscapes(_ text: String) -> [TypeAction] {
        // Process text with escape sequences like \n, \t, etc.
        var actions: [TypeAction] = []
        var currentText = ""
        var i = text.startIndex

        while i < text.endIndex {
            let char = text[i]

            if char == "\\" && text.index(after: i) < text.endIndex {
                let nextChar = text[text.index(after: i)]

                switch nextChar {
                case "n":
                    // Add accumulated text
                    if !currentText.isEmpty {
                        actions.append(.text(currentText))
                        currentText = ""
                    }
                    // Add return key
                    actions.append(.key(.return))
                    // Skip the 'n'
                    i = text.index(after: i)

                case "t":
                    // Add accumulated text
                    if !currentText.isEmpty {
                        actions.append(.text(currentText))
                        currentText = ""
                    }
                    // Add tab key
                    actions.append(.key(.tab))
                    // Skip the 't'
                    i = text.index(after: i)

                case "b":
                    // Add accumulated text
                    if !currentText.isEmpty {
                        actions.append(.text(currentText))
                        currentText = ""
                    }
                    // Add backspace/delete key
                    actions.append(.key(.delete))
                    // Skip the 'b'
                    i = text.index(after: i)

                case "e":
                    // Add accumulated text
                    if !currentText.isEmpty {
                        actions.append(.text(currentText))
                        currentText = ""
                    }
                    // Add escape key
                    actions.append(.key(.escape))
                    // Skip the 'e'
                    i = text.index(after: i)

                case "\\":
                    // Escaped backslash
                    currentText.append("\\")
                    // Skip the second backslash
                    i = text.index(after: i)

                default:
                    // Not a recognized escape, keep the backslash
                    currentText.append(char)
                }
            } else {
                currentText.append(char)
            }

            i = text.index(after: i)
        }

        // Add any remaining text
        if !currentText.isEmpty {
            actions.append(.text(currentText))
        }

        return actions
    }
}

@MainActor
extension TypeCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.text = try values.decodeOptionalPositional(0, label: "text")
        self.session = values.singleOption("session")
        if let delay: Int = try values.decodeOption("delay", as: Int.self) {
            self.delay = delay
        }
        self.tab = try values.decodeOption("tab", as: Int.self)
        self.pressReturn = values.flag("pressReturn")
        self.escape = values.flag("escape")
        self.delete = values.flag("delete")
        self.clear = values.flag("clear")
        self.app = values.singleOption("app")
        self.focusOptions = try values.makeFocusOptions()
    }
}

// MARK: - JSON Output Structure

struct TypeCommandResult: Codable {
    let success: Bool
    let typedText: String?
    let keyPresses: Int
    let totalCharacters: Int
    let executionTime: TimeInterval
}

// MARK: - Conformances

@MainActor
extension TypeCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
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
                      peekaboo type "Line 1\nLine 2"        # Type with newline
                      peekaboo type "Name:\tJohn"           # Type with tab
                      peekaboo type "Path: C:\\data"       # Type literal backslash

                    SPECIAL KEYS:
                      Use flags for special keys:
                      --return    Press return/enter
                      --tab       Press tab (with optional count)
                      --escape    Press escape
                      --delete    Press delete
                      --clear     Clear current field (Cmd+A, Delete)

                    ESCAPE SEQUENCES:
                      Supported escape sequences in text:
                      \\n  - Newline/return
                      \\t  - Tab
                      \\b  - Backspace/delete
                      \\e  - Escape
                      \\\\  - Literal backslash

                    FOCUS MANAGEMENT:
                      The command assumes an element is already focused.
                      Use 'click' to focus an input field first.
                """
            )
        }
    }
}

extension TypeCommand: AsyncRuntimeCommand {}
