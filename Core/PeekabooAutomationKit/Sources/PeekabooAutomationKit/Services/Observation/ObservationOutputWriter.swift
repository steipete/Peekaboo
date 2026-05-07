import AppKit
import Foundation
import PeekabooFoundation

@MainActor
public protocol ObservationOutputWriting: Sendable {
    func write(
        capture: CaptureResult,
        elements: ElementDetectionResult?,
        options: DesktopObservationOutputOptions) async throws -> DesktopObservationFiles
}

@MainActor
public final class ObservationOutputWriter: ObservationOutputWriting {
    private let snapshotManager: (any SnapshotManagerProtocol)?

    public init(snapshotManager: (any SnapshotManagerProtocol)? = nil) {
        self.snapshotManager = snapshotManager
    }

    public func write(
        capture: CaptureResult,
        elements: ElementDetectionResult?,
        options: DesktopObservationOutputOptions) async throws -> DesktopObservationFiles
    {
        let rawPath = try self.writeRawScreenshotIfNeeded(capture: capture, options: options)
        let effectiveRawPath = rawPath ?? capture.savedPath
        let annotatedPath = try self.writeAnnotatedScreenshotIfNeeded(
            rawPath: effectiveRawPath,
            capture: capture,
            elements: elements,
            options: options)
        try await self.writeSnapshotIfNeeded(
            rawPath: effectiveRawPath,
            annotatedPath: annotatedPath,
            capture: capture,
            elements: elements,
            options: options)
        return DesktopObservationFiles(
            rawScreenshotPath: effectiveRawPath,
            annotatedScreenshotPath: annotatedPath)
    }

    public nonisolated static func annotatedScreenshotPath(forRawScreenshotPath rawPath: String) -> String {
        (rawPath as NSString).deletingPathExtension + "_annotated.png"
    }

    private func writeRawScreenshotIfNeeded(
        capture: CaptureResult,
        options: DesktopObservationOutputOptions) throws -> String?
    {
        guard options.saveRawScreenshot || options.saveAnnotatedScreenshot || options.saveSnapshot else {
            return nil
        }

        let url = self.outputURL(path: options.path, format: options.format)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try self.encodedImageData(capture.imageData, format: options.format).write(to: url, options: .atomic)
        return url.path
    }

    private func writeSnapshotIfNeeded(
        rawPath: String?,
        annotatedPath: String?,
        capture: CaptureResult,
        elements: ElementDetectionResult?,
        options: DesktopObservationOutputOptions) async throws
    {
        guard options.saveSnapshot, let snapshotManager = self.snapshotManager, let rawPath else {
            return
        }

        let snapshotID = options.snapshotID ?? elements?.snapshotId
        guard let snapshotID else {
            return
        }

        let windowContext = elements?.metadata.windowContext
        try await snapshotManager.storeScreenshot(SnapshotScreenshotRequest(
            snapshotId: snapshotID,
            screenshotPath: rawPath,
            applicationBundleId: windowContext?.applicationBundleId ?? capture.metadata.applicationInfo?
                .bundleIdentifier,
            applicationProcessId: windowContext?.applicationProcessId ?? capture.metadata.applicationInfo?
                .processIdentifier,
            applicationName: windowContext?.applicationName ?? capture.metadata.applicationInfo?.name,
            windowTitle: windowContext?.windowTitle ?? capture.metadata.windowInfo?.title,
            windowBounds: windowContext?.windowBounds ?? capture.metadata.windowInfo?.bounds))

        if let elements {
            try await snapshotManager.storeDetectionResult(
                snapshotId: snapshotID,
                result: ElementDetectionResult(
                    snapshotId: snapshotID,
                    screenshotPath: rawPath,
                    elements: elements.elements,
                    metadata: elements.metadata))
        }

        if let annotatedPath {
            try await snapshotManager.storeAnnotatedScreenshot(
                snapshotId: snapshotID,
                annotatedScreenshotPath: annotatedPath)
        }
    }

    private func writeAnnotatedScreenshotIfNeeded(
        rawPath: String?,
        capture: CaptureResult,
        elements: ElementDetectionResult?,
        options: DesktopObservationOutputOptions) throws -> String?
    {
        guard options.saveAnnotatedScreenshot else {
            return nil
        }
        guard let rawPath, let elements else {
            return nil
        }

        let sourceImage = NSImage(contentsOfFile: rawPath) ?? NSImage(data: capture.imageData)
        guard let sourceImage else {
            throw OperationError.captureFailed(reason: "Failed to load screenshot for annotation")
        }

        let annotatedPath = Self.annotatedScreenshotPath(forRawScreenshotPath: rawPath)
        let annotatedImage = self.annotatedImage(from: sourceImage, detectionResult: elements)
        guard let pngData = self.pngData(from: annotatedImage) else {
            throw OperationError.captureFailed(reason: "Failed to encode annotated screenshot")
        }
        try pngData.write(to: URL(fileURLWithPath: annotatedPath), options: .atomic)
        return annotatedPath
    }

