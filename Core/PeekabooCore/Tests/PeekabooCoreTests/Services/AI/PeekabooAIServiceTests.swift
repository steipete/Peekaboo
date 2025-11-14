//
//  PeekabooAIServiceTests.swift
//  PeekabooCore
//

import Foundation
import Tachikoma
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@Suite("PeekabooAIService Tests")
struct PeekabooAIServiceTests {
    @Test("Initialize AI service")
    @MainActor
    func initialization() async throws {
        let service = PeekabooAIService()
        #expect(service != nil)
    }

    @Test("List available models")
    @MainActor
    func testAvailableModels() async throws {
        let service = PeekabooAIService()
        let models = service.availableModels()

        #expect(!models.isEmpty)
        #expect(models == [.openai(.gpt5), .anthropic(.sonnet45)])
    }

    @Test("Generate text with default model")
    @MainActor
    func testGenerateText() async throws {
        let service = PeekabooAIService()

        // Skip test if no API key is configured
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else {
            throw Issue.record("Skipping test - OPENAI_API_KEY not configured")
        }

        let result = try await service.generateText(prompt: "Say 'Hello test' and nothing else")
        #expect(result.lowercased().contains("hello"))
        #expect(result.lowercased().contains("test"))
    }

    @Test("Analyze image data")
    @MainActor
    func analyzeImageData() async throws {
        let service = PeekabooAIService()

        // Skip test if no API key is configured
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else {
            throw Issue.record("Skipping test - OPENAI_API_KEY not configured")
        }

        // Create a simple test image (1x1 red pixel)
        let imageData = self.createTestImageData()

        let result = try await service.analyzeImage(
            imageData: imageData,
            question: "What color is this image? Answer with just the color name.")

        #expect(!result.isEmpty)
        // The AI should recognize it's a red image
        #expect(result.lowercased().contains("red") || result.lowercased().contains("color"))
    }

    @Test("Analyze image file")
    @MainActor
    func testAnalyzeImageFile() async throws {
        let service = PeekabooAIService()

        // Skip test if no API key is configured
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else {
            throw Issue.record("Skipping test - OPENAI_API_KEY not configured")
        }

        // Create a temporary test image file
        let tempDir = FileManager.default.temporaryDirectory
        let imagePath = tempDir.appendingPathComponent("test_image_\(UUID().uuidString).png").path

        let imageData = self.createTestImageData()
        try imageData.write(to: URL(fileURLWithPath: imagePath))

        defer {
            try? FileManager.default.removeItem(atPath: imagePath)
        }

        let result = try await service.analyzeImageFile(
            at: imagePath,
            question: "Is there an image? Answer yes or no.")

        #expect(!result.isEmpty)
        #expect(result.lowercased().contains("yes") || result.lowercased().contains("image"))
    }

    @Test("Use custom model for generation")
    @MainActor
    func customModel() async throws {
        let service = PeekabooAIService()

        // Skip test if no API key is configured
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else {
            throw Issue.record("Skipping test - OPENAI_API_KEY not configured")
        }

        let result = try await service.generateText(
            prompt: "Say 'Model test' and nothing else",
            model: .openai(.gpt5))

        #expect(result.lowercased().contains("model"))
        #expect(result.lowercased().contains("test"))
    }

    // Helper function to create test image data
    private func createTestImageData() -> Data {
        // Create a simple 1x1 red pixel PNG
        let width = 1
        let height = 1
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        // Set red pixel (RGBA)
        pixels[0] = 255 // R
        pixels[1] = 0 // G
        pixels[2] = 0 // B
        pixels[3] = 255 // A

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue)
        else {
            return Data()
        }

        guard let cgImage = context.makeImage() else {
            return Data()
        }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:])
        else {
            return Data()
        }

        return pngData
    }
}
