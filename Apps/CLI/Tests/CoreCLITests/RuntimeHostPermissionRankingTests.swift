import Commander
import Foundation
import PeekabooAutomation
import PeekabooBridge
import PeekabooBridgeTestSupport
import Testing
@testable import PeekabooCLI

@Suite(.serialized, .tags(.safe))
@MainActor
struct RuntimeHostPermissionRankingTests {
    @Test
    func `ungranted exact build daemon yields to granted GUI for type`() async throws {
        let fixture = try Fixture(exactBuild: true)
        defer { Task { await fixture.peer.stop() } }
        let options = try Self.options(TypeCommand.self)
        #expect(BridgeCapabilityPolicy.explicitlyMissingRemotePermissions(
            for: fixture.daemonHandshake,
            options: options
        )
            == [.accessibility])
        let resolution = try await fixture.resolve(options)
        #expect(resolution.selectedRemoteSocketPath == PeekabooBridgeConstants.peekabooSocketPath)
        #expect(fixture.handshakePaths.filter { $0 == fixture.peer.socketPath }.count == 1)
        #expect(fixture.handshakePaths.filter { $0 == PeekabooBridgeConstants.peekabooSocketPath }.count == 1)
    }

    @Test
    func `ungranted reusable daemon yields to granted GUI for press`() async throws {
        let fixture = try Fixture()
        defer { Task { await fixture.peer.stop() } }
        let options = try Self.options(PressCommand.self)
        #expect(BridgeCapabilityPolicy.explicitlyMissingRemotePermissions(
            for: fixture.daemonHandshake,
            options: options
        )
            == [.accessibility, .postEvent])
        let resolution = try await fixture.resolve(options)
        #expect(resolution.selectedRemoteSocketPath == PeekabooBridgeConstants.peekabooSocketPath)
        #expect(fixture.handshakePaths.count == 2)
    }

    @Test(arguments: [false, true])
    func `granted daemon keeps priority over granted GUI`(exactBuild: Bool) async throws {
        let fixture = try Fixture(exactBuild: exactBuild, daemonPermissions: Self.granted)
        defer { Task { await fixture.peer.stop() } }
        let resolution = try await fixture.resolve(Self.options(TypeCommand.self))
        #expect(resolution.selectedRemoteSocketPath == fixture.peer.socketPath)
        #expect(fixture.handshakePaths == [fixture.peer.socketPath])
    }

    @Test
    func `unknown daemon permissions keep daemon priority`() async throws {
        let fixture = try Fixture(daemonPermissions: nil)
        defer { Task { await fixture.peer.stop() } }
        let resolution = try await fixture.resolve(Self.options(PressCommand.self))
        #expect(resolution.selectedRemoteSocketPath == fixture.peer.socketPath)
        #expect(fixture.handshakePaths == [fixture.peer.socketPath])
    }

    @Test(arguments: [false, true])
    func `unavailable or incapable GUI retains ungranted daemon for native hide`(unavailable: Bool) async throws {
        let fixture = try Fixture(guiUnavailable: unavailable, guiCapable: unavailable)
        defer { Task { await fixture.peer.stop() } }
        let resolution = try await fixture.resolve(Self.options(AppCommand.HideSubcommand.self))
        #expect(resolution.selectedRemoteSocketPath == fixture.peer.socketPath)
    }

    @Test
    func `opposing grants preserve daemon priority`() async throws {
        let fixture = try Fixture(
            daemonPermissions: .init(screenRecording: false, accessibility: true, postEvent: false),
            guiPermissions: .init(screenRecording: true, accessibility: false, postEvent: true)
        )
        defer { Task { await fixture.peer.stop() } }
        let resolution = try await fixture.resolve(Self.options(AppCommand.HideSubcommand.self))
        #expect(resolution.selectedRemoteSocketPath == fixture.peer.socketPath)
    }

    @Test(arguments: [false, true])
    func `explicit socket and environment override retain ungranted daemon`(environmentOverride: Bool) async throws {
        let fixture = try Fixture()
        defer { Task { await fixture.peer.stop() } }
        var options = try Self.options(AppCommand.HideSubcommand.self)
        if !environmentOverride {
            options.bridgeSocketPath = fixture.peer.socketPath
        }
        let environment = environmentOverride ? ["PEEKABOO_BRIDGE_SOCKET": fixture.peer.socketPath] : [:]
        let resolution = try await fixture.resolve(options, environment: environment)
        #expect(resolution.selectedRemoteSocketPath == fixture.peer.socketPath)
        #expect(fixture.handshakePaths == [fixture.peer.socketPath])
    }

    @Test
    func `snapshot reference keeps ungranted daemon producer`() async throws {
        let fixture = try Fixture()
        defer { Task { await fixture.peer.stop() } }
        var options = try Self.options(AppCommand.HideSubcommand.self)
        options.explicitSnapshotID = "ps1_0123456789abcdef0123456789abcdef"
        let resolution = try await fixture.resolve(options)
        #expect(resolution.selectedRemoteSocketPath == fixture.peer.socketPath)
    }

    @Test
    func `quit keeps ungranted surviving daemon`() async throws {
        let fixture = try Fixture()
        defer { Task { await fixture.peer.stop() } }
        let resolution = try await fixture.resolve(Self.options(AppCommand.QuitSubcommand.self))
        #expect(resolution.selectedRemoteSocketPath == fixture.peer.socketPath)
        #expect(fixture.handshakePaths == [fixture.peer.socketPath])
    }

    @Test
    func `relaunch keeps ungranted surviving daemon`() async throws {
        let fixture = try Fixture()
        defer { Task { await fixture.peer.stop() } }
        let resolution = try await fixture.resolve(Self.options(AppCommand.RelaunchSubcommand.self))
        #expect(resolution.selectedRemoteSocketPath == fixture.peer.socketPath)
        #expect(fixture.handshakePaths == [fixture.peer.socketPath])
    }

    @Test(arguments: [false, true])
    func `unknown GUI permissions or no grants anywhere preserve daemon priority`(unknown: Bool) async throws {
        let fixture = try Fixture(guiPermissions: unknown ? nil : Self.denied)
        defer { Task { await fixture.peer.stop() } }
        let resolution = try await fixture.resolve(Self.options(AppCommand.HideSubcommand.self))
        #expect(resolution.selectedRemoteSocketPath == fixture.peer.socketPath)
    }

    @Test(arguments: [false, true])
    func `omitted legacy post event status is unknown rather than denied`(legacyGUI: Bool) async throws {
        let legacy = try JSONDecoder().decode(
            PermissionsStatus.self,
            from: Data(#"{"screenRecording":true,"accessibility":true}"#.utf8)
        )
        #expect(!legacy.postEvent)
        #expect(!legacy.reportsPostEvent)
        let fixture = try Fixture(
            daemonPermissions: legacyGUI
                ? .init(screenRecording: false, accessibility: true, postEvent: true) : legacy,
            guiPermissions: legacyGUI ? legacy : Self.granted
        )
        defer { Task { await fixture.peer.stop() } }
        let resolution = try await fixture.resolve(Self.options(PressCommand.self))
        #expect(resolution.selectedRemoteSocketPath == (
            legacyGUI ? PeekabooBridgeConstants.peekabooSocketPath : fixture.peer.socketPath
        ))
        let encodedValue = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy))
        let encoded = try #require(encodedValue as? [String: Any])
        #expect(encoded["reportsPostEvent"] == nil)
    }

    @Test(arguments: [
        PeekabooBridgePermissionKind.screenRecording, .accessibility, .postEvent, .appleScript,
    ])
    func `only native permission losses affect ranking`(missing: PeekabooBridgePermissionKind) async throws {
        let fixture = try Fixture(
            daemonPermissions: .init(
                screenRecording: missing != .screenRecording,
                accessibility: missing != .accessibility,
                appleScript: missing != .appleScript,
                postEvent: missing != .postEvent
            ),
            guiPermissions: .init(screenRecording: true, accessibility: true, appleScript: true, postEvent: true)
        )
        defer { Task { await fixture.peer.stop() } }
        let resolution = try await fixture.resolve(Self.options(AppCommand.HideSubcommand.self))
        let expectedSocket = missing == .appleScript
            ? fixture.peer.socketPath : PeekabooBridgeConstants.peekabooSocketPath
        #expect(resolution.selectedRemoteSocketPath == expectedSocket)
    }

    @Test(arguments: [false, true])
    func `bridge status selects granted GUI ahead of ungranted daemon`(exactBuild: Bool) async throws {
        let fixture = try Fixture(exactBuild: exactBuild)
        defer { Task { await fixture.peer.stop() } }
        let daemon = Self.candidate(fixture.peer.socketPath, kind: .onDemand, reusable: true)
        let gui = Self.candidate(PeekabooBridgeConstants.peekabooSocketPath, kind: .gui)
        let report = try await BridgeDiagnostics(logger: .shared).report(
            runtimeOptions: CommandRuntimeOptions(),
            candidatePlan: .init(
                explicitSocket: nil,
                daemonSocketPath: daemon.socketPath,
                runtimeBuildIdentity: "synthetic",
                buildScopedDaemonSocketPath: exactBuild ? daemon.socketPath : nil,
                historicalBuildScopedDaemonSocketPaths: [],
                candidates: [daemon, gui]
            ),
            probedCandidates: [
                .init(socketPath: daemon.socketPath, outcome: .success(fixture.daemonHandshake)),
                .init(socketPath: gui.socketPath, outcome: .success(fixture.guiHandshake)),
            ],
            identity: .init(bundleIdentifier: nil, teamIdentifier: nil, processIdentifier: 123)
        )
        #expect(report.selected.source == .remote)
        #expect(report.selected.socketPath == gui.socketPath)
        #expect(report.candidates.map(\.socketPath) == [gui.socketPath, daemon.socketPath])
        #expect(await fixture.peer.acceptedConnectionCount == 0)
    }

    @Test
    func `deprioritizing a weaker daemon retains a stronger daemon before GUI`() async throws {
        let weak = Self.candidate("/synthetic/weak.sock", kind: .onDemand)
        let strong = Self.candidate("/synthetic/strong.sock", kind: .onDemand)
        let gui = Self.candidate(PeekabooBridgeConstants.peekabooSocketPath, kind: .gui)
        let identity = PeekabooBridgeClientIdentity(
            bundleIdentifier: nil, teamIdentifier: nil, processIdentifier: 123
        )
        var paths: [String] = []
        let cache = RuntimeHostResolver.RemoteHandshakeCache(
            identity: identity,
            handshakeProvider: { candidate, _ in
                paths.append(candidate.socketPath)
                return BridgeTestFixtures.handshake(
                    negotiatedVersion: PeekabooBridgeConstants.protocolVersion,
                    hostKind: candidate.requiredHostKind ?? .onDemand,
                    supportedOperations: [],
                    permissions: candidate == weak ? Self.denied : Self.granted
                )
            }
        )
        var rejections: [String] = []
        let resolution = try await RuntimeHostResolver.resolveRemoteServices(
            candidates: [weak, strong, gui],
            identity: identity,
            options: CommandRuntimeOptions(),
            snapshotInvalidationRemoteSocketPaths: [],
            permissionRejections: &rejections,
            makeRemoteServices: ScreenCaptureKitOwnerRuntimeTests.makeInertRemoteServices,
            handshakeCache: cache,
            guiPermissionCandidate: gui
        )
        #expect(resolution?.selectedRemoteSocketPath == strong.socketPath)
        #expect(paths == [weak.socketPath, gui.socketPath, strong.socketPath])
    }

    @Test
    func `failed GUI first preserves following daemon order`() async throws {
        let gui = Self.candidate(PeekabooBridgeConstants.peekabooSocketPath, kind: .gui)
        let weak = Self.candidate("/synthetic/weak.sock", kind: .onDemand)
        let strong = Self.candidate("/synthetic/strong.sock", kind: .onDemand)
        let identity = PeekabooBridgeClientIdentity(
            bundleIdentifier: nil, teamIdentifier: nil, processIdentifier: 123
        )
        let cache = RuntimeHostResolver.RemoteHandshakeCache(
            identity: identity,
            handshakeProvider: { candidate, _ in
                BridgeTestFixtures.handshake(
                    negotiatedVersion: PeekabooBridgeConstants.protocolVersion,
                    hostKind: candidate.requiredHostKind ?? .onDemand,
                    supportedOperations: candidate == gui ? [] : [.invalidateImplicitLatestSnapshot],
                    permissions: candidate == weak ? Self.denied : Self.granted
                )
            }
        )
        var options = CommandRuntimeOptions()
        options.requiresImplicitSnapshotInvalidation = true
        var rejections: [String] = []
        let resolution = try await RuntimeHostResolver.resolveRemoteServices(
            candidates: [gui, weak, strong],
            identity: identity,
            options: options,
            snapshotInvalidationRemoteSocketPaths: [],
            permissionRejections: &rejections,
            makeRemoteServices: ScreenCaptureKitOwnerRuntimeTests.makeInertRemoteServices,
            handshakeCache: cache,
            guiPermissionCandidate: gui
        )
        #expect(resolution?.selectedRemoteSocketPath == weak.socketPath)
    }

    private static func candidate(
        _ path: String,
        kind: PeekabooBridgeHostKind,
        reusable: Bool = false
    ) -> RuntimeHostResolver.ImplicitRemoteCandidate {
        .init(
            socketPath: path,
            requireReusableDaemon: reusable,
            requiredHostKind: kind,
            requiresValidatedHistoricalDaemon: false
        )
    }

    private static let granted = PermissionsStatus(screenRecording: true, accessibility: true, postEvent: true)
    private static let denied = PermissionsStatus(screenRecording: false, accessibility: false, postEvent: false)

    private static func options(_ command: any ParsableCommand.Type) throws -> CommandRuntimeOptions {
        var options = try CommanderCLIBinder.makeRuntimeOptions(
            from: ParsedValues(
                positional: command == PressCommand.self ? ["return"] : [],
                options: command == PressCommand.self ? ["windowId": ["42"]] : [:],
                flags: command == AppCommand.RelaunchSubcommand.self ? ["foreground"] : []
            ),
            commandType: command,
            environment: [:]
        )
        options.autoStartDaemon = false
        return options
    }

    @MainActor
    private final class Fixture {
        let peer: ScriptedBridgePeer
        let exactBuild: Bool
        let daemonHandshake: PeekabooBridgeHandshakeResponse
        let guiHandshake: PeekabooBridgeHandshakeResponse
        let guiUnavailable: Bool
        var handshakePaths: [String] = []

        init(
            exactBuild: Bool = false,
            daemonPermissions: PermissionsStatus? = RuntimeHostPermissionRankingTests.denied,
            guiPermissions: PermissionsStatus? = RuntimeHostPermissionRankingTests.granted,
            guiUnavailable: Bool = false,
            guiCapable: Bool = true
        ) throws {
            self.exactBuild = exactBuild
            self.guiUnavailable = guiUnavailable
            let operations: [PeekabooBridgeOperation] = [
                .daemonStatus,
                .invalidateImplicitLatestSnapshot,
                .quitApplication,
                .targetedTypeActions,
                .targetedHotkey,
                .getFocusedElement,
                .hideApplication,
                .launchApplicationWithOptions,
                .relaunchApplicationWithOptions,
            ]
            let controlHandshake = BridgeTestFixtures.handshake(
                negotiatedVersion: .init(major: 1, minor: 28),
                supportedOperations: [.daemonStatus]
            )
            let status = PeekabooDaemonStatus(running: true, pid: 4242, mode: .auto)
            self.peer = try ScriptedBridgePeer(responses: (0..<8).flatMap { _ in
                [.handshake(controlHandshake), .daemonStatus(status)]
            })
            self.daemonHandshake = BridgeTestFixtures.handshake(
                negotiatedVersion: PeekabooBridgeConstants.protocolVersion,
                supportedOperations: operations,
                permissions: daemonPermissions,
                enabledOperations: operations,
                hostCapabilities: [
                    PeekabooBridgeHostCapability.attestedOperationReceipts,
                    PeekabooBridgeHostCapability.processGenerationPinnedApplicationHide
                ]
            )
            self.guiHandshake = BridgeTestFixtures.handshake(
                negotiatedVersion: PeekabooBridgeConstants.protocolVersion,
                hostKind: .gui,
                supportedOperations: guiCapable ? operations : [],
                permissions: guiPermissions,
                enabledOperations: guiCapable ? operations : [],
                hostCapabilities: [
                    PeekabooBridgeHostCapability.attestedOperationReceipts,
                    PeekabooBridgeHostCapability.processGenerationPinnedApplicationHide
                ]
            )
        }

        func resolve(_ options: CommandRuntimeOptions, environment: [String: String] = [:]) async throws
        -> RuntimeHostResolver.Resolution {
            let dependencies = ScreenCaptureKitOwnerRuntimeTests.inertDependencies(
                makeLocalServices: { _ in OwnerPolicyFixtureServices(ownerAware: true) },
                claimScreenCaptureKitOwner: { fatalError("No capture ownership claims") },
                inspectScreenCaptureKitOwner: { nil },
                remoteCandidatePlan: { options, environment in
                    let explicitSocket = BridgeSocketResolver.explicitBridgeSocket(
                        options: options, environment: environment
                    )
                    let surviving = options.requiresApplicationRelaunch || options.requiresSurvivingApplicationHost
                    let daemon = RuntimeHostResolver.ImplicitRemoteCandidate(
                        socketPath: self.peer.socketPath,
                        requireReusableDaemon: explicitSocket == nil,
                        requiredHostKind: explicitSocket != nil ? nil : .onDemand,
                        requiresValidatedHistoricalDaemon: false
                    )
                    let gui = RuntimeHostResolver.ImplicitRemoteCandidate(
                        socketPath: PeekabooBridgeConstants.peekabooSocketPath,
                        requireReusableDaemon: false,
                        requiredHostKind: .gui,
                        requiresValidatedHistoricalDaemon: false
                    )
                    return .init(
                        explicitSocket: explicitSocket,
                        daemonSocketPath: self.peer.socketPath,
                        runtimeBuildIdentity: "synthetic",
                        buildScopedDaemonSocketPath: self.exactBuild ? self.peer.socketPath : nil,
                        historicalBuildScopedDaemonSocketPaths: [],
                        candidates: explicitSocket != nil || surviving ? [daemon] : [daemon, gui]
                    )
                },
                makeRemoteHandshakeCache: {
                    RuntimeHostResolver.RemoteHandshakeCache(
                        identity: .init(
                            bundleIdentifier: "boo.peekaboo.test.ranking",
                            teamIdentifier: nil,
                            processIdentifier: 123
                        ),
                        handshakeProvider: { candidate, _ in
                            self.handshakePaths.append(candidate.socketPath)
                            if candidate.socketPath == self.peer.socketPath {
                                return self.daemonHandshake
                            }
                            if self.guiUnavailable {
                                throw POSIXError(.ENOENT)
                            }
                            return self.guiHandshake
                        }
                    )
                },
                snapshotAffinityProbe: { candidate, _, _, _ in
                    candidate.socketPath == self.peer.socketPath ? .owner : .missing
                }
            )
            return try await RuntimeHostResolver.resolveServices(
                options: options, environment: environment, configurationInput: nil, dependencies: dependencies
            )
        }
    }
}
