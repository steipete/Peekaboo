import Commander
import Foundation
import PeekabooBridge
import PeekabooCore

extension DaemonCommand {
    @MainActor
    struct Run: AsyncRuntimeCommand, CommanderBindableCommand, RuntimeOptionsConfigurable {
        nonisolated(unsafe) static var commandDescription: CommandDescription {
            MainActorCommandDescription.describe {
                CommandDescription(
                    commandName: "run",
                    abstract: "Run the daemon (internal)"
                )
            }
        }

        @Option(name: .long, help: "Daemon mode (manual, mcp)")
        var mode: String = "manual"

        @Option(name: .long, help: "Override bridge socket path")
        var bridgeSocket: String?

        @Option(name: .long, help: "Window tracker poll interval in milliseconds (default 1000)")
        var pollIntervalMs: Int?

        @Option(name: .long, help: "Idle seconds before auto daemon shutdown")
        var idleTimeoutSeconds: Double?

        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            let pollInterval = TimeInterval(Double(self.pollIntervalMs ?? 1000) / 1000.0)
            let socketPath = self.bridgeSocket ?? PeekabooBridgeConstants.peekabooSocketPath

            let normalizedMode = self.mode.lowercased()
            let config: PeekabooDaemon.Configuration = if normalizedMode == "auto" {
                .auto(
                    bridgeSocketPath: socketPath,
                    windowPollInterval: pollInterval,
                    idleTimeout: self.idleTimeoutSeconds ?? CommandRuntime.defaultDaemonIdleTimeoutSeconds
                )
            } else if normalizedMode == "mcp" {
                .mcp(bridgeSocketPath: socketPath, windowPollInterval: pollInterval)
            } else {
                .manual(bridgeSocketPath: socketPath, windowPollInterval: pollInterval)
            }

            let daemon = PeekabooDaemon(configuration: config)
            await daemon.runUntilStop()
        }

        mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
            if let modeOption = values.singleOption("mode") {
                self.mode = modeOption
            }
            if let socketOption = values.singleOption("bridge-socket") {
                self.bridgeSocket = socketOption
            }
            if let pollMs = try values.decodeOption("pollIntervalMs", as: Int.self) {
                self.pollIntervalMs = pollMs
            }
            if let idleSeconds = try values.decodeOption("idleTimeoutSeconds", as: Double.self) {
                self.idleTimeoutSeconds = idleSeconds
            }
        }
    }
}
