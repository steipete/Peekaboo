import Darwin
import Foundation
import PeekabooBridge

enum DaemonLaunchPolicy {
    static func shouldAutoStartDaemon(
        options: CommandRuntimeOptions,
        environment: [String: String]
    ) -> Bool {
        options.autoStartDaemon &&
            BridgeSocketResolver.explicitBridgeSocket(options: options, environment: environment) == nil
    }

    static func daemonSocketPath(environment: [String: String]) -> String {
        if let socket = environment["PEEKABOO_DAEMON_SOCKET"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !socket.isEmpty {
            return socket
        }
        return PeekabooBridgeConstants.peekabooSocketPath
    }

    static func daemonIdleTimeoutSeconds(environment: [String: String]) -> TimeInterval {
        guard let raw = environment["PEEKABOO_DAEMON_IDLE_TIMEOUT_SECONDS"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            let value = TimeInterval(raw),
            value > 0 else {
            return CommandRuntime.defaultDaemonIdleTimeoutSeconds
        }
        return value
    }

    static func onDemandDaemonArguments(socketPath: String, idleTimeoutSeconds: TimeInterval) -> [String] {
        [
            "daemon",
            "run",
            "--mode",
            "auto",
            "--bridge-socket",
            socketPath,
            "--idle-timeout-seconds",
            String(format: "%.3f", idleTimeoutSeconds),
        ]
    }

    static func startOnDemandDaemon(socketPath: String, environment: [String: String]) async -> Bool {
        let client = DaemonControlClient(socketPath: socketPath)
        let lockHandle = DaemonPaths.openDaemonStartupLock()
        if let fileDescriptor = lockHandle?.fileDescriptor {
            flock(fileDescriptor, LOCK_EX)
        }
        defer {
            if let fileDescriptor = lockHandle?.fileDescriptor {
                flock(fileDescriptor, LOCK_UN)
            }
            try? lockHandle?.close()
        }

        if await client.fetchStatus() != nil {
            return true
        }

        let executable = CommandLine.arguments.first ?? "/usr/local/bin/peekaboo"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = self.onDemandDaemonArguments(
            socketPath: socketPath,
            idleTimeoutSeconds: self.daemonIdleTimeoutSeconds(environment: environment)
        )
        let logHandle = DaemonPaths.openDaemonLogForAppend() ?? FileHandle.nullDevice
        process.standardOutput = logHandle
        process.standardError = logHandle
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return false
        }

        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if await client.fetchStatus() != nil {
                return true
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return false
    }
}
