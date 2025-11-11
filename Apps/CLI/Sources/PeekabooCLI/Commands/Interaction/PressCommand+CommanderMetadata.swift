import Commander

extension PressCommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            arguments: [
                .make(
                    label: "keys",
                    help: "Key(s) to press",
                    isOptional: false
                ),
            ],
            options: [
                .commandOption(
                    "count",
                    help: "Repeat count for all keys",
                    long: "count"
                ),
                .commandOption(
                    "delay",
                    help: "Delay between key presses in milliseconds",
                    long: "delay"
                ),
                .commandOption(
                    "hold",
                    help: "Hold duration for each key in milliseconds",
                    long: "hold"
                ),
                .commandOption(
                    "session",
                    help: "Session ID (uses latest if not specified)",
                    long: "session"
                ),
            ],
            optionGroups: [
                FocusCommandOptions.commanderSignature(),
            ]
        )
    }
}
