import AppKit
import CoreGraphics
import Foundation
import PeekabooFoundation
@preconcurrency import ScreenCaptureKit

extension LegacyScreenCaptureOperator {
    func captureScreen(
        displayIndex: Int?,
        correlationId: String,
        visualizerMode _: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        self.logger.debug("Using legacy CGWindowList API for screen capture", correlationId: correlationId)

        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            throw OperationError.captureFailed(reason: "No displays available")
        }

        let targetScreen: NSScreen
        if let index = displayIndex {
            guard index >= 0, index < screens.count else {
                throw PeekabooError.invalidInput(
                    "displayIndex: Index \(index) is out of range. Available displays: 0-\(screens.count - 1)")
            }
            targetScreen = screens[index]
        } else {
            targetScreen = screens.first!
        }

        let screenBounds = targetScreen.frame
        let scalePlan = ScreenCaptureScaleResolver.plan(
            preference: scale,
            screenBackingScaleFactor: targetScreen.backingScaleFactor,
            fallbackPixelWidth: Int(screenBounds.width * targetScreen.backingScaleFactor),
            frameWidth: screenBounds.width)
        let image = try self.captureDisplayWithCGDisplay(screen: targetScreen)

        let scaledImage = ScreenCaptureImageScaler.maybeDownscale(
            image,
            scale: scale,
            fallbackScale: scalePlan.nativeScale)

        let imageData: Data
        do {
            imageData = try scaledImage.pngData()
        } catch {
            throw OperationError.captureFailed(reason: "Failed to convert image to PNG format")
        }

        self.logger.debug(
            "Legacy screenshot created",
            metadata: [
                "imageSize": "\(scaledImage.width)x\(scaledImage.height)",
                "dataSize": imageData.count,
            ],
            correlationId: correlationId)

        let metadata = CaptureMetadata(
            size: CGSize(width: scaledImage.width, height: scaledImage.height),
            mode: .screen,
            displayInfo: DisplayInfo(
                index: displayIndex ?? 0,
                name: "Display \(displayIndex ?? 0)",
                bounds: screenBounds,
                scaleFactor: scalePlan.outputScale),
            diagnostics: ScreenCaptureScaleResolver.diagnostics(
                plan: scalePlan,
                finalPixelSize: CGSize(width: scaledImage.width, height: scaledImage.height)))

        return CaptureResult(
            imageData: imageData,
            metadata: metadata)
    }

    func captureArea(
        _ rect: CGRect,
        correlationId: String,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        self.logger.debug(
            "Legacy area capture using ScreenCaptureKit screenshot manager",
            correlationId: correlationId)

        let content = try await ScreenCaptureKitCaptureGate.currentShareableContent()
        guard let display = content.displays.first(where: { $0.frame.contains(rect) }) else {
            throw PeekabooError.invalidInput(
                "captureArea: The specified area is not within any display bounds")
        }

        let scalePlan = ScreenCaptureScaleResolver.plan(
            preference: scale,
            displayID: display.displayID,
            fallbackPixelWidth: display.width,
            frameWidth: display.frame.width)
        let outputScale = scalePlan.outputScale

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        // `rect` is global desktop geometry; display-bound filters need local source geometry.
        config.sourceRect = ScreenCapturePlanner.displayLocalSourceRect(
            globalRect: rect,
            displayFrame: display.frame)
        config.width = Int(rect.width * outputScale)
        config.height = Int(rect.height * outputScale)
        config.captureResolution = .best
        config.showsCursor = false

        let image = try await ScreenCaptureKitCaptureGate.captureImage(
            contentFilter: filter,
            configuration: config)

        let imageData = try image.pngData()
        let metadata = CaptureMetadata(
            size: CGSize(width: image.width, height: image.height),
            mode: .area,
            displayInfo: DisplayInfo(
                index: content.displays.firstIndex(where: { $0.displayID == display.displayID }) ?? 0,
                name: display.displayID.description,
                bounds: display.frame,
                scaleFactor: outputScale),
            diagnostics: ScreenCaptureScaleResolver.diagnostics(
                plan: scalePlan,
                finalPixelSize: CGSize(width: image.width, height: image.height)))

        return CaptureResult(imageData: imageData, metadata: metadata)
    }
}
