import Commander

extension PermissionsCommand.StatusSubcommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature()
    }
}

extension PermissionsCommand.GrantSubcommand: CommanderSignatureProviding {
    static func commanderSignature() -> CommandSignature {
        CommandSignature()
    }
}
