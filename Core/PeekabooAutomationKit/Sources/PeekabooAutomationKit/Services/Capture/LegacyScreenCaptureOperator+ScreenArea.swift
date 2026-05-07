import AppKit
import CoreGraphics
import Foundation
import ImageIO
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
        self.logger.debug("Legacy area capture using CoreGraphics display capture", correlationId: correlationId)

        let displays = Self.activeDisplays()
        guard let display = displays.first(where: { $0.bounds.contains(rect) }) else {
            throw PeekabooError.invalidInput(
                "captureArea: The specified area is not within any display bounds")
        }

        let scalePlan = ScreenCaptureScaleResolver.plan(
            preference: scale,
            displayID: display.id,
            fallbackPixelWidth: CGDisplayPixelsWide(display.id),
            frameWidth: display.bounds.width)
        let image = if let systemImage = try? self.captureAreaWithSystemScreencapture(
            rect,
            correlationId: correlationId)
        {
            systemImage
        } else {
            try self.captureAreaWithCoreGraphics(display: display, rect: rect)
        }
        let scaledImage = ScreenCaptureImageScaler.maybeDownscale(
            image,
            scale: scale,
            fallbackScale: scalePlan.nativeScale)
        let imageData = try scaledImage.pngData()
        let metadata = CaptureMetadata(
            size: CGSize(width: scaledImage.width, height: scaledImage.height),
            mode: .area,
            displayInfo: DisplayInfo(
                index: display.index,
                name: display.id.description,
                bounds: rect,
                scaleFactor: scalePlan.outputScale),
            diagnostics: ScreenCaptureScaleResolver.diagnostics(
                plan: scalePlan,
                finalPixelSize: CGSize(width: scaledImage.width, height: scaledImage.height)))

        return CaptureResult(imageData: imageData, metadata: metadata)
    }

    private func captureAreaWithCoreGraphics(
        display: (index: Int, id: CGDirectDisplayID, bounds: CGRect),
        rect: CGRect) throws -> CGImage
    {
        guard let displayImage = CGDisplayCreateImage(display.id) else {
            throw OperationError.captureFailed(reason: "CGDisplayCreateImage returned nil for display")
        }
        let cropRect = Self.pixelCropRect(
            globalRect: rect,
            displayBounds: display.bounds,
            scale: Self.nativeScale(for: display))
        guard let image = displayImage.cropping(to: cropRect) else {
            throw OperationError.captureFailed(reason: "Failed to crop CoreGraphics display image for capture area")
        }
        return image
    }

    private func captureAreaWithSystemScreencapture(
        _ rect: CGRect,
        correlationId: String) throws -> CGImage
    {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("peekaboo-area-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = [
            "-x",
            "-R\(Int(rect.minX.rounded(.down))),\(Int(rect.minY.rounded(.down)))," +
                "\(Int(rect.width.rounded(.toNearestOrAwayFromZero)))," +
                "\(Int(rect.height.rounded(.toNearestOrAwayFromZero)))",
            url.path,
        ]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw OperationError.captureFailed(reason: "screencapture exited with \(process.terminationStatus)")
        }
        let data = try Data(contentsOf: url)
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw OperationError.captureFailed(reason: "Failed to decode screencapture output")
        }
        self.logger.debug(
            "Captured area via system screencapture",
            metadata: ["imageSize": "\(image.width)x\(image.height)"],
            correlationId: correlationId)
        return image
    }

    private nonisolated static func activeDisplays() -> [(index: Int, id: CGDirectDisplayID, bounds: CGRect)] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            return []
        }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else {
            return []
        }
        return ids.prefix(Int(count)).enumerated().map { index, id in
            (index: index, id: id, bounds: CGDisplayBounds(id))
        }
    }

    private nonisolated static func pixelCropRect(
        globalRect: CGRect,
        displayBounds: CGRect,
        scale: CGFloat) -> CGRect
    {
        CGRect(
            x: ((globalRect.minX - displayBounds.minX) * scale).rounded(.down),
            y: ((globalRect.minY - displayBounds.minY) * scale).rounded(.down),
            width: max((globalRect.width * scale).rounded(.toNearestOrAwayFromZero), 1),
            height: max((globalRect.height * scale).rounded(.toNearestOrAwayFromZero), 1))
    }

    private nonisolated static func nativeScale(for display: (index: Int, id: CGDirectDisplayID, bounds: CGRect))
        -> CGFloat
    {
        let width = max(display.bounds.width, 1)
        return max(CGFloat(CGDisplayPixelsWide(display.id)) / width, 1)
    }
}
