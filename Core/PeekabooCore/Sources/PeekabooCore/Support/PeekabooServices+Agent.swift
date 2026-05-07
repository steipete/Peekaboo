import Darwin
import Foundation
import os.log
import PeekabooAgentRuntime
import PeekabooFoundation
import Tachikoma

extension PeekabooServices {
    /// Refresh the agent service when API keys change
    @MainActor
    public func refreshAgentService() {
        self.logger.info("🔄 Refreshing agent service with updated configuration")

        // Reload configuration to get latest API keys
        _ = self.configuration.loadConfiguration()

        // Check for available API keys
        let hasOpenAI = self.configuration.getOpenAIAPIKey() != nil && !self.configuration.getOpenAIAPIKey()!.isEmpty
        let hasAnthropic = self.configuration.getAnthropicAPIKey() != nil && !self.configuration.getAnthropicAPIKey()!
            .isEmpty
        let hasOllama = false

        if hasOpenAI || hasAnthropic || hasOllama {
            let agentConfig = self.configuration.getConfiguration()
            let providers = self.configuration.getAIProviders()
            let environmentProviders = EnvironmentVariables.value(for: "PEEKABOO_AI_PROVIDERS")

            let sources = ModelSources(
                providers: providers,
                hasOpenAI: hasOpenAI,
                hasAnthropic: hasAnthropic,
                hasOllama: hasOllama,
                configuredDefault: agentConfig?.agent?.defaultModel,
                isEnvironmentProvided: environmentProviders != nil)

            let determination = self.determineDefaultModelWithConflict(sources)
            if determination.hasConflict {
                Self.logModelConflict(determination, logger: self.logger)
            }

            self.agentLock.lock()
            defer { agentLock.unlock() }

            do {
                let languageModel = Self.parseModelStringForAgent(determination.model)
                self.agent = try PeekabooAgentService(
                    services: self,
                    defaultModel: languageModel)
            } catch {
                self.logger.error("Failed to refresh PeekabooAgentService: \(error)")
                self.agent = nil
            }
            self.logger
                .info("\(AgentDisplayTokens.Status.success) Agent service refreshed with providers: \(providers)")
        } else {
            self.agentLock.lock()
            defer { agentLock.unlock() }

            self.agent = nil
            self.logger.warning("\(AgentDisplayTokens.Status.warning) No API keys available - agent service disabled")
        }
    }

    /// Parse model string to LanguageModel enum.
    private static func parseModelStringForAgent(_ modelString: String) -> LanguageModel {
        LanguageModel.parse(from: modelString) ?? .openai(.gpt51)
    }

    private static func logModelConflict(_ determination: ModelDetermination, logger: SystemLogger) {
        logger.warning("\(AgentDisplayTokens.Status.warning) Model configuration conflict detected.")
        logger.warning("   Config file specifies: \(determination.configModel ?? "none")")
        logger.warning("   Environment variable specifies: \(determination.environmentModel ?? "none")")
        logger.warning("   Using environment variable: \(determination.model)")

        let warningMessage = """
        \(AgentDisplayTokens.Status.warning)  Model configuration conflict:
           Config (~/.peekaboo/config.json) specifies: \(determination.configModel ?? "none")
           PEEKABOO_AI_PROVIDERS environment variable specifies: \(determination.environmentModel ?? "none")
           → Using environment variable: \(determination.model)
        """
        print(warningMessage)
    }

    private func determineDefaultModelWithConflict(_ sources: ModelSources) -> ModelDetermination {
        let components = sources.providers
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let environmentModel = components.first?.split(separator: "/").last.map(String.init)

        let hasConflict = sources.isEnvironmentProvided
            && sources.configuredDefault != nil
            && sources.configuredDefault != environmentModel

        let model: String = if !sources.providers.isEmpty {
            environmentModel ?? "gpt-5.1"
        } else if let configuredDefault = sources.configuredDefault {
            configuredDefault
        } else if sources.hasAnthropic {
            "claude-sonnet-4.5"
        } else if sources.hasOpenAI {
            "gpt-5.1"
        } else if sources.hasOllama {
            "gpt-5.1"
        } else {
            "gpt-5.1"
        }

        return ModelDetermination(
            model: model,
            hasConflict: hasConflict,
            configModel: sources.configuredDefault,
            environmentModel: environmentModel)
    }
}

private enum EnvironmentVariables {
    static func value(for key: String) -> String? {
        guard let raw = getenv(key) else { return nil }
        return String(cString: raw)
    }
}

/// Result of model determination with conflict detection.
private struct ModelDetermination {
    let model: String
    let hasConflict: Bool
    let configModel: String?
    let environmentModel: String?
}

private struct ModelSources {
    let providers: String
    let hasOpenAI: Bool
    let hasAnthropic: Bool
    let hasOllama: Bool
    let configuredDefault: String?
    let isEnvironmentProvided: Bool
}
