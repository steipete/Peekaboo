import AVFoundation
import CoreGraphics
import Foundation
import PeekabooFoundation

/// Simple MP4 writer that appends CGImages as video frames.
final class VideoWriter {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let frameDuration: CMTime
    private var frameIndex: Int64 = 0

    var finalURL: URL { self.writer.outputURL }

    init(outputPath: String, width: Int, height: Int, fps: Double) throws {
        let url = URL(fileURLWithPath: outputPath)
        self.writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        self.input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        self.input.expectsMediaDataInRealTime = false

        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        self.adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: self.input,
            sourcePixelBufferAttributes: attrs)

        guard self.writer.canAdd(self.input) else {
            throw PeekabooError.captureFailed(reason: "Cannot add video input")
        }
        self.writer.add(self.input)
        self.frameDuration = CMTime(value: 1, timescale: CMTimeScale(max(1, Int(fps))))
    }

    func startIfNeeded() throws {
        guard self.writer.status == .unknown else { return }
        guard self.writer.startWriting() else {
            throw self.writer.error ?? PeekabooError.captureFailed(reason: "Failed to start video writer")
        }
        self.writer.startSession(atSourceTime: .zero)
    }

    func append(image: CGImage) throws {
        try self.startIfNeeded()
        guard self.input.isReadyForMoreMediaData else { return }

        var pixelBuffer: CVPixelBuffer?
        let width = image.width
        let height = image.height
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer)
        guard let buffer = pixelBuffer else { return }

        CVPixelBufferLockBaseAddress(buffer, [])
        if let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        {
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        let pts = CMTimeMultiply(self.frameDuration, multiplier: Int32(self.frameIndex))
        self.adaptor.append(buffer, withPresentationTime: pts)
        self.frameIndex += 1
    }

    func finish() async throws {
        guard self.writer.status != .completed else { return }
        self.input.markAsFinished()
        await withCheckedContinuation { continuation in
            self.writer.finishWriting {
                continuation.resume()
            }
        }
        if self.writer.status != .completed {
            throw self.writer.error ?? PeekabooError.captureFailed(reason: "Failed to finalize video")
        }
    }
}
