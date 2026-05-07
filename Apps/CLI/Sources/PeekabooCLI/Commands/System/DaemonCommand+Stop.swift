import Commander
import Foundation
import PeekabooBridge
import PeekabooFoundation

extension DaemonCommand {
    @MainActor
    struct Stop: OutputFormattable, RuntimeOptionsConfigurable {
        nonisolated(unsafe) static var commandDescription: CommandDescription {
            MainActorCommandDescription.describe {
                CommandDescription(
                    commandName: "stop",
                    abstract: "Stop the Peekaboo daemon"
                )
            }
        }

        @Option(name: .long, help: "Override bridge socket path")
        var bridgeSocket: String?

        @Option(name: .long, help: "Seconds to wait for daemon shutdown (default 3)")
        var waitSeconds: Int = 3

        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var outputLogger: Logger {
            self.logger
        }

        var jsonOutput: Bool {
            self.resolvedRuntime.configuration.jsonOutput
        }

        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            let socketPath = self.bridgeSocket ?? PeekabooBridgeConstants.peekabooSocketPath
            let client = DaemonControlClient(socketPath: socketPath)

            guard let status = await client.fetchStatus() else {
                let stopped = PeekabooDaemonStatus(running: false)
                self.output(stopped) {
                    DaemonStatusPrinter.render(status: stopped)
                }
                return
            }

            if status.mode == nil {
                throw PeekabooError.operationError(message: "Connected host does not support daemon stop")
            }

            let stopped = try await client.stopDaemon()
            guard stopped else {
                throw PeekabooError.operationError(message: "Daemon refused stop request")
            }

            let deadline = Date().addingTimeInterval(TimeInterval(self.waitSeconds))
            while Date() < deadline {
                if await client.fetchStatus() == nil {
                    let stopped = PeekabooDaemonStatus(running: false)
                    self.output(stopped) {
                        DaemonStatusPrinter.render(status: stopped)
                    }
                    return
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }

            throw PeekabooError.operationError(message: "Daemon did not stop within \(self.waitSeconds)s")
        }
    }
}

extension DaemonCommand.Stop: AsyncRuntimeCommand {}

@MainActor
extension DaemonCommand.Stop: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.bridgeSocket = values.singleOption("bridge-socket")
        if let waitSeconds = try values.decodeOption("waitSeconds", as: Int.self) {
            self.waitSeconds = waitSeconds
        }
    }
}
