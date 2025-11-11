import Commander

extension DialogCommand.ClickSubcommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            options: [
                .commandOption("button", help: "Button text to click", long: "button"),
                .commandOption("window", help: "Specific window/sheet title", long: "window"),
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
                .commandOption("select", help: "Button to click after entering path/name", long: "select"),
            ]
        )
    }
}

extension DialogCommand.DismissSubcommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            options: [
                .commandOption("window", help: "Window/sheet title to target", long: "window"),
            ],
            flags: [
                .commandFlag("force", help: "Force dismiss with Escape", long: "force"),
            ]
        )
    }
}

extension DialogCommand.ListSubcommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature()
    }
}
