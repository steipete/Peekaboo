import CoreGraphics
import Foundation
import PeekabooFoundation
@preconcurrency import ScreenCaptureKit

@MainActor
final class SingleShotFrameSource: CaptureFrameSource {
    private let logger: CategoryLogger
    private var currentRequest: CaptureFrameRequest?

    init(logger: CategoryLogger) {
        self.logger = logger
    }

    func start(request: CaptureFrameRequest) async throws {
        self.currentRequest = request
    }

    func stop() async {
        self.currentRequest = nil
    }

    func nextFrame() async throws -> (cgImage: CGImage?, metadata: CaptureMetadata)? {
        try await self.nextFrame(maxAge: nil)
    }

    func nextFrame(maxAge _: TimeInterval?) async throws -> (cgImage: CGImage?, metadata: CaptureMetadata)? {
        guard let request = self.currentRequest else {
            throw OperationError.captureFailed(reason: "Single-shot capture request missing")
        }

        let display = request.display
        let sourceRect = request.sourceRect
        let scaleFactor = Self.scaleFactor(for: display, preference: request.scale)

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        config.width = Int(sourceRect.width * scaleFactor)
        config.height = Int(sourceRect.height * scaleFactor)
        config.captureResolution = .best
        config.showsCursor = false

        let start = Date()
        let image = try await RetryHandler.withRetry(policy: .standard) {
            try await withTimeout(seconds: 3.0) {
                try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config)
            }
        }
        let duration = Date().timeIntervalSince(start)
        self.logger.debug(
            "Single-shot capture complete",
            metadata: [
                "durationMs": Int(duration * 1000),
                "displayID": display.displayID,
            ],
            correlationId: request.correlationId)

        let size: CGSize = if request.mode == .area {
            request.displayBounds.size
        } else {
            CGSize(width: image.width, height: image.height)
        }

        let metadata = CaptureMetadata(
            size: size,
            mode: request.mode,
            displayInfo: DisplayInfo(
                index: request.displayIndex,
                name: request.displayName ?? display.displayID.description,
                bounds: request.displayBounds,
                scaleFactor: scaleFactor),
            timestamp: Date())

        return (cgImage: image, metadata: metadata)
    }

    private nonisolated static func scaleFactor(
        for display: SCDisplay,
        preference: CaptureScalePreference) -> CGFloat
    {
        let nativeScale: CGFloat = {
            let width = CGFloat(display.width)
            let frameWidth = display.frame.width
            guard frameWidth > 0 else { return 1.0 }
            let scale = width / frameWidth
            return scale > 0 ? scale : 1.0
        }()

        switch preference {
        case .native:
            return nativeScale
        case .logical1x:
            return 1.0
        }
    }
}
