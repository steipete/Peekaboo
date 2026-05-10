import Commander
import Foundation
import PeekabooBridge

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

struct DaemonControlClient {
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

enum DaemonPaths {
    static func daemonLogURL() -> URL {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".peekaboo")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("daemon.log")
    }

    static func openDaemonLogForAppend() -> FileHandle? {
        self.openFileForAppend(at: self.daemonLogURL())
    }

    static func openDaemonStartupLock() -> FileHandle? {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".peekaboo")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return self.openFileForAppend(at: root.appendingPathComponent("daemon-start.lock"))
    }

    static func openFileForAppend(at fileURL: URL) -> FileHandle? {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        let handle = try? FileHandle(forWritingTo: fileURL)
        handle?.seekToEndOfFile()
        return handle
    }
}

enum DaemonStatusPrinter {
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

        if let browser = status.browser {
            print("")
            print("Browser MCP")
            print("-----------")
            print("Connected: \(browser.isConnected ? "yes" : "no")")
            print("Tools: \(browser.toolCount)")
            print("Detected Chrome: \(browser.detectedBrowsers.count)")
        }

        if let activity = status.activity {
            print("")
            print("Activity")
            print("--------")
            print("Active Requests: \(activity.activeRequests)")
            if let lastActivityAt = activity.lastActivityAt {
                print("Last Activity: \(Self.formatDate(lastActivityAt))")
            }
            if let idleTimeoutSeconds = activity.idleTimeoutSeconds {
                print("Idle Timeout: \(String(format: "%.0f", idleTimeoutSeconds))s")
            }
            if let idleExitAt = activity.idleExitAt {
                print("Idle Exit: \(Self.formatDate(idleExitAt))")
            }
        }
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
