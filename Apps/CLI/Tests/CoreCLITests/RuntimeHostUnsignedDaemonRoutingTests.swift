import Darwin
import Foundation
import PeekabooBridgeTestSupport
import Testing
@testable import PeekabooBridge
@testable import PeekabooCLI

@MainActor
@Suite(.tags(.safe))
struct RuntimeHostUnsignedDaemonRoutingTests {
    @Test(arguments: [false, true])
    func `unsigned without opt-in skips daemon launch and falls back`(exactBuild: Bool) async throws {
        let fixture = Fixture(exactBuild: exactBuild)
        let resolution = try await fixture.resolve()
        #expect(fixture.launches.isEmpty)
        #expect(resolution.selectedRemoteSocketPath == nil)
        #expect(resolution.hostDescription.contains("auto-start skipped"))
    }

    @Test(arguments: [false, true], [false, true])
    func `unsigned untrusted daemon falls back without relaunch`(exactBuild: Bool, optIn: Bool) async throws {
        let fixture = Fixture(exactBuild: exactBuild, optIn: optIn, failure: Self.authenticationFailure())
        let resolution = try await fixture.resolve()
        #expect(fixture.launches.isEmpty)
        #expect(resolution.selectedRemoteSocketPath == nil)
        #expect(resolution.hostDescription.contains("untrusted host"))
    }

    @Test
    func `unsigned client continues from untrusted daemon to another candidate`() async throws {
        let fixture = Fixture(failure: Self.authenticationFailure())
        fixture.availableFallback = true
        let resolution = try await fixture.resolve()
        #expect(resolution.selectedRemoteSocketPath == "/fixture/bridge.sock")
        #expect(fixture.launches.isEmpty)
    }

    @Test(arguments: [false, true], [false, true])
    func `release signed or opted-in clients retain auto-start`(exactBuild: Bool, releaseSigned: Bool) async throws {
        let fixture = Fixture(exactBuild: exactBuild, releaseSigned: releaseSigned, optIn: !releaseSigned)
        _ = try await fixture.resolve()
        #expect(fixture.launches == [fixture.socketPath])
    }

    @Test(arguments: [false, true])
    func `release signed client still surfaces untrusted occupancy`(exactBuild: Bool) async {
        let fixture = Fixture(exactBuild: exactBuild, releaseSigned: true, failure: Self.authenticationFailure())
        let error = await #expect(throws: PeekabooBridgeErrorEnvelope.self) { try await fixture.resolve() }
        #expect(error?.isLocalHostAuthenticationFailure == true)
        #expect(fixture.launches.isEmpty)
    }

    @Test(arguments: [false, true], [PeekabooBridgeErrorCode.timeout, .unauthorizedClient, .internalError])
    func `non authentication probe errors still surface`(exactBuild: Bool, code: PeekabooBridgeErrorCode) async {
        let failure = PeekabooBridgeErrorEnvelope(code: code, message: "unmarked probe error")
        let fixture = Fixture(exactBuild: exactBuild, optIn: true, failure: failure)
        let error = await #expect(throws: PeekabooBridgeErrorEnvelope.self) { try await fixture.resolve() }
        #expect(error?.code == code)
        #expect(fixture.launches.isEmpty)
    }

    @Test(arguments: [false, true])
    func `authentication race during implicit startup falls back`(releaseSigned: Bool) async throws {
        let fixture = Fixture(releaseSigned: releaseSigned, optIn: true)
        fixture.launchFailure = Self.authenticationFailure()
        if releaseSigned {
            let error = await #expect(throws: PeekabooBridgeErrorEnvelope.self) { try await fixture.resolve() }
            #expect(error?.isLocalHostAuthenticationFailure == true)
        } else {
            let resolution = try await fixture.resolve()
            #expect(resolution.selectedRemoteSocketPath == nil)
            #expect(resolution.hostDescription.contains("untrusted host"))
        }
        #expect(fixture.launches == [fixture.socketPath])
    }

