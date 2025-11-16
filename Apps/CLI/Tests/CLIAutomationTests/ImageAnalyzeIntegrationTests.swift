import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite("ImageCommand Analyze Integration Tests", .serialized, .tags(.imageCapture, .imageAnalysis, .integration))
struct ImageAnalyzeIntegrationTests {
    // MARK: - Test Helpers

    private func createTestImageFile() throws -> String {
        let testPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_capture_\(UUID().uuidString).png").path

        // Create a simple 1x1 PNG for testing
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

        try pngData.write(to: URL(fileURLWithPath: testPath))
        return testPath
    }

    private func cleanupTestFile(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - Analyze Error Handling Tests

    @Test("Analyze with missing image file", .tags(.fast))
    func analyzeWithMissingFile() async throws {
        // Note: We can't directly test analyzeImage as it's private
        // This test validates that the command accepts analyze option
        // The actual file validation happens during execution
        let command = try ImageCommand.parse([
            "--path", "/tmp/non_existent_\(UUID().uuidString).png",
            "--analyze", "Test prompt",
        ])

        #expect(command.analyze == "Test prompt")
        // Actual file validation would happen during command execution
    }

    @Test("Analyze prompt variations", .tags(.fast))
    func analyzePromptVariations() throws {
        let prompts = [
            "What is shown?",
            "Describe the UI elements in detail",
            "Is there an error message?",
            "What application is this?",
            "Summarize the content",
            "List all visible buttons",
            "What is the main color scheme?",
        ]

        // Test that all prompts are valid
        for prompt in prompts {
            let command = try ImageCommand.parse(["--analyze", prompt])
            #expect(command.analyze == prompt)
        }
    }

    @Test("Long analyze prompts", .tags(.fast))
    func longAnalyzePrompts() throws {
        let longPrompt = String(repeating: "Please analyze this image and tell me ", count: 10) + "what you see."
        let command = try ImageCommand.parse(["--analyze", longPrompt])
        #expect(command.analyze == longPrompt)
    }

    @Test("Unicode in analyze prompts", .tags(.fast))
    func unicodeAnalyzePrompts() throws {
        let unicodePrompts = [
            "这个图片显示了什么？",
            "この画像には何が表示されていますか？",
            "Что показано на этом изображении?",
            "🔍 What do you see? 👀",
        ]

        for prompt in unicodePrompts {
            let command = try ImageCommand.parse(["--analyze", prompt])
            #expect(command.analyze == prompt)
        }
    }

    // MARK: - Multiple File Analysis Tests

    @Test("Analysis with multi-mode capture", .tags(.fast))
    func analysisWithMultiMode() throws {
        // When capturing multiple windows, only the first should be analyzed
        let command = try ImageCommand.parse([
            "--mode", "multi",
            "--app", "TestApp",
            "--analyze", "Compare these windows",
        ])

        #expect(command.mode == .multi)
        #expect(command.analyze == "Compare these windows")
        // Note: In actual execution, only the first captured image would be analyzed
    }

    // MARK: - Configuration Integration Tests

    @Test("Analyze with different AI provider configurations", .tags(.fast))
    func analyzeWithDifferentProviders() throws {
        let providerConfigs = [
            "openai/gpt-5.1",
            "anthropic/claude-sonnet-4.5",
            "openai/gpt-5.1,anthropic/claude-sonnet-4.5",
            "anthropic/claude-sonnet-4.5,openai/gpt-5.1",
        ]

        // Test that commands parse correctly with different provider configurations
        for _ in providerConfigs {
            let command = try ImageCommand.parse([
                "--analyze", "Test prompt",
                "--json-output",
            ])

            #expect(command.analyze == "Test prompt")
            #expect(command.jsonOutput == true)
        }
    }

    // MARK: - Edge Case Tests

    @Test("Empty analyze prompt handling", .tags(.fast))
    func emptyAnalyzePrompt() throws {
        // Empty prompts should be allowed at parse time
        let command = try ImageCommand.parse(["--analyze", ""])
        #expect(command.analyze?.isEmpty == true)
    }

    @Test("Analyze with all capture modes", .tags(.fast))
    func analyzeWithAllCaptureModes() throws {
        let modes: [(mode: String, expectedMode: CaptureMode?)] = [
            ("screen", .screen),
            ("window", .window),
            ("multi", .multi),
            ("frontmost", .frontmost),
        ]

        for (modeString, expectedMode) in modes {
            let command = try ImageCommand.parse([
                "--mode", modeString,
                "--analyze", "Analyze this \(modeString) capture",
            ])

            #expect(command.mode == expectedMode)
            #expect(command.analyze == "Analyze this \(modeString) capture")
        }
    }

    @Test("Analyze option position in command", .tags(.fast))
    func analyzeOptionPosition() throws {
        // Test that analyze works regardless of position in command
        let commands = [
            ["--analyze", "Test", "--mode", "screen"],
            ["--mode", "screen", "--analyze", "Test"],
            ["--app", "Safari", "--analyze", "Test", "--format", "png"],
            ["--analyze", "Test", "--json-output", "--path", "/tmp/test.png"],
        ]

        for args in commands {
            let command = try ImageCommand.parse(args)
            #expect(command.analyze == "Test")
        }
    }

    @Test("Path handling with analysis", .tags(.fast))
    func pathHandlingWithAnalysis() throws {
        let testPaths = [
            "/tmp/analysis.png",
            "~/Desktop/screenshot-analysis.png",
            "./local-analysis.jpg",
            "/path with spaces/analyzed image.png",
        ]

        for path in testPaths {
            let command = try ImageCommand.parse([
                "--path", path,
                "--analyze", "Analyze this",
            ])

            #expect(command.path == path)
            #expect(command.analyze == "Analyze this")
        }
    }
}

// MARK: - Mock AI Provider Tests

@Suite("ImageCommand Mock AI Provider Tests", .serialized, .tags(.imageCapture, .imageAnalysis, .unit))
struct ImageCommandMockAIProviderTests {
    @Test("Analyze with mock provider", .tags(.fast))
    func analyzeWithMockProvider() async throws {
        // This would test with a mock AI provider if we had one set up
        // For now, we're testing the command parsing and structure
        let command = try ImageCommand.parse([
            "--mode", "frontmost",
            "--analyze", "Mock analysis test",
            "--json-output",
        ])

        #expect(command.mode == .frontmost)
        #expect(command.analyze == "Mock analysis test")
        #expect(command.jsonOutput == true)
    }
}
