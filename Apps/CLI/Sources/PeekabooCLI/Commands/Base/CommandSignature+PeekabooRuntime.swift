import Commander

extension CommandSignature {
    /// Add Peekaboo's standard runtime flags and options (extends Commander defaults).
    func withPeekabooRuntimeFlags() -> CommandSignature {
        let base = self.withStandardRuntimeFlags()

        let xpcServiceOption = OptionDefinition.make(
            label: "xpc-service",
            names: [
                .long("xpc-service"),
                .aliasLong("xpcService"),
            ],
            help: "Override the mach service name for the XPC helper",
            parsing: .singleValue
        )

        let noRemoteFlag = FlagDefinition.make(
            label: "no-remote",
            names: [
                .long("no-remote"),
            ],
            help: "Force local execution; skip the XPC helper even if available"
        )

        return CommandSignature(
            arguments: base.arguments,
            options: base.options + [xpcServiceOption],
            flags: base.flags + [noRemoteFlag],
            optionGroups: base.optionGroups
        )
    }
}
