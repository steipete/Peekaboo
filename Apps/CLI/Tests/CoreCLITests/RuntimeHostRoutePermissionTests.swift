import Commander
import Foundation
import PeekabooAutomation
import PeekabooBridge
import PeekabooBridgeTestSupport
import Testing
@testable import PeekabooCLI

@Suite(.serialized, .tags(.safe))
@MainActor
struct RuntimeHostRoutePermissionTests {
    @Test(arguments: ["type", "press-ax", "press-events", "window"], [false, true])
    func `declared route permissions reject weaker daemon candidates`(route: String, gui: Bool) async throws {
        let options = try Self.options(route)
        let weak = Self.candidate("/synthetic/weak.sock", kind: .onDemand)
        let strong = Self.candidate("/synthetic/strong.sock", kind: gui ? .gui : .onDemand)
        let missing: PeekabooBridgePermissionKind = route == "press-events" ? .postEvent : .accessibility
        let weakHandshake = Self.handshake(kind: .onDemand, missing: missing)
        let cache = RuntimeHostResolver.RemoteHandshakeCache(
            identity: Self.identity,
            handshakeProvider: { candidate, _ in
                candidate == weak ? weakHandshake : Self.handshake(kind: gui ? .gui : .onDemand)
            }
        )
        var rejections: [String] = []
        let resolution = try await RuntimeHostResolver.resolveRemoteServices(
            candidates: [weak, strong],
            identity: Self.identity,
            options: options,
            snapshotInvalidationRemoteSocketPaths: [],
            permissionRejections: &rejections,
            makeRemoteServices: ScreenCaptureKitOwnerRuntimeTests.makeInertRemoteServices,
            handshakeCache: cache
        )
        // No GUI ranking hint: candidate admission itself must reject the weak host.
        #expect(resolution?.selectedRemoteSocketPath == strong.socketPath)
        #expect(rejections.count == 1)
        #expect(rejections.first?.contains(weak.socketPath) == true)
    }

    @Test
    func `native hide accepts a host with no grants`() async throws {
        let options = try Self.options("hide")
        let candidate = Self.candidate("/synthetic/ungranted.sock", kind: .onDemand)
        let handshake = Self.handshake(granted: false)
        let evaluation = await RuntimeHostResolver.validateRemoteCandidate(
            candidate, handshake: handshake, options: options
        )
        #expect(evaluation != nil)
        #expect(BridgeCapabilityPolicy.explicitlyMissingRemotePermissions(for: handshake, options: options).isEmpty)
    }

    @Test(arguments: ["type", "press-ax", "window"])
    func `no grants still construct the local fallback once`(route: String) async throws {
        let options = try Self.options(route)
        let daemon = Self.candidate("/synthetic/daemon.sock", kind: .onDemand)
        let gui = Self.candidate(PeekabooBridgeConstants.peekabooSocketPath, kind: .gui)
        var localCalls = 0
        let local = OwnerPolicyFixtureServices(ownerAware: true)
        let dependencies = ScreenCaptureKitOwnerRuntimeTests.inertDependencies(
            makeLocalServices: { _ in
                localCalls += 1
                return local
            },
            claimScreenCaptureKitOwner: { fatalError("No capture") },
            inspectScreenCaptureKitOwner: { nil },
            remoteCandidatePlan: { _, _ in
                .init(
                    explicitSocket: nil,
                    daemonSocketPath: daemon.socketPath,
                    runtimeBuildIdentity: "synthetic",
                    buildScopedDaemonSocketPath: nil,
                    historicalBuildScopedDaemonSocketPaths: [],
                    candidates: [daemon, gui]
                )
            },
            makeRemoteHandshakeCache: {
                RuntimeHostResolver.RemoteHandshakeCache(
                    identity: Self.identity,
                    handshakeProvider: { candidate, _ in
                        Self.handshake(kind: candidate.requiredHostKind ?? .onDemand, granted: false)
                    }
                )
            }
        )
        let resolution = try await RuntimeHostResolver.resolveServices(
            options: options, environment: [:], configurationInput: nil, dependencies: dependencies
        )
        #expect(localCalls == 1)
        #expect(resolution.services === local)
        #expect(resolution.selectedRemoteSocketPath == nil)
        #expect(resolution.requiredHostFailure == nil)
        #expect(resolution.hostDescription.contains("local (in-process fallback; rejected"))
        #expect(resolution.hostDescription.contains(daemon.socketPath))
        #expect(resolution.hostDescription.contains(gui.socketPath))
        #expect(resolution.hostDescription.contains("Accessibility"))
    }

    @Test(arguments: ["type", "press-events", "window"])
    func `omitted permission reports remain eligible`(route: String) throws {
        let options = try Self.options(route)
        let current = Self.handshake()
        let unknown = BridgeTestFixtures.handshake(
            negotiatedVersion: current.negotiatedVersion,
            supportedOperations: current.supportedOperations,
            permissions: nil
        )
        #expect(BridgeCapabilityPolicy.supportsRemoteRequirements(for: unknown, options: options))
        #expect(BridgeCapabilityPolicy.explicitlyMissingRemotePermissions(for: unknown, options: options).isEmpty)
    }

