import Testing
@testable import PeekabooCLI

@Suite("Daemon Command Tests", .tags(.safe))
struct DaemonCommandTests {
    @Test("DaemonCommand description")
    func daemonCommandDescription() {
        let config = DaemonCommand.commandDescription
        #expect(config.commandName == "daemon")
        #expect(config.abstract == "Manage the headless Peekaboo daemon")
        #expect(config.subcommands.count == 4)
    }

    @Test("Daemon start defaults")
    func daemonStartDefaults() throws {
        let command = try DaemonCommand.Start.parse([])
        #expect(command.bridgeSocket == nil)
        #expect(command.pollIntervalMs == nil)
        #expect(command.waitSeconds == 3)
    }

    @Test("Daemon stop defaults")
    func daemonStopDefaults() throws {
        let command = try DaemonCommand.Stop.parse([])
        #expect(command.bridgeSocket == nil)
        #expect(command.waitSeconds == 3)
    }

    @Test("Daemon status defaults")
    func daemonStatusDefaults() throws {
        let command = try DaemonCommand.Status.parse([])
        #expect(command.bridgeSocket == nil)
    }

    @Test("Daemon run parsing")
    func daemonRunParsing() throws {
        let args = ["--mode", "manual", "--bridge-socket", "/tmp/peekaboo.sock", "--poll-interval-ms", "500"]
        let command = try DaemonCommand.Run.parse(args)
        #expect(command.mode == "manual")
        #expect(command.bridgeSocket == "/tmp/peekaboo.sock")
        #expect(command.pollIntervalMs == 500)
    }
}
