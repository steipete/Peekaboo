import Commander

extension FocusCommandOptions {
    static func commanderSignature(includeBackgroundDelivery: Bool = false) -> CommandSignature {
        var flags: [FlagDefinition] = [
            .commandFlag(
                "noAutoFocus",
                help: "Disable automatic focus before interaction",
                long: "no-auto-focus"
            ),
            .commandFlag(
                "spaceSwitch",
                help: "Switch to the window's Space if on a different Space",
                long: "space-switch"
            ),
            .commandFlag(
                "bringToCurrentSpace",
                help: "Bring window to current Space instead of switching",
                long: "bring-to-current-space"
            ),
        ]
        if includeBackgroundDelivery {
            flags.append(.commandFlag(
                "focusBackground",
                help: "Send the hotkey to the target process without focusing it",
                long: "focus-background"
            ))
        }

        return CommandSignature(
            options: [
                .commandOption(
                    "focusTimeoutSeconds",
                    help: "Timeout for focus operations in seconds",
                    long: "focus-timeout-seconds"
                ),
                .commandOption(
                    "focusRetryCount",
                    help: "Number of retries for focus operations",
                    long: "focus-retry-count"
                ),
            ],
            flags: flags
        )
    }
}
