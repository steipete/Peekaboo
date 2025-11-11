import Commander

extension MenuCommand.ClickSubcommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            options: [
                .commandOption(
                    "app",
                    help: "Target application by name, bundle ID, or 'PID:12345'",
                    long: "app"
                ),
                .commandOption(
                    "pid",
                    help: "Target application by process ID",
                    long: "pid"
                ),
                .commandOption(
                    "item",
                    help: "Menu item to click",
                    long: "item"
                ),
                .commandOption(
                    "path",
                    help: "Menu path for nested items",
                    long: "path"
                ),
            ],
            optionGroups: [
                FocusCommandOptions.commanderSignature(),
            ]
        )
    }
}

extension MenuCommand.ClickExtraSubcommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            options: [
                .commandOption(
                    "title",
                    help: "Title of the menu extra",
                    long: "title"
                ),
                .commandOption(
                    "item",
                    help: "Menu item to click after opening the extra",
                    long: "item"
                ),
            ]
        )
    }
}

extension MenuCommand.ListSubcommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            options: [
                .commandOption(
                    "app",
                    help: "Target application by name, bundle ID, or 'PID:12345'",
                    long: "app"
                ),
                .commandOption(
                    "pid",
                    help: "Target application by process ID",
                    long: "pid"
                ),
            ],
            flags: [
                .commandFlag(
                    "includeDisabled",
                    help: "Include disabled menu items",
                    long: "include-disabled"
                ),
            ],
            optionGroups: [
                FocusCommandOptions.commanderSignature(),
            ]
        )
    }
}

extension MenuCommand.ListAllSubcommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            flags: [
                .commandFlag(
                    "includeDisabled",
                    help: "Include disabled menu items",
                    long: "include-disabled"
                ),
                .commandFlag(
                    "includeFrames",
                    help: "Include frame data for each item",
                    long: "include-frames"
                ),
            ]
        )
    }
}
