import Testing
@testable import Commander

private let signature = CommandSignature(
    arguments: [ArgumentDefinition(label: "path", help: nil, isOptional: false)],
    options: [
        OptionDefinition(label: "app", names: [.long("app")], help: nil, parsing: .singleValue),
        OptionDefinition(label: "includes", names: [.long("include")], help: nil, parsing: .upToNextOption),
        OptionDefinition(label: "rest", names: [.long("rest")], help: nil, parsing: .remaining),
    ],
    flags: [FlagDefinition(label: "dryRun", names: [.long("dry-run")], help: nil)])

@Test
func parsesOptionsFlagsAndArguments() throws {
    let parser = CommandParser(signature: signature)
    let values = try parser.parse(arguments: [
        "Project",
        "--app",
        "Safari",
        "--dry-run",
        "--include",
        "a",
        "b",
        "--",
        "tail1",
        "tail2",
    ])

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

@Test
func programResolvesCommand() throws {
    let descriptor = CommandDescriptor(name: "demo", abstract: "", discussion: nil, signature: signature)
    let program = Program(descriptors: [descriptor])
    let invocation = try program.resolve(argv: ["peekaboo", "demo", "Workspace"])
    #expect(invocation.descriptor.name == "demo")
    #expect(invocation.parsedValues.positional == ["Workspace"])
    #expect(invocation.path == ["demo"])
}

@Test
func programDetectsUnknownCommand() {
    let program = Program(descriptors: [])
    #expect(throws: CommanderProgramError.unknownCommand("foo")) {
        _ = try program.resolve(argv: ["foo"])
    }
}

@Test
func programResolvesNestedSubcommand() throws {
    let child = CommandDescriptor(name: "windows", abstract: "", discussion: nil, signature: signature)
    let parent = CommandDescriptor(
        name: "list",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [child])
    let program = Program(descriptors: [parent])
    let invocation = try program.resolve(argv: ["peekaboo", "list", "windows", "Workspace"])
    #expect(invocation.descriptor.name == "windows")
    #expect(invocation.parsedValues.positional == ["Workspace"])
    #expect(invocation.path == ["list", "windows"])
}

@Test
func programUsesDefaultSubcommandWhenMissing() throws {
    let runtimeSignature = CommandSignature().withStandardRuntimeFlags()
    let apps = CommandDescriptor(
        name: "apps",
        abstract: "",
        discussion: nil,
        signature: runtimeSignature)
    let parent = CommandDescriptor(
        name: "list",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [apps],
        defaultSubcommandName: "apps")
    let program = Program(descriptors: [parent])
    let invocation = try program.resolve(argv: ["peekaboo", "list", "--json-output"])
    #expect(invocation.descriptor.name == "apps")
    #expect(invocation.parsedValues.flags.contains("jsonOutput"))
    #expect(invocation.path == ["list", "apps"])
}

@Test
func programErrorsWhenSubcommandMissing() {
    let child = CommandDescriptor(name: "apps", abstract: "", discussion: nil, signature: signature)
    let parent = CommandDescriptor(
        name: "list",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [child])
    let program = Program(descriptors: [parent])
    #expect(throws: CommanderProgramError.missingSubcommand(command: "list")) {
        _ = try program.resolve(argv: ["peekaboo", "list"])
    }
}

@Test
func programErrorsOnUnknownSubcommand() {
    let child = CommandDescriptor(name: "windows", abstract: "", discussion: nil, signature: signature)
    let parent = CommandDescriptor(
        name: "list",
        abstract: "",
        discussion: nil,
        signature: CommandSignature(),
        subcommands: [child])
    let program = Program(descriptors: [parent])
    #expect(throws: CommanderProgramError.unknownSubcommand(command: "list", name: "apps")) {
        _ = try program.resolve(argv: ["peekaboo", "list", "apps"])
    }
}
