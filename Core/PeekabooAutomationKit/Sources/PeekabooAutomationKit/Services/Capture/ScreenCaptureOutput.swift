import CoreGraphics
import CoreMedia
import Foundation
import ImageIO
import PeekabooFoundation
@preconcurrency import ScreenCaptureKit
import UniformTypeIdentifiers

// MARK: - Capture Output Handler

@MainActor
final class CaptureOutput: NSObject, @unchecked Sendable {
    private var continuation: CheckedContinuation<CGImage, any Error>?
    private var timeoutTask: Task<Void, Never>?
    private var pendingCancellation = false

    @MainActor
    fileprivate func finish(_ result: Result<CGImage, any Error>) {
        // Single exit hatch for all completion paths: ensures timeout is canceled and continuation
        // is resumed exactly once, eliminating the racey scatter of resumes that existed before.
        // Cancel any pending timeout
        self.pendingCancellation = false
        self.timeoutTask?.cancel()
        self.timeoutTask = nil

        guard let cont = self.continuation else { return }
        self.continuation = nil
        switch result {
        case let .success(image):
            cont.resume(returning: image)
        case let .failure(error):
            cont.resume(throwing: error)
        }
    }

    @MainActor
    fileprivate func setContinuation(_ cont: CheckedContinuation<CGImage, any Error>) {
        // Tests inject their own continuation; production uses waitForImage().
        self.continuation = cont
        if self.pendingCancellation {
            self.pendingCancellation = false
            self.finish(.failure(CancellationError()))
        }
    }

    deinit {
        // Cancel timeout task first to prevent race condition
        timeoutTask?.cancel()

        // Ensure continuation is resumed if object is deallocated
        if let continuation = self.continuation {
            continuation.resume(throwing: OperationError.captureFailed(
                reason: "CaptureOutput deallocated before frame captured"))
            self.continuation = nil
        }
    }

    /// Suspend until the next captured frame arrives, throwing if the stream stalls.
    func waitForImage() async throws -> CGImage {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.setContinuation(continuation)

                // Add a timeout to ensure the continuation is always resumed.
                self.timeoutTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                    await MainActor.run {
                        guard let self else { return }
                        self.finish(.failure(OperationError.timeout(
                            operation: "CaptureOutput.waitForImage",
                            duration: 3.0)))
                    }
                }
            }
        } onCancel: { [weak self] in
            Task.detached { @MainActor [weak self] in
                guard let self else { return }
                self.pendingCancellation = true
                self.finish(.failure(CancellationError()))
            }
        }
    }

    /// Feed new screen samples into the pending continuation, delivering captured frames.
    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType)
    {
        guard type == .screen else { return }

        guard let imageBuffer = sampleBuffer.imageBuffer else {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.finish(.failure(OperationError.captureFailed(reason: "No image buffer in sample")))
            }
            return
        }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.finish(.failure(OperationError.captureFailed(
                    reason: "Failed to create CGImage from buffer")))
            }
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.finish(.success(cgImage))
        }
    }
}

extension CaptureOutput: SCStreamOutput {}

extension CaptureOutput: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.finish(.failure(error))
        }
    }
}

#if DEBUG
extension CaptureOutput {
    /// Test-only hook to inject the continuation used by `waitForImage()`.
    @MainActor
    func injectContinuation(_ cont: CheckedContinuation<CGImage, any Error>) {
        self.setContinuation(cont)
    }

    /// Test-only hook to drive completion of the continuation.
    @MainActor
    func injectFinish(_ result: Result<CGImage, any Error>) {
        self.finish(result)
    }
}
#endif

// MARK: - Extensions

extension CGImage {
    func pngData() throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil)
        else {
            throw OperationError.captureFailed(reason: "Failed to create PNG destination")
        }
        CGImageDestinationAddImage(destination, self, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw OperationError.captureFailed(reason: "Failed to finalize PNG data")
        }
        return data as Data
    }
}
