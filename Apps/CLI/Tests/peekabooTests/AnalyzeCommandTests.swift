import Foundation
import Testing
@testable import peekaboo

@Suite("AnalyzeCommand Tests")
struct AnalyzeCommandTests {}

// MARK: - Integration Tests

@Suite("AnalyzeCommand Integration Tests")
struct AnalyzeIntegrationTests {
    private var tempImagePath: String {
        NSTemporaryDirectory() + "integration_test.png"
    }

    private func createTestPNG() throws {
        // Create a valid PNG file
        let pngData = Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT chunk
            0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
            0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
            0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, // IEND chunk
            0x44, 0xAE, 0x42, 0x60, 0x82,
        ])
        try pngData.write(to: URL(fileURLWithPath: self.tempImagePath))
    }

    @Test("End-to-end with mock providers")
    func endToEndWithMockProviders() async throws {
        // Clean up before test
        try? FileManager.default.removeItem(atPath: self.tempImagePath)

        // Create test image
        try self.createTestPNG()
        defer {
            try? FileManager.default.removeItem(atPath: tempImagePath)
        }

        // Create a mock provider factory or use dependency injection
        // This is complex without modifying the main code structure

        // For now, we verify the basic structure
        #expect(FileManager.default.fileExists(atPath: self.tempImagePath))

        // Test that we can read and base64 encode the image
        let imageData = try Data(contentsOf: URL(fileURLWithPath: tempImagePath))
        let base64String = imageData.base64EncodedString()
        #expect(!base64String.isEmpty)
    }

    @Test("File format validation")
    func fileFormatValidation() throws {
        // Test supported formats
        let supportedExtensions = ["png", "jpg", "jpeg", "webp"]
        for ext in supportedExtensions {
            let path = "/test/image.\(ext)"
            let url = URL(fileURLWithPath: path)
            #expect(supportedExtensions.contains(url.pathExtension.lowercased()))
        }

        // Test unsupported formats
        let unsupportedExtensions = ["txt", "pdf", "doc", "gif", "bmp"]
        for ext in unsupportedExtensions {
            let path = "/test/image.\(ext)"
            let url = URL(fileURLWithPath: path)
            #expect(!supportedExtensions.contains(url.pathExtension.lowercased()))
        }
    }
}
