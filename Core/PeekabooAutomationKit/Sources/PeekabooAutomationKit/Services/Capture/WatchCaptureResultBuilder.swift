import Foundation

struct WatchCaptureResultBuilder {
    let sourceKind: CaptureSessionResult.Source
    let videoIn: String?
    let videoOut: String?
    let scope: CaptureScope
    let options: CaptureOptions
    let videoOptions: CaptureVideoOptionsSnapshot?
    let diffScale: String

    struct Input {
        let frames: [CaptureFrameInfo]
        let contactSheet: CaptureContactSheet
        let metadataURL: URL
        let durationMs: Int
        let framesDropped: Int
        let totalBytes: Int
        let warnings: [CaptureWarning]
    }

    func build(_ input: Input) -> CaptureSessionResult {
        CaptureSessionResult(
            source: self.sourceKind,
            videoIn: self.videoIn,
            videoOut: self.videoOut,
            frames: input.frames,
            contactSheet: input.contactSheet,
            metadataFile: input.metadataURL.path,
            stats: self.makeStats(
                durationMs: input.durationMs,
                frames: input.frames,
                framesDropped: input.framesDropped,
                totalBytes: input.totalBytes),
            scope: self.scope,
            diffAlgorithm: self.options.diffStrategy.rawValue,
            diffScale: self.diffScale,
            options: self.makeOptionsSnapshot(),
            warnings: self.warningsWithNoMotionCheck(frames: input.frames, warnings: input.warnings))
    }

    private func warningsWithNoMotionCheck(
        frames: [CaptureFrameInfo],
        warnings: [CaptureWarning]) -> [CaptureWarning]
    {
        var output = warnings
        if frames.isEmpty {
            output.append(WatchWarning(code: .noMotion, message: "No frames were captured"))
        } else if frames.count < 2 {
            output.append(WatchWarning(code: .noMotion, message: "No motion detected; only key frames captured"))
        }
        return output
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

    private func makeStats(
        durationMs: Int,
        frames: [CaptureFrameInfo],
        framesDropped: Int,
        totalBytes: Int) -> WatchStats
    {
        let maxMbHit = self.options.maxMegabytes != nil
            && totalBytes / (1024 * 1024) >= (self.options.maxMegabytes ?? 0)
        return WatchStats(
            durationMs: durationMs,
            fpsIdle: self.options.idleFps,
            fpsActive: self.options.activeFps,
            fpsEffective: Self.computeEffectiveFps(frameCount: frames.count, durationMs: durationMs),
            framesKept: frames.count,
            framesDropped: framesDropped,
            maxFramesHit: frames.count >= self.options.maxFrames,
            maxMbHit: maxMbHit)
    }

    private static func computeEffectiveFps(frameCount: Int, durationMs: Int) -> Double {
        guard durationMs > 0 else { return 0 }
        return Double(frameCount) / (Double(durationMs) / 1000.0)
    }
}
