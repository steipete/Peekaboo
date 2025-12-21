import Foundation
import os.log
import PeekabooAutomationKit
import PeekabooBridge
import PeekabooFoundation

@MainActor
public final class PeekabooDaemon: PeekabooDaemonControlProviding {
    public struct Configuration: Sendable {
        public let mode: PeekabooDaemonMode
        public let bridgeSocketPath: String
        public let allowlistedTeams: Set<String>
        public let allowlistedBundles: Set<String>
        public let allowedOperations: Set<PeekabooBridgeOperation>
        public let windowTrackingEnabled: Bool
        public let windowPollInterval: TimeInterval
        public let hostKind: PeekabooBridgeHostKind
        public let exitOnStop: Bool

        public init(
            mode: PeekabooDaemonMode,
            bridgeSocketPath: String = PeekabooBridgeConstants.peekabooSocketPath,
            allowlistedTeams: Set<String> = ["Y5PE65HELJ"],
            allowlistedBundles: Set<String> = [],
            allowedOperations: Set<PeekabooBridgeOperation> = PeekabooBridgeOperation.remoteDefaultAllowlist,
            windowTrackingEnabled: Bool = true,
            windowPollInterval: TimeInterval = 1.0,
            hostKind: PeekabooBridgeHostKind,
            exitOnStop: Bool = false)
        {
            self.mode = mode
            self.bridgeSocketPath = bridgeSocketPath
            self.allowlistedTeams = allowlistedTeams
            self.allowlistedBundles = allowlistedBundles
            self.allowedOperations = allowedOperations
            self.windowTrackingEnabled = windowTrackingEnabled
            self.windowPollInterval = windowPollInterval
            self.hostKind = hostKind
            self.exitOnStop = exitOnStop
        }

        public static func manual(
            bridgeSocketPath: String = PeekabooBridgeConstants.peekabooSocketPath,
            windowPollInterval: TimeInterval = 1.0) -> Configuration
        {
            Configuration(
                mode: .manual,
                bridgeSocketPath: bridgeSocketPath,
                allowlistedTeams: [],
                windowTrackingEnabled: true,
                windowPollInterval: windowPollInterval,
                hostKind: .onDemand)
        }

        public static func mcp(
            bridgeSocketPath: String = PeekabooBridgeConstants.peekabooSocketPath,
            windowPollInterval: TimeInterval = 1.0) -> Configuration
        {
            Configuration(
                mode: .mcp,
                bridgeSocketPath: bridgeSocketPath,
                allowlistedTeams: [],
                windowTrackingEnabled: true,
                windowPollInterval: windowPollInterval,
                hostKind: .inProcess,
                exitOnStop: true)
        }
    }

    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "Daemon")
    private let configuration: Configuration
    private let services: PeekabooServices
    private let startTime: Date
    private var bridgeHost: PeekabooBridgeHost?
    private var windowTracker: WindowTrackerService?
    private var stopContinuation: CheckedContinuation<Void, Never>?
    private var isStopping = false

    public init(configuration: Configuration) {
        self.configuration = configuration
        self.services = PeekabooServices(snapshotManager: InMemorySnapshotManager())
        self.startTime = Date()
    }

    public func start() async {
        self.services.installAgentRuntimeDefaults()
        self.services.ensureVisualizerConnection()

        if self.configuration.windowTrackingEnabled {
            let tracker = WindowTrackerService(
                configuration: WindowTrackerConfiguration(pollInterval: self.configuration.windowPollInterval))
            tracker.start()
            WindowMovementTracking.provider = tracker
            self.windowTracker = tracker
        }

        if self.bridgeHost == nil {
            self.bridgeHost = PeekabooBridgeBootstrap.startHost(
                services: self.services,
                hostKind: self.configuration.hostKind,
                socketPath: self.configuration.bridgeSocketPath,
                allowlistedTeams: self.configuration.allowlistedTeams,
                allowlistedBundles: self.configuration.allowlistedBundles,
                daemonControl: self,
                allowedOperations: self.configuration.allowedOperations)
        }

        self.logger.info("Peekaboo daemon started mode=\(self.configuration.mode.rawValue)")
    }

    public func runUntilStop() async {
        await self.start()
        await withCheckedContinuation { continuation in
            self.stopContinuation = continuation
        }
        await self.shutdown()
    }

    public func daemonStatus() async -> PeekabooDaemonStatus {
        let permissions = self.services.permissions.checkAllPermissions()
        let snapshots = await self.snapshotStatus()
        let trackerStatus = self.windowTracker?.status()

        let bridgeStatus = PeekabooDaemonBridgeStatus(
            socketPath: self.configuration.bridgeSocketPath,
            hostKind: self.configuration.hostKind,
            allowedOperations: Array(self.configuration.allowedOperations).sorted { $0.rawValue < $1.rawValue })

        let windowStatus = trackerStatus.map { status in
            PeekabooDaemonWindowTrackerStatus(
                trackedWindows: status.trackedWindows,
                lastEventAt: status.lastEventAt,
                lastPollAt: status.lastPollAt,
                axObserverCount: status.axObserverCount,
                cgPollIntervalMs: status.cgPollIntervalMs)
        }

        return PeekabooDaemonStatus(
            running: true,
            pid: getpid(),
            startedAt: self.startTime,
            mode: self.configuration.mode,
            bridge: bridgeStatus,
            permissions: permissions,
            snapshots: snapshots,
            windowTracker: windowStatus)
    }

    public func requestStop() async -> Bool {
        guard !self.isStopping else { return false }
        self.isStopping = true
        await self.shutdown()
        self.stopContinuation?.resume()
        self.stopContinuation = nil

        if self.configuration.exitOnStop {
            exit(0)
        }

        return true
    }

    private func shutdown() async {
        self.windowTracker?.stop()
        self.windowTracker = nil
        WindowMovementTracking.provider = nil

        if let host = self.bridgeHost {
            await host.stop()
            self.bridgeHost = nil
        }
    }

    private func snapshotStatus() async -> PeekabooDaemonSnapshotStatus {
        let list = await (try? self.services.snapshots.listSnapshots()) ?? []
        let lastAccessed = list.map(\ .lastAccessedAt).max()
        let backend: String = self.services.snapshots is InMemorySnapshotManager ? "memory" : "disk"
        return PeekabooDaemonSnapshotStatus(
            backend: backend,
            snapshotCount: list.count,
            lastAccessedAt: lastAccessed,
            storagePath: self.services.snapshots.getSnapshotStoragePath())
    }
}
