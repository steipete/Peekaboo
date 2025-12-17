import Commander

extension SeeCommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            options: [
                .commandOption(
                    "app",
                    help: "Application name to capture, or special values: 'menubar', 'frontmost'",
                    long: "app"
                ),
                .commandOption(
                    "pid",
                    help: "Target application by process ID",
                    long: "pid"
                ),
                .commandOption(
                    "windowTitle",
                    help: "Specific window title to capture",
                    long: "window-title"
                ),
                .commandOption(
                    "mode",
                    help: "Capture mode (screen, window, frontmost)",
                    long: "mode"
                ),
                .commandOption(
                    "path",
                    help: "Output path for screenshot",
                    long: "path"
                ),
                .commandOption(
                    "captureEngine",
                    help: "Capture engine: auto|classic|cg|modern|sckit (defaults to auto)",
                    long: "capture-engine"
                ),
                .commandOption(
                    "screenIndex",
                    help: "Specific screen index to capture (0-based)",
                    long: "screen-index"
                ),
                .commandOption(
                    "analyze",
                    help: "Analyze captured content with AI",
                    long: "analyze"
                ),
                .commandOption(
                    "timeoutSeconds",
                    help: "Overall timeout in seconds (default: 20, or 60 when --analyze is set)",
                    long: "timeout-seconds"
                ),
            ],
            flags: [
                .commandFlag(
                    "annotate",
                    help: "Generate annotated screenshot with interaction markers",
                    long: "annotate"
                ),
                .commandFlag(
                    "noWebFocus",
                    help: "Skip web-content focus fallback when no text fields are detected",
                    long: "no-web-focus"
                ),
            ]
        )
    }
}
