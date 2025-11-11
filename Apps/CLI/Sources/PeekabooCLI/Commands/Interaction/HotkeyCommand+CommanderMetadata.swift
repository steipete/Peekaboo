import Commander

extension HotkeyCommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            options: [
                .commandOption(
                    "keys",
                    help: "Keys to press (comma-separated or space-separated)",
                    long: "keys"
                ),
                .commandOption(
                    "holdDuration",
                    help: "Delay between key press and release in milliseconds",
                    long: "hold-duration"
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
