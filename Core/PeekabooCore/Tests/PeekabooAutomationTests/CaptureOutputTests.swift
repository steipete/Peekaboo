import CoreImage
import Testing
@testable import PeekabooAutomation

@Suite("CaptureOutput finish semantics")
struct CaptureOutputTests {
    @Test("finish resumes continuation with success")
    @MainActor
    func finishSuccess() async throws {
        let output = makeOutput()
        let dummyImage = CGImage(
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data([0, 0, 0, 0]) as CFData)!,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent)!

        let result = try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                output.injectContinuation(continuation)
                output.injectFinish(.success(dummyImage))
            }
        }
        #expect(result.width == 1)
    }

    @Test("finish resumes continuation with failure")
    @MainActor
    func finishFailure() async {
        let output = makeOutput()
        struct DummyError: Error {}

        do {
            _ = try await withCheckedThrowingContinuation { continuation in
                Task { @MainActor in
                    output.injectContinuation(continuation)
                    output.injectFinish(.failure(DummyError()))
                }
            }
            Issue.record("Expected failure, got success")
        } catch {
            // expected
        }
    }
}

// MARK: - Test hooks

@MainActor
private func makeOutput() -> CaptureOutput {
    CaptureOutput()
}
