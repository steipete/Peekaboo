import Commander

extension ToolsCommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature(
            flags: [
                .commandFlag(
                    "noSort",
                    help: "Disable alphabetical sorting",
                    long: "no-sort"
                ),
            ]
        )
    }
}
