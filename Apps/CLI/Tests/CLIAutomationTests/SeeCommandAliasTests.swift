import Testing
@testable import PeekabooCLI

@Suite(.serialized, .tags(.safe))
struct SeeCommandAliasTests {
    @Test
    func `Legacy --output/--save/-o map to --path`() throws {
        let outputCommand = try SeeCommand.parse(["--output", "/tmp/output.png"])
        #expect(outputCommand.path == "/tmp/output.png")

        let saveCommand = try SeeCommand.parse(["--save", "/tmp/save.png"])
        #expect(saveCommand.path == "/tmp/save.png")

        let shortCommand = try SeeCommand.parse(["-o", "/tmp/short.png"])
        #expect(shortCommand.path == "/tmp/short.png")
    }

    @Test
    func `Global --json alias enables JSON output`() throws {
        let command = try SeeCommand.parse([
            "--json",
            "--path", "/tmp/screenshot.png",
        ])
        #expect(command.jsonOutput == true)
    }
}
