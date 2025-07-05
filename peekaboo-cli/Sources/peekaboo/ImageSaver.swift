import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Handles saving captured images to disk.
///
/// Provides functionality to save CGImage data to files in various formats (PNG, JPEG)
/// with proper error handling for common file system issues.
struct ImageSaver: Sendable {
    static func saveImage(_ image: CGImage, to path: String, format: ImageFormat) throws(CaptureError) {
        // Validate path doesn't contain null characters
        if path.contains("\0") {
            let error = NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileWriteInvalidFileNameError,
                userInfo: [NSLocalizedDescriptionKey: "Invalid characters in file path"]
            )
            throw CaptureError.fileWriteError(path, error)
        }

        let url = URL(fileURLWithPath: path)

        // Create parent directory if it doesn't exist
        let directory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw CaptureError.fileWriteError(path, error)
        }

        let utType: UTType = format == .png ? .png : .jpeg
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            utType.identifier as CFString,
            1,
            nil
        ) else {
            // Try to create a more specific error for common cases
            if !FileManager.default.isWritableFile(atPath: directory.path) {
                let error = NSError(
                    domain: NSPOSIXErrorDomain,
                    code: Int(EACCES),
                    userInfo: [NSLocalizedDescriptionKey: "Permission denied"]
                )
                throw CaptureError.fileWriteError(path, error)
            }
            throw CaptureError.fileWriteError(path, nil)
        }

        // Set compression quality for JPEG images (1.0 = highest quality)
        let properties: CFDictionary? = if format == .jpg {
            [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary
        } else {
            nil
        }

        CGImageDestinationAddImage(destination, image, properties)

        guard CGImageDestinationFinalize(destination) else {
            throw CaptureError.fileWriteError(path, nil)
        }
    }
}
