import Commander

extension InteractionTargetOptions {
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
                    help: "Target window by title (partial match supported)",
                    long: "window-title"
                ),
                .commandOption(
                    "windowIndex",
                    help: "Target window by index (0-based, frontmost is 0)",
                    long: "window-index"
                ),
            ]
        )
    }
}
