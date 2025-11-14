import Commander

extension TypeCommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            arguments: [
                .make(
                    label: "text",
                    help: "Text to type",
                    isOptional: true
                ),
            ],
            options: [
                .commandOption(
                    "session",
                    help: "Session ID (uses latest if not specified)",
                    long: "session"
                ),
                .commandOption(
                    "delay",
                    help: "Delay between keystrokes in milliseconds",
                    long: "delay"
                ),
                .commandOption(
                    "wpm",
                    help: "Approximate human typing speed (words per minute)",
                    long: "wpm"
                ),
                .commandOption(
                    "tab",
                    help: "Press tab N times",
                    long: "tab"
                ),
                .commandOption(
                    "app",
                    help: "Target application to focus before typing",
                    long: "app"
                ),
            ],
            flags: [
                .commandFlag(
                    "pressReturn",
                    help: "Press return/enter after typing",
                    long: "return"
                ),
                .commandFlag(
                    "escape",
                    help: "Press escape",
                    long: "escape"
                ),
                .commandFlag(
                    "delete",
                    help: "Press delete/backspace",
                    long: "delete"
                ),
                .commandFlag(
                    "clear",
                    help: "Clear the field before typing (Cmd+A, Delete)",
                    long: "clear"
                ),
            ],
            optionGroups: [
                FocusCommandOptions.commanderSignature(),
            ]
        )
    }
}
