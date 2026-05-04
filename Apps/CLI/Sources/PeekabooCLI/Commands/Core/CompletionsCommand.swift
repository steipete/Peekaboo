import Commander
import Foundation

/// Generate shell completion scripts for `peekaboo`.
///
/// The generated scripts are rendered from Commander descriptor metadata so the
/// CLI help, docs, and completion tables stay aligned. Users should normally
/// install them with:
///
/// ```bash
/// eval "$(peekaboo completions $SHELL)"
/// ```
@MainActor
struct CompletionsCommand: ParsableCommand {
    static let commandDescription = CommandDescription(
        commandName: "completions",
        abstract: "Generate shell completion scripts",
        discussion: """
        Generate shell completions for peekaboo. The command accepts either a shell
        name (`zsh`, `bash`, `fish`) or a full shell path such as `/bin/zsh`.

        Supported shells: zsh (default), bash, fish

        SETUP:
          # Auto-detect the current shell (recommended)
          eval "$(peekaboo completions $SHELL)"

          # Explicit shell selection
          eval "$(peekaboo completions zsh)"
          eval "$(peekaboo completions bash)"
          peekaboo completions fish | source

        PERMANENT INSTALLATION:
          # Zsh – add to ~/.zshrc
          eval "$(peekaboo completions $SHELL)"

          # Bash – add to ~/.bashrc or ~/.bash_profile
          eval "$(peekaboo completions bash)"

          # Fish – add to ~/.config/fish/config.fish
          peekaboo completions fish | source
        """,
        usageExamples: [
            .init(
                command: "peekaboo completions $SHELL",
                description: "Generate a script for the current shell"
            ),
            .init(
                command: "eval \"$(peekaboo completions $SHELL)\"",
                description: "Enable completions for the current shell session"
            ),
            .init(
                command: "peekaboo completions fish | source",
                description: "Load fish completions in the current shell"
            ),
        ]
    )

    @Argument(help: "Shell type or path (zsh, bash, fish, /bin/zsh). Auto-detected from $SHELL if omitted.")
    var shell: String?

    mutating func run() async throws {
        let resolvedShell = try self.resolveShell()
        let document = CompletionScriptDocument.make(descriptors: CommanderRegistryBuilder.buildDescriptors())
        let script = CompletionScriptRenderer.render(document: document, for: resolvedShell)
        print(script)
    }
}

extension CompletionsCommand {
    enum Shell: String, CaseIterable {
        case zsh
        case bash
        case fish

        var displayName: String {
            self.rawValue
        }

        var installationSnippet: String {
            switch self {
            case .zsh, .bash:
                "eval \"$(peekaboo completions \(self.rawValue))\""
            case .fish:
                "peekaboo completions fish | source"
            }
        }

        var helpText: String {
            switch self {
            case .zsh:
                "Generate a zsh completion script"
            case .bash:
                "Generate a bash completion script"
            case .fish:
                "Generate a fish completion script"
            }
        }

        static func parse(_ specifier: String?) -> Shell? {
            guard let specifier else { return nil }
            let trimmed = specifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            let lastPathComponent = URL(fileURLWithPath: trimmed).lastPathComponent.lowercased()
            let normalized = if lastPathComponent.hasPrefix("-") {
                String(lastPathComponent.dropFirst())
            } else {
                lastPathComponent
            }

            for shell in Self.allCases {
                if normalized == shell.rawValue {
                    return shell
                }

                guard normalized.hasPrefix(shell.rawValue) else { continue }
                let suffix = normalized.dropFirst(shell.rawValue.count)
                if suffix.isEmpty { return shell }
                let first = suffix.first!
                if first == "-" || first == "." || first.isNumber {
                    return shell
                }
            }

            return nil
        }
    }

    func resolveShell() throws -> Shell {
        if let explicit = self.shell {
            if let shell = Shell.parse(explicit) {
                return shell
            }
            let supported = Shell.allCases.map(\.rawValue).joined(separator: ", ")
            throw ValidationError("Unsupported shell '\(explicit)'. Supported shells: \(supported)")
        }
        return Self.detectShell()
    }

    static func detectShell() -> Shell {
        Shell.parse(ProcessInfo.processInfo.environment["SHELL"]) ?? .zsh
    }
}

@MainActor
extension CompletionsCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.shell = values.positionalValue(at: 0)
    }
}
