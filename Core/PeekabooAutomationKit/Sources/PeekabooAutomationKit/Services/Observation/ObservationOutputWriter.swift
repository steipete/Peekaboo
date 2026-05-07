import AppKit
import Foundation
import PeekabooFoundation

@MainActor
public protocol ObservationOutputWriting: Sendable {
    func write(capture: CaptureResult, options: DesktopObservationOutputOptions) async throws -> DesktopObservationFiles
}

@MainActor
public final class ObservationOutputWriter: ObservationOutputWriting {
    public init() {}

    public func write(
        capture: CaptureResult,
        options: DesktopObservationOutputOptions) async throws -> DesktopObservationFiles
    {
        let rawPath = try self.writeRawScreenshotIfNeeded(capture: capture, options: options)
        return DesktopObservationFiles(
            rawScreenshotPath: rawPath ?? capture.savedPath,
            annotatedScreenshotPath: nil)
    }

    public nonisolated static func annotatedScreenshotPath(forRawScreenshotPath rawPath: String) -> String {
        (rawPath as NSString).deletingPathExtension + "_annotated.png"
    }

    private func writeRawScreenshotIfNeeded(
        capture: CaptureResult,
        options: DesktopObservationOutputOptions) throws -> String?
    {
        guard options.saveRawScreenshot else {
            return nil
        }

        let url = self.outputURL(path: options.path, format: options.format)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try self.encodedImageData(capture.imageData, format: options.format).write(to: url, options: .atomic)
        return url.path
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
