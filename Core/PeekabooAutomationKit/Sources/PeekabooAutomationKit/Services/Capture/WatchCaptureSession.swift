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

    private let screenCapture: any ScreenCaptureServiceProtocol
    private let scope: CaptureScope
    private let options: CaptureOptions
    private let outputRoot: URL
    private let autocleanMinutes: Int
    private let managedAutoclean: Bool
    private let fileManager = FileManager.default
    private let screenService: (any ScreenServiceProtocol)?
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
    private var motionIntervals: [CaptureMotionInterval] = []
    private var warnings: [CaptureWarning] = []
    private var framesDropped: Int = 0
    private var totalBytes: Int = 0
    private var activeIntervalStart: (index: Int, startMs: Int, maxChange: Double)?

    public init(dependencies: WatchCaptureDependencies, configuration: WatchCaptureConfiguration) {
        self.screenCapture = dependencies.screenCapture
        self.screenService = dependencies.screenService
        self.frameSource = dependencies.frameSource
        self.scope = configuration.scope
        self.options = configuration.options
        self.outputRoot = configuration.outputRoot
        self.autocleanMinutes = configuration.autoclean.minutes
        self.managedAutoclean = configuration.autoclean.managed
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
    }

    public func run() async throws -> CaptureSessionResult {
        try self.prepareOutputRoot()
        self.performAutoclean()
        // videoWriter is created lazily on first saved frame to match actual dimensions.

        let timing = self.makeTiming(start: Date())
        try await self.captureFrames(timing: timing)
        self.finalizeActiveInterval(start: timing.start)
        try await self.ensureFallbackFrame(start: timing.start)

        if let writer = self.videoWriter {
            try await writer.finish()
        }

        let contact = try WatchCaptureArtifactWriter.buildContactSheet(
            frames: self.frames,
            outputRoot: self.outputRoot,
            columns: Constants.contactMaxColumns,
            thumbSize: CGSize(width: Constants.contactThumb, height: Constants.contactThumb))
        let durationMs = self.elapsedMilliseconds(since: timing.start)
        self.appendNoMotionWarningIfNeeded()

        let optionsSnapshot = self.makeOptionsSnapshot()
        let stats = self.makeStats(durationMs: durationMs)
        let metadataURL = self.outputRoot.appendingPathComponent("metadata.json")
        let metadata = CaptureSessionResult(
            source: self.sourceKind,
            videoIn: self.videoIn,
            videoOut: self.videoWriter?.finalURL.path,
            frames: self.frames,
            contactSheet: contact,
            metadataFile: metadataURL.path,
            stats: stats,
            scope: self.scope,
            diffAlgorithm: self.options.diffStrategy.rawValue,
            diffScale: "w\(Int(Constants.diffScaleWidth))",
            options: optionsSnapshot,
            warnings: self.warnings)

        try self.writeJSON(metadata, to: metadataURL)
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
            self.updateActiveInterval(
                changePercent: diff.changePercent,
                elapsedNs: elapsedNs,
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

    private struct CaptureEnvelope {
        let cgImage: CGImage?
        let metadata: CaptureMetadata
        let motionBoxes: [CGRect]?
    }

    private func captureFrame() async throws -> CaptureEnvelope? {
        if let source = self.frameSource {
            guard let output = try await source.nextFrame() else { return nil }
            guard let image = output.cgImage else {
                return CaptureEnvelope(cgImage: nil, metadata: output.metadata, motionBoxes: nil)
            }
            let capped = self.capResolutionIfNeeded(image)
            return CaptureEnvelope(cgImage: capped, metadata: output.metadata, motionBoxes: nil)
        }

        let result: CaptureResult
        switch self.scope.kind {
        case .screen:
            result = try await self.screenCapture.captureScreen(
                displayIndex: self.scope.screenIndex,
                visualizerMode: .watchCapture,
                scale: .logical1x)
        case .frontmost:
            result = try await self.screenCapture.captureFrontmost(
                visualizerMode: .watchCapture,
                scale: .logical1x)
        case .window:
            guard let app = self.scope.applicationIdentifier else {
                throw PeekabooError.windowNotFound(criteria: "missing application identifier")
            }
            result = try await self.screenCapture.captureWindow(
                appIdentifier: app,
                windowIndex: self.scope.windowIndex,
                visualizerMode: .watchCapture,
                scale: .logical1x)
        case .region:
            guard let rect = self.scope.region else {
                throw PeekabooError.captureFailed(reason: "Region missing for watch capture")
            }
            let validated = try self.validateRegion(rect)
            result = try await self.screenCapture.captureArea(
                validated,
                visualizerMode: .watchCapture,
                scale: .logical1x)
        }

        guard let image = WatchCaptureArtifactWriter.makeCGImage(from: result.imageData) else {
            return CaptureEnvelope(cgImage: nil, metadata: result.metadata, motionBoxes: nil)
        }

        let cappedImage = self.capResolutionIfNeeded(image)
        return CaptureEnvelope(cgImage: cappedImage, metadata: result.metadata, motionBoxes: nil)
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

    private func updateActiveInterval(
        changePercent: Double,
        elapsedNs: UInt64,
        now: Date,
        state: inout SessionState)
    {
        let threshold = self.options.changeThresholdPercent
        let enterActive = changePercent >= threshold
        let exitActive = state.activeMode && Self.shouldExitActive(
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
            self.activeIntervalStart = (
                index: state.frameIndex,
                startMs: Int(elapsedNs / 1_000_000),
                maxChange: changePercent)
            return
        }

        if exitActive {
            if let interval = self.activeIntervalStart {
                let endMs = Int(elapsedNs / 1_000_000)
                self.motionIntervals.append(
                    WatchMotionInterval(
                        startFrameIndex: interval.index,
                        endFrameIndex: max(state.frameIndex - 1, interval.index),
                        startMs: interval.startMs,
                        endMs: endMs,
                        maxChangePercent: interval.maxChange))
            }
            state.activeMode = false
            self.activeIntervalStart = nil
            return
        }

        if state.activeMode, var interval = self.activeIntervalStart {
            interval.maxChange = max(interval.maxChange, changePercent)
            self.activeIntervalStart = interval
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
        let capture: CaptureEnvelope
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

    private func computeEffectiveFps(durationMs: Int) -> Double {
        guard durationMs > 0 else { return 0 }
        return Double(self.frames.count) / (Double(durationMs) / 1000.0)
    }

    private func finalizeActiveInterval(start: Date) {
        guard let interval = self.activeIntervalStart else { return }
        let endMs = self.elapsedMilliseconds(since: start)
        self.motionIntervals.append(
            WatchMotionInterval(
                startFrameIndex: interval.index,
                endFrameIndex: max(self.frames.count - 1, interval.index),
                startMs: interval.startMs,
                endMs: endMs,
                maxChangePercent: interval.maxChange))
        self.activeIntervalStart = nil
    }

    private func ensureFallbackFrame(start: Date) async throws {
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

    private func appendNoMotionWarningIfNeeded() {
        if self.frames.isEmpty {
            self.warnings.append(
                WatchWarning(code: .noMotion, message: "No frames were captured"))
        } else if self.frames.count < 2 {
            self.warnings.append(
                WatchWarning(code: .noMotion, message: "No motion detected; only key frames captured"))
        }
    }

    private func makeOptionsSnapshot() -> CaptureOptionsSnapshot {
        CaptureOptionsSnapshot(
            duration: self.options.duration,
            idleFps: self.options.idleFps,
            activeFps: self.options.activeFps,
            changeThresholdPercent: self.options.changeThresholdPercent,
            heartbeatSeconds: self.options.heartbeatSeconds,
            quietMsToIdle: self.options.quietMsToIdle,
            maxFrames: self.options.maxFrames,
            maxMegabytes: self.options.maxMegabytes,
            highlightChanges: self.options.highlightChanges,
            captureFocus: self.options.captureFocus,
            resolutionCap: self.options.resolutionCap,
            diffStrategy: self.options.diffStrategy,
            diffBudgetMs: self.options.diffBudgetMs,
            video: self.videoOptions)
    }

    private func makeStats(durationMs: Int) -> WatchStats {
        let maxMbHit = self.options.maxMegabytes != nil
            && self.totalBytes / (1024 * 1024) >= (self.options.maxMegabytes ?? 0)
        return WatchStats(
            durationMs: durationMs,
            fpsIdle: self.options.idleFps,
            fpsActive: self.options.activeFps,
            fpsEffective: self.computeEffectiveFps(durationMs: durationMs),
            framesKept: self.frames.count,
            framesDropped: self.framesDropped,
            maxFramesHit: self.frames.count >= self.options.maxFrames,
            maxMbHit: maxMbHit)
    }

    private func prepareOutputRoot() throws {
        try self.fileManager.createDirectory(
            at: self.outputRoot,
            withIntermediateDirectories: true)
    }

    private func performAutoclean() {
        guard self.managedAutoclean else { return }
        let root = self.outputRoot.deletingLastPathComponent()
        guard root.lastPathComponent == "watch-sessions" else { return }
        guard let contents = try? self.fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles)
        else { return }

        let deadline = Date().addingTimeInterval(TimeInterval(-self.autocleanMinutes) * 60)
        var removed = 0
        for url in contents {
            guard let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = attrs.contentModificationDate else { continue }
            if modified < deadline {
                if (try? self.fileManager.removeItem(at: url)) != nil {
                    removed += 1
                }
            }
        }
        if removed > 0 {
            self.warnings.append(
                WatchWarning(
                    code: .autoclean,
                    message: "Autoclean removed \(removed) old watch sessions",
                    details: ["session": self.sessionId]))
        }
    }

    private func sleep(ns: UInt64, since start: Date) async throws {
        // For video sources we don't throttle cadence; return immediately.
        if self.frameSource != nil { return }
        let elapsed = UInt64(Date().timeIntervalSince(start) * 1_000_000_000)
        if ns > elapsed {
            try await Task.sleep(nanoseconds: ns - elapsed)
        }
    }

    private func writeJSON(_ value: some Encodable, to url: URL) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Region validation

    private func validateRegion(_ rect: CGRect) throws -> CGRect {
        let screens = self.screenCaptureScreens()
        guard !screens.isEmpty else {
            throw PeekabooError.invalidInput("No screens available for region capture")
        }

        // Global coords are expected; find intersection across all screens.
        var union = CGRect.null
        for screen in screens {
            union = union.union(screen.frame)
        }

        guard rect.intersects(union) else {
            throw PeekabooError.invalidInput("Region lies outside all screens")
        }

        let clamped = rect.intersection(union)
        if clamped != rect {
            // Clamp instead of failing when partially visible; signal to callers via warning.
            self.warnings.append(
                WatchWarning(code: .displayChanged, message: "Region adjusted to visible area"))
        }
        return clamped
    }

    private func screenCaptureScreens() -> [ScreenInfo] {
        self.screenService?.listScreens() ?? []
    }
}

extension WatchCaptureSession {
    /// Returns true when the capture loop should drop from active to idle cadence.
    /// We leave active mode once change is below half the threshold for at least `quietMs`.
    static func shouldExitActive(
        changePercent: Double,
        threshold: Double,
        lastActivityTime: Date,
        quietMs: Int,
        now: Date) -> Bool
    {
        guard changePercent < threshold / 2 else { return false }
        let quietNs = UInt64(quietMs) * 1_000_000
        let elapsedNs = UInt64(now.timeIntervalSince(lastActivityTime) * 1_000_000_000)
        return elapsedNs >= quietNs
    }
}
