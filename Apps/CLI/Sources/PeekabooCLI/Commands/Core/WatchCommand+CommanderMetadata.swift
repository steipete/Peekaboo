import Commander

extension WatchCommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            options: [
                .commandOption("app", help: "Target application name, bundle ID, or 'PID:12345'", long: "app"),
                .commandOption("pid", help: "Target application by process ID", long: "pid"),
                .commandOption("mode", help: "Capture mode (screen, window, frontmost, region)", long: "mode"),
                .commandOption("windowTitle", help: "Capture window with specific title", long: "window-title"),
                .commandOption("windowIndex", help: "Window index to capture", long: "window-index"),
                .commandOption("screenIndex", help: "Screen index for screen captures", long: "screen-index"),
                .commandOption("region", help: "Region to capture: x,y,width,height", long: "region"),
                .commandOption("captureFocus", help: "Window focus behavior", long: "capture-focus"),
                .commandOption("duration", help: "Duration in seconds (default 60, max 180)", long: "duration"),
                .commandOption("idleFps", help: "Idle FPS during quiet periods (default 2)", long: "idle-fps"),
                .commandOption("activeFps", help: "Active FPS during motion (default 8, max 15)", long: "active-fps"),
                .commandOption("threshold", help: "Change threshold percent (default 2.5)", long: "threshold"),
                .commandOption("heartbeatSec", help: "Heartbeat interval seconds (default 5)", long: "heartbeat-sec"),
                .commandOption("quietMs", help: "Calm period before dropping to idle (default 1000)", long: "quiet-ms"),
                .commandOption("maxFrames", help: "Soft frame cap (default 800)", long: "max-frames"),
                .commandOption("maxMb", help: "Soft size cap in MB (optional)", long: "max-mb"),
                .commandOption("resolutionCap", help: "Cap longest side in px (default 1440)", long: "resolution-cap"),
                .commandOption("diffStrategy", help: "Diff strategy: fast|quality", long: "diff-strategy"),
                .commandOption(
                    "diffBudgetMs",
                    help: "Diff time budget in ms before falling back to fast (default 30 for quality)",
                    long: "diff-budget-ms"
                ),
                .commandOption("path", help: "Output directory", long: "path"),
                .commandOption(
                    "autocleanMinutes",
                    help: "Minutes before temp sessions auto-clean (default 120)",
                    long: "autoclean-minutes"
                )
            ],
            flags: [
                .commandFlag("highlightChanges", help: "Overlay motion boxes on frames", long: "highlight-changes")
            ]
        )
    }
}
