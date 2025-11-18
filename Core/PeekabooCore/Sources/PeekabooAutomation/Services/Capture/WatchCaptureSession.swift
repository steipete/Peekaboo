import AppKit
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import PeekabooFoundation
import UniformTypeIdentifiers

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

    public init(
        scope: CaptureScope,
        options: CaptureOptions,
        outputRoot: URL,
        autoclean: WatchAutocleanConfig,
        sourceKind: CaptureSessionResult.Source = .live,
        videoIn: String? = nil,
        videoOut: String? = nil,
        keepAllFrames: Bool = false)
    {
        self.scope = scope
        self.options = options
        self.outputRoot = outputRoot
        self.autoclean = autoclean
        self.sourceKind = sourceKind
        self.videoIn = videoIn
        self.videoOut = videoOut
        self.keepAllFrames = keepAllFrames
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

        if self.sourceKind == .video, self.frames.count < 2 {
            throw PeekabooError.captureFailed(reason: "Video input yielded fewer than 2 frames; adjust sampling or trim")
        }

        if let writer = self.videoWriter {
            try await writer.finish()
        }

        let contact = try self.buildContactSheet()
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
        var lastDiffBuffer: LumaBuffer?
        var frameIndex: Int
    }

    private struct DiffComputation {
        let changePercent: Double
        let motionBoxes: [CGRect]?
        let buffer: LumaBuffer
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
                        timestampMs: Int(elapsedNs / 1_000_000),
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
                    timestampMs: Int(elapsedNs / 1_000_000),
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
                visualizerMode: .watchCapture)
        case .frontmost:
            result = try await self.screenCapture.captureFrontmost(visualizerMode: .watchCapture)
        case .window:
            guard let app = self.scope.applicationIdentifier else {
                throw PeekabooError.windowNotFound(criteria: "missing application identifier")
            }
            result = try await self.screenCapture.captureWindow(
                appIdentifier: app,
                windowIndex: self.scope.windowIndex,
                visualizerMode: .watchCapture)
        case .region:
            guard let rect = self.scope.region else {
                throw PeekabooError.captureFailed(reason: "Region missing for watch capture")
            }
            let validated = try self.validateRegion(rect)
            result = try await self.screenCapture.captureArea(
                validated,
                visualizerMode: .watchCapture)
        }

        guard let image = WatchCaptureSession.makeCGImage(from: result.imageData) else {
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
        return WatchCaptureSession.resize(image: image, to: newSize) ?? image
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

    private func computeDiff(cgImage: CGImage, previous: LumaBuffer?) -> DiffComputation {
        let downscaled = self.makeLumaBuffer(from: cgImage)
        let diff = WatchCaptureSession.computeChange(
            using: DiffInput(
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
            self.videoWriter = try VideoWriter(
                outputPath: self.videoOut ?? self.outputRoot.appendingPathComponent("capture.mp4").path,
                width: cgImage.width,
                height: cgImage.height,
                fps: fps)
        }
        if let writer = self.videoWriter {
            try writer.append(image: cgImage)
        }

        let fileName = String(format: "keep-%04d.png", self.frames.count + 1)
        let url = self.outputRoot.appendingPathComponent(fileName)
        try WatchCaptureSession.writePNG(
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

    // MARK: - Contact sheet

    private func buildContactSheet() throws -> WatchContactSheet {
        let columns = Constants.contactMaxColumns
        let maxCells = columns * columns
        let framesToUse: [CaptureFrameInfo]
        let sampledIndexes: [Int]
        if self.frames.count <= maxCells {
            framesToUse = self.frames
            sampledIndexes = self.frames.map(\.index)
        } else {
            // Sample evenly to keep contact sheets readable when many frames are kept.
            framesToUse = WatchCaptureSession.sampleFrames(self.frames, maxCount: maxCells)
            sampledIndexes = framesToUse.map(\.index)
        }
        let rows = Int(ceil(Double(framesToUse.count) / Double(columns)))
        let thumbSize = CGSize(width: Constants.contactThumb, height: Constants.contactThumb)
        let sheetSize = CGSize(width: CGFloat(columns) * thumbSize.width, height: CGFloat(rows) * thumbSize.height)
        guard let context = CGContext(
            data: nil,
            width: Int(sheetSize.width),
            height: Int(sheetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            throw PeekabooError.captureFailed(reason: "Failed to build contact sheet context")
        }

        for (idx, frame) in framesToUse.enumerated() {
            guard let image = WatchCaptureSession.makeCGImage(fromFile: frame.path) else { continue }
            let resized = WatchCaptureSession.resize(image: image, to: thumbSize) ?? image
            let row = idx / columns
            let col = idx % columns
            let origin = CGPoint(
                x: CGFloat(col) * thumbSize.width,
                y: CGFloat(rows - row - 1) * thumbSize.height)
            context.draw(resized, in: CGRect(origin: origin, size: thumbSize))
        }

        guard let cg = context.makeImage() else {
            throw PeekabooError.captureFailed(reason: "Failed to finalize contact sheet")
        }

        let contactURL = self.outputRoot.appendingPathComponent("contact.png")
        try WatchCaptureSession.writePNG(image: cg, to: contactURL, highlight: nil)

        return CaptureContactSheet(
            path: contactURL.path,
            file: "contact.png",
            columns: columns,
            rows: rows,
            thumbSize: thumbSize,
            sampledFrameIndexes: sampledIndexes)
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
            diffBudgetMs: self.options.diffBudgetMs)
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

    private static func makeCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func makeCGImage(fromFile path: String) -> CGImage? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return self.makeCGImage(from: data)
    }

    private static func resize(image: CGImage, to size: CGSize) -> CGImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue)
        else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }

    struct LumaBuffer {
        let width: Int
        let height: Int
        let pixels: [UInt8]
    }

    private func makeLumaBuffer(from image: CGImage) -> LumaBuffer {
        let maxWidth = Constants.diffScaleWidth
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let scale = min(1, maxWidth / max(width, height))
        let targetSize = CGSize(width: width * scale, height: height * scale)
        let w = Int(targetSize.width)
        let h = Int(targetSize.height)
        var pixels = [UInt8](repeating: 0, count: w * h)
        guard let context = CGContext(
            data: &pixels,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else {
            return LumaBuffer(width: 1, height: 1, pixels: [0])
        }
        context.draw(image, in: CGRect(origin: .zero, size: targetSize))
        return LumaBuffer(width: w, height: h, pixels: pixels)
    }

    struct DiffResult {
        let changePercent: Double
        let boundingBoxes: [CGRect]
        let downgraded: Bool
    }

    struct DiffInput {
        let strategy: WatchCaptureOptions.DiffStrategy
        let diffBudgetMs: Int?
        let previous: LumaBuffer?
        let current: LumaBuffer
        let deltaThreshold: UInt8
        let originalSize: CGSize
    }

    nonisolated static func computeChange(using input: DiffInput) -> DiffResult {
        guard let previous = input.previous else {
            // First frame: force 100% change and a full-frame box so downstream logic always keeps it.
            return DiffResult(
                changePercent: 100.0,
                boundingBoxes: [CGRect(origin: .zero, size: input.originalSize)],
                downgraded: false)
        }

        // Fast path always runs to get bounding boxes; quality may replace change% but keeps the boxes.
        let pixelDiff = self.computePixelDelta(
            previous: previous,
            current: input.current,
            deltaThreshold: input.deltaThreshold,
            originalSize: input.originalSize)

        var changePercent: Double
        switch input.strategy {
        case .fast:
            changePercent = pixelDiff.changePercent
        case .quality:
            if let budget = input.diffBudgetMs {
                let start = DispatchTime.now().uptimeNanoseconds
                let ssim = self.computeSSIM(previous: previous, current: input.current)
                let elapsedMs = Int((DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
                if elapsedMs > budget {
                    // Guardrail: fall back to fast diff if SSIM is too slow to keep the session responsive.
                    changePercent = pixelDiff.changePercent
                    return DiffResult(
                        changePercent: changePercent,
                        boundingBoxes: pixelDiff.boundingBoxes,
                        downgraded: true)
                } else {
                    changePercent = max(0, min(100, (1 - ssim) * 100))
                }
            } else {
                let ssim = self.computeSSIM(previous: previous, current: input.current)
                changePercent = max(0, min(100, (1 - ssim) * 100))
            }
        }

        return DiffResult(
            changePercent: changePercent,
            boundingBoxes: pixelDiff.boundingBoxes,
            downgraded: false)
    }

    private nonisolated static func computePixelDelta(
        previous: LumaBuffer,
        current: LumaBuffer,
        deltaThreshold: UInt8,
        originalSize: CGSize) -> DiffResult
    {
        let count = min(previous.pixels.count, current.pixels.count)
        if count == 0 { return DiffResult(changePercent: 0, boundingBoxes: [], downgraded: false) }

        var changed = 0
        var mask = Array(repeating: false, count: count)
        for idx in 0..<count {
            let diff = abs(Int(previous.pixels[idx]) - Int(current.pixels[idx]))
            if diff >= deltaThreshold {
                changed += 1
                mask[idx] = true
            }
        }

        let percent = (Double(changed) / Double(count)) * 100.0
        if changed == 0 { return DiffResult(changePercent: percent, boundingBoxes: [], downgraded: false) }

        let boxes = self.extractBoundingBoxes(
            mask: mask,
            width: current.width,
            height: current.height,
            originalSize: originalSize)
        return DiffResult(changePercent: percent, boundingBoxes: boxes, downgraded: false)
    }

    /// Extract axis-aligned bounding boxes for connected components in the diff mask.
    private nonisolated static func extractBoundingBoxes(
        mask: [Bool],
        width: Int,
        height: Int,
        originalSize: CGSize) -> [CGRect]
    {
        var visited = Array(repeating: false, count: mask.count)
        let directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        let maxBoxes = 5 // Avoid overwhelming overlays
        let minPixels = 1 // Tiny blobs still count; caller can filter when drawing
        var collected: [CGRect] = []

        func index(_ x: Int, _ y: Int) -> Int { y * width + x }

        for y in 0..<height {
            for x in 0..<width {
                let idx = index(x, y)
                if !mask[idx] || visited[idx] { continue }

                var stack = [(x, y)]
                visited[idx] = true
                var minX = x, maxX = x, minY = y, maxY = y
                var count = 0

                while let (cx, cy) = stack.popLast() {
                    count += 1
                    minX = min(minX, cx); maxX = max(maxX, cx)
                    minY = min(minY, cy); maxY = max(maxY, cy)
                    for (dx, dy) in directions {
                        let nx = cx + dx, ny = cy + dy
                        if nx < 0 || ny < 0 || nx >= width || ny >= height { continue }
                        let nIdx = index(nx, ny)
                        if mask[nIdx], !visited[nIdx] {
                            visited[nIdx] = true
                            stack.append((nx, ny))
                        }
                    }
                }

                guard count >= minPixels else { continue }

                let scaleX = originalSize.width / CGFloat(width)
                let scaleY = originalSize.height / CGFloat(height)
                let rect = CGRect(
                    x: CGFloat(minX) * scaleX,
                    y: CGFloat(minY) * scaleY,
                    width: CGFloat(maxX - minX + 1) * scaleX,
                    height: CGFloat(maxY - minY + 1) * scaleY)
                collected.append(rect)
            }
        }

        guard !collected.isEmpty else {
            return []
        }

        let sorted = collected.sorted { lhs, rhs in
            let lhsArea = lhs.width * lhs.height
            let rhsArea = rhs.width * rhs.height
            if lhsArea == rhsArea {
                return lhs.origin.y < rhs.origin.y
            }
            return lhsArea > rhsArea
        }

        let unionRect = sorted.dropFirst().reduce(sorted[0]) { partialResult, rect in
            partialResult.union(rect)
        }

        var result: [CGRect] = [unionRect]
        for rect in sorted {
            guard result.count < maxBoxes else { break }
            if rect.equalTo(unionRect) { continue }
            result.append(rect)
        }

        return result
    }

    nonisolated static func computeSSIM(previous: LumaBuffer, current: LumaBuffer) -> Double {
        let count = min(previous.pixels.count, current.pixels.count)
        if count == 0 { return 0 }

        var meanX: Double = 0
        var meanY: Double = 0
        for idx in 0..<count {
            meanX += Double(previous.pixels[idx])
            meanY += Double(current.pixels[idx])
        }
        meanX /= Double(count)
        meanY /= Double(count)

        var varianceX: Double = 0
        var varianceY: Double = 0
        var covariance: Double = 0
        for idx in 0..<count {
            let x = Double(previous.pixels[idx]) - meanX
            let y = Double(current.pixels[idx]) - meanY
            varianceX += x * x
            varianceY += y * y
            covariance += x * y
        }
        varianceX /= Double(count - 1)
        varianceY /= Double(count - 1)
        covariance /= Double(count - 1)

        let c1 = pow(0.01 * 255.0, 2.0)
        let c2 = pow(0.03 * 255.0, 2.0)

        let numerator = (2 * meanX * meanY + c1) * (2 * covariance + c2)
        let denominator = (meanX * meanX + meanY * meanY + c1) * (varianceX + varianceY + c2)

        guard denominator != 0 else { return 0 }
        return numerator / denominator
    }

    private static func sampleFrames(_ frames: [CaptureFrameInfo], maxCount: Int) -> [CaptureFrameInfo] {
        guard frames.count > maxCount else { return frames }
        let step = Double(frames.count - 1) / Double(maxCount - 1)
        var indexes: [Int] = []
        for i in 0..<maxCount {
            let idx = Int(round(Double(i) * step))
            indexes.append(min(idx, frames.count - 1))
        }
        let set = Set(indexes)
        return frames.enumerated()
            .filter { set.contains($0.offset) }
            .map(\.element)
    }

    private static func writePNG(image: CGImage, to url: URL, highlight: [CGRect]?) throws {
        let finalImage: CGImage = if let highlight, !highlight.isEmpty,
                                     let annotated = self.annotate(image: image, boxes: highlight)
        {
            annotated
        } else {
            image
        }

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil)
        else {
            throw PeekabooError.captureFailed(reason: "Failed to create image destination")
        }
        CGImageDestinationAddImage(destination, finalImage, nil)
        if !CGImageDestinationFinalize(destination) {
            throw PeekabooError.captureFailed(reason: "Failed to write PNG")
        }
    }

    private static func annotate(image: CGImage, boxes: [CGRect]) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.setStrokeColor(NSColor.systemRed.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(max(2, CGFloat(image.width) * 0.002))
        for box in boxes {
            context.stroke(box)
        }
        return context.makeImage()
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
