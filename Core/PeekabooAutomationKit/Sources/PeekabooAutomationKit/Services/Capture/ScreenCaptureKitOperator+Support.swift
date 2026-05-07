import CoreGraphics
import Foundation
import PeekabooFoundation
@preconcurrency import ScreenCaptureKit

@MainActor
extension ScreenCaptureKitOperator {
    func captureDisplayFrame(
        request: CaptureFrameRequest) async throws -> (image: CGImage, metadata: CaptureMetadata)
    {
        let policy = ScreenCapturePlanner.frameSourcePolicy(for: request.mode, windowID: nil)
        if self.useFastStream, policy == .fastStream {
            do {
                try await self.frameSource.start(request: request)
                if let output = try await self.frameSource.nextFrame(maxAge: nil),
                   let image = output.cgImage
                {
                    return (image: image, metadata: output.metadata)
                }
                throw OperationError.captureFailed(reason: "Fast stream produced no image")
            } catch {
                self.logger.warning(
                    "Fast frame source failed, falling back to single-shot",
                    metadata: ["error": String(describing: error)],
                    correlationId: request.correlationId)
            }
        }

        try await self.fallbackFrameSource.start(request: request)
        guard let output = try await self.fallbackFrameSource.nextFrame(maxAge: nil),
              let image = output.cgImage
        else {
            throw OperationError.captureFailed(reason: "Single-shot produced no image")
        }

        return (image: image, metadata: output.metadata)
    }

    func emitVisualizer(mode: CaptureVisualizerMode, rect: CGRect) async {
        switch mode {
        case .screenshotFlash:
            _ = await self.feedbackClient.showScreenshotFlash(in: rect)
        case .watchCapture:
            _ = await self.feedbackClient.showWatchCapture(in: rect)
        }
    }

    nonisolated static func windowIndexError(requestedIndex: Int, totalWindows: Int) -> String {
        let lastIndex = max(totalWindows - 1, 0)
        return "windowIndex: Index \(requestedIndex) is out of range. Valid windows: 0-\(lastIndex)"
    }

    func scalePlan(
        for display: SCDisplay,
        preference: CaptureScalePreference) -> ScreenCaptureScaleResolver.Plan
    {
        ScreenCaptureScaleResolver.plan(
            preference: preference,
            displayID: display.displayID,
            fallbackPixelWidth: display.width,
            frameWidth: display.frame.width)
    }

    func display(for window: SCWindow, displays: [SCDisplay]) -> SCDisplay? {
        displays.first(where: { $0.frame.intersects(window.frame) })
    }
}
