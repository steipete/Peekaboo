import Commander

extension WindowIdentificationOptions {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            options: [
                .commandOption(
                    "app",
                    help: "Target application name, bundle ID, or 'PID:12345'",
                    long: "app"
                ),
                .commandOption(
                    "pid",
                    help: "Target application by process ID",
                    long: "pid"
                ),
                .commandOption(
                    "windowTitle",
                    help: "Target window by title",
                    long: "window-title"
                ),
                .commandOption(
                    "windowIndex",
                    help: "Target window by index (0-based)",
                    long: "window-index"
                ),
            ]
        )
    }
}
