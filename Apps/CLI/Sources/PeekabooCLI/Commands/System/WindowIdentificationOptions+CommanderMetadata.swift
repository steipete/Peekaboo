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
                    "windowId",
                    help: "Target window by CoreGraphics window id (window_id)",
                    long: "window-id"
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
