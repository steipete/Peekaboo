import CoreGraphics
import Foundation
import PeekabooAutomationKit
import PeekabooBridge
import PeekabooCore
import Testing

struct PeekabooBridgeTargetedClickTests {
    private func decode(_ data: Data) throws -> PeekabooBridgeResponse {
        try JSONDecoder.peekabooBridgeDecoder().decode(PeekabooBridgeResponse.self, from: data)
    }

    @Test
    @MainActor
    func `automation targeted click is forwarded`() async throws {
        let services = StubServices()
        let server = PeekabooBridgeServer(
            services: services,
            hostKind: .gui,
            allowlistedTeams: [],
            allowlistedBundles: [],
            postEventAccessEvaluator: { true })

        let request = PeekabooBridgeRequest.targetedClick(
            PeekabooBridgeTargetedClickRequest(
                target: .coordinates(CGPoint(x: 10, y: 20)),
                clickType: .double,
                snapshotId: nil,
                targetProcessIdentifier: 9001))
        let requestData = try JSONEncoder.peekabooBridgeEncoder().encode(request)
        let responseData = await server.decodeAndHandle(requestData, peer: nil)
        let response = try self.decode(responseData)

        guard case .ok = response else {
            Issue.record("Expected ok response, got \(response)")
            return
        }

        let lastClick = services.automationStub.lastProcessTargetedClick
        if case let .coordinates(point) = lastClick?.target {
            #expect(point == CGPoint(x: 10, y: 20))
        } else {
            Issue.record("Expected coordinates click, got \(String(describing: lastClick?.target))")
        }
        #expect(lastClick?.type == .double)
        #expect(lastClick?.targetProcessIdentifier == 9001)
    }

    @Test
    @MainActor
    func `targeted click is disabled when post event access is missing`() async throws {
        let server = PeekabooBridgeServer(
            services: StubServices(),
            hostKind: .gui,
            allowlistedTeams: [],
            allowlistedBundles: [],
            postEventAccessEvaluator: { false })

        let identity = PeekabooBridgeClientIdentity(
            bundleIdentifier: "dev.peeka.cli",
            teamIdentifier: "TEAMID",
            processIdentifier: getpid(),
            hostname: Host.current().name)
        let handshakeRequest = PeekabooBridgeRequest.handshake(
            .init(
                protocolVersion: PeekabooBridgeConstants.protocolVersion,
                client: identity,
                requestedHostKind: .gui))

        let handshakeData = try JSONEncoder.peekabooBridgeEncoder().encode(handshakeRequest)
        let handshakeResponseData = await server.decodeAndHandle(handshakeData, peer: nil)
        let handshakeResponse = try self.decode(handshakeResponseData)

        guard case let .handshake(handshake) = handshakeResponse else {
            Issue.record("Expected handshake response, got \(handshakeResponse)")
            return
        }

        #expect(handshake.supportedOperations.contains(.targetedClick))
        #expect(handshake.enabledOperations?.contains(.targetedClick) == false)
        #expect(handshake.permissionTags[PeekabooBridgeOperation.targetedClick.rawValue] == [.postEvent])
    }

    @Test
    func `background input operations only require post event permission`() {
        #expect(PeekabooBridgeOperation.targetedHotkey.requiredPermissions == [.postEvent])
        #expect(PeekabooBridgeOperation.targetedClick.requiredPermissions == [.postEvent])
    }

    @Test
    func `element action operations require accessibility permission`() {
        #expect(PeekabooBridgeOperation.setValue.requiredPermissions == [.accessibility])
        #expect(PeekabooBridgeOperation.performAction.requiredPermissions == [.accessibility])
    }

    @Test
    func `desktop observation operation requires screen recording permission`() {
        #expect(PeekabooBridgeOperation.desktopObservation.requiredPermissions == [.screenRecording])
    }
}
