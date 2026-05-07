import Commander
import Foundation
import PeekabooBridge
import PeekabooFoundation

extension DaemonCommand {
    @MainActor
    struct Start: OutputFormattable, RuntimeOptionsConfigurable {
        nonisolated(unsafe) static var commandDescription: CommandDescription {
            MainActorCommandDescription.describe {
                CommandDescription(
                    commandName: "start",
                    abstract: "Start the Peekaboo daemon (on-demand)"
                )
            }
        }

        @Option(name: .long, help: "Override bridge socket path")
        var bridgeSocket: String?

        @Option(name: .long, help: "Window tracker poll interval in milliseconds (default 1000)")
        var pollIntervalMs: Int?

        @Option(name: .long, help: "Seconds to wait for daemon startup (default 3)")
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

            if let status = await client.fetchStatus() {
                self.output(status) {
                    DaemonStatusPrinter.render(status: status)
                }
                return
            }

            let executable = Self.resolveExecutablePath()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            var args = ["daemon", "run", "--mode", "manual"]
            if let bridgeSocket {
                args.append(contentsOf: ["--bridge-socket", bridgeSocket])
            }
            if let pollIntervalMs {
                args.append(contentsOf: ["--poll-interval-ms", "\(pollIntervalMs)"])
            }
            process.arguments = args

            let logURL = DaemonPaths.daemonLogURL()
            let logHandle = try? FileHandle(forWritingTo: logURL)
            logHandle?.seekToEndOfFile()
            process.standardOutput = logHandle
            process.standardError = logHandle
            process.standardInput = FileHandle.nullDevice

            try process.run()

            let deadline = Date().addingTimeInterval(TimeInterval(self.waitSeconds))
            while Date() < deadline {
                if let status = await client.fetchStatus() {
                    self.output(status) {
                        DaemonStatusPrinter.render(status: status)
                    }
                    return
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }

            throw PeekabooError.operationError(message: "Daemon did not start within \(self.waitSeconds)s")
        }

        private static func resolveExecutablePath() -> String {
            if let path = CommandLine.arguments.first {
                return path
            }
            return "/usr/local/bin/peekaboo"
        }
    }
}

extension DaemonCommand.Start: AsyncRuntimeCommand {}

@MainActor
extension DaemonCommand.Start: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.bridgeSocket = values.singleOption("bridge-socket")
        self.pollIntervalMs = try values.decodeOption("pollIntervalMs", as: Int.self)
        if let waitSeconds = try values.decodeOption("waitSeconds", as: Int.self) {
            self.waitSeconds = waitSeconds
        }
    }
}
