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
    @Test("Region clamp emits warning")
    @MainActor
    func regionClampWarning() async throws {
        let stubCapture = StubScreenCaptureService(permissionGranted: true)
        let png = WatchCommandTests.makePNG(color: .systemTeal, size: CGSize(width: 50, height: 50))
        stubCapture.captureAreaHandler = { _ in
            return CaptureResult(
                imageData: png,
                savedPath: nil,
                metadata: CaptureMetadata(
                    size: CGSize(width: 50, height: 50),
                    mode: .area,
                    applicationInfo: nil,
                    windowInfo: nil,
                    displayInfo: nil,
                    timestamp: Date()))
        }

        // A region that is partially off-screen will be clamped and produce a warning.
        let args = [
            "watch",
            "--mode", "region",
            "--region", "-10,-10,40,40",
            "--duration", "1",
            "--json-output"
        ]

        let ctx = TestServicesFactory.makeAutomationTestContext(
            screens: [
                ScreenInfo(index: 0, name: "Test", frame: CGRect(x: 0, y: 0, width: 100, height: 100), visibleFrame: CGRect(x: 0, y: 0, width: 100, height: 100), isPrimary: true, scaleFactor: 2, displayID: 1)
            ],
            screenCapture: stubCapture)

        let result = try await InProcessCommandRunner.run(args, services: ctx.services)
        #expect(result.exitStatus == 0)
        let decoded = try JSONDecoder().decode(WatchCaptureResult.self, from: Data(result.stdout.utf8))
        #expect(decoded.warnings.contains { $0.code == .displayChanged })
    }
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
    @Test("Emits diffDowngraded when SSIM exceeds budget")
    @MainActor
    func emitsDiffDowngradedWarning() async throws {
        let stubCapture = StubScreenCaptureService(permissionGranted: true)
        // Make SSIM path slow by injecting a large image and low budget.
        let data = WatchCommandTests.makePNG(color: .systemYellow, size: CGSize(width: 400, height: 400))
        stubCapture.captureFrontmostHandler = {
            return CaptureResult(
                imageData: data,
                savedPath: nil,
                metadata: CaptureMetadata(
                    size: CGSize(width: 400, height: 400),
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
            "--idle-fps", "2",
            "--active-fps", "2",
            "--threshold", "0.1",
            "--max-frames", "1",
            "--diff-strategy", "quality",
            "--diff-budget-ms", "1",
            "--json-output"
        ]

        let result = try await InProcessCommandRunner.run(args, services: ctx.services)
        #expect(result.exitStatus == 0)
        let decoded = try JSONDecoder().decode(WatchCaptureResult.self, from: Data(result.stdout.utf8))
        #expect(decoded.warnings.contains { $0.code == .diffDowngraded })
    }

    @Test("Meta summary mirrors capture result")
    @MainActor
    func metaSummaryMatchesResult() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-meta-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        var call = 0
        let frames = [
            WatchCommandTests.makePNG(color: .systemRed, size: CGSize(width: 20, height: 20)),
            WatchCommandTests.makePNG(color: .systemBlue, size: CGSize(width: 20, height: 20))
        ]

        let stubCapture = StubScreenCaptureService(permissionGranted: true)
        stubCapture.captureFrontmostHandler = {
            defer { call += 1 }
            let data = frames[call % frames.count]
            return CaptureResult(
                imageData: data,
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
            "--duration", "1",
            "--idle-fps", "4",
            "--active-fps", "6",
            "--threshold", "0.1",
            "--max-frames", "3",
            "--path", tmp.path,
            "--json-output"
        ]

        let result = try await InProcessCommandRunner.run(args, services: ctx.services)
        #expect(result.exitStatus == 0)
        let decoded = try JSONDecoder().decode(WatchCaptureResult.self, from: Data(result.stdout.utf8))
        let meta = WatchMetaSummary.make(from: decoded)

        #expect(meta.frames == decoded.frames.map(\.path))
        #expect(meta.contactPath == decoded.contactSheet.path)
        #expect(meta.metadataPath == decoded.metadataFile)
        #expect(meta.diffAlgorithm == decoded.diffAlgorithm)
        #expect(meta.diffScale == decoded.diffScale)
        #expect(meta.contactColumns == decoded.contactColumns)
        #expect(meta.contactRows == decoded.contactRows)
        #expect(meta.contactSampledIndexes == decoded.contactSampledIndexes)
    }
