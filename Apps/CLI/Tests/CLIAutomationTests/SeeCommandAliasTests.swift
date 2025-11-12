import Testing
@testable import PeekabooCLI

@Suite("SeeCommand Alias Tests", .serialized, .tags(.safe))
struct SeeCommandAliasTests {
    @Test("Legacy --output/--save/-o map to --path")
    func parseOutputAliases() throws {
        let outputCommand = try SeeCommand.parse(["--output", "/tmp/output.png"])
        #expect(outputCommand.path == "/tmp/output.png")

        let saveCommand = try SeeCommand.parse(["--save", "/tmp/save.png"])
        #expect(saveCommand.path == "/tmp/save.png")

        let shortCommand = try SeeCommand.parse(["-o", "/tmp/short.png"])
        #expect(shortCommand.path == "/tmp/short.png")
    }

    @Test("Global --json alias enables JSON output")
    func parseJsonAlias() throws {
        let command = try SeeCommand.parse([
            "--json",
            "--path", "/tmp/screenshot.png",
        ])
        #expect(command.jsonOutput == true)
    }
}
