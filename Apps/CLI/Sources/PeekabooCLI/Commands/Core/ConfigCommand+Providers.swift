import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation

private enum ConfigCommandTimeouts {
    static let network: Duration = .seconds(10)
}

enum TimeoutError: Error {
    case timedOut
}

@Sendable
func withTimeout<T: Sendable>(_ duration: Duration, operation: @escaping @Sendable () async -> T) async -> Result<T, TimeoutError> {
    await withTaskGroup(of: Result<T, TimeoutError>.self) { group in
        group.addTask {
            .success(await operation())
        }
        group.addTask {
            try? await Task.sleep(for: duration)
            return .failure(.timedOut)
        }
        let result = await group.next()!
        group.cancelAll()
        return result
    }
}

@available(macOS 14.0, *)
@MainActor
extension ConfigCommand {
    /// Add a custom AI provider.
    struct AddProviderCommand: ConfigRuntimeCommand {
        static let commandDescription = CommandDescription(
            commandName: "add-provider",
            abstract: "Add a custom AI provider",
            discussion: """
            Add a custom AI provider to your Peekaboo configuration.

            This allows you to connect to OpenAI-compatible or Anthropic-compatible
            endpoints beyond the built-in providers.

            Examples:

            # Add OpenRouter
            peekaboo config add-provider openrouter \\
              --type openai \\
              --name "OpenRouter" \\
              --base-url "https://openrouter.ai/api/v1" \\
              --api-key "{env:OPENROUTER_API_KEY}" \\
              --description "Access to 300+ models via OpenRouter"

            # Add local Ollama with authentication
            peekaboo config add-provider local-ollama \\
              --type openai \\
              --name "Local Ollama" \\
              --base-url "http://localhost:11434/v1" \\
              --api-key "dummy-key"

            # Add Groq
            peekaboo config add-provider groq \\
              --type openai \\
              --name "Groq" \\
              --base-url "https://api.groq.com/openai/v1" \\
              --api-key "{env:GROQ_API_KEY}"
            """
        )

        @Argument(help: "Unique identifier for the provider (letters, numbers, hyphens only)")
        var providerId: String

        @Option(name: .long, help: "Provider type (openai or anthropic)")
        var type: String

        @Option(name: .long, help: "Human-readable name for the provider")
        var name: String

        @Option(name: .long, help: "Base URL for the API endpoint")
        var baseUrl: String

        @Option(name: .long, help: "API key or credential reference (e.g., {env:API_KEY})")
        var apiKey: String

        @Option(name: .long, help: "Optional description of the provider")
        var description: String?

        @Option(name: .long, help: "Additional HTTP headers (key:value,key:value)")
        var headers: String?

        @Flag(name: .long, help: "Overwrite existing provider with same ID")
        var force: Bool = false

        @Flag(name: .long, help: "Show the change without writing to disk")
        var dryRun: Bool = false

        @RuntimeStorage var runtime: CommandRuntime?

        enum HeaderParseError: LocalizedError {
            case invalidPair(String)
            case emptyKey(String)

            var errorDescription: String? {
                switch self {
                case .invalidPair(let pair):
                    return "Invalid header entry '\(pair)'. Use key:value pairs separated by commas."
                case .emptyKey(let pair):
                    return "Header key is empty in entry '\(pair)'."
                }
            }
        }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.prepare(using: runtime)

            guard Self.isValidProviderId(self.providerId) else {
                self.emitError(
                    code: "INVALID_ID",
                    message: "Provider ID must contain only letters, numbers, hyphens, and underscores"
                )
                throw ExitCode.failure
            }

            guard let providerType = Configuration.CustomProvider.ProviderType(rawValue: self.type) else {
                self.emitError(
                    code: "INVALID_TYPE",
                    message: "Invalid provider type '\(self.type)'. Must be 'openai' or 'anthropic'."
                )
                throw ExitCode.failure
            }

