import AVFoundation
import CoreGraphics
import Foundation
import PeekabooFoundation

/// Frame source that samples frames from a video asset.
public final class VideoFrameSource: CaptureFrameSource {
    private let generator: AVAssetImageGenerator
    private let times: [CMTime]
    private var index: Int = 0
    private let mode: CaptureMode = .screen
    public let effectiveFPS: Double

    public init(
        url: URL,
        sampleFps: Double?,
        everyMs: Int?,
        startMs: Int?,
        endMs: Int?,
        resolutionCap: CGFloat?) async throws
    {
        let asset = AVAsset(url: url)
        let duration: CMTime
        if #available(macOS 13.0, *) {
            duration = try await asset.load(.duration)
        } else {
            duration = asset.duration
        }
        guard duration.isNumeric, duration.seconds > 0 else {
            throw PeekabooError.captureFailed(reason: "Video has no duration")
        }

        let start = CMTime(milliseconds: startMs ?? 0)
        let end = endMs.map { CMTime(milliseconds: $0) } ?? duration
        guard end > start else { throw PeekabooError.captureFailed(reason: "end-ms must exceed start-ms") }

        // Derive sampling cadence from either fps or fixed millisecond interval,
        // and expose effectiveFPS so the video writer can match it later.
        let interval: CMTime
        if let everyMs, everyMs > 0 {
            interval = CMTime(milliseconds: everyMs)
            self.effectiveFPS = everyMs > 0 ? min(240, max(0.1, 1000.0 / Double(everyMs))) : 2.0
        } else {
            let fps = sampleFps ?? 2.0
            interval = CMTime(seconds: 1.0 / max(fps, 0.1), preferredTimescale: 1_000_000)
            self.effectiveFPS = fps
        }

        var cursor = start
        var requested: [CMTime] = []
        while cursor <= end {
            requested.append(cursor)
            cursor = CMTimeAdd(cursor, interval)
        }
        if requested.count < 2 {
            requested.append(end)
        }

        self.times = requested
        self.generator = AVAssetImageGenerator(asset: asset)
        self.generator.appliesPreferredTrackTransform = true
        if let cap = resolutionCap {
            self.generator.maximumSize = CGSize(width: cap, height: cap)
        }
    }

    public func nextFrame() async throws -> (cgImage: CGImage?, metadata: CaptureMetadata)? {
        guard self.index < self.times.count else { return nil }
        let time = self.times[self.index]
        self.index += 1

        var actual = CMTime.zero
        do {
            let image = try self.generator.copyCGImage(at: time, actualTime: &actual)
            let size = CGSize(width: image.width, height: image.height)
            let meta = CaptureMetadata(
                size: size,
                mode: self.mode,
                applicationInfo: nil,
                windowInfo: nil,
                displayInfo: nil,
                timestamp: Date())
            return (image, meta)
        } catch {
            // Skip unreadable frames but keep advancing
            let meta = CaptureMetadata(
                size: .zero,
                mode: self.mode,
                applicationInfo: nil,
                windowInfo: nil,
                displayInfo: nil,
                timestamp: Date())
            return (nil, meta)
        }
    }
}

extension CMTime {
    fileprivate init(milliseconds: Int) {
        self.init(value: CMTimeValue(milliseconds), timescale: 1000)
    }
}
