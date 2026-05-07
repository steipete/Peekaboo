import CoreGraphics
import CoreImage
import CoreMedia
import Dispatch
import Foundation
import PeekabooFoundation
@preconcurrency import ScreenCaptureKit

struct SCKFrameStreamKey: Hashable {
    let displayID: CGDirectDisplayID
    let scale: CaptureScalePreference
}

struct SCKFrameContext {
    let displayFrame: CGRect
    let scaleFactor: CGFloat
    let sourceRect: CGRect
}

struct SCKFrame {
    let image: CGImage
    let timestamp: Date
    let displayFrame: CGRect
    let scaleFactor: CGFloat
    let sourceRect: CGRect
}

final class SCKStreamFrameHandler: NSObject, SCStreamOutput, SCStreamDelegate {
    private let context: CIContext
    private let onFrame: @MainActor (CGImage, Date, CGRect) -> Void
    private let onError: @MainActor (any Error) -> Void

    init(
        context: CIContext = CIContext(),
        onFrame: @escaping @MainActor (CGImage, Date, CGRect) -> Void,
        onError: @escaping @MainActor (any Error) -> Void)
    {
        self.context = context
        self.onFrame = onFrame
        self.onError = onError
    }

    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType)
    {
        guard type == .screen else { return }
        guard let imageBuffer = sampleBuffer.imageBuffer else { return }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = self.context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let timestamp = Date()
        let rect = ciImage.extent

        let onFrame = self.onFrame
        Task { @MainActor in
            onFrame(cgImage, timestamp, rect)
        }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        let onError = self.onError
        Task { @MainActor in
            onError(error)
        }
    }
}

@MainActor
final class SCKStreamSession {
    let key: SCKFrameStreamKey
    let display: SCDisplay
    let scaleFactor: CGFloat
    let logger: CategoryLogger
    let stream: SCStream
    let handler: SCKStreamFrameHandler
    let queue: DispatchQueue

    var isRunning = false
    var currentSourceRect: CGRect
    var currentSize: CGSize
    var pendingError: (any Error)?

    init(
        key: SCKFrameStreamKey,
        display: SCDisplay,
        scaleFactor: CGFloat,
        logger: CategoryLogger,
        handler: SCKStreamFrameHandler,
        queue: DispatchQueue) throws
    {
        self.key = key
        self.display = display
        self.scaleFactor = scaleFactor
        self.logger = logger
        self.handler = handler
        self.queue = queue

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        let logicalSize = display.frame.size
        let width = Int(logicalSize.width * scaleFactor)
        let height = Int(logicalSize.height * scaleFactor)
        config.width = width
        config.height = height
        config.sourceRect = CGRect(origin: .zero, size: logicalSize)
        config.captureResolution = .best
        config.showsCursor = false
        config.capturesAudio = false
        config.shouldBeOpaque = true
        config.queueDepth = 1

        if let fps = ScreenCaptureKitFrameSource.defaultFPS {
            config.minimumFrameInterval = CMTime(value: 1, timescale: fps)
        }

        self.currentSourceRect = config.sourceRect
        self.currentSize = CGSize(width: width, height: height)

        let stream = SCStream(filter: filter, configuration: config, delegate: handler)
        self.stream = stream
        try stream.addStreamOutput(handler, type: .screen, sampleHandlerQueue: queue)
    }

    func start(correlationId: String) async throws {
        guard !self.isRunning else { return }
        do {
            let stream = self.stream
            try await withTimeout(seconds: 3.0) {
                try await stream.startCapture()
            }
            self.isRunning = true
            self.logger.debug(
                "Fast stream started",
                metadata: [
                    "displayID": self.display.displayID,
                    "scaleFactor": self.scaleFactor,
                ],
                correlationId: correlationId)
        } catch {
            self.pendingError = error
            throw error
        }
    }

    func ensureConfiguration(
        sourceRect: CGRect,
        size: CGSize,
        correlationId: String) async throws
    {
        guard self.currentSourceRect != sourceRect || self.currentSize != size else { return }
        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        config.width = Int(size.width)
        config.height = Int(size.height)
        config.captureResolution = .best
        config.showsCursor = false
        config.capturesAudio = false
        config.shouldBeOpaque = true
        config.queueDepth = 1
        if let fps = ScreenCaptureKitFrameSource.defaultFPS {
            config.minimumFrameInterval = CMTime(value: 1, timescale: fps)
        }

        let stream = self.stream
        let start = Date()
        try await withTimeout(seconds: 3.0) {
            try await stream.updateConfiguration(config)
        }
        let duration = Date().timeIntervalSince(start)
        self.currentSourceRect = sourceRect
        self.currentSize = size

        self.logger.debug(
            "Fast stream config updated",
            metadata: [
                "durationMs": Int(duration * 1000),
                "displayID": self.display.displayID,
            ],
            correlationId: correlationId)
    }
}
