import Commander
import Foundation
import PeekabooBridge
import PeekabooCore
import PeekabooFoundation

/// Manage the Peekaboo headless daemon lifecycle.
@MainActor
struct DaemonCommand: ParsableCommand {
    static let commandDescription = CommandDescription(
        commandName: "daemon",
        abstract: "Manage the headless Peekaboo daemon",
        discussion: """
        Control the on-demand Peekaboo daemon.

        Examples:
          peekaboo daemon start
          peekaboo daemon status
          peekaboo daemon stop
        """,
        subcommands: [Start.self, Stop.self, Status.self, Run.self],
        defaultSubcommand: Status.self,
        showHelpOnEmptyInvocation: false
    )
}

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

        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

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

        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

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

    @MainActor
    struct Status: OutputFormattable, RuntimeOptionsConfigurable {
        nonisolated(unsafe) static var commandDescription: CommandDescription {
            MainActorCommandDescription.describe {
                CommandDescription(
                    commandName: "status",
                    abstract: "Show daemon status"
                )
            }
        }

        @Option(name: .long, help: "Override bridge socket path")
        var bridgeSocket: String?

        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }

        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            let socketPath = self.bridgeSocket ?? PeekabooBridgeConstants.peekabooSocketPath
            let client = DaemonControlClient(socketPath: socketPath)

            if let status = await client.fetchStatus() {
                self.output(status) {
                    DaemonStatusPrinter.render(status: status)
                }
            } else {
                let stopped = PeekabooDaemonStatus(running: false)
                self.output(stopped) {
                    DaemonStatusPrinter.render(status: stopped)
                }
            }
        }
    }

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

        @RuntimeStorage private var runtime: CommandRuntime?
        var runtimeOptions = CommandRuntimeOptions()

        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            let pollInterval = TimeInterval(Double(self.pollIntervalMs ?? 1000) / 1000.0)
            let socketPath = self.bridgeSocket ?? PeekabooBridgeConstants.peekabooSocketPath

            let config: PeekabooDaemon.Configuration = if self.mode.lowercased() == "mcp" {
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

extension DaemonCommand.Status: AsyncRuntimeCommand {}

@MainActor
extension DaemonCommand.Status: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.bridgeSocket = values.singleOption("bridge-socket")
    }
}

private struct DaemonControlClient {
    let socketPath: String

    func fetchStatus() async -> PeekabooDaemonStatus? {
        let client = PeekabooBridgeClient(socketPath: self.socketPath)
        do {
            return try await client.daemonStatus()
        } catch let envelope as PeekabooBridgeErrorEnvelope {
            if envelope.code == .operationNotSupported {
                return await self.fallbackHandshake(client: client)
            }
            return nil
        } catch {
            return nil
        }
    }

    func stopDaemon() async throws -> Bool {
        let client = PeekabooBridgeClient(socketPath: self.socketPath)
        return try await client.daemonStop()
    }

    private func fallbackHandshake(client: PeekabooBridgeClient) async -> PeekabooDaemonStatus? {
        let identity = PeekabooBridgeClientIdentity(
            bundleIdentifier: Bundle.main.bundleIdentifier,
            teamIdentifier: nil,
            processIdentifier: getpid(),
            hostname: Host.current().name
        )
        do {
            let handshake = try await client.handshake(client: identity)
            let bridge = PeekabooDaemonBridgeStatus(
                socketPath: self.socketPath,
                hostKind: handshake.hostKind,
                allowedOperations: handshake.supportedOperations
            )
            return PeekabooDaemonStatus(
                running: true,
                pid: nil,
                startedAt: nil,
                mode: nil,
                bridge: bridge,
                permissions: handshake.permissions,
                snapshots: nil,
                windowTracker: nil
            )
        } catch {
            return nil
        }
    }
}

private enum DaemonPaths {
    static func daemonLogURL() -> URL {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".peekaboo")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("daemon.log")
    }
}

private enum DaemonStatusPrinter {
    static func render(status: PeekabooDaemonStatus) {
        print("Peekaboo Daemon")
        print("==============")

        guard status.running else {
            print("Status: not running")
            return
        }

        if let mode = status.mode {
            print("Mode: \(mode.rawValue)")
        }
        if let pid = status.pid {
            print("PID: \(pid)")
        }
        if let startedAt = status.startedAt {
            print("Started: \(Self.formatDate(startedAt))")
        }

        if let bridge = status.bridge {
            print("")
            print("Bridge")
            print("------")
            print("Socket: \(bridge.socketPath)")
            print("Host: \(bridge.hostKind.rawValue)")
            print("Ops: \(bridge.allowedOperations.count)")
        }

        if let permissions = status.permissions {
            print("")
            print("Permissions")
            print("-----------")
            print("Screen Recording: \(permissions.screenRecording ? "granted" : "missing")")
            print("Accessibility: \(permissions.accessibility ? "granted" : "missing")")
            if permissions.appleScript {
                print("AppleScript: granted")
            }
        }

        if let snapshots = status.snapshots {
            print("")
            print("Snapshots")
            print("---------")
            print("Backend: \(snapshots.backend)")
            print("Count: \(snapshots.snapshotCount)")
            if let lastAccessedAt = snapshots.lastAccessedAt {
                print("Last Access: \(Self.formatDate(lastAccessedAt))")
            }
            print("Path: \(snapshots.storagePath)")
        }

        if let tracker = status.windowTracker {
            print("")
            print("Window Tracker")
            print("--------------")
            print("Tracked Windows: \(tracker.trackedWindows)")
            if let lastEventAt = tracker.lastEventAt {
                print("Last Event: \(Self.formatDate(lastEventAt))")
            }
            if let lastPollAt = tracker.lastPollAt {
                print("Last Poll: \(Self.formatDate(lastPollAt))")
            }
            print("AX Observers: \(tracker.axObserverCount)")
            print("Poll Interval: \(tracker.cgPollIntervalMs)ms")
        }
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
