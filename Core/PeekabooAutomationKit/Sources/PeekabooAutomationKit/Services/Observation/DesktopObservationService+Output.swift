import Foundation

extension DesktopObservationService {
    func writeOutputIfNeeded(
        capture: CaptureResult,
        elements: ElementDetectionResult?,
        options: DesktopObservationOutputOptions,
        tracer: DesktopObservationTraceRecorder) async throws -> DesktopObservationFiles
    {
        guard options.saveRawScreenshot || options.saveAnnotatedScreenshot || options.saveSnapshot else {
            return DesktopObservationFiles(rawScreenshotPath: capture.savedPath)
        }

        let output = try await tracer.span("output.write") {
            try await self.outputWriter.write(capture: capture, elements: elements, options: options)
        }
        tracer.append(output.spans)
        return output.files
    }
}
