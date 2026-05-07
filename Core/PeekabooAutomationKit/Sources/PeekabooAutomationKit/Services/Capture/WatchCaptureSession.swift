import CoreGraphics
import Foundation
import PeekabooFoundation

public struct WatchCaptureDependencies {
    public let screenCapture: any ScreenCaptureServiceProtocol
    public let screenService: (any ScreenServiceProtocol)?
    public let frameSource: (any CaptureFrameSource)?

    public init(
        screenCapture: any ScreenCaptureServiceProtocol,
        screenService: (any ScreenServiceProtocol)? = nil,
        frameSource: (any CaptureFrameSource)? = nil)
    {
        self.screenCapture = screenCapture
        self.screenService = screenService
        self.frameSource = frameSource
    }
}

public struct WatchAutocleanConfig {
    public let minutes: Int
    public let managed: Bool

    public init(minutes: Int, managed: Bool) {
        self.minutes = minutes
        self.managed = managed
    }
}

public struct WatchCaptureConfiguration {
    public let scope: CaptureScope
    public let options: CaptureOptions
    public let outputRoot: URL
    public let autoclean: WatchAutocleanConfig
    public let sourceKind: CaptureSessionResult.Source
    public let videoIn: String?
    public let videoOut: String?
    public let keepAllFrames: Bool
    public let videoOptions: CaptureVideoOptionsSnapshot?

    public init(
        scope: CaptureScope,
        options: CaptureOptions,
        outputRoot: URL,
        autoclean: WatchAutocleanConfig,
        sourceKind: CaptureSessionResult.Source = .live,
        videoIn: String? = nil,
        videoOut: String? = nil,
        keepAllFrames: Bool = false,
        videoOptions: CaptureVideoOptionsSnapshot? = nil)
    {
        self.scope = scope
        self.options = options
        self.outputRoot = outputRoot
        self.autoclean = autoclean
        self.sourceKind = sourceKind
        self.videoIn = videoIn
        self.videoOut = videoOut
        self.keepAllFrames = keepAllFrames
        self.videoOptions = videoOptions
    }
}

/// Adaptive PNG capture session for agents.
@MainActor
public final class WatchCaptureSession {
    enum Constants {
        static let diffScaleWidth: CGFloat = 256
        static let motionDelta: UInt8 = 18 // luma delta threshold (0-255)
        static let contactMaxColumns = 6
        static let contactThumb: CGFloat = 200
    }

    let frameProvider: WatchCaptureFrameProvider
    let scope: CaptureScope
    let options: CaptureOptions
    let outputRoot: URL
    let store: WatchCaptureSessionStore
    let frameSource: (any CaptureFrameSource)?
    let sourceKind: CaptureSessionResult.Source
    let videoIn: String?
    let videoOut: String?
    let keepAllFrames: Bool
    let videoOptions: CaptureVideoOptionsSnapshot?
    let videoWriterFPS: Double?
    let sessionId = UUID().uuidString
    var videoWriter: VideoWriter?

    var frames: [CaptureFrameInfo] = []
    var warnings: [CaptureWarning] = []
    var framesDropped: Int = 0
    var totalBytes: Int = 0

    public init(dependencies: WatchCaptureDependencies, configuration: WatchCaptureConfiguration) {
        let regionValidator = WatchCaptureRegionValidator(screenService: dependencies.screenService)
        self.frameSource = dependencies.frameSource
        self.scope = configuration.scope
        self.options = configuration.options
        self.outputRoot = configuration.outputRoot
        self.store = WatchCaptureSessionStore(
            outputRoot: configuration.outputRoot,
            autocleanMinutes: configuration.autoclean.minutes,
            managedAutoclean: configuration.autoclean.managed,
            sessionId: self.sessionId)
        self.sourceKind = configuration.sourceKind
        self.videoIn = configuration.videoIn
        self.videoOut = configuration.videoOut
        self.keepAllFrames = configuration.keepAllFrames
        self.videoOptions = configuration.videoOptions
        if let videoSource = dependencies.frameSource as? VideoFrameSource {
            self.videoWriterFPS = videoSource.effectiveFPS
        } else {
            self.videoWriterFPS = configuration.options.activeFps
        }
        self.frameProvider = WatchCaptureFrameProvider(
            screenCapture: dependencies.screenCapture,
            frameSource: dependencies.frameSource,
            scope: configuration.scope,
            options: configuration.options,
            regionValidator: regionValidator)
    }

    public func run() async throws -> CaptureSessionResult {
        try self.store.prepareOutputRoot()
        if let autocleanWarning = self.store.performAutoclean() {
            self.warnings.append(autocleanWarning)
        }
        // videoWriter is created lazily on first saved frame to match actual dimensions.

        let timing = self.makeTiming(start: Date())
        try await self.captureFrames(timing: timing)
        try await self.ensureFallbackFrame()

        if let writer = self.videoWriter {
            try await writer.finish()
        }

        let contact = try WatchCaptureArtifactWriter.buildContactSheet(
            frames: self.frames,
            outputRoot: self.outputRoot,
            columns: Constants.contactMaxColumns,
            thumbSize: CGSize(width: Constants.contactThumb, height: Constants.contactThumb))
        let durationMs = self.elapsedMilliseconds(since: timing.start)
        let metadataURL = self.outputRoot.appendingPathComponent("metadata.json")
        let metadata = WatchCaptureResultBuilder(
            sourceKind: self.sourceKind,
            videoIn: self.videoIn,
            videoOut: self.videoWriter?.finalURL.path,
            scope: self.scope,
            options: self.options,
            videoOptions: self.videoOptions,
            diffScale: "w\(Int(Constants.diffScaleWidth))")
            .build(.init(
                frames: self.frames,
                contactSheet: contact,
                metadataURL: metadataURL,
                durationMs: durationMs,
                framesDropped: self.framesDropped,
                totalBytes: self.totalBytes,
                warnings: self.warnings))

        try self.store.writeJSON(metadata, to: metadataURL)
        return metadata
    }
}
