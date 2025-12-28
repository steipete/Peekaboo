import CoreGraphics
import CoreImage
import CoreMedia
import Dispatch
import Foundation
import PeekabooFoundation
@preconcurrency import ScreenCaptureKit

@MainActor
final class ScreenCaptureKitFrameSource: CaptureFrameSource {
    struct StreamKey: Hashable {
        let displayID: CGDirectDisplayID
        let scale: CaptureScalePreference
    }

    struct FrameContext {
        let displayFrame: CGRect
        let scaleFactor: CGFloat
        let sourceRect: CGRect
    }

    struct Frame {
        let image: CGImage
        let timestamp: Date
        let displayFrame: CGRect
        let scaleFactor: CGFloat
        let sourceRect: CGRect
    }

    private final class StreamFrameHandler: NSObject, SCStreamOutput, SCStreamDelegate {
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
    private final class StreamSession {
        let key: StreamKey
        let display: SCDisplay
        let scaleFactor: CGFloat
        let logger: CategoryLogger
        let stream: SCStream
        let handler: StreamFrameHandler
        let queue: DispatchQueue

        var isRunning = false
        var currentSourceRect: CGRect
        var currentSize: CGSize
        var pendingError: (any Error)?

        init(
            key: StreamKey,
            display: SCDisplay,
            scaleFactor: CGFloat,
            logger: CategoryLogger,
            handler: StreamFrameHandler,
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

    private let logger: CategoryLogger
    private let maxFrameAge: TimeInterval
    private let frameWaitTimeout: TimeInterval
    private let framePollInterval: TimeInterval
    private var sessions: [StreamKey: StreamSession] = [:]
    private var latestFrames: [StreamKey: Frame] = [:]
    private var currentRequest: CaptureFrameRequest?

    init(logger: CategoryLogger) {
        self.logger = logger
        self.maxFrameAge = ScreenCaptureKitFrameSource.defaultMaxFrameAge
        self.frameWaitTimeout = ScreenCaptureKitFrameSource.defaultFrameWaitTimeout
        self.framePollInterval = ScreenCaptureKitFrameSource.defaultFramePollInterval
    }

    func start(request: CaptureFrameRequest) async throws {
        self.currentRequest = request
    }

    func stop() async {
        for session in self.sessions.values {
            do {
                let stream = session.stream
                try await withTimeout(seconds: 2.0) {
                    try await stream.stopCapture()
                }
            } catch {
                self.logger.debug(
                    "Fast stream stop failed",
                    metadata: [
                        "displayID": session.display.displayID,
                        "error": String(describing: error),
                    ])
            }
        }

        self.sessions.removeAll()
        self.latestFrames.removeAll()
        self.currentRequest = nil
    }

    func nextFrame() async throws -> (cgImage: CGImage?, metadata: CaptureMetadata)? {
        try await self.nextFrame(maxAge: nil)
    }

    func nextFrame(maxAge: TimeInterval?) async throws -> (cgImage: CGImage?, metadata: CaptureMetadata)? {
        guard let request = self.currentRequest else {
            throw OperationError.captureFailed(reason: "Fast stream capture request missing")
        }

        let display = request.display
        let sourceRect = request.sourceRect
        let scale = request.scale
        let correlationId = request.correlationId

        let key = StreamKey(displayID: display.displayID, scale: scale)
        let session = try self.session(for: display, scale: scale, key: key, correlationId: correlationId)
        try await session.start(correlationId: correlationId)

        let context = FrameContext(
            displayFrame: display.frame,
            scaleFactor: session.scaleFactor,
            sourceRect: sourceRect)
        let configSize = CGSize(
            width: sourceRect.width * session.scaleFactor,
            height: sourceRect.height * session.scaleFactor)
        let requestTime = Date()
        try await session.ensureConfiguration(
            sourceRect: sourceRect,
            size: configSize,
            correlationId: correlationId)

        let frame = try await self.waitForFrame(
            key: key,
            context: context,
            after: requestTime,
            maxAge: maxAge,
            correlationId: correlationId)

        let waitDuration = Date().timeIntervalSince(requestTime)
        let frameAge = Date().timeIntervalSince(frame.timestamp)
        self.logger.debug(
            "Fast stream capture complete",
            metadata: [
                "waitMs": Int(waitDuration * 1000),
                "frameAgeMs": Int(frameAge * 1000),
                "displayID": display.displayID,
            ],
            correlationId: correlationId)

        let size: CGSize = if request.mode == .area {
            request.displayBounds.size
        } else {
            CGSize(width: frame.image.width, height: frame.image.height)
        }

        let metadata = CaptureMetadata(
            size: size,
            mode: request.mode,
            displayInfo: DisplayInfo(
                index: request.displayIndex,
                name: request.displayName ?? display.displayID.description,
                bounds: request.displayBounds,
                scaleFactor: frame.scaleFactor),
            timestamp: frame.timestamp)

        return (cgImage: frame.image, metadata: metadata)
    }

    private func session(
        for display: SCDisplay,
        scale: CaptureScalePreference,
        key: StreamKey,
        correlationId: String) throws -> StreamSession
    {
        if let existing = self.sessions[key] {
            if let error = existing.pendingError {
                throw error
            }
            return existing
        }

        let scaleFactor = ScreenCaptureKitFrameSource.scaleFactor(for: display, preference: scale)
        let queue = DispatchQueue(label: "boo.peekaboo.capture.stream.\(display.displayID)")
        let handler = StreamFrameHandler(
            onFrame: { [weak self] image, timestamp, _ in
                let context = FrameContext(
                    displayFrame: display.frame,
                    scaleFactor: scaleFactor,
                    sourceRect: CGRect(origin: .zero, size: display.frame.size))
                self?.update(
                    image: image,
                    timestamp: timestamp,
                    context: context,
                    key: key)
            },
            onError: { [weak self] error in
                self?.handleStreamError(error, key: key)
            })

        let session = try StreamSession(
            key: key,
            display: display,
            scaleFactor: scaleFactor,
            logger: self.logger,
            handler: handler,
            queue: queue)
        self.sessions[key] = session

        self.logger.debug(
            "Fast stream session created",
            metadata: [
                "displayID": display.displayID,
                "scaleFactor": scaleFactor,
            ],
            correlationId: correlationId)

        return session
    }

    private func update(
        image: CGImage,
        timestamp: Date,
        context: FrameContext,
        key: StreamKey)
    {
        self.latestFrames[key] = Frame(
            image: image,
            timestamp: timestamp,
            displayFrame: context.displayFrame,
            scaleFactor: context.scaleFactor,
            sourceRect: context.sourceRect)
    }

    private func handleStreamError(_ error: any Error, key: StreamKey) {
        if let session = self.sessions[key] {
            session.pendingError = error
        }
        self.logger.error(
            "Fast stream error",
            metadata: ["error": String(describing: error)])
    }

    private func waitForFrame(
        key: StreamKey,
        context: FrameContext,
        after requestTime: Date,
        maxAge: TimeInterval?,
        correlationId: String) async throws -> Frame
    {
        let ageLimit = maxAge ?? self.maxFrameAge
        let deadline = Date().addingTimeInterval(self.frameWaitTimeout)
        while Date() < deadline {
            if let frame = self.latestFrames[key] {
                let age = Date().timeIntervalSince(frame.timestamp)
                if frame.timestamp >= requestTime || age <= ageLimit {
                    return Frame(
                        image: frame.image,
                        timestamp: frame.timestamp,
                        displayFrame: context.displayFrame,
                        scaleFactor: context.scaleFactor,
                        sourceRect: context.sourceRect)
                }
            }
            try await Task.sleep(nanoseconds: UInt64(self.framePollInterval * 1_000_000_000))
        }

        self.logger.warning(
            "Fast stream wait timed out",
            correlationId: correlationId)
        throw OperationError.timeout(
            operation: "FastStream.waitForFrame",
            duration: self.frameWaitTimeout)
    }

    private nonisolated static func scaleFactor(for display: SCDisplay, preference: CaptureScalePreference) -> CGFloat {
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

    private nonisolated static let defaultMaxFrameAge: TimeInterval = 0.25
    private nonisolated static let defaultFrameWaitTimeout: TimeInterval = 0.6
    private nonisolated static let defaultFramePollInterval: TimeInterval = 0.02
    private nonisolated static let defaultFPS: CMTimeScale? = nil
}