            guard !self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.emitError(
                    code: "INVALID_NAME",
                    message: "Provider name must not be empty"
                )
                throw ExitCode.failure
            }

            guard let validatedBaseURL = Self.validatedURL(self.baseUrl) else {
                self.emitError(
                    code: "INVALID_URL",
                    message: "Base URL must include scheme and host (e.g., https://api.example.com)"
                )
                throw ExitCode.failure
            }

            guard !self.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.emitError(
                    code: "INVALID_API_KEY",
                    message: "API key must not be empty"
                )
                throw ExitCode.failure
            }

            let manager = self.configManager
            if manager.getCustomProvider(id: self.providerId) != nil, !self.force {
                self.emitError(
                    code: "PROVIDER_EXISTS",
                    message: "Provider '\(self.providerId)' already exists. Use --force to overwrite."
                )
                throw ExitCode.failure
            }

            let headerDict: [String: String]?
            do {
                headerDict = try Self.parseHeaders(self.headers)
            } catch {
                self.emitError(code: "INVALID_HEADERS", message: error.localizedDescription)
                throw ExitCode.failure
            }

            let options = Configuration.ProviderOptions(
                baseURL: validatedBaseURL,
                apiKey: self.apiKey,
                headers: headerDict
            )

            let provider = Configuration.CustomProvider(
                name: self.name,
                description: self.description,
                type: providerType,
                options: options,
                models: nil,
                enabled: true
            )

            if self.dryRun {
                self.emitDryRunSummary(provider: provider, providerId: self.providerId)
                return
            }

            do {
                try manager.addCustomProvider(provider, id: self.providerId)

                if self.jsonOutput {
                    let successOutput = SuccessOutput(
                        success: true,
                        data: [
                            "providerId": providerId,
                            "name": name,
                            "type": type,
                            "baseUrl": baseUrl
                        ]
                    )
                    outputJSON(successOutput, logger: self.logger)
                } else {
                    print("[ok] Added custom provider '\(self.providerId)' (\(self.name))")
                    print("   Type: \(self.type)")
                    print("   Base URL: \(self.baseUrl)")
                    if let description {
                        print("   Description: \(description)")
                    }
                    print("\nTip: Test the connection with: peekaboo config test-provider \(self.providerId)")
                }
            } catch {
                self.emitError(
                    code: "ADD_FAILED",
                    message: "Failed to add provider: \(error.localizedDescription)"
                )
                throw ExitCode.failure
            }
        }

        static func isValidProviderId(_ id: String) -> Bool {
            let pattern = "^[a-zA-Z0-9-_]+$"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            let range = NSRange(location: 0, length: id.utf16.count)
            return regex.firstMatch(in: id, options: [], range: range) != nil
        }

        static func parseHeaders(_ rawHeaders: String?) throws -> [String: String]? {
            guard let rawHeaders, !rawHeaders.isEmpty else { return nil }

            var headerDict: [String: String] = [:]
            for pair in rawHeaders.split(separator: ",") {
                let entry = String(pair)
                let components = entry.split(separator: ":", maxSplits: 1)
                guard components.count == 2 else {
                    throw HeaderParseError.invalidPair(entry)
                }

                let key = components[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let value = components[1].trimmingCharacters(in: .whitespacesAndNewlines)

                guard !key.isEmpty else {
                    throw HeaderParseError.emptyKey(entry)
                }
                headerDict[key] = value
            }
            return headerDict
        }

        static func validatedURL(_ value: String) -> String? {
            guard let components = URLComponents(string: value),
                  let scheme = components.scheme,
                  !scheme.isEmpty,
                  components.host != nil
            else { return nil }
            return components.string
        }

        private func emitError(code: String, message: String) {
            if self.jsonOutput {
                let errorOutput = ErrorOutput(error: true, code: code, message: message, details: nil)
                outputJSON(errorOutput, logger: self.logger)
            } else {
                print("[error] \(message)")
            }
        }

        private func emitDryRunSummary(provider: Configuration.CustomProvider, providerId: String) {
            let summary = [
                "providerId": providerId,
                "type": provider.type.rawValue,
                "baseUrl": provider.options.baseURL,
                "apiKey": provider.options.apiKey
            ]

            if self.jsonOutput {
                let output = SuccessOutput(success: true, data: [
                    "message": "Dry run - no changes written",
                    "provider": summary
                ])
                outputJSON(output, logger: self.logger)
            } else {
                print("[dry-run] Would add provider '\(providerId)' (\(provider.name))")
                print("   Type: \(provider.type.rawValue)")
                print("   Base URL: \(provider.options.baseURL)")
                if let description = provider.description {
                    print("   Description: \(description)")
                }
            }
        }
    }

    /// List configured custom AI providers.
    struct ListProvidersCommand: ConfigRuntimeCommand {
        static let commandDescription = CommandDescription(
            commandName: "list-providers",
            abstract: "List configured custom AI providers",
            discussion: """
            Display all custom AI providers configured in Peekaboo.

            This shows providers you've added with 'peekaboo config add-provider',
            not the built-in providers (openai, anthropic, ollama).
            """
        )

        @RuntimeStorage var runtime: CommandRuntime?

        mutating func run(using runtime: CommandRuntime) async throws {
            self.prepare(using: runtime)

            let customProviders = self.configManager.listCustomProviders()

            if self.jsonOutput {
                let data: [String: Any] = [
                    "providers": customProviders.mapValues { provider in
                        [
                            "name": provider.name,
                            "description": provider.description ?? "",
                            "type": provider.type.rawValue,
                            "baseUrl": provider.options.baseURL,
                            "enabled": provider.enabled,
                            "modelCount": provider.models?.count ?? 0
                        ]
                    }
                ]
                let output = SuccessOutput(success: true, data: data)
                outputJSON(output, logger: self.logger)
                return
            }

            guard !customProviders.isEmpty else {
                print("No custom providers configured.")
                print("Add one with: peekaboo config add-provider <id> --type <type>")
                print("  --name <name> --base-url <url> --api-key <key>")
                return
            }

            print("Custom AI Providers:")
            print()

            for (id, provider) in customProviders.sorted(by: { $0.key < $1.key }) {
                let status = provider.enabled ? "[ok]" : "[disabled]"
                print("  \(status) \(id) (\(provider.name))")
                print("     Type: \(provider.type.rawValue)")
                print("     URL: \(provider.options.baseURL)")
                if let description = provider.description {
                    print("     Description: \(description)")
                }
                if let models = provider.models {
                    print("     Models: \(models.count) configured")
                }
                print()
            }

            print("Tip: Test a provider with: peekaboo config test-provider <id>")
            print("Tip: Remove a provider with: peekaboo config remove-provider <id>")
        }
    }

    /// Test a custom AI provider connection.
    struct TestProviderCommand: ConfigRuntimeCommand {
        static let commandDescription = CommandDescription(
            commandName: "test-provider",
            abstract: "Test connection to a custom AI provider",
            discussion: """
            Test the connection to a custom AI provider by making a simple API call.

            This verifies that:
            • The base URL is accessible
            • The API key is valid
            • The endpoint responds correctly

            For OpenAI-compatible providers, this calls the /models endpoint.
            For Anthropic-compatible providers, this makes a simple message request.
            """
        )

        @Argument(help: "Provider ID to test")
        var providerId: String

        @RuntimeStorage var runtime: CommandRuntime?

        mutating func run(using runtime: CommandRuntime) async throws {
            self.prepare(using: runtime)

            let manager = self.configManager
            let providerId = self.providerId
            let result: Result<(Bool, String?), TimeoutError> = await withTimeout(
                ConfigCommandTimeouts.network
            ) {
                await manager.testCustomProvider(id: providerId)
            }

            let success: Bool
            let error: String?

            switch result {
            case .failure:
                success = false
                error = "Connection test timed out"
            case .success(let value):
                success = value.0
                error = value.1
            }

            if self.jsonOutput {
                if success {
                    let successOutput = SuccessOutput(
                        success: true,
                        data: [
                            "providerId": providerId,
                            "connectionStatus": "successful"
                        ]
                    )
                    outputJSON(successOutput, logger: self.logger)
                } else {
                    let errorOutput = ErrorOutput(
                        error: true,
                        code: "CONNECTION_FAILED",
                        message: error ?? "Connection test failed",
                        details: nil
                    )
                    outputJSON(errorOutput, logger: self.logger)
                }
            } else {
                if success {
                    print("[ok] Connection to '\(self.providerId)' successful!")
                } else {
                    print("[error] Connection to '\(self.providerId)' failed: \(error ?? "Unknown error")")
                }
            }

            if !success {
                throw ExitCode.failure
            }
        }
    }

    /// Remove a custom AI provider.
    struct RemoveProviderCommand: ConfigRuntimeCommand {
        static let commandDescription = CommandDescription(
            commandName: "remove-provider",
            abstract: "Remove a custom AI provider",
            discussion: """
            Remove a custom AI provider from your Peekaboo configuration.

            This only removes providers you've added with 'peekaboo config add-provider'.
            Built-in providers (openai, anthropic, ollama) cannot be removed.
            """
        )

        @Argument(help: "Provider ID to remove")
        var providerId: String

        @Flag(name: .long, help: "Skip confirmation prompt")
        var force: Bool = false

        @Flag(name: .long, help: "Show planned removal without writing to disk")
        var dryRun: Bool = false

        @RuntimeStorage var runtime: CommandRuntime?

        mutating func run(using runtime: CommandRuntime) async throws {
            self.prepare(using: runtime)

            guard let provider = self.configManager.getCustomProvider(id: self.providerId) else {
                self.emitNotFoundError()
                throw ExitCode.failure
            }

            if !self.force && !self.jsonOutput {
                print(
                    "Are you sure you want to remove provider '\(self.providerId)' (\(provider.name))? [y/N]: ",
                    terminator: ""
                )
                let response = readLine()?.lowercased()
                if response != "y" && response != "yes" {
                    print("Cancelled.")
                    return
                }
            }

            if self.dryRun {
                self.emitDryRun(provider: provider)
                return
            }

            do {
                try self.configManager.removeCustomProvider(id: self.providerId)

                if self.jsonOutput {
                    let successOutput = SuccessOutput(
                        success: true,
                        data: [
                            "providerId": providerId,
                            "action": "removed"
                        ]
                    )
                    outputJSON(successOutput, logger: self.logger)
                } else {
                    print("[ok] Removed custom provider '\(self.providerId)'")
                }
            } catch {
                self.emitError(
                    code: "REMOVE_FAILED",
                    message: "Failed to remove provider: \(error.localizedDescription)"
                )
                throw ExitCode.failure
            }
        }

        private func emitNotFoundError() {
            if self.jsonOutput {
                let errorOutput = ErrorOutput(
                    error: true,
                    code: "PROVIDER_NOT_FOUND",
                    message: "Provider '\(providerId)' not found",
                    details: nil
                )
                outputJSON(errorOutput, logger: self.logger)
            } else {
                print("[error] Provider '\(self.providerId)' not found")
            }
        }

        private func emitError(code: String, message: String) {
            if self.jsonOutput {
                let errorOutput = ErrorOutput(error: true, code: code, message: message, details: nil)
                outputJSON(errorOutput, logger: self.logger)
            } else {
                print("[error] \(message)")
            }
        }

        private func emitDryRun(provider: Configuration.CustomProvider) {
            if self.jsonOutput {
                let output = SuccessOutput(success: true, data: [
                    "message": "Dry run - no changes written",
                    "providerId": self.providerId,
                    "action": "remove"
                ])
                outputJSON(output, logger: self.logger)
            } else {
                print("[dry-run] Would remove provider '\(self.providerId)' (\(provider.name))")
            }
        }
    }

    /// Discover or list models for a custom AI provider.
    struct ModelsProviderCommand: ConfigRuntimeCommand {
        static let commandDescription = CommandDescription(
            commandName: "models-provider",
            abstract: "List available models from a custom AI provider",
            discussion: """
            Discover and list available models from a custom AI provider.

            For OpenAI-compatible providers, this queries the /models endpoint.
            For Anthropic-compatible providers, this shows configured models
            since Anthropic doesn't have a public models endpoint.
            """
        )

        @Argument(help: "Provider ID to query")
        var providerId: String

        @Flag(name: .long, help: "Discover models from API (for OpenAI-compatible providers)")
        var discover: Bool = false

        @Flag(name: .long, help: "Persist discovered (or configured) models back into configuration")
        var save: Bool = false

        @RuntimeStorage var runtime: CommandRuntime?

        mutating func run(using runtime: CommandRuntime) async throws {
            self.prepare(using: runtime)

            guard let provider = self.configManager.getCustomProvider(id: providerId) else {
                self.emitNotFoundError()
                throw ExitCode.failure
            }

            let manager = self.configManager
            let providerId = self.providerId
            let modelResult: Result<(models: [String], error: String?), TimeoutError> = await withTimeout(
                ConfigCommandTimeouts.network
            ) {
                await manager.discoverModelsForCustomProvider(id: providerId)
            }

            let models: [String]
            let apiError: String?

            switch modelResult {
            case .failure:
                models = []
                apiError = "Model discovery timed out"
            case .success(let tuple):
                if self.discover && provider.type == .openai {
                    models = tuple.models
                    apiError = tuple.error
                } else {
                    models = provider.models?.keys.map { String($0) } ?? []
                    apiError = tuple.error
                }
            }

            if self.jsonOutput {
                let data: [String: Any] = [
                    "providerId": providerId,
                    "models": models,
                    "source": discover && provider.type == .openai ? "api" : "configuration",
                    "error": apiError as Any
                ]
                let output = SuccessOutput(success: apiError == nil, data: data)
                outputJSON(output, logger: self.logger)
                return
            }

            if let error = apiError {
                print("[error] Failed to discover models: \(error)")
                if !models.isEmpty {
                    print("Showing configured models instead:")
                }
            }

            if models.isEmpty {
                if provider.type == .openai && !self.discover {
                    print("No configured models. Try --discover to query the API.")
                } else {
                    print("No models available.")
                }
            } else {
                print("Models for provider '\(self.providerId)' (\(provider.name)):")
                print()
                for model in models.sorted() {
                    print("  • \(model)")
                }
                print()
                print("Found \(models.count) model(s)")

                if provider.type == .openai && !self.discover {
                    print("Tip: Use --discover to query the API for all available models")
                }
            }

            if self.save, apiError == nil {
                try self.saveModels(models, for: providerId, existing: provider)
            }
        }

        private func emitNotFoundError() {
            if self.jsonOutput {
                let errorOutput = ErrorOutput(
                    error: true,
                    code: "PROVIDER_NOT_FOUND",
                    message: "Provider '\(providerId)' not found",
                    details: nil
                )
                outputJSON(errorOutput, logger: self.logger)
            } else {
                print("[error] Provider '\(self.providerId)' not found")
            }
        }

        private func saveModels(_ models: [String], for providerId: String, existing provider: Configuration.CustomProvider) throws {
            let modelDefinitions = Dictionary(
                uniqueKeysWithValues: models.map { ($0, Configuration.ModelDefinition(name: $0)) }
            )
            let updated = Configuration.CustomProvider(
                name: provider.name,
                description: provider.description,
                type: provider.type,
                options: provider.options,
                models: modelDefinitions,
                enabled: provider.enabled
            )
            try self.configManager.addCustomProvider(updated, id: providerId)
            print("[ok] Saved \(models.count) model(s) to configuration")
        }
    }
}
