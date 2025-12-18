import Commander

extension MoveCommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            arguments: [
                .make(
                    label: "coordinates",
                    help: "Coordinates as x,y",
                    isOptional: true
                ),
            ],
            options: [
                .commandOption(
                    "coords",
                    help: "Coordinates as x,y (alias for positional argument)",
                    long: "coords"
                ),
                .commandOption(
                    "to",
                    help: "Move to element by text/label",
                    long: "to"
                ),
                .commandOption(
                    "id",
                    help: "Move to element by ID",
                    long: "id"
                ),
                .commandOption(
                    "duration",
                    help: "Movement duration in milliseconds",
                    long: "duration"
                ),
                .commandOption(
                    "steps",
                    help: "Number of steps for smooth movement",
                    long: "steps"
                ),
                .commandOption(
                    "profile",
                    help: "Movement profile (linear or human)",
                    long: "profile"
                ),
                .commandOption(
                    "snapshot",
                    help: "Snapshot ID for element resolution",
                    long: "snapshot"
                ),
            ],
            flags: [
                .commandFlag(
                    "center",
                    help: "Move to screen center",
                    long: "center"
                ),
                .commandFlag(
                    "smooth",
                    help: "Use smooth movement animation",
                    long: "smooth"
                ),
            ],
            optionGroups: [
                InteractionTargetOptions.commanderSignature(),
                FocusCommandOptions.commanderSignature(),
            ]
        )
    }
}
