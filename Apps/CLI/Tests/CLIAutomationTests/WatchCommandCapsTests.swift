import AppKit
import Foundation
import PeekabooAutomation
import PeekabooCore
import PeekabooFoundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite("WatchCommand caps warnings", .tags(.automation), .enabled(if: CLITestEnvironment.runAutomationActions))
struct WatchCommandCapsTests {
    @Test("Emits frameCap warning when max-frames hit")
    @MainActor
    func emitsFrameCapWarning() async throws {
        let stubCapture = StubScreenCaptureService(permissionGranted: true)
        let png = makePNG(color: .systemPink)
        stubCapture.captureFrontmostHandler = {
            return CaptureResult(
                imageData: png,
                savedPath: nil,
                metadata: CaptureMetadata(
                    size: CGSize(width: 20, height: 20),
                    mode: .frontmost,
                    applicationInfo: nil,
                    windowInfo: nil,
                    displayInfo: nil,
                    timestamp: Date()))
        }

        let ctx = TestServicesFactory.makeAutomationTestContext(
            screens: [
                ScreenInfo(index: 0, name: "Test", frame: CGRect(x: 0, y: 0, width: 100, height: 100), visibleFrame: CGRect(x: 0, y: 0, width: 100, height: 100), isPrimary: true, scaleFactor: 2, displayID: 1)
            ],
            screenCapture: stubCapture)

        let args = [
            "watch",
            "--duration", "2",
            "--idle-fps", "10",
            "--active-fps", "10",
            "--threshold", "0",
            "--max-frames", "1",
            "--json-output"
        ]

        let result = try await InProcessCommandRunner.run(args, services: ctx.services)
        #expect(result.exitStatus == 0)
        let decoded = try JSONDecoder().decode(WatchCaptureResult.self, from: Data(result.stdout.utf8))
        #expect(decoded.warnings.contains { $0.code == .frameCap })
    }

    @Test("Emits sizeCap warning when optional max-mb hit")
    @MainActor
    func emitsSizeCapWarning() async throws {
        let stubCapture = StubScreenCaptureService(permissionGranted: true)
        // Large fake frame (~1MB) to trip a low max-mb.
        let png = makePNG(color: .systemGray, size: CGSize(width: 500, height: 500))
        stubCapture.captureFrontmostHandler = {
            return CaptureResult(
                imageData: png,
                savedPath: nil,
                metadata: CaptureMetadata(
                    size: CGSize(width: 500, height: 500),
                    mode: .frontmost,
                    applicationInfo: nil,
                    windowInfo: nil,
                    displayInfo: nil,
                    timestamp: Date()))
        }

        let ctx = TestServicesFactory.makeAutomationTestContext(
            screens: [
                ScreenInfo(index: 0, name: "Test", frame: CGRect(x: 0, y: 0, width: 100, height: 100), visibleFrame: CGRect(x: 0, y: 0, width: 100, height: 100), isPrimary: true, scaleFactor: 2, displayID: 1)
            ],
            screenCapture: stubCapture)

        let args = [
            "watch",
            "--duration", "2",
            "--idle-fps", "5",
            "--active-fps", "5",
            "--threshold", "0",
            "--max-mb", "1", // low cap to trigger early stop
            "--json-output"
        ]

        let result = try await InProcessCommandRunner.run(args, services: ctx.services)
        #expect(result.exitStatus == 0)
        let decoded = try JSONDecoder().decode(WatchCaptureResult.self, from: Data(result.stdout.utf8))
        #expect(decoded.warnings.contains { $0.code == .sizeCap })
    }

    // MARK: - Helpers

    private func makePNG(color: NSColor, size: CGSize = CGSize(width: 20, height: 20)) -> Data {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSColor.clear.setStroke()
        CGRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        guard
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let png = rep.representation(using: .png, properties: [:])
        else {
            fatalError("Failed to make png")
        }
        return png
    }
}
#endif
