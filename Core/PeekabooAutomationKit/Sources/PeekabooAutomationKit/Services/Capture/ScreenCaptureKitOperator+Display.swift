import CoreGraphics
import Foundation
import PeekabooFoundation
@preconcurrency import ScreenCaptureKit

@MainActor
extension ScreenCaptureKitOperator {
    func captureScreenImpl(
        displayIndex: Int?,
        correlationId: String,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        self.logger.debug("Fetching shareable content", correlationId: correlationId)
        let content = try await ScreenCaptureKitCaptureGate.currentShareableContent()
        let displays = content.displays

        self.logger.debug(
            "Found displays",
            metadata: ["count": displays.count],
            correlationId: correlationId)
        guard !displays.isEmpty else {
            self.logger.error("No displays found", correlationId: correlationId)
            throw OperationError.captureFailed(reason: "No displays available for capture")
        }

        let targetDisplay: SCDisplay
        if let index = displayIndex {
            guard index >= 0, index < displays.count else {
                throw PeekabooError.invalidInput(
                    "displayIndex: Index \(index) is out of range. Available displays: 0-\(displays.count - 1)")
            }
            targetDisplay = displays[index]
        } else {
            targetDisplay = displays.first!
        }

        self.logger.debug(
            "Creating screenshot of display",
            metadata: ["displayID": targetDisplay.displayID],
            correlationId: correlationId)

        let request = CaptureFrameRequest(
            mode: .screen,
            display: targetDisplay,
            displayIndex: displayIndex ?? 0,
            displayName: targetDisplay.displayID.description,
            displayBounds: targetDisplay.frame,
            sourceRect: CGRect(origin: .zero, size: targetDisplay.frame.size),
            scale: scale,
            correlationId: correlationId)
        let capture = try await self.captureDisplayFrame(request: request)
        let image = capture.image

        let imageData = try image.pngData()

        self.logger.debug(
            "Screenshot created",
            metadata: [
                "imageSize": "\(image.width)x\(image.height)",
                "dataSize": imageData.count,
            ],
            correlationId: correlationId)

        await self.emitVisualizer(mode: visualizerMode, rect: targetDisplay.frame)

        return CaptureResult(imageData: imageData, metadata: capture.metadata)
    }

    func captureAreaImpl(
        _ rect: CGRect,
        correlationId: String,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        self.logger.debug("Finding display containing rect", correlationId: correlationId)
        let content = try await ScreenCaptureKitCaptureGate.currentShareableContent()
        guard let display = content.displays.first(where: { $0.frame.contains(rect) }) else {
            self.logger.error(
                "No display contains the specified area",
                metadata: [
                    "rect": "\(rect.origin.x),\(rect.origin.y) \(rect.width)x\(rect.height)",
                ],
                correlationId: correlationId)
            throw PeekabooError.invalidInput(
                "captureArea: The specified area is not within any display bounds")
        }

        self.logger.debug(
            "Found display for area",
            metadata: ["displayID": display.displayID],
            correlationId: correlationId)

        let displayIndex = content.displays.firstIndex(where: { $0.displayID == display.displayID }) ?? 0
        let localRect = ScreenCapturePlanner.displayLocalSourceRect(
            globalRect: rect,
            displayFrame: display.frame)
        let request = CaptureFrameRequest(
            mode: .area,
            display: display,
            displayIndex: displayIndex,
            displayName: display.displayID.description,
            displayBounds: rect,
            sourceRect: localRect,
            scale: scale,
            correlationId: correlationId)
        let capture = try await self.captureDisplayFrame(request: request)
        let image = capture.image

        let imageData = try image.pngData()

        return CaptureResult(imageData: imageData, metadata: capture.metadata)
    }
}
