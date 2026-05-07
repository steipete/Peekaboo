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

    private let frameProvider: WatchCaptureFrameProvider
    private let scope: CaptureScope
    private let options: CaptureOptions
    private let outputRoot: URL
    private let store: WatchCaptureSessionStore
    private let frameSource: (any CaptureFrameSource)?
    private let sourceKind: CaptureSessionResult.Source
    private let videoIn: String?
    private let videoOut: String?
    private let keepAllFrames: Bool
    private let videoOptions: CaptureVideoOptionsSnapshot?
    private let videoWriterFPS: Double?
    private let sessionId = UUID().uuidString
    private var videoWriter: VideoWriter?

    private var frames: [CaptureFrameInfo] = []
    private var warnings: [CaptureWarning] = []
    private var framesDropped: Int = 0
    private var totalBytes: Int = 0

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

    // MARK: - Capture helpers

    private struct SessionTiming {
        let start: Date
        let durationNs: UInt64
        let heartbeatNs: UInt64
        let cadenceIdleNs: UInt64
        let cadenceActiveNs: UInt64
    }

    private struct SessionState {
        var lastKeptTime: Date
        var lastActivityTime: Date
        var activeMode: Bool
        var lastDiffBuffer: WatchFrameDiffer.LumaBuffer?
        var frameIndex: Int
    }

    private struct DiffComputation {
        let changePercent: Double
        let motionBoxes: [CGRect]?
        let buffer: WatchFrameDiffer.LumaBuffer
        let enterActive: Bool
    }

    private func makeTiming(start: Date) -> SessionTiming {
        let durationNs = UInt64(self.options.duration * 1_000_000_000)
        let heartbeatNs = self.options.heartbeatSeconds > 0
            ? UInt64(self.options.heartbeatSeconds * 1_000_000_000)
            : UInt64.max

        let cadenceIdleNs = UInt64(1_000_000_000 / max(self.options.idleFps, 0.1))
        let cadenceActiveNs = UInt64(1_000_000_000 / max(self.options.activeFps, 0.1))

        return SessionTiming(
            start: start,
            durationNs: durationNs,
            heartbeatNs: heartbeatNs,
            cadenceIdleNs: cadenceIdleNs,
            cadenceActiveNs: cadenceActiveNs)
    }

    private func captureFrames(timing: SessionTiming) async throws {
        var state = SessionState(
            lastKeptTime: timing.start,
            lastActivityTime: timing.start,
            activeMode: false,
            lastDiffBuffer: nil,
            frameIndex: 0)

        while true {
            let now = Date()
            let elapsedNs = Self.elapsedNanoseconds(since: timing.start, now: now)
            if self.shouldEndSession(elapsedNs: elapsedNs, durationNs: timing.durationNs) { break }
            if self.hitFrameCap() || self.hitSizeCap() { break }

            let frameStart = Date()
            let cadence = state.activeMode ? timing.cadenceActiveNs : timing.cadenceIdleNs
            guard let capture = try await self.captureFrame() else {
                // Frame source exhausted (e.g., video input)
                break
            }
            let timestampMs = capture.metadata.videoTimestampMs ?? Int(elapsedNs / 1_000_000)

            guard let cgImage = capture.cgImage else {
                self.framesDropped += 1
                try await self.sleep(ns: cadence, since: frameStart)
                continue
            }

            if self.keepAllFrames {
                let reason: CaptureFrameInfo.Reason = self.frames.isEmpty ? .first : .motion
                let saved = try self.saveFrame(
                    cgImage: cgImage,
                    context: FrameSaveContext(
                        capture: capture,
                        index: state.frameIndex,
                        timestampMs: timestampMs,
                        changePercent: 0,
                        reason: reason,
                        motionBoxes: nil))
                self.frames.append(saved)
                state.frameIndex += 1
                try await self.sleep(ns: cadence, since: frameStart)
                continue
            }

            let diff = self.computeDiff(cgImage: cgImage, previous: state.lastDiffBuffer)
            state.lastDiffBuffer = diff.buffer
            self.updateActiveMode(
                changePercent: diff.changePercent,
                now: now,
                state: &state)

            let decision = self.keepDecision(
                now: now,
                state: state,
                heartbeatNs: timing.heartbeatNs,
                enterActive: diff.enterActive)

            if decision.keep {
                let saveContext = FrameSaveContext(
                    capture: capture,
                    index: state.frameIndex,
                    timestampMs: timestampMs,
                    changePercent: diff.changePercent,
                    reason: decision.reason,
                    motionBoxes: diff.motionBoxes)
                let saved = try self.saveFrame(cgImage: cgImage, context: saveContext)
                self.frames.append(saved)
                state.lastKeptTime = now
            } else {
                self.framesDropped += 1
            }

            state.frameIndex += 1
            try await self.sleep(ns: cadence, since: frameStart)
        }
    }

    private func captureFrame() async throws -> WatchCaptureFrame? {
        let output = try await self.frameProvider.captureFrame()
        if let warning = output.warning {
            self.warnings.append(warning)
        }
        return output.frame
    }

    private static func elapsedNanoseconds(since start: Date, now: Date) -> UInt64 {
        UInt64(now.timeIntervalSince(start) * 1_000_000_000)
    }

    private func shouldEndSession(elapsedNs: UInt64, durationNs: UInt64) -> Bool {
        elapsedNs >= durationNs
    }

    private func hitFrameCap() -> Bool {
        guard self.frames.count >= self.options.maxFrames else { return false }
        self.warnings.append(
            WatchWarning(code: .frameCap, message: "Stopped after reaching max-frames cap"))
        return true
    }

    private func hitSizeCap() -> Bool {
        guard let maxMb = self.options.maxMegabytes else { return false }
        let currentMb = self.totalBytes / (1024 * 1024)
        guard currentMb >= maxMb else { return false }
        self.warnings.append(
            WatchWarning(code: .sizeCap, message: "Stopped after reaching max-mb cap"))
        return true
    }

    private func computeDiff(
        cgImage: CGImage,
        previous: WatchFrameDiffer.LumaBuffer?) -> DiffComputation
    {
        let downscaled = WatchFrameDiffer.makeLumaBuffer(from: cgImage, maxWidth: Constants.diffScaleWidth)
        let diff = WatchFrameDiffer.computeChange(
            using: WatchFrameDiffer.DiffInput(
                strategy: self.options.diffStrategy,
                diffBudgetMs: self.options.diffBudgetMs,
                previous: previous,
                current: downscaled,
                deltaThreshold: Constants.motionDelta,
                originalSize: CGSize(width: cgImage.width, height: cgImage.height)))

        if diff.downgraded {
            self.warnings.append(
                WatchWarning(code: .diffDowngraded, message: "Diff downgraded to fast due to budget"))
        }

        return DiffComputation(
            changePercent: diff.changePercent,
            motionBoxes: diff.boundingBoxes,
            buffer: downscaled,
            enterActive: diff.changePercent >= self.options.changeThresholdPercent)
    }

    private func updateActiveMode(
        changePercent: Double,
        now: Date,
        state: inout SessionState)
    {
        let threshold = self.options.changeThresholdPercent
        let enterActive = changePercent >= threshold
        let exitActive = state.activeMode && WatchCaptureActivityPolicy.shouldExitActive(
            changePercent: changePercent,
            threshold: threshold,
            lastActivityTime: state.lastActivityTime,
            quietMs: self.options.quietMsToIdle,
            now: now)

        if enterActive {
            state.lastActivityTime = now
        }

        if enterActive, !state.activeMode {
            state.activeMode = true
            return
        }

        if exitActive {
            state.activeMode = false
        }
    }

    private func keepDecision(
        now: Date,
        state: SessionState,
        heartbeatNs: UInt64,
        enterActive: Bool) -> (keep: Bool, reason: CaptureFrameInfo.Reason)
    {
        if state.frameIndex == 0 {
            return (true, .first)
        }

        if enterActive {
            return (true, .motion)
        }

        let isHeartbeat = UInt64(now.timeIntervalSince(state.lastKeptTime) * 1_000_000_000) >= heartbeatNs
        if isHeartbeat {
            return (true, .heartbeat)
        }

        return (false, .cap)
    }

    /// Returns a bounded video size that preserves aspect ratio while keeping the longest edge under `maxDimension`.
    /// If `maxDimension` is nil or smaller than the current image, the original size is returned.
    public static func scaledVideoSize(for size: CGSize, maxDimension: Int?) -> (width: Int, height: Int) {
        guard let maxDimension, maxDimension > 0 else {
            return (Int(size.width), Int(size.height))
        }
        let currentMax = Int(max(size.width, size.height))
        guard currentMax > maxDimension else {
            return (Int(size.width), Int(size.height))
        }
        let scale = Double(maxDimension) / Double(currentMax)
        let scaledWidth = max(1, Int((Double(size.width) * scale).rounded()))
        let scaledHeight = max(1, Int((Double(size.height) * scale).rounded()))
        return (scaledWidth, scaledHeight)
    }

    private struct FrameSaveContext {
        let capture: WatchCaptureFrame
        let index: Int
        let timestampMs: Int
        let changePercent: Double
        let reason: CaptureFrameInfo.Reason
        let motionBoxes: [CGRect]?
    }

    private func saveFrame(cgImage: CGImage, context: FrameSaveContext) throws -> CaptureFrameInfo {
        // Create writer lazily on first kept frame so we match the actual frame size.
        if self.videoOut != nil, self.videoWriter == nil {
            let fps = self.videoWriterFPS ?? self.options.activeFps
            let size = Self.scaledVideoSize(
                for: CGSize(width: cgImage.width, height: cgImage.height),
                maxDimension: self.options.resolutionCap.map { Int($0) })
            self.videoWriter = try VideoWriter(
                outputPath: self.videoOut ?? self.outputRoot.appendingPathComponent("capture.mp4").path,
                width: size.width,
                height: size.height,
                fps: fps)
        }
        if let writer = self.videoWriter {
            try writer.append(image: cgImage)
        }

        let fileName = String(format: "keep-%04d.png", self.frames.count + 1)
        let url = self.outputRoot.appendingPathComponent(fileName)
        try WatchCaptureArtifactWriter.writePNG(
            image: cgImage,
            to: url,
            highlight: self.options.highlightChanges ? context.motionBoxes : nil)

        if let data = try? Data(contentsOf: url) {
            self.totalBytes += data.count
        }

        return CaptureFrameInfo(
            index: context.index,
            path: url.path,
            file: fileName,
            timestampMs: context.timestampMs,
            changePercent: context.changePercent,
            reason: context.reason,
            motionBoxes: context.motionBoxes?.isEmpty == false ? context.motionBoxes : nil)
    }

    // MARK: - Utilities

    private func ensureFallbackFrame() async throws {
        guard self.frames.isEmpty else { return }
        guard let capture = try? await self.captureFrame(), let cg = capture.cgImage else { return }
        let context = FrameSaveContext(
            capture: capture,
            index: 0,
            timestampMs: 0,
            changePercent: 0,
            reason: .first,
            motionBoxes: nil)
        let saved = try self.saveFrame(cgImage: cg, context: context)
        self.frames.append(saved)
    }

    private func elapsedMilliseconds(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }

    private func sleep(ns: UInt64, since start: Date) async throws {
        // For video sources we don't throttle cadence; return immediately.
        if self.frameSource != nil { return }
        let elapsed = UInt64(Date().timeIntervalSince(start) * 1_000_000_000)
        if ns > elapsed {
            try await Task.sleep(nanoseconds: ns - elapsed)
        }
    }
}
