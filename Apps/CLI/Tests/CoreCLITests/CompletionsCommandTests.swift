import Commander
import Foundation
import Testing
@testable import PeekabooCLI

@Suite("CompletionsCommand")
struct CompletionsCommandTests {
    // MARK: - Shell Resolution

    @Test
    func `Auto-detect defaults to zsh when SHELL is unsupported`() {
        #expect(CompletionsCommand.Shell.parse(nil) == nil)
        #expect(CompletionsCommand.Shell.parse("/bin/unknown-shell") == nil)
        #expect(CompletionsCommand.detectShell() == (CompletionsCommand.Shell.parse(
            ProcessInfo.processInfo.environment["SHELL"]
        ) ?? .zsh))
    }

    @Test
    func `Explicit shell names and paths resolve`() throws {
        var command = CompletionsCommand()
        command.shell = "bash"
        #expect(try command.resolveShell() == .bash)

        command.shell = "/bin/zsh"
        #expect(try command.resolveShell() == .zsh)

        command.shell = "/opt/homebrew/bin/fish"
        #expect(try command.resolveShell() == .fish)

        command.shell = "/usr/local/bin/bash5"
        #expect(try command.resolveShell() == .bash)

        command.shell = "/bin/bash-old"
        #expect(try command.resolveShell() == .bash)

        command.shell = "/bin/zsh-5.8"
        #expect(try command.resolveShell() == .zsh)

        command.shell = "/bin/-bash"
        #expect(try command.resolveShell() == .bash)

        command.shell = "/bin/bash-"
        #expect(try command.resolveShell() == .bash)
    }

    @Test
    func `Unsupported explicit shell throws validation error`() {
        var command = CompletionsCommand()
        command.shell = "nushell"

        #expect(throws: ValidationError.self) {
            _ = try command.resolveShell()
        }
    }

    // MARK: - Metadata Extraction

    @Test
    func `Document is generated from Commander descriptors`() {
        let document = CompletionScriptDocument.make(descriptors: CommanderRegistryBuilder.buildDescriptors())
        #expect(document.commandName == "peekaboo")
        #expect(document.commands.contains(where: { $0.name == "click" }))
        #expect(document.commands.contains(where: { $0.name == "completions" }))
        #expect(document.commands.contains(where: { $0.name == "help" }))
    }

    @Test
    func `Help mirror follows the command tree`() throws {
        let document = CompletionScriptDocument.make(descriptors: CommanderRegistryBuilder.buildDescriptors())
        let help = try #require(document.commands.first(where: { $0.name == "help" }))
        let capture = try #require(help.subcommands.first(where: { $0.name == "capture" }))
        #expect(capture.subcommands.contains(where: { $0.name == "live" }))
    }

    @Test
    func `Aliases from Commander metadata are preserved`() throws {
        let document = CompletionScriptDocument.make(descriptors: CommanderRegistryBuilder.buildDescriptors())
        let clickPath = try #require(document.flattenedPaths.first(where: { $0.path == ["click"] }))
        let names = Set(clickPath.options.flatMap(\.names))

        #expect(names.contains("--json"))
        #expect(names.contains("--json-output"))
        #expect(names.contains("--jsonOutput"))
        #expect(names.contains("-j"))
    }

    @Test
    func `Argument choice metadata is generated from source types`() throws {
        let document = CompletionScriptDocument.make(descriptors: CommanderRegistryBuilder.buildDescriptors())
        let completionsPath = try #require(document.flattenedPaths.first(where: { $0.path == ["completions"] }))
        let shellArgument = try #require(completionsPath.arguments.first)
        let values = shellArgument.choices.map(\.value)

        #expect(values == ["zsh", "bash", "fish"])
    }

    @Test
    func `Root options include help and version`() {
        let document = CompletionScriptDocument.make(descriptors: CommanderRegistryBuilder.buildDescriptors())
        let names = Set(document.rootOptions.flatMap(\.names))

        #expect(names.contains("--help"))
        #expect(names.contains("-h"))
        #expect(names.contains("--version"))
        #expect(names.contains("-V"))
    }

    // MARK: - Script Rendering

    @Test
    func `Bash script uses self-contained helper functions`() {
        let script = CompletionScriptRenderer.render(
            document: CompletionScriptDocument.make(descriptors: CommanderRegistryBuilder.buildDescriptors()),
            for: .bash
        )

        #expect(script.contains("__peekaboo_bash_subcommands"))
        #expect(script.contains("__peekaboo_bash_options"))
        #expect(script.contains("__peekaboo_bash_argument_values"))
        #expect(script.contains("complete -F __peekaboo_bash_complete peekaboo"))
        #expect(!script.contains("_init_completion"))
    }

    @Test
    func `Zsh script uses compdef and dynamic helpers`() {
        let script = CompletionScriptRenderer.render(
            document: CompletionScriptDocument.make(descriptors: CommanderRegistryBuilder.buildDescriptors()),
            for: .zsh
        )

        #expect(script.contains("#compdef peekaboo"))
        #expect(script.contains("__peekaboo_zsh_subcommands"))
        #expect(script.contains("__peekaboo_zsh_compadd_with_help"))
        #expect(script.contains("compdef _peekaboo peekaboo"))
    }

    @Test
    func `Fish script uses dynamic completion function`() {
        let script = CompletionScriptRenderer.render(
            document: CompletionScriptDocument.make(descriptors: CommanderRegistryBuilder.buildDescriptors()),
            for: .fish
        )

        #expect(script.contains("function __peekaboo_fish_complete"))
        #expect(script.contains("commandline -opc"))
        #expect(script.contains("complete -c peekaboo -f -a '(__peekaboo_fish_complete)'"))
    }

    @Test
    func `Scripts include shell argument completions`() {
        let bash = CompletionScriptRenderer.render(
            document: CompletionScriptDocument.make(descriptors: CommanderRegistryBuilder.buildDescriptors()),
            for: .bash
        )
        #expect(bash.contains("zsh"))
        #expect(bash.contains("bash"))
        #expect(bash.contains("fish"))
    }

    @Test
    func `Scripts include global runtime flag aliases`() {
        let zsh = CompletionScriptRenderer.render(
            document: CompletionScriptDocument.make(descriptors: CommanderRegistryBuilder.buildDescriptors()),
            for: .zsh
        )

        #expect(zsh.contains("--json-output"))
        #expect(zsh.contains("--log-level"))
        #expect(zsh.contains("--verbose"))
    }

    @Test
    func `Scripts include curated option value choices`() {
        let bash = CompletionScriptRenderer.render(
            document: CompletionScriptDocument.make(descriptors: CommanderRegistryBuilder.buildDescriptors()),
            for: .bash
        )

        #expect(bash.contains("trace"))
        #expect(bash.contains("warning"))
        #expect(bash.contains("critical"))
    }

    // MARK: - Binding and Registration

    @Test
    func `Binder maps optional shell argument`() throws {
        let parsed = ParsedValues(positional: ["/bin/zsh"], options: [:], flags: [])
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: CompletionsCommand.self,
            parsedValues: parsed
        )
        #expect(command.shell == "/bin/zsh")
    }

    @Test
    func `Completions command is registered`() {
        let definitions = CommandRegistry.definitions()
        let completions = definitions.first { $0.name == "completions" }
        #expect(completions != nil)
        #expect(completions?.category == .core)
    }

    // MARK: - Shell Parse Smoke Tests

    @Test
    func `Generated bash script parses without syntax errors`() throws {
        let script = CompletionScriptRenderer.render(
            document: CompletionScriptDocument.make(descriptors: CommanderRegistryBuilder.buildDescriptors()),
            for: .bash
        )
        let result = try Self.shellCheck(script: script, shell: "bash", args: ["-n"])
        #expect(result.exitCode == 0, "bash -n failed:\n\(result.stderr)")
    }

    @Test
    func `Generated zsh script parses without syntax errors`() throws {
        let script = CompletionScriptRenderer.render(
            document: CompletionScriptDocument.make(descriptors: CommanderRegistryBuilder.buildDescriptors()),
            for: .zsh
        )
        let result = try Self.shellCheck(script: script, shell: "zsh", args: ["-n"])
        #expect(result.exitCode == 0, "zsh -n failed:\n\(result.stderr)")
    }

    @Test(
        .enabled(if: CompletionsCommandTests.fishAvailable)
    )
    func `Generated fish script parses without syntax errors`() throws {
        let fishPath = Self.findExecutable("fish")
        try #require(fishPath != nil, "fish not installed")
        let script = CompletionScriptRenderer.render(
            document: CompletionScriptDocument.make(descriptors: CommanderRegistryBuilder.buildDescriptors()),
            for: .fish
        )
        let result = try Self.shellCheck(script: script, shell: #require(fishPath), args: ["--no-execute"])
        #expect(result.exitCode == 0, "fish --no-execute failed:\n\(result.stderr)")
    }

    // MARK: - Helpers

    nonisolated(unsafe) static let fishAvailable: Bool = {
        let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/usr/local/bin")
            .split(separator: ":")
        return paths.contains { dir in
            FileManager.default.isExecutableFile(atPath: "\(dir)/fish")
        }
    }()

    private struct ShellResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    private static func shellCheck(script: String, shell: String, args: [String]) throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [shell] + args

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        stdinPipe.fileHandleForWriting.write(Data(script.utf8))
        stdinPipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        return ShellResult(
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }

    private static func findExecutable(_ name: String) -> String? {
        let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/usr/local/bin")
            .split(separator: ":")
        for dir in paths {
            let candidate = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
}