    @Test(arguments: ["click", "move"])
    func `existing permission flags still require an explicit grant`(route: String) throws {
        let options = try CommanderCLIBinder.makeRuntimeOptions(
            from: ParsedValues(positional: [], options: [:], flags: []),
            commandType: route == "click" ? ClickCommand.self : MoveCommand.self,
            environment: [:]
        )
        #expect(options.requiresAccessibilityPermission == (route == "click"))
        #expect(options.requiresPostEventPermission == (route == "move"))
        #expect(!options.routeRequiresAccessibilityPermission)
        #expect(!options.routeRequiresPostEventPermission)
        for granted in [false, true] {
            let handshake = BridgeTestFixtures.handshake(
                negotiatedVersion: PeekabooBridgeConstants.protocolVersion,
                supportedOperations: [.targetedClick, .invalidateImplicitLatestSnapshot],
                permissions: granted ? .init(screenRecording: true, accessibility: true, postEvent: true) : nil,
                hostCapabilities: [
                    PeekabooBridgeHostCapability.attestedOperationReceipts,
                    PeekabooBridgeHostCapability.targetedClickAccessibilityValueDelivery
                ]
            )
            #expect(BridgeCapabilityPolicy.supportsRemoteRequirements(for: handshake, options: options) == granted)
        }
    }

    @Test(arguments: ["type", "press-events"])
    func `route declarations trust unknown reports but reject explicit denials`(route: String) throws {
        let options = try Self.options(route)
        let unknown = Self.handshake(permissions: nil)
        #expect(BridgeCapabilityPolicy.supportsRemoteRequirements(for: unknown, options: options))
        let legacy = try JSONDecoder().decode(
            PermissionsStatus.self,
            from: Data(#"{"screenRecording":true,"accessibility":true}"#.utf8)
        )
        #expect(!legacy.reportsPostEvent)
        #expect(BridgeCapabilityPolicy.supportsRemoteRequirements(
            for: Self.handshake(permissions: legacy), options: options
        ))
        let missing: PeekabooBridgePermissionKind = route == "type" ? .accessibility : .postEvent
        let denied = Self.handshake(missing: missing)
        #expect(!BridgeCapabilityPolicy.supportsRemoteRequirements(for: denied, options: options))
        #expect(BridgeCapabilityPolicy.explicitlyMissingRemotePermissions(for: denied, options: options) == [missing])
    }

    @Test
    func `route requirements do not weaken operation requirements or permission requests`() throws {
        var options = CommandRuntimeOptions()
        options.routeRequiresAccessibilityPermission = true
        options.routeRequiresPostEventPermission = true
        let denied = Self.handshake(granted: false)
        #expect(BridgeCapabilityPolicy.requiredRemotePermissions(for: denied, options: options).isEmpty)
        #expect(BridgeCapabilityPolicy.explicitlyMissingRemotePermissions(for: denied, options: options)
            == [.accessibility, .postEvent])

        let legacy = try JSONDecoder().decode(
            PermissionsStatus.self,
            from: Data(#"{"screenRecording":true,"accessibility":true}"#.utf8)
        )
        let handshake = Self.handshake(permissions: legacy)
        #expect(BridgeCapabilityPolicy.explicitlyMissingRemotePermissions(for: handshake, options: options).isEmpty)
        options.requiresExactWindowTargetedKeyboard = true
        #expect(BridgeCapabilityPolicy.requiredRemotePermissions(for: handshake, options: options).contains(.postEvent))
        #expect(BridgeCapabilityPolicy.explicitlyMissingRemotePermissions(for: handshake, options: options)
            == [.postEvent])

        options.requestsHostPermissionGrant = true
        #expect(BridgeCapabilityPolicy.explicitlyMissingRemotePermissions(for: denied, options: options).isEmpty)
    }

    private static let identity = PeekabooBridgeClientIdentity(
        bundleIdentifier: nil, teamIdentifier: nil, processIdentifier: 123
    )

    private static func options(_ route: String) throws -> CommandRuntimeOptions {
        let command: any ParsableCommand.Type = switch route {
        case "type": TypeCommand.self
        case "window": WindowCommand.MoveSubcommand.self
        case "hide": AppCommand.HideSubcommand.self
        default: PressCommand.self
        }
        var options = try CommanderCLIBinder.makeRuntimeOptions(
            from: ParsedValues(positional: ["return"], options: ["windowId": ["42"]], flags: []),
            commandType: command,
            environment: [:]
        )
        options.autoStartDaemon = false
        return options
    }

    private static func candidate(
        _ path: String, kind: PeekabooBridgeHostKind
    ) -> RuntimeHostResolver.ImplicitRemoteCandidate {
        .init(
            socketPath: path,
            requireReusableDaemon: false,
            requiredHostKind: kind,
            requiresValidatedHistoricalDaemon: false
        )
    }

    private static func handshake(
        kind: PeekabooBridgeHostKind = .onDemand,
        missing: PeekabooBridgePermissionKind? = nil,
        granted: Bool = true
    ) -> PeekabooBridgeHandshakeResponse {
        self.handshake(kind: kind, permissions: .init(
            screenRecording: granted,
            accessibility: granted && missing != .accessibility,
            postEvent: granted && missing != .postEvent
        ))
    }

    private static func handshake(
        kind: PeekabooBridgeHostKind = .onDemand,
        permissions: PermissionsStatus?
    ) -> PeekabooBridgeHandshakeResponse {
        BridgeTestFixtures.handshake(
            negotiatedVersion: PeekabooBridgeConstants.protocolVersion,
            hostKind: kind,
            supportedOperations: [
                .targetedTypeActions,
                .targetedHotkey,
                .getFocusedElement,
                .invalidateImplicitLatestSnapshot,
                .hideApplication
            ],
            permissions: permissions,
            hostCapabilities: [
                PeekabooBridgeHostCapability.attestedOperationReceipts,
                PeekabooBridgeHostCapability.processGenerationPinnedApplicationHide
            ]
        )
    }
}
