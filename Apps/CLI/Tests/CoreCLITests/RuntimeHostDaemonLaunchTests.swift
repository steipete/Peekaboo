import Commander
import Foundation
import PeekabooAutomation
import PeekabooBridge
import PeekabooBridgeTestSupport
import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite(.serialized, .tags(.safe))
@MainActor
struct RuntimeHostDaemonLaunchTests {
    @Test(arguments: ["type", "press", "click"], [false, true])
    func `ungranted caller skips absent exact daemon for granted GUI`(
        command: String,
        releaseSigned: Bool
    ) async throws {
        let fixture = Fixture()
        fixture.releaseSigned = releaseSigned
        let options = try Self.options(command)
        #expect(options.requiresImplicitSnapshotInvalidation)
        let resolution = try await fixture.resolve(options)
        #expect(fixture.launchPaths.isEmpty)
        #expect(resolution.selectedRemoteSocketPath == fixture.guiPath)
        #expect(fixture.handshakePaths.filter { $0 == fixture.guiPath }.count == 1)
        #expect(fixture.preflightCount == 1)
        #expect(Set(resolution.snapshotInvalidationRemoteSocketPaths) == Set([
            fixture.guiPath, fixture.daemonPath, fixture.exactPath,
        ]))
    }

    @Test(arguments: ["granted", "unknown", "opposing"])
    func `caller grants preserve daemon launch`(state: String) async throws {
        let fixture = Fixture()
        fixture.callerPermissions = switch state {
        case "granted": Self.granted
        case "unknown": nil
        default: .init(screenRecording: false, accessibility: true, postEvent: false)
        }
        if state == "opposing" {
            fixture.guiPermissions = .init(screenRecording: true, accessibility: false, postEvent: true)
        }
        _ = try await fixture.resolve(Self.options("press"))
        #expect(fixture.launchPaths == [fixture.exactPath])
    }

    @Test(arguments: ["unknown", "unavailable", "incapable", "disabled-invalidation", "wrong-kind"])
    func `unproven or unusable GUI preserves daemon launch`(state: String) async throws {
        let fixture = Fixture()
        fixture.guiPermissions = state == "unknown" ? nil : Self.granted
        fixture.guiUnavailable = state == "unavailable"
        fixture.guiCapable = state != "incapable"
        fixture.guiInvalidationEnabled = state != "disabled-invalidation"
        fixture.guiKind = state == "wrong-kind" ? .onDemand : .gui
        _ = try await fixture.resolve(Self.options("press"))
        #expect(fixture.launchPaths == [fixture.exactPath])
        #expect(fixture.handshakePaths.filter { $0 == fixture.guiPath }.count == 1)
    }

    @Test(arguments: ["quit", "relaunch"])
    func `lifecycle commands still launch surviving daemon`(command: String) async throws {
        let fixture = Fixture()
        let options = try Self.options(command)
        _ = try await fixture.resolve(options)
        let prefersExact = RuntimeHostResolver.prefersExactBuildScopedHost(
            options: options, explicitSocket: nil, buildScopedDaemonSocketPath: fixture.exactPath
        )
        #expect(fixture.launchPaths == [prefersExact ? fixture.exactPath : fixture.daemonPath])
        #expect(fixture.preflightCount == 0)
        #expect(!fixture.handshakePaths.contains(fixture.guiPath))
    }

    @Test
    func `snapshot owner bypasses launch prediction`() async throws {
        let fixture = Fixture()
        var options = try Self.options("press")
        options.explicitSnapshotID = "ps1_0123456789abcdef0123456789abcdef"
        let resolution = try await fixture.resolve(options)
        #expect(resolution.selectedRemoteSocketPath == fixture.guiPath)
        #expect(fixture.launchPaths.isEmpty)
        #expect(fixture.preflightCount == 0)
    }

    @Test
    func `disabled auto start still selects GUI with invalidation targets`() async throws {
        let fixture = Fixture()
        var options = try Self.options("press")
        options.autoStartDaemon = false
        let resolution = try await fixture.resolve(options)
        #expect(resolution.selectedRemoteSocketPath == fixture.guiPath)
        #expect(fixture.launchPaths.isEmpty)
        #expect(fixture.preflightCount == 0)
        #expect(resolution.snapshotInvalidationRemoteSocketPaths.contains(fixture.exactPath))
    }

    @Test(arguments: [false, true])
    func `GUI fallback invalidates selected local and sibling snapshots`(autoStart: Bool) async throws {
        let fixture = Fixture()
        var options = try Self.options("press")
        options.autoStartDaemon = autoStart
        let resolution = try await fixture.resolve(options)
        let selected = resolution.services.snapshots
        let local = InMemorySnapshotManager()
        let sibling = InMemorySnapshotManager()
        let explicit = try await selected.createSnapshot()
        _ = try await selected.createSnapshot()
        _ = try await local.createSnapshot()
        _ = try await sibling.createSnapshot()
        var visited: [String] = []

        let invalidated = await InteractionObservationInvalidator.invalidateAfterMutation(
            targets: .init(
                snapshots: selected,
                selectedRemoteSocketPath: resolution.selectedRemoteSocketPath,
                remoteSocketPaths: resolution.snapshotInvalidationRemoteSocketPaths,
                socketExists: { $0 == fixture.daemonPath },
                makeLocalSnapshotManager: { local },
                makeRemoteSnapshotManager: { path in
                    visited.append(path)
                    return sibling
                }
            ),
            logger: .shared,
            reason: "synthetic GUI fallback mutation"
        )
        #expect(invalidated)
        #expect(fixture.launchPaths.isEmpty)
        #expect(resolution.selectedRemoteSocketPath == fixture.guiPath)
        #expect(await selected.getMostRecentSnapshot() == nil)
        #expect(await local.getMostRecentSnapshot() == nil)
        #expect(await sibling.getMostRecentSnapshot() == nil)
        #expect(try await selected.listSnapshots().contains { $0.id == explicit })
        #expect(visited == [fixture.daemonPath])
    }

    @Test
    func `explicit daemon commands disable implicit auto start`() throws {
        for command in [DaemonCommand.Start.self, DaemonCommand.Run.self] as [any ParsableCommand.Type] {
            let options = try CommanderCLIBinder.makeRuntimeOptions(
                from: ParsedValues(positional: [], options: [:], flags: []),
                commandType: command,
                environment: [:]
            )
            #expect(!options.autoStartDaemon)
            #expect(!options.preferRemote)
        }
    }

    @Test
    func `non exact routing uses capable GUI without launching`() async throws {
        let fixture = Fixture()
        fixture.exactBuild = false
        let resolution = try await fixture.resolve(Self.options("press"))
        #expect(resolution.selectedRemoteSocketPath == fixture.guiPath)
        #expect(fixture.launchPaths.isEmpty)
    }

    @Test
    func `non exact routing still launches when GUI is unavailable`() async throws {
        let fixture = Fixture()
        fixture.exactBuild = false
        fixture.guiUnavailable = true
        _ = try await fixture.resolve(Self.options("press"))
        #expect(fixture.launchPaths == [fixture.daemonPath])
        #expect(fixture.handshakePaths.filter { $0 == fixture.guiPath }.count == 1)
    }

    @Test
    func `missing daemon handshake is retried after it appears`() async throws {
        var attempts = 0
        let identity = PeekabooBridgeClientIdentity(
            bundleIdentifier: nil, teamIdentifier: nil, processIdentifier: 123
        )
        let candidate = RuntimeHostResolver.ImplicitRemoteCandidate(
            socketPath: "/synthetic/appearing-daemon.sock",
            requireReusableDaemon: true,
            requiredHostKind: .onDemand,
            requiresValidatedHistoricalDaemon: false
        )
        let cache = RuntimeHostResolver.RemoteHandshakeCache(identity: identity, handshakeProvider: { _, _ in
            attempts += 1
            if attempts == 1 {
                throw POSIXError(.ENOENT)
            }
            return BridgeTestFixtures.handshake(
                negotiatedVersion: PeekabooBridgeConstants.protocolVersion,
                supportedOperations: []
            )
        })
        do {
            _ = try await cache.handshake(candidate, identity: identity)
            Issue.record("Absent daemon unexpectedly answered")
        } catch let error as POSIXError {
            #expect(error.code == .ENOENT)
        }
        _ = try await cache.handshake(candidate, identity: identity)
        #expect(attempts == 2)
    }

    @Test
    func `bridge status selects GUI when exact daemon is absent`() async throws {
        let fixture = Fixture()
        let options = try Self.options("press")
        let report = try await BridgeDiagnostics(logger: .shared).report(
            runtimeOptions: options,
            candidatePlan: fixture.plan(options),
            probedCandidates: [
                .init(socketPath: fixture.exactPath, outcome: .failure(.other(POSIXError(.ENOENT)))),
                .init(socketPath: fixture.daemonPath, outcome: .failure(.other(POSIXError(.ENOENT)))),
                .init(socketPath: fixture.guiPath, outcome: .success(fixture.guiHandshake)),
            ],
            identity: fixture.identity
        )
        #expect(report.selected.source == .remote)
        #expect(report.selected.socketPath == fixture.guiPath)
        #expect(fixture.launchPaths.isEmpty)
    }

    private static let granted = PermissionsStatus(screenRecording: true, accessibility: true, postEvent: true)
    private static let denied = PermissionsStatus(screenRecording: false, accessibility: false, postEvent: false)

    private static func options(_ command: String) throws -> CommandRuntimeOptions {
        let type: any ParsableCommand.Type = switch command {
        case "type": TypeCommand.self
        case "click": ClickCommand.self
        case "quit": AppCommand.QuitSubcommand.self
        case "relaunch": AppCommand.RelaunchSubcommand.self
        default: PressCommand.self
        }
        return try CommanderCLIBinder.makeRuntimeOptions(
            from: ParsedValues(positional: [], options: [:], flags: command == "relaunch" ? ["foreground"] : []),
            commandType: type,
            environment: [:]
        )
    }

    private final class Fixture {
        let daemonPath = "/synthetic/absent-daemon.sock"
        let exactPath = "/synthetic/absent-exact-daemon.sock"
        let guiPath = PeekabooBridgeConstants.peekabooSocketPath
        let identity = PeekabooBridgeClientIdentity(
            bundleIdentifier: "boo.peekaboo.test.launch", teamIdentifier: nil, processIdentifier: 123
        )
        var exactBuild = true
        var releaseSigned = true
        var callerPermissions: PermissionsStatus? = RuntimeHostDaemonLaunchTests.denied
        var guiPermissions: PermissionsStatus? = RuntimeHostDaemonLaunchTests.granted
        var guiUnavailable = false
        var guiCapable = true
        var guiInvalidationEnabled = true
        var guiKind: PeekabooBridgeHostKind = .gui
        var launchPaths: [String] = []
        var handshakePaths: [String] = []
        var preflightCount = 0

        var guiHandshake: PeekabooBridgeHandshakeResponse {
            let operations: [PeekabooBridgeOperation] = self.guiCapable ? [
                .invalidateImplicitLatestSnapshot, .targetedTypeActions, .targetedHotkey, .targetedClick,
                .getFocusedElement,
            ] : []
            return BridgeTestFixtures.handshake(
                negotiatedVersion: PeekabooBridgeConstants.protocolVersion,
                hostKind: self.guiKind,
                supportedOperations: operations,
                permissions: self.guiPermissions,
                enabledOperations: self.guiInvalidationEnabled
                    ? operations : operations.filter { $0 != .invalidateImplicitLatestSnapshot },
                hostCapabilities: [
                    PeekabooBridgeHostCapability.attestedOperationReceipts,
                    PeekabooBridgeHostCapability.targetedClickAccessibilityValueDelivery,
                ]
            )
        }

        func plan(_ options: CommandRuntimeOptions) -> RuntimeHostResolver.RemoteCandidatePlan {
            let daemon = RuntimeHostResolver.ImplicitRemoteCandidate(
                socketPath: self.exactBuild ? self.exactPath : self.daemonPath,
                requireReusableDaemon: true,
                requiredHostKind: .onDemand,
                requiresValidatedHistoricalDaemon: false
            )
            let gui = RuntimeHostResolver.ImplicitRemoteCandidate(
                socketPath: self.guiPath,
                requireReusableDaemon: false,
                requiredHostKind: .gui,
                requiresValidatedHistoricalDaemon: false
            )
            return .init(
                explicitSocket: nil,
                daemonSocketPath: self.daemonPath,
                runtimeBuildIdentity: "synthetic",
                buildScopedDaemonSocketPath: self.exactBuild ? self.exactPath : nil,
                historicalBuildScopedDaemonSocketPaths: [],
                candidates: options.requiresApplicationRelaunch || options.requiresSurvivingApplicationHost
                    ? [daemon] : [daemon, gui]
            )
        }

        func resolve(_ options: CommandRuntimeOptions) async throws -> RuntimeHostResolver.Resolution {
            let dependencies = RuntimeHostResolver.Dependencies(
                makeLocalServices: { _ in OwnerPolicyFixtureServices(ownerAware: true) },
                claimScreenCaptureKitOwner: { fatalError("No capture ownership claims") },
                inspectScreenCaptureKitOwner: { nil },
                remoteCandidatePlan: { options, _ in self.plan(options) },
                snapshotAffinityProbe: { candidate, _, _, _ in
                    candidate.socketPath == self.guiPath ? .owner : .missing
                },
                makeRemoteHandshakeCache: {
                    RuntimeHostResolver.RemoteHandshakeCache(
                        identity: self.identity,
                        handshakeProvider: { candidate, _ in
                            self.handshakePaths.append(candidate.socketPath)
                            guard candidate.socketPath == self.guiPath, !self.guiUnavailable else {
                                throw POSIXError(.ENOENT)
                            }
                            return self.guiHandshake
                        }
                    )
                },
                makeRemoteServices: ScreenCaptureKitOwnerRuntimeTests.makeInertRemoteServices,
                callerPermissionPreflight: {
                    self.preflightCount += 1
                    return self.callerPermissions
                },
                startOnDemandDaemon: { path, _ in
                    self.launchPaths.append(path)
                    return nil
                },
                fetchDaemonStatus: { _ in nil },
                currentProcessIsReleaseSigned: { self.releaseSigned }
            )
            return try await RuntimeHostResolver.resolveServices(
                options: options,
                environment: self.releaseSigned ? [:] : ["PEEKABOO_ALLOW_UNSIGNED_DAEMON": "1"],
                configurationInput: nil,
                dependencies: dependencies
            )
        }
    }
}
