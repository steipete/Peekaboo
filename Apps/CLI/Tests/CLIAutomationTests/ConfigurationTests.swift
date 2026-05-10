import Foundation
import Testing
@testable import PeekabooCLI

@Suite(.tags(.unit), .serialized)
struct ConfigurationTests {
    // MARK: - JSONC Parser Tests

    @Test(.tags(.fast))
    func `Strip single-line comments from JSONC`() throws {
        let manager = ConfigurationManager.shared

        let jsonc = """
        {
            // This is a comment
            "key": "value", // Another comment
            "number": 42
        }
        """

        let result = manager.stripJSONComments(from: jsonc)
        let data = Data(result.utf8)
        let parsed = try Self.decodedDictionary(from: data)

        #expect(parsed["key"] as? String == "value")
        #expect(parsed["number"] as? Int == 42)
    }

    @Test(.tags(.fast))
    func `Strip multi-line comments from JSONC`() throws {
        let manager = ConfigurationManager.shared

        let jsonc = """
        {
            /* This is a
               multi-line comment */
            "key": "value",
            /* Another
               comment */ "number": 42
        }
        """

        let result = manager.stripJSONComments(from: jsonc)
        let data = Data(result.utf8)
        let parsed = try Self.decodedDictionary(from: data)

        #expect(parsed["key"] as? String == "value")
        #expect(parsed["number"] as? Int == 42)
    }

    @Test(.tags(.fast))
    func `Preserve comments inside strings`() throws {
        let manager = ConfigurationManager.shared

        let jsonc = """
        {
            "url": "http://example.com//path",
            "comment": "This // is not a comment",
            "multiline": "This /* is also */ not a comment"
        }
        """

        let result = manager.stripJSONComments(from: jsonc)
        let data = Data(result.utf8)
        let parsed = try Self.decodedDictionary(from: data)

        #expect(parsed["url"] as? String == "http://example.com//path")
        #expect(parsed["comment"] as? String == "This // is not a comment")
        #expect(parsed["multiline"] as? String == "This /* is also */ not a comment")
    }

    // MARK: - Environment Variable Expansion Tests

    @Test(.tags(.fast))
    func `Expand environment variables`() {
        let manager = ConfigurationManager.shared

        // Set test environment variables
        setenv("TEST_VAR", "test_value", 1)
        setenv("ANOTHER_VAR", "another_value", 1)

        let text = """
        {
            "key1": "${TEST_VAR}",
            "key2": "prefix_${ANOTHER_VAR}_suffix",
            "key3": "${UNDEFINED_VAR}"
        }
        """

        let result = manager.expandEnvironmentVariables(in: text)

        #expect(result.contains("\"test_value\""))
        #expect(result.contains("prefix_another_value_suffix"))
        let containsUndefinedVar = result.contains("${UNDEFINED_VAR}")
        #expect(containsUndefinedVar) // Undefined vars should remain as-is

        // Clean up
        unsetenv("TEST_VAR")
        unsetenv("ANOTHER_VAR")
    }

    // MARK: - Configuration Value Precedence Tests

    @Test(.tags(.fast))
    func `Configuration value precedence`() {
        let manager = ConfigurationManager.shared

        // Test precedence: CLI > env > config > default

        // CLI value takes highest precedence
        let cliResult = manager.getValue(
            cliValue: "cli_value",
            envVar: nil,
            configValue: "config_value",
            defaultValue: "default_value"
        )
        #expect(cliResult == "cli_value")

        // Environment variable takes second precedence
        setenv("TEST_ENV_VAR", "env_value", 1)
        let envResult = manager.getValue(
            cliValue: nil as String?,
            envVar: "TEST_ENV_VAR",
            configValue: "config_value",
            defaultValue: "default_value"
        )
        #expect(envResult == "env_value")
        unsetenv("TEST_ENV_VAR")

        // Config value takes third precedence
        let configResult = manager.getValue(
            cliValue: nil as String?,
            envVar: "UNDEFINED_VAR",
            configValue: "config_value",
            defaultValue: "default_value"
        )
        #expect(configResult == "config_value")

        // Default value as fallback
        let defaultResult = manager.getValue(
            cliValue: nil as String?,
            envVar: "UNDEFINED_VAR",
            configValue: nil as String?,
            defaultValue: "default_value"
        )
        #expect(defaultResult == "default_value")
    }

    // MARK: - Configuration Loading Tests

