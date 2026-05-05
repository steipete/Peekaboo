import Commander

extension CompletionsCommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            arguments: [
                .make(
                    label: "shell",
                    help: "Shell type (zsh, bash, fish). Auto-detected from $SHELL if omitted.",
                    isOptional: true
                ),
            ]
        )
    }
}
