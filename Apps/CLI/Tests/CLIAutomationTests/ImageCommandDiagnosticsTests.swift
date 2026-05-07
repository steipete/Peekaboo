import CoreGraphics
import Foundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@MainActor
extension ImageCommandTests {
    @Test(.tags(.imageCapture))
    func `JSON output includes observation diagnostics`() async throws {
        let captureResult = Self.makeScreenCaptureResult(size: CGSize(width: 1200, height: 800), scale: 1.0)
        let captureService = StubScreenCaptureService(permissionGranted: true)
        captureService.captureScreenHandler = { _, _ in
            captureResult
        }

        let services = TestServicesFactory.makePeekabooServices(
            screenCapture: captureService
        )
        let path = Self.makeTempCapturePath("diagnostics.png")

        let result = try await InProcessCommandRunner.run(
            [
                "image",
                "--mode", "screen",
                "--path", path,
                "--json",
            ],
            services: services
        )

        #expect(result.exitStatus == 0)
        let response = try JSONDecoder().decode(
            CodableJSONResponse<ImageCaptureResult>.self,
            from: Data(result.combinedOutput.utf8)
        )
        #expect(response.data.files.count == 1)
        #expect(response.data.observations.count == 1)
        #expect(response.data.observations[0].spans.contains { $0.name == "capture.screen" })
        #expect(response.data.observations[0].state_snapshot != nil)
        try? FileManager.default.removeItem(atPath: path)
    }
}
#endif