    private func annotatedImage(
        from sourceImage: NSImage,
        detectionResult: ElementDetectionResult) -> NSImage
    {
        let imageSize = sourceImage.size
        let annotatedImage = NSImage(size: imageSize)
        annotatedImage.lockFocus()
        defer { annotatedImage.unlockFocus() }

        sourceImage.draw(
            at: .zero,
            from: NSRect(origin: .zero, size: imageSize),
            operation: .copy,
            fraction: 1)

        let windowOrigin = Self.windowOrigin(for: detectionResult)
        for element in detectionResult.elements.all where element.isEnabled {
            let rect = Self.drawingRect(for: element, imageSize: imageSize, windowOrigin: windowOrigin)
            self.drawAnnotation(id: element.id, type: element.type, rect: rect)
        }

        return annotatedImage
    }

    private func drawAnnotation(id: String, type: ElementType, rect: NSRect) {
        let color = self.color(for: type)
        color.withAlphaComponent(0.18).setFill()
        NSBezierPath(rect: rect).fill()

        color.withAlphaComponent(0.9).setStroke()
        let borderPath = NSBezierPath(rect: rect)
        borderPath.lineWidth = 1.5
        borderPath.stroke()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let label = id as NSString
        let labelSize = label.size(withAttributes: attributes)
        let labelRect = NSRect(
            x: rect.minX,
            y: rect.maxY + 3,
            width: labelSize.width + 8,
            height: labelSize.height + 4)

        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 2, yRadius: 2).fill()
        label.draw(
            at: NSPoint(x: labelRect.minX + 4, y: labelRect.minY + 2),
            withAttributes: attributes)
    }

    private func color(for type: ElementType) -> NSColor {
        switch type {
        case .button, .link, .menu:
            NSColor(red: 0, green: 0.48, blue: 1, alpha: 1)
        case .textField:
            NSColor(red: 0.204, green: 0.78, blue: 0.349, alpha: 1)
        default:
            NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1)
        }
    }

    private static func windowOrigin(for detectionResult: ElementDetectionResult) -> CGPoint {
        if let windowBounds = detectionResult.metadata.windowContext?.windowBounds {
            return windowBounds.origin
        }

        guard !detectionResult.elements.all.isEmpty else {
            return .zero
        }

        let minX = detectionResult.elements.all.map(\.bounds.minX).min() ?? 0
        let minY = detectionResult.elements.all.map(\.bounds.minY).min() ?? 0
        return CGPoint(x: minX, y: minY)
    }

    private static func drawingRect(
        for element: DetectedElement,
        imageSize: CGSize,
        windowOrigin: CGPoint) -> NSRect
    {
        let elementFrame = CGRect(
            x: element.bounds.origin.x - windowOrigin.x,
            y: element.bounds.origin.y - windowOrigin.y,
            width: element.bounds.width,
            height: element.bounds.height)

        return NSRect(
            x: elementFrame.origin.x,
            y: imageSize.height - elementFrame.origin.y - elementFrame.height,
            width: elementFrame.width,
            height: elementFrame.height)
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    private func outputURL(path: String?, format: ImageFormat) -> URL {
        let baseURL: URL
        if let path {
            baseURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        } else {
            let filename = "peekaboo-observation-\(Self.timestamp()).\(format.fileExtension)"
            baseURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        }

        if baseURL.pathExtension.isEmpty {
            return baseURL.appendingPathExtension(format.fileExtension)
        }
        return baseURL
    }

    private func encodedImageData(_ data: Data, format: ImageFormat) throws -> Data {
        switch format {
        case .png:
            return data
        case .jpg:
            guard let image = NSImage(data: data),
                  let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
            else {
                throw OperationError.captureFailed(reason: "Failed to convert screenshot to JPEG")
            }
            return jpeg
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        return formatter.string(from: Date())
    }
}

extension ImageFormat {
    fileprivate var fileExtension: String {
        switch self {
        case .png:
            "png"
        case .jpg:
            "jpg"
        }
    }
}