    @Test(.tags(.fast))
    func `Parse valid configuration`() throws {
        let json = """
        {
            "aiProviders": {
                "providers": "openai/gpt-5.5,anthropic/claude-opus-4-7",
                "openaiApiKey": "test_key",
                "anthropicApiKey": "test_claude_key"
            },
            "defaults": {
                "savePath": "~/Desktop/Screenshots",
                "imageFormat": "png",
                "captureMode": "window",
                "captureFocus": "auto"
            },
            "logging": {
                "level": "debug",
                "path": "/tmp/peekaboo.log"
            }
        }
        """

        let data = Data(json.utf8)
        let config = try JSONDecoder().decode(Configuration.self, from: data)

        #expect(config.aiProviders?.providers == "openai/gpt-5.5,anthropic/claude-opus-4-7")
        #expect(config.aiProviders?.openaiApiKey == "test_key")
        #expect(config.aiProviders?.anthropicApiKey == "test_claude_key")

        #expect(config.defaults?.savePath == "~/Desktop/Screenshots")
        #expect(config.defaults?.imageFormat == "png")
        #expect(config.defaults?.captureMode == "window")
        #expect(config.defaults?.captureFocus == "auto")

        #expect(config.logging?.level == "debug")
        #expect(config.logging?.path == "/tmp/peekaboo.log")
    }

    @Test(.tags(.fast))
    func `Parse partial configuration`() throws {
        let json = """
        {
            "aiProviders": {
                "providers": "anthropic/claude-opus-4-7"
            }
        }
        """

        let data = Data(json.utf8)
        let config = try JSONDecoder().decode(Configuration.self, from: data)

        #expect(config.aiProviders?.providers == "anthropic/claude-opus-4-7")
        #expect(config.aiProviders?.openaiApiKey == nil)
        #expect(config.defaults == nil)
        #expect(config.logging == nil)
    }

    // MARK: - Path Expansion Tests

    @Test(.tags(.fast))
    func `Expand tilde in paths`() {
        let manager = ConfigurationManager.shared

        let path = manager.getDefaultSavePath(cliValue: "~/Desktop/Screenshots")
        #expect(path.hasPrefix("/"))
        #expect(!path.contains("~"))
        #expect(path.contains("Desktop/Screenshots"))
    }

    // MARK: - Integration Tests

    @Test(.tags(.fast))
    func `Get AI providers with configuration`() {
        let manager = ConfigurationManager.shared

        // Capture baseline (may include persisted user configuration)
        let baselineProviders = manager.getAIProviders(cliValue: nil)
        #expect(!baselineProviders.isEmpty)

        // Test with CLI value
        let cliProviders = manager.getAIProviders(cliValue: "openai/gpt-5.5")
        #expect(cliProviders == "openai/gpt-5.5")

        // Test with environment variable
        setenv("PEEKABOO_AI_PROVIDERS", "env_provider", 1)
        let envProviders = manager.getAIProviders(cliValue: nil)
        #expect(envProviders == "env_provider")
        unsetenv("PEEKABOO_AI_PROVIDERS")

        // After clearing env override, manager should return to baseline
        let restoredProviders = manager.getAIProviders(cliValue: nil)
        #expect(restoredProviders == baselineProviders)
    }

    @Test(.tags(.fast))
    func `Get OpenAI API key with configuration`() {
        let manager = ConfigurationManager.shared

        // Capture baseline (may come from credentials)
        let baselineKey = manager.getOpenAIAPIKey()

        setenv("OPENAI_API_KEY", "test_api_key", 1)
        let envKey = manager.getOpenAIAPIKey()
        #expect(envKey == "test_api_key")

        // Restore environment
        if let baselineKey {
            setenv("OPENAI_API_KEY", baselineKey, 1)
        } else {
            unsetenv("OPENAI_API_KEY")
        }

        let restoredKey = manager.getOpenAIAPIKey()
        #expect(restoredKey == baselineKey)
    }

    @Test(.tags(.fast))
    func `Get Ollama base URL with configuration`() {
        let manager = ConfigurationManager.shared

        // Test default value
        let defaultURL = manager.getOllamaBaseURL()
        #expect(defaultURL == "http://localhost:11434")

        // Test with environment variable
        setenv("PEEKABOO_OLLAMA_BASE_URL", "http://custom:11434", 1)
        let envURL = manager.getOllamaBaseURL()
        #expect(envURL == "http://custom:11434")
        unsetenv("PEEKABOO_OLLAMA_BASE_URL")
    }
}

extension ConfigurationTests {
    fileprivate static func decodedDictionary(from data: Data) throws -> [String: Any] {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = json as? [String: Any] else {
            throw ConfigurationTestsError.invalidJSON
        }
        return dictionary
    }
}

private enum ConfigurationTestsError: Error {
    case invalidJSON
}
