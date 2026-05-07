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
    private let annotationRenderer: ObservationAnnotationRenderer

    public init(
        snapshotManager: (any SnapshotManagerProtocol)? = nil,
        annotationRenderer: ObservationAnnotationRenderer = ObservationAnnotationRenderer())
    {
        self.snapshotManager = snapshotManager
        self.annotationRenderer = annotationRenderer
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

        return try self.annotationRenderer.renderAnnotatedScreenshot(
            originalPath: rawPath,
            detectionResult: elements,
            annotatedPath: Self.annotatedScreenshotPath(forRawScreenshotPath: rawPath))
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
