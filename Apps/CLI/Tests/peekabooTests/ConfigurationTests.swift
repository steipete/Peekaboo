import Foundation
import Testing
@testable import peekaboo

@Suite("Configuration Tests", .tags(.unit))
struct ConfigurationTests {
    // MARK: - JSONC Parser Tests

    @Test("Strip single-line comments from JSONC", .tags(.fast))
    func stripSingleLineComments() throws {
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
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(parsed["key"] as? String == "value")
        #expect(parsed["number"] as? Int == 42)
    }

    @Test("Strip multi-line comments from JSONC", .tags(.fast))
    func stripMultiLineComments() throws {
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
        let data = result.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(parsed["key"] as? String == "value")
        #expect(parsed["number"] as? Int == 42)
    }

    @Test("Preserve comments inside strings", .tags(.fast))
    func preserveCommentsInStrings() throws {
        let manager = ConfigurationManager.shared

        let jsonc = """
        {
            "url": "http://example.com//path",
            "comment": "This // is not a comment",
            "multiline": "This /* is also */ not a comment"
        }
        """

        let result = manager.stripJSONComments(from: jsonc)
        let data = result.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(parsed["url"] as? String == "http://example.com//path")
        #expect(parsed["comment"] as? String == "This // is not a comment")
        #expect(parsed["multiline"] as? String == "This /* is also */ not a comment")
    }

    // MARK: - Environment Variable Expansion Tests

    @Test("Expand environment variables", .tags(.fast))
    func expandEnvironmentVariables() throws {
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

    @Test("Configuration value precedence", .tags(.fast))
    func configurationPrecedence() {
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

    @Test("Parse valid configuration", .tags(.fast))
    func parseValidConfiguration() throws {
        let json = """
        {
            "aiProviders": {
                "providers": "openai/gpt-4o,ollama/llava:latest",
                "openaiApiKey": "test_key",
                "ollamaBaseUrl": "http://localhost:11434"
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

        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(Configuration.self, from: data)

        #expect(config.aiProviders?.providers == "openai/gpt-4o,ollama/llava:latest")
        #expect(config.aiProviders?.openaiApiKey == "test_key")
        #expect(config.aiProviders?.ollamaBaseUrl == "http://localhost:11434")

        #expect(config.defaults?.savePath == "~/Desktop/Screenshots")
        #expect(config.defaults?.imageFormat == "png")
        #expect(config.defaults?.captureMode == "window")
        #expect(config.defaults?.captureFocus == "auto")

        #expect(config.logging?.level == "debug")
        #expect(config.logging?.path == "/tmp/peekaboo.log")
    }

    @Test("Parse partial configuration", .tags(.fast))
    func parsePartialConfiguration() throws {
        let json = """
        {
            "aiProviders": {
                "providers": "ollama/llava:latest"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(Configuration.self, from: data)

        #expect(config.aiProviders?.providers == "ollama/llava:latest")
        #expect(config.aiProviders?.openaiApiKey == nil)
        #expect(config.defaults == nil)
        #expect(config.logging == nil)
    }

    // MARK: - Path Expansion Tests

    @Test("Expand tilde in paths", .tags(.fast))
    func expandTildeInPaths() {
        let manager = ConfigurationManager.shared

        let path = manager.getDefaultSavePath(cliValue: "~/Desktop/Screenshots")
        #expect(path.hasPrefix("/"))
        #expect(!path.contains("~"))
        #expect(path.contains("Desktop/Screenshots"))
    }

    // MARK: - Integration Tests

    @Test("Get AI providers with configuration", .tags(.fast))
    func getAIProvidersWithConfig() {
        let manager = ConfigurationManager.shared

        // Test default value
        let defaultProviders = manager.getAIProviders(cliValue: nil)
        #expect(defaultProviders == "openai/gpt-5,ollama/llava:latest,anthropic/claude-opus-4-20250514")

        // Test with CLI value
        let cliProviders = manager.getAIProviders(cliValue: "openai/gpt-4o")
        #expect(cliProviders == "openai/gpt-4o")

        // Test with environment variable
        setenv("PEEKABOO_AI_PROVIDERS", "env_provider", 1)
        let envProviders = manager.getAIProviders(cliValue: nil)
        #expect(envProviders == "env_provider")
        unsetenv("PEEKABOO_AI_PROVIDERS")
    }

    @Test("Get OpenAI API key with configuration", .tags(.fast))
    func getOpenAIAPIKeyWithConfig() {
        let manager = ConfigurationManager.shared

        // Save current API key if it exists
        let originalKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        unsetenv("OPENAI_API_KEY")

        // Test default (nil)
        let defaultKey = manager.getOpenAIAPIKey()
        #expect(defaultKey == nil)

        // Test with environment variable
        setenv("OPENAI_API_KEY", "test_api_key", 1)
        let envKey = manager.getOpenAIAPIKey()
        #expect(envKey == "test_api_key")

        // Restore original key
        if let originalKey {
            setenv("OPENAI_API_KEY", originalKey, 1)
        } else {
            unsetenv("OPENAI_API_KEY")
        }
    }

    @Test("Get Ollama base URL with configuration", .tags(.fast))
    func getOllamaBaseURLWithConfig() {
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
