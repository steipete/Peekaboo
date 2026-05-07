import CoreGraphics
import Foundation
import XCTest
@testable import PeekabooAutomationKit

final class FileServiceImageTests: XCTestCase {
    func testSaveImageExpandsHomeDirectoryPath() throws {
        let relativePath = "Library/Caches/peekaboo-file-service-\(UUID().uuidString).png"
        let outputURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(relativePath)
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try FileService().saveImage(
            self.makePixelImage(),
            to: "~/\(relativePath)",
            format: .png)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    private func makePixelImage() throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixel: UInt32 = 0xFF00_00FF
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            let image = context.makeImage()
        else {
            throw XCTSkip("Unable to create test image")
        }
        return image
    }
}
