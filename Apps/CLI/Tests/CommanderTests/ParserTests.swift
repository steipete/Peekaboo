@testable import Commander
import Testing

private let signature = CommandSignature(
    arguments: [ArgumentDefinition(label: "path", help: nil, isOptional: false)],
    options: [
        OptionDefinition(label: "app", names: [.long("app")], help: nil, parsing: .singleValue),
        OptionDefinition(label: "includes", names: [.long("include")], help: nil, parsing: .upToNextOption),
        OptionDefinition(label: "rest", names: [.long("rest")], help: nil, parsing: .remaining)
    ],
    flags: [FlagDefinition(label: "dryRun", names: [.long("dry-run")], help: nil)]
)

@Test
func parsesOptionsFlagsAndArguments() throws {
    let parser = CommandParser(signature: signature)
    let values = try parser.parse(arguments: ["Project", "--app", "Safari", "--dry-run", "--include", "a", "b", "--", "tail1", "tail2"])

    #expect(values.options["app"] == ["Safari"])
    #expect(values.flags.contains("dryRun"))
    #expect(values.options["includes"] == ["a", "b"])
    #expect(values.options["rest"] == ["tail1", "tail2"])
    #expect(values.positional == ["Project"])
}

@Test
func errorsOnUnknownOption() {
    let parser = CommandParser(signature: signature)
    #expect(throws: CommanderError.unknownOption("--foo")) {
        _ = try parser.parse(arguments: ["--foo"])
    }
}
