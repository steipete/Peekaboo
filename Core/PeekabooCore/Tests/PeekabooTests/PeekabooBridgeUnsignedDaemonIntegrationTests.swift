import Darwin
import Foundation
import PeekabooAutomationKit
import Testing
@testable import PeekabooBridge

@Suite(.serialized)
struct PeekabooBridgeUnsignedDaemonIntegrationTests {
    @Test(arguments: [false, true])
    @MainActor
    func `developer daemon negotiates bound receipts without release provenance`(emptyAllowlist: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pbdev-\(UUID().uuidString)")
        let socket = root.appendingPathComponent("d.sock").path
        defer { try? FileManager.default.removeItem(at: root) }
        let policy = PeekabooBridgeUnsignedDaemonPolicy(
            environment: ["PEEKABOO_ALLOW_UNSIGNED_DAEMON": "1"],
            currentProcessIsReleaseSigned: { false })
        let teams: Set<String> = emptyAllowlist ? [] : ["RELEASE"]
        let server = PeekabooBridgeServer(
            services: StubServices(),
            hostKind: .onDemand,
            allowlistedTeams: teams,
            allowlistedBundles: [],
            allowedOperations: [.permissionsStatus],
            screenCaptureKitProcessCapabilityRegistrar: {},
            screenCaptureKitOwnershipPreparer: {},
            permissionStatusEvaluator: { _ in
                PermissionsStatus(
                    screenRecording: false,
                    accessibility: false,
                    postEvent: false)
            })
        let host = PeekabooBridgeHost(
            socketPath: socket,
            server: server,
            allowedTeamIDs: teams)
        await host.setAuthenticationForTesting(.init(
            liveIdentity: { try PeekabooBridgeSocketIO.livePeerIdentity(fd: $0) },
            coldPeer: { live, teams in
                PeekabooBridgeHost.peerInfoIfAllowed(
                    liveIdentity: live,
                    allowedTeamIDs: teams,
                    signingIdentityProvider: { _ in nil },
                    allowUnsignedSocketClients: false,
                    hostKind: .onDemand,
                    unsignedDaemonPolicy: policy)
            }))
        try await host.startChecked()
        do {
            let client = PeekabooBridgeClient(
                socketPath: socket,
                trustedHostTeamIDs: ["RELEASE"],
                hostAuthentication: .init(
                    signingIdentity: { _ in nil },
                    currentProcessIsReleaseSigned: { false },
                    unsignedDaemonPolicy: policy))
            let handshake = try await client.handshake(client: .init(
                bundleIdentifier: nil,
                teamIdentifier: nil,
                processIdentifier: getpid()))
            #expect(handshake.trustMode == .unsignedSameBinaryDeveloperOptIn)
            #expect(handshake.operationAttestation != nil)
            #expect(await client.authenticatedHostIdentity() == nil)
            _ = try await client.permissionsStatus()
            #expect(await client.lastOperationReceipt() != nil)
        } catch {
            await host.stop()
            throw error
        }
        await host.stop()
    }
}