    @Test(arguments: [false, true])
    func `explicit socket retains host authentication error and installation hint`(environmentSelected: Bool) async {
        let fixture = Fixture(failure: Self.authenticationFailure(), explicit: true)
        let error = await #expect(throws: PeekabooBridgeErrorEnvelope.self) {
            try await fixture.resolve(environmentSelected: environmentSelected)
        }
        #expect(error?.isLocalHostAuthenticationFailure == true)
        #expect(error?.message.contains(PeekabooBridgeSigningDiagnostics.unsignedBuildHint) == true)
        #expect(fixture.launches.isEmpty)
    }

    @Test
    func `explicit daemon status preserves local authentication failure and installation hint`() async throws {
        let peer = try ScriptedBridgePeer(responses: [.handshake(BridgeTestFixtures.handshake(
            negotiatedVersion: .init(major: 1, minor: 28), hostKind: .onDemand, supportedOperations: [.daemonStatus]
        ))])
        let client = PeekabooBridgeClient(
            socketPath: peer.socketPath,
            trustedHostTeamIDs: ["FWJYW4S8P8"],
            hostAuthentication: .init(
                signingIdentity: { _ in nil },
                currentProcessIsReleaseSigned: { false },
                unsignedDaemonPolicy: .init(environment: [:], currentProcessIsReleaseSigned: { false })
            )
        )
        let error = await #expect(throws: PeekabooBridgeErrorEnvelope.self) {
            try await DaemonControlClient(socketPath: peer.socketPath).fetchStatus(using: client)
        }
        await peer.stop()
        #expect(error?.isLocalHostAuthenticationFailure == true)
        #expect(error?.message.contains(PeekabooBridgeSigningDiagnostics.unsignedBuildHint) == true)
    }

    private static func authenticationFailure() -> PeekabooBridgeErrorEnvelope {
        do {
            try PeekabooBridgeConnectedHostTrust.validate(
                nil,
                socketPath: "/fixture/daemon.sock",
                trustedTeamIDs: ["FWJYW4S8P8"],
                unsignedDaemonPolicy: .init(environment: [:], currentProcessIsReleaseSigned: { false }),
                currentProcessIsReleaseSigned: { false }
            )
        } catch let error as PeekabooBridgeErrorEnvelope {
            return error
        } catch {
            preconditionFailure("Unexpected authentication error: \(error)")
        }
        preconditionFailure("Missing host identity cannot authenticate")
    }

    private final class Fixture {
        let socketPath = "/fixture/daemon.sock"
        let exactBuild: Bool
        let releaseSigned: Bool
        let optIn: Bool
        let failure: PeekabooBridgeErrorEnvelope?
        let explicit: Bool
        var launches: [String] = []
        var launchFailure: PeekabooBridgeErrorEnvelope?
        var availableFallback = false

        init(
            exactBuild: Bool = false,
            releaseSigned: Bool = false,
            optIn: Bool = false,
            failure: PeekabooBridgeErrorEnvelope? = nil,
            explicit: Bool = false
        ) {
            self.exactBuild = exactBuild
            self.releaseSigned = releaseSigned
            self.optIn = optIn
            self.failure = failure
            self.explicit = explicit
        }

        func resolve(environmentSelected: Bool = false) async throws -> RuntimeHostResolver.Resolution {
            var options = CommandRuntimeOptions()
            options.preferRemote = true
            options.autoStartDaemon = true
            options.requiresImplicitSnapshotInvalidation = self.exactBuild
            if self.explicit, !environmentSelected {
                options.bridgeSocketPath = self.socketPath
            }
            var environment = self.optIn ? ["PEEKABOO_ALLOW_UNSIGNED_DAEMON": "1"] : [:]
            if self.explicit, environmentSelected {
                environment["PEEKABOO_BRIDGE_SOCKET"] = self.socketPath
            }
            let dependencies = RuntimeHostResolver.Dependencies(
                makeLocalServices: { _ in OwnerPolicyFixtureServices(ownerAware: true) },
                claimScreenCaptureKitOwner: { fatalError("No capture ownership claims") },
                inspectScreenCaptureKitOwner: { nil },
                remoteCandidatePlan: { _, _ in
                    .init(
                        explicitSocket: self.explicit ? self.socketPath : nil,
                        daemonSocketPath: self.socketPath,
                        runtimeBuildIdentity: "fixture",
                        buildScopedDaemonSocketPath: self.exactBuild ? self.socketPath : nil,
                        historicalBuildScopedDaemonSocketPaths: [],
                        candidates: [.init(
                            socketPath: self.socketPath,
                            requireReusableDaemon: !self.explicit,
                            requiredHostKind: nil,
                            requiresValidatedHistoricalDaemon: false
                        )] + (self.availableFallback ? [.init(
                            socketPath: "/fixture/bridge.sock",
                            requireReusableDaemon: false,
                            requiredHostKind: .gui,
                            requiresValidatedHistoricalDaemon: false
                        )] : [])
                    )
                },
                makeRemoteHandshakeCache: {
                    .init(
                        identity: .init(bundleIdentifier: nil, teamIdentifier: nil, processIdentifier: getpid()),
                        handshakeProvider: { candidate, _ in
                            if candidate.socketPath == "/fixture/bridge.sock" {
                                return BridgeTestFixtures.handshake(
                                    negotiatedVersion: PeekabooBridgeConstants.protocolVersion,
                                    hostKind: .gui,
                                    supportedOperations: []
                                )
                            }
                            if let failure = self.failure {
                                throw failure
                            }
                            throw POSIXError(.ENOENT)
                        }
                    )
                },
                makeRemoteServices: { _, _, _ in OwnerPolicyFixtureServices(ownerAware: true) },
                callerPermissionPreflight: { nil },
                startOnDemandDaemon: { path, _ in
                    self.launches.append(path)
                    if let launchFailure = self.launchFailure {
                        throw launchFailure
                    }
                    return nil
                },
                fetchDaemonStatus: { _ in
                    if let failure = self.failure {
                        throw failure
                    }
                    return nil
                },
                currentProcessIsReleaseSigned: { self.releaseSigned }
            )
            return try await RuntimeHostResolver.resolveServices(
                options: options, environment: environment, configurationInput: nil, dependencies: dependencies
            )
        }
    }
}
