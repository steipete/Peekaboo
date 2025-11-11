import Commander

extension ImageCommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            options: [
                .commandOption(
                    "app",
                    help: "Target application name, bundle ID, 'PID:12345', 'menubar', or 'frontmost'",
                    long: "app"
                ),
                .commandOption(
                    "pid",
                    help: "Target application by process ID",
                    long: "pid"
                ),
                .commandOption(
                    "path",
                    help: "Output path for saved image",
                    long: "path"
                ),
                .commandOption(
                    "mode",
                    help: "Capture mode (auto, screen, window, frontmost)",
                    long: "mode"
                ),
                .commandOption(
                    "windowTitle",
                    help: "Capture window with specific title",
                    long: "window-title"
                ),
                .commandOption(
                    "windowIndex",
                    help: "Window index to capture",
                    long: "window-index"
                ),
                .commandOption(
                    "screenIndex",
                    help: "Screen index for screen captures",
                    long: "screen-index"
                ),
                .commandOption(
                    "format",
                    help: "Image format (png or jpg)",
                    long: "format"
                ),
                .commandOption(
                    "captureFocus",
                    help: "Window focus behavior",
                    long: "capture-focus"
                ),
                .commandOption(
                    "analyze",
                    help: "Analyze the captured image with AI",
                    long: "analyze"
                ),
            ]
        )
    }
}
