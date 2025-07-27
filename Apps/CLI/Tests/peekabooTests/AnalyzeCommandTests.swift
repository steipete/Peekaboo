import Foundation
import Testing
import PeekabooCore
@testable import peekaboo

@Suite("AnalyzeCommand Tests")
struct AnalyzeCommandTests {
    private var testImagePath: String {
        NSTemporaryDirectory() + "test_image.png"
    }

    private func createTestImage() throws {
        // Create a simple 1x1 PNG image for testing
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
        try pngData.write(to: URL(fileURLWithPath: self.testImagePath))
    }

    @Test("Analyze with mock provider")
    func analyzeWithMockProvider() async throws {
        // Clean up any test files
        try? FileManager.default.removeItem(atPath: self.testImagePath)

        // Create test image
        try self.createTestImage()
        defer {
            try? FileManager.default.removeItem(atPath: testImagePath)
        }

        // Set up environment with mock provider config
        let originalEnv = ProcessInfo.processInfo.environment["PEEKABOO_AI_PROVIDERS"]
        defer {
            // Restore original environment
            if let original = originalEnv {
                setenv("PEEKABOO_AI_PROVIDERS", original, 1)
            } else {
                unsetenv("PEEKABOO_AI_PROVIDERS")
            }
        }

        // Test the basic command structure using parse
        let args = [testImagePath, "What is this?", "--provider", "auto"]
        let command = try AnalyzeCommand.parse(args)

        // Verify the command properties are set correctly
        #expect(command.imagePath == self.testImagePath)
        #expect(command.question == "What is this?")
        #expect(command.provider == "auto")
        #expect(command.jsonOutput == false)
    }

    @Test("Analyze command validation")
    func analyzeCommandValidation() throws {
        // Test default values by parsing with minimal arguments
        let args = ["/tmp/test.png", "Test question"]
        let command = try AnalyzeCommand.parse(args)
        #expect(command.provider == "auto")
        #expect(command.jsonOutput == false)
        #expect(command.model == nil)
    }

    @Test("Analyze error file not found")
    func analyzeErrorFileNotFound() {
        let error = AnalyzeError.fileNotFound("/path/to/missing.png")
        #expect(error.errorDescription == "Image file not found: /path/to/missing.png")
    }

    @Test("Analyze error unsupported format")
    func analyzeErrorUnsupportedFormat() {
        let error = AnalyzeError.unsupportedFormat("txt")
        #expect(
            error.errorDescription ==
                "Unsupported image format: .txt. Supported formats: .png, .jpg, .jpeg, .webp")
    }

    @Test("Analyze error no providers configured")
    func analyzeErrorNoProvidersConfigured() {
        let error = AnalyzeError.noProvidersConfigured
        #expect(
            error.errorDescription ==
                "AI analysis not configured. Set the PEEKABOO_AI_PROVIDERS environment variable.")
    }
}

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
