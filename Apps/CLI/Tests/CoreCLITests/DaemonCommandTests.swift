import Testing
@testable import PeekabooCLI

@Suite(.tags(.safe))
struct DaemonCommandTests {
    @Test
    func `DaemonCommand description`() {
        let config = DaemonCommand.commandDescription
        #expect(config.commandName == "daemon")
        #expect(config.abstract == "Manage the headless Peekaboo daemon")
        #expect(config.subcommands.count == 4)
    }

    @Test
    func `Daemon start defaults`() throws {
        let command = try DaemonCommand.Start.parse([])
        #expect(command.bridgeSocket == nil)
        #expect(command.pollIntervalMs == nil)
        #expect(command.waitSeconds == 3)
    }

    @Test
    func `Daemon stop defaults`() throws {
        let command = try DaemonCommand.Stop.parse([])
        #expect(command.bridgeSocket == nil)
        #expect(command.waitSeconds == 3)
    }

    @Test
    func `Daemon status defaults`() throws {
        let command = try DaemonCommand.Status.parse([])
        #expect(command.bridgeSocket == nil)
    }

    @Test
    func `Daemon run parsing`() throws {
        let args = ["--mode", "manual", "--bridge-socket", "/tmp/peekaboo.sock", "--poll-interval-ms", "500"]
        let command = try DaemonCommand.Run.parse(args)
        #expect(command.mode == "manual")
        #expect(command.bridgeSocket == "/tmp/peekaboo.sock")
        #expect(command.pollIntervalMs == 500)
    }
}
