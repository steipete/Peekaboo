import Commander

extension CommandSignature {
    /// Add Peekaboo's standard runtime flags and options (extends Commander defaults).
    func withPeekabooRuntimeFlags() -> CommandSignature {
        let base = self.withStandardRuntimeFlags()

        let bridgeSocketOption = OptionDefinition.make(
            label: "bridge-socket",
            names: [
                .long("bridge-socket"),
                .aliasLong("bridgeSocket"),
            ],
            help: "Override the socket path for a Peekaboo Bridge host",
            parsing: .singleValue
        )

        let noRemoteFlag = FlagDefinition.make(
            label: "no-remote",
            names: [
                .long("no-remote"),
            ],
            help: "Force local execution; skip remote hosts even if available"
        )

        return CommandSignature(
            arguments: base.arguments,
            options: base.options + [bridgeSocketOption],
            flags: base.flags + [noRemoteFlag],
            optionGroups: base.optionGroups
        )
    }
}
