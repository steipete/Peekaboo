import Foundation
import Testing
@testable import PeekabooAutomation

struct PeekabooAIServiceProviderTests {
    @Test
    @MainActor
    func `Resolves custom provider entries from config`() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("peekaboo-config-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let configPath = tempDir.appendingPathComponent("config.json")
        try """
        {
          "aiProviders": { "providers": "local-proxy/mini" },
          "customProviders": {
            "local-proxy": {
              "name": "Local Proxy",
              "type": "openai",
              "enabled": true,
              "options": {
                "baseURL": "http://localhost:8317/v1",
                "apiKey": "dummy-not-used"
              },
              "models": {
                "mini": {
                  "name": "gpt-5.4-mini",
                  "supportsVision": true
                }
              }
            }
          }
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
        let model = try #require(service.availableModels().first)
        #expect(service.availableModels().count == 1)
        #expect(model.modelId == "local-proxy/gpt-5.4-mini")
        #expect(model.supportsVision)
    }
}
