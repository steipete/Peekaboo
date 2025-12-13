import CoreGraphics
import Foundation
import PeekabooFoundation

/// Abstract source of frames for capture sessions (live or video).
public protocol CaptureFrameSource {
    /// Returns next frame; nil when the source is exhausted.
    func nextFrame() async throws -> (cgImage: CGImage?, metadata: CaptureMetadata)?
}
