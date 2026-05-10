import Foundation
import PeekabooAutomationKit
import PeekabooBridge
import PeekabooCore
import Testing

struct PeekabooBridgeOperationRoutingTests {
    private func decode(_ data: Data) throws -> PeekabooBridgeResponse {
        try JSONDecoder.peekabooBridgeDecoder().decode(PeekabooBridgeResponse.self, from: data)
    }

    @Test
    @MainActor
    func `desktop observation bridge operation forwards request without returning image bytes`() async throws {
        let services = StubServices()
        let server = PeekabooBridgeServer(
            services: services,
            allowlistedTeams: [],
            allowlistedBundles: [],
            allowedOperations: [.desktopObservation],
            permissionStatusEvaluator: { _ in
                PermissionsStatus(screenRecording: true, accessibility: true, appleScript: true, postEvent: true)
            })
        let request = DesktopObservationRequest(
            target: .screen(index: 0),
            detection: DesktopDetectionOptions(mode: .none),
            output: DesktopObservationOutputOptions(path: "/tmp/stub.png", saveRawScreenshot: true))
        let requestData = try JSONEncoder.peekabooBridgeEncoder()
            .encode(PeekabooBridgeRequest.desktopObservation(request))
        let response = try await self.decode(server.decodeAndHandle(requestData, peer: nil))

        guard case let .desktopObservation(result) = response else {
            Issue.record("Expected desktopObservation response, got \(response)")
            return
        }

        #expect(services.desktopObservationStub.lastRequest == request)
        #expect(result.capture.savedPath == "/tmp/stub.png")
        #expect(result.files.rawScreenshotPath == "/tmp/stub.png")
        #expect(result.capture.imageData.isEmpty)
    }

    @Test
    @MainActor
    func `browser bridge operations route through service provider`() async throws {
        let services = StubServices()
        let server = PeekabooBridgeServer(
            services: services,
            allowlistedTeams: [],
            allowlistedBundles: [],
            allowedOperations: [.browserStatus, .browserExecute])

        let statusRequest = PeekabooBridgeRequest.browserStatus(.init(channel: "stable"))
        let statusData = try JSONEncoder.peekabooBridgeEncoder().encode(statusRequest)
        let statusResponse = try await self.decode(server.decodeAndHandle(statusData, peer: nil))

        guard case let .browserStatus(status) = statusResponse else {
            Issue.record("Expected browserStatus response, got \(statusResponse)")
            return
        }
        #expect(status.isConnected)
        #expect(status.toolCount == 1)
        #expect(services.lastBrowserStatusChannel == "stable")

        let executeRequest = PeekabooBridgeRequest.browserExecute(.init(
            toolName: "list_pages",
            arguments: ["page": .int(1)],
            channel: "canary"))
        let executeData = try JSONEncoder.peekabooBridgeEncoder().encode(executeRequest)
        let executeResponse = try await self.decode(server.decodeAndHandle(executeData, peer: nil))

        guard case let .browserToolResponse(toolResponse) = executeResponse else {
            Issue.record("Expected browserToolResponse response, got \(executeResponse)")
            return
        }
        #expect(toolResponse.isError == false)
        #expect(services.lastBrowserExecute?.toolName == "list_pages")
        #expect(services.lastBrowserExecute?.channel == "canary")
    }
}
