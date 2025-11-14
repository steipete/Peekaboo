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

    @Option(name: .customLong("text"), help: "Text to type (alternative to positional argument)")
    var textOption: String?

    @Option(help: "Session ID (uses latest if not specified)")
    var session: String?

    @Option(help: "Delay between keystrokes in milliseconds")
    var delay: Int = 2

    @Option(name: .customLong("wpm"), help: "Approximate human typing speed (words per minute)")
    var wordsPerMinute: Int?

    @Option(name: .customLong("profile"), help: "Typing profile: human (default) or linear")
    var profileOption: String?

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

    private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput }
    private var resolvedText: String? {
        if let primary = text, !primary.isEmpty {
            return primary
        }
        return self.textOption
    }

    private static let defaultHumanWPM = 140

    private var resolvedProfile: TypingProfile {
        if let profileOption,
           let selection = TypingProfile(rawValue: profileOption.lowercased())
        {
            return selection
        }
        return .human
    }

    private var resolvedWordsPerMinute: Int {
        self.wordsPerMinute ?? Self.defaultHumanWPM
    }

    private var typingCadence: TypingCadence {
        switch self.resolvedProfile {
        case .human:
            return .human(wordsPerMinute: self.resolvedWordsPerMinute)
        case .linear:
            return .fixed(milliseconds: self.delay)
        }
    }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.prepare(using: runtime)
        try self.validate()
        let startTime = Date()
        do {
            let actions = try self.buildActions()
            let sessionId = await self.resolveSessionId()
            self.warnIfFocusUnknown(sessionId: sessionId)
            try await self.focusIfNeeded(sessionId: sessionId)
            let typeResult = try await self.executeTypeActions(actions: actions, sessionId: sessionId)
            self.renderResult(typeResult, startTime: startTime)
        } catch {
            self.handleError(error)
            throw ExitCode.failure
        }
    }

    private mutating func prepare(using runtime: CommandRuntime) {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)
    }

    private func buildActions() throws -> [TypeAction] {
        var actions: [TypeAction] = []

        if self.clear {
            actions.append(.clear)
        }

        if let textToType = self.resolvedText {
            actions.append(contentsOf: Self.processTextWithEscapes(textToType))
        }

        if let tabCount = tab {
            actions.append(contentsOf: Array(repeating: TypeAction.key(.tab), count: tabCount))
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

        guard !actions.isEmpty else {
            throw ValidationError("No input specified. Provide text or key flags.")
        }

        return actions
    }

    private func resolveSessionId() async -> String? {
        if let providedSession = session {
            providedSession
        } else {
            await self.services.sessions.getMostRecentSession()
        }
    }

    mutating func validate() throws {
        if let option = self.profileOption,
           TypingProfile(rawValue: option.lowercased()) == nil
        {
            throw ValidationError("--profile must be either 'human' or 'linear'")
        }

        if let wpm = self.wordsPerMinute {
            guard (80...220).contains(wpm) else {
                throw ValidationError("--wpm must be between 80 and 220 to stay believable")
            }
            guard self.resolvedProfile == .human else {
                throw ValidationError("--wpm is only valid when --profile human")
            }
        }
    }

    private func warnIfFocusUnknown(sessionId: String?) {
        guard self.focusOptions.autoFocus, sessionId == nil, self.app == nil else { return }
        self.logger.warn(
            """
            Typing without an associated --app or session. \
            We'll inject keys blindly; run 'peekaboo see' or provide --app if you need focus guarantees.
            """
        )
    }

    private func focusIfNeeded(sessionId: String?) async throws {
        try await ensureFocused(
            sessionId: sessionId,
            applicationName: self.app,
            options: self.focusOptions,
            services: self.services
        )
    }

    private func executeTypeActions(actions: [TypeAction], sessionId: String?) async throws -> TypeResult {
        let request = TypeActionsRequest(actions: actions, cadence: self.typingCadence, sessionId: sessionId)
        return try await AutomationServiceBridge.typeActions(automation: self.services.automation, request: request)
    }

    private func renderResult(_ typeResult: TypeResult, startTime: Date) {
        let result = TypeCommandResult(
            success: true,
            typedText: self.resolvedText,
            keyPresses: typeResult.keyPresses,
            totalCharacters: typeResult.totalCharacters,
            executionTime: Date().timeIntervalSince(startTime),
            wordsPerMinute: self.resolvedProfile == .human ? self.resolvedWordsPerMinute : nil,
            profile: self.resolvedProfile.rawValue
        )

        output(result) {
            print("✅ Typing completed")
            if let typed = self.resolvedText {
                print("⌨️  Typed: \"\(typed)\"")
            }
            let specialKeys = max(typeResult.keyPresses - typeResult.totalCharacters, 0)
            if specialKeys > 0 {
                print("🔑 Special keys: \(specialKeys)")
            }
            print("📊 Total characters: \(typeResult.totalCharacters)")
            switch self.resolvedProfile {
            case .human:
                print("🏃‍♀️ Human cadence: \(self.resolvedWordsPerMinute) WPM")
            case .linear:
                print("⚙️  Fixed delay: \(self.delay)ms between keys")
            }
            print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
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
        self.textOption = values.singleOption("text")
        self.session = values.singleOption("session")
        if let delay: Int = try values.decodeOption("delay", as: Int.self) {
            self.delay = delay
        }
        if let wpm: Int = try values.decodeOption("wpm", as: Int.self) {
            self.wordsPerMinute = wpm
        }
        self.profileOption = values.singleOption("profile")
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
    let wordsPerMinute: Int?
    let profile: String
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
                      peekaboo type "text" --wpm 150       # Type like a fast human (150 WPM)
                      peekaboo type "text" --profile linear # Force deterministic linear cadence
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

                    HUMAN TYPING:
                      Use --profile human (default) for realistic cadence; override speed with --wpm (80-220).
                      Use --profile linear for deterministic timing via --delay.
                """
            )
        }
    }
}

extension TypeCommand: AsyncRuntimeCommand {}
