import CoreGraphics
import Foundation
import PeekabooFoundation

struct WatchCaptureFrame {
    let cgImage: CGImage?
    let metadata: CaptureMetadata
    let motionBoxes: [CGRect]?
}

@MainActor
struct WatchCaptureFrameProvider {
    let screenCapture: any ScreenCaptureServiceProtocol
    let frameSource: (any CaptureFrameSource)?
    let scope: CaptureScope
    let options: CaptureOptions
    let regionValidator: WatchCaptureRegionValidator

    func captureFrame() async throws -> (frame: WatchCaptureFrame?, warning: WatchWarning?) {
        if let source = self.frameSource {
            return try await self.captureFrame(from: source)
        }

        let result: CaptureResult
        let warning: WatchWarning?
        switch self.scope.kind {
        case .screen:
            warning = nil
            result = try await self.screenCapture.captureScreen(
                displayIndex: self.scope.screenIndex,
                visualizerMode: .watchCapture,
                scale: .logical1x)
        case .frontmost:
            warning = nil
            result = try await self.screenCapture.captureFrontmost(
                visualizerMode: .watchCapture,
                scale: .logical1x)
        case .window:
            if let windowId = self.scope.windowId {
                warning = nil
                result = try await self.screenCapture.captureWindow(
                    windowID: CGWindowID(windowId),
                    visualizerMode: .watchCapture,
                    scale: .logical1x)
                break
            }

            guard let app = self.scope.applicationIdentifier else {
                throw PeekabooError.windowNotFound(criteria: "missing application identifier")
            }
            warning = nil
            result = try await self.screenCapture.captureWindow(
                appIdentifier: app,
                windowIndex: self.scope.windowIndex,
                visualizerMode: .watchCapture,
                scale: .logical1x)
        case .region:
            guard let rect = self.scope.region else {
                throw PeekabooError.captureFailed(reason: "Region missing for watch capture")
            }
            let validation = try self.regionValidator.validateRegion(rect)
            warning = validation.warning
            result = try await self.screenCapture.captureArea(
                validation.rect,
                visualizerMode: .watchCapture,
                scale: .logical1x)
        }

        guard let image = WatchCaptureArtifactWriter.makeCGImage(from: result.imageData) else {
            return (WatchCaptureFrame(cgImage: nil, metadata: result.metadata, motionBoxes: nil), warning)
        }

        return (
            WatchCaptureFrame(
                cgImage: self.capResolutionIfNeeded(image),
                metadata: result.metadata,
                motionBoxes: nil),
            warning)
    }

    private func captureFrame(from source: any CaptureFrameSource) async throws
        -> (frame: WatchCaptureFrame?, warning: WatchWarning?)
    {
        guard let output = try await source.nextFrame() else { return (nil, nil) }
        guard let image = output.cgImage else {
            return (WatchCaptureFrame(cgImage: nil, metadata: output.metadata, motionBoxes: nil), nil)
        }
        return (
            WatchCaptureFrame(
                cgImage: self.capResolutionIfNeeded(image),
                metadata: output.metadata,
                motionBoxes: nil),
            nil)
    }

    private func capResolutionIfNeeded(_ image: CGImage) -> CGImage {
        guard let cap = self.options.resolutionCap else { return image }
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let maxDimension = max(width, height)
        guard maxDimension > cap else { return image }
        let scale = cap / maxDimension
        let newSize = CGSize(width: width * scale, height: height * scale)
        return WatchCaptureArtifactWriter.resize(image: image, to: newSize) ?? image
    }
}
