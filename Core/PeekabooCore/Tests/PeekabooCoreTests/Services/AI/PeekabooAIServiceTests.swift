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
        #expect(models == [.openai(.gpt51), .anthropic(.opus45)])
    }

    @Test("Respects configured provider default")
    @MainActor
    func respectsConfiguredProvider() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("peekaboo-config-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let configPath = tempDir.appendingPathComponent("config.json")
        try """
        {
          "aiProviders": { "providers": "anthropic/claude-sonnet-4.5" }
        }
        """.write(to: configPath, atomically: true, encoding: .utf8)

        // Point configuration manager at the temporary config and reload.
        setenv("PEEKABOO_CONFIG_DIR", tempDir.path, 1)
        defer {
            unsetenv("PEEKABOO_CONFIG_DIR")
            ConfigurationManager.shared.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        ConfigurationManager.shared.resetForTesting()
        _ = ConfigurationManager.shared.loadConfiguration()

        let service = PeekabooAIService()
        #expect(service.resolvedDefaultModel == .anthropic(.sonnet45))
        #expect(service.availableModels() == [.anthropic(.sonnet45)])
    }

    @Test("Uses provider list ordering for default model")
    @MainActor
    func usesProvidersListOrdering() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("peekaboo-config-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let configPath = tempDir.appendingPathComponent("config.json")
        try """
        {
          "aiProviders": { "providers": "anthropic/claude-sonnet-4.5,openai/gpt-5.1" }
        }
        """.write(to: configPath, atomically: true, encoding: .utf8)

        setenv("PEEKABOO_CONFIG_DIR", tempDir.path, 1)
        defer {
            unsetenv("PEEKABOO_CONFIG_DIR")
            ConfigurationManager.shared.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        ConfigurationManager.shared.resetForTesting()
        _ = ConfigurationManager.shared.loadConfiguration()

        let service = PeekabooAIService()
        #expect(service.availableModels() == [.anthropic(.sonnet45), .openai(.gpt51)])
        #expect(service.resolvedDefaultModel == .anthropic(.sonnet45))
    }

    @Test("Automatically loads configuration when resolving providers")
    @MainActor
    func autoLoadsConfiguration() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("peekaboo-config-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let configPath = tempDir.appendingPathComponent("config.json")
        try """
        {
          "aiProviders": { "providers": "anthropic/claude-sonnet-4.5" }
        }
        """.write(to: configPath, atomically: true, encoding: .utf8)

        setenv("PEEKABOO_CONFIG_DIR", tempDir.path, 1)
        defer {
            unsetenv("PEEKABOO_CONFIG_DIR")
            ConfigurationManager.shared.resetForTesting()
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Intentionally do NOT call loadConfiguration to mirror CLI startup.
        ConfigurationManager.shared.resetForTesting()

        let service = PeekabooAIService()
        #expect(service.availableModels() == [.anthropic(.sonnet45)])
        #expect(service.resolvedDefaultModel == .anthropic(.sonnet45))
    }

    @Test("Falls back to Anthropic when only Anthropic key is present")
    @MainActor
    func fallbackAnthropicWithKey() async throws {
        setenv("ANTHROPIC_API_KEY", "key", 1)
        unsetenv("OPENAI_API_KEY")
        unsetenv("PEEKABOO_CONFIG_DIR")
        defer {
            unsetenv("ANTHROPIC_API_KEY")
            ConfigurationManager.shared.resetForTesting()
        }

        ConfigurationManager.shared.resetForTesting()
        _ = ConfigurationManager.shared.loadConfiguration()

        let service = PeekabooAIService()
        #expect(service.resolvedDefaultModel == .anthropic(.opus45))
        #expect(service.availableModels() == [.anthropic(.opus45)])
    }

    @Test("Falls back to OpenAI when no config or keys present")
    @MainActor
    func fallbackOpenAIWhenEmpty() async throws {
        unsetenv("PEEKABOO_CONFIG_DIR")
        unsetenv("OPENAI_API_KEY")
        unsetenv("ANTHROPIC_API_KEY")
        ConfigurationManager.shared.resetForTesting()
        _ = ConfigurationManager.shared.loadConfiguration()

        let service = PeekabooAIService()
        #expect(service.resolvedDefaultModel == .openai(.gpt51))
        #expect(service.availableModels().first == .openai(.gpt51))
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
            model: .openai(.gpt51))

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
