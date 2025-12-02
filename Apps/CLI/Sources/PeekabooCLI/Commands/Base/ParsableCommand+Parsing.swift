import Commander

extension ParsableCommand {
    static func parse(_ arguments: [String]) throws -> Self {
        let instance = Self()
        let signature = CommandSignature.describe(instance)
            .flattened()
            .withPeekabooRuntimeFlags()
        let parser = CommandParser(signature: signature)
        let parsedValues = try parser.parse(arguments: arguments)
        return try CommanderCLIBinder.instantiateCommand(ofType: Self.self, parsedValues: parsedValues)
    }
}
