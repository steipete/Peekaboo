import Commander

extension ClickCommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            arguments: [
                .make(
                    label: "query",
                    help: "Element text or query to click",
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
                    "on",
                    help: "Element ID to click (e.g., B1, T2)",
                    long: "on"
                ),
                .commandOption(
                    "id",
                    help: "Element ID to click (alias for --on)",
                    long: "id"
                ),
                .commandOption(
                    "app",
                    help: "Application name to focus before clicking",
                    long: "app"
                ),
                .commandOption(
                    "coords",
                    help: "Click at coordinates (x,y)",
                    long: "coords"
                ),
                .commandOption(
                    "waitFor",
                    help: "Maximum milliseconds to wait for element",
                    long: "wait-for"
                ),
            ],
            flags: [
                .commandFlag(
                    "double",
                    help: "Double-click instead of single click",
                    long: "double"
                ),
                .commandFlag(
                    "right",
                    help: "Right-click (secondary click)",
                    long: "right"
                ),
            ],
            optionGroups: [
                FocusCommandOptions.commanderSignature(),
            ]
        )
    }
}
