import CoreGraphics
import Foundation
import PeekabooCore
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@MainActor
extension ImageCommandTests {
    static let validFormats: [ImageFormat] = [.png, .jpg]
    static let validCaptureModes: [CaptureMode] = [.screen, .window, .multi]
    static let validCaptureFocus: [CaptureFocus] = [.background, .foreground]

    static func createTestCommand(_ args: [String] = []) throws -> ImageCommand {
        try ImageCommand.parse(args)
    }

    static func makeTempCapturePath(_ suffix: String) -> String {
        FileManager.default
            .temporaryDirectory
            .appendingPathComponent("image-command-tests-\(UUID().uuidString)-\(suffix)")
            .path
    }

    static func makeCaptureResult(
        app: ServiceApplicationInfo,
        window: ServiceWindowInfo
    ) -> CaptureResult {
        let metadata = CaptureMetadata(
            size: window.bounds.size,
            mode: .window,
            applicationInfo: app,
            windowInfo: window
        )
        return CaptureResult(
            imageData: Data(repeating: 0xAB, count: 32),
            metadata: metadata
        )
    }

    static func makeScreenInfo(scale: CGFloat) -> ScreenInfo {
        ScreenInfo(
            index: 0,
            name: "Retina",
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            isPrimary: true,
            scaleFactor: scale,
            displayID: 1
        )
    }

    static func makeScreenCaptureResult(size: CGSize, scale: CGFloat) -> CaptureResult {
        let metadata = CaptureMetadata(
            size: size,
            mode: .screen,
            displayInfo: DisplayInfo(
                index: 0,
                name: "Retina",
                bounds: CGRect(origin: .zero, size: CGSize(width: size.width / scale, height: size.height / scale)),
                scaleFactor: scale
            )
        )
        return CaptureResult(
            imageData: Data(repeating: 0xCD, count: 16),
            metadata: metadata
        )
    }
}
#endif
