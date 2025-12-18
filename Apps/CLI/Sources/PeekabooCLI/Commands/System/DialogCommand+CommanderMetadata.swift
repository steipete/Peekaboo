import Commander

extension DialogCommand.ClickSubcommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            options: [
                .commandOption("button", help: "Button text to click", long: "button"),
                .commandOption("app", help: "Target application name, bundle ID, or 'PID:12345'", long: "app"),
                .commandOption("pid", help: "Target application by process ID", long: "pid"),
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

extension DialogCommand.InputSubcommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            options: [
                .commandOption("text", help: "Text to enter", long: "text"),
                .commandOption("field", help: "Field label or placeholder", long: "field"),
                .commandOption("index", help: "Field index (0-based)", long: "index"),
                .commandOption("app", help: "Target application name, bundle ID, or 'PID:12345'", long: "app"),
                .commandOption("pid", help: "Target application by process ID", long: "pid"),
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
            ],
            flags: [
                .commandFlag("clear", help: "Clear existing text first", long: "clear"),
            ]
        )
    }
}

extension DialogCommand.FileSubcommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            options: [
                .commandOption("path", help: "Full file path to navigate to", long: "path"),
                .commandOption("name", help: "File name to enter", long: "name"),
                .commandOption(
                    "select",
                    help: "Button to click after entering path/name (omit or 'default' to click OKButton)",
                    long: "select"
                ),
                .commandOption("app", help: "Target application name, bundle ID, or 'PID:12345'", long: "app"),
                .commandOption("pid", help: "Target application by process ID", long: "pid"),
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
            ],
            flags: [
                .commandFlag(
                    "ensureExpanded",
                    help: "Ensure file dialogs are expanded (Show Details)",
                    long: "ensure-expanded"
                ),
            ]
        )
    }
}

extension DialogCommand.DismissSubcommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            options: [
                .commandOption("app", help: "Target application name, bundle ID, or 'PID:12345'", long: "app"),
                .commandOption("pid", help: "Target application by process ID", long: "pid"),
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
            ],
            flags: [
                .commandFlag("force", help: "Force dismiss with Escape", long: "force"),
            ]
        )
    }
}

extension DialogCommand.ListSubcommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            options: [
                .commandOption("app", help: "Target application name, bundle ID, or 'PID:12345'", long: "app"),
                .commandOption("pid", help: "Target application by process ID", long: "pid"),
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
