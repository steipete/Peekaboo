import AppKit
import Foundation
import PeekabooAutomation
import PeekabooCore
import PeekabooFoundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite("WatchCommand automation", .tags(.automation), .enabled(if: CLITestEnvironment.runAutomationActions))
struct WatchCommandTests {
    @Test("Captures and returns contact metadata in JSON")
    @MainActor
    func watchJsonIncludesContactMetadata() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-json-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        // Two-frame fake capture: red then blue to guarantee change.
        var call = 0
        let frames = [
            WatchCommandTests.makePNG(color: .systemRed),
            WatchCommandTests.makePNG(color: .systemBlue)
        ]

        let stubCapture = StubScreenCaptureService(permissionGranted: true)
        stubCapture.captureFrontmostHandler = {
            defer { call += 1 }
            let data = frames[call % frames.count]
            return CaptureResult(
                imageData: data,
                savedPath: nil,
                metadata: CaptureMetadata(
                    size: CGSize(width: 10, height: 10),
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
            "--duration", "1",
            "--idle-fps", "5",
            "--active-fps", "5",
            "--threshold", "0.1",
            "--max-frames", "2",
            "--path", tmp.path,
            "--json-output"
        ]

        let result = try await InProcessCommandRunner.run(args, services: ctx.services)
        #expect(result.exitStatus == 0)
        let decoded = try JSONDecoder().decode(WatchCaptureResult.self, from: Data(result.stdout.utf8))

        #expect(decoded.frames.count == 2)
        #expect(decoded.contactColumns == 6 || decoded.contactColumns > 0)
        #expect(decoded.contactSampledIndexes.count > 0)
        #expect(decoded.diffAlgorithm == "fast")
    }

    // MARK: - Helpers

    private static func makePNG(color: NSColor, size: CGSize = CGSize(width: 10, height: 10)) -> Data {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSColor.clear.setStroke()
        let rect = CGRect(origin: .zero, size: size)
        rect.fill()
        image.unlockFocus()

        guard
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let png = rep.representation(using: .png, properties: [:])
        else {
            fatalError("Failed to build PNG")
        }
        return png
    }
}
#endif
