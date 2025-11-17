import Foundation
import PeekabooCore

@available(macOS 14.0, *)
@MainActor
struct ProviderStatusReporter {
    private let timeoutSeconds: Double
    private let manager = ConfigurationManager.shared

    init(timeoutSeconds: Double) {
        self.timeoutSeconds = timeoutSeconds > 0 ? timeoutSeconds : 30
    }

    func printSummary() async {
        let providers: [ProviderId] = [.openai, .anthropic, .grok, .gemini]
        print("Providers:")
        for provider in providers {
            let status = await self.status(for: provider)
            print("  \(provider.displayName): \(status)")
        }
    }

    private func status(for provider: ProviderId) async -> String {
        switch self.source(for: provider) {
        case let .env(key):
            let validation = await self.validate(provider: provider, secret: self.envValue(key: key) ?? "")
            return self.describe(source: "env \(key)", validation: validation)
        case let .credentials(key, value):
            let validation = await self.validate(provider: provider, secret: value)
            return self.describe(source: "credentials \(key)", validation: validation)
        case let .oauth(prefix, access):
            let validation = await self.validate(provider: provider, secret: access)
            return self.describe(source: "oauth \(prefix)", validation: validation)
        case .missing:
            return "missing"
        }
    }

    private func describe(source: String, validation: ValidationResult) -> String {
        switch validation {
        case .success:
            return "ready (\(source), validated)"
        case let .failure(reason):
            return "stored (\(source), validation failed: \(reason))"
        case let .timeout(seconds):
            return "stored (\(source), validation timed out after \(Int(seconds))s)"
        }
    }

    private func source(for provider: ProviderId) -> ProviderSource {
        switch provider {
        case .openai:
            if let key = self.envValue(key: "OPENAI_API_KEY") {
                return .env("OPENAI_API_KEY")
            }
            if let access = self.manager.credentialValue(for: "OPENAI_ACCESS_TOKEN") {
                return .oauth("OPENAI", access)
            }
            if let key = self.manager.credentialValue(for: "OPENAI_API_KEY") {
                return .credentials("OPENAI_API_KEY", key)
            }
        case .anthropic:
            if let key = self.envValue(key: "ANTHROPIC_API_KEY") {
                return .env("ANTHROPIC_API_KEY")
            }
            if let access = self.manager.credentialValue(for: "ANTHROPIC_ACCESS_TOKEN") {
                return .oauth("ANTHROPIC", access)
            }
            if let key = self.manager.credentialValue(for: "ANTHROPIC_API_KEY") {
                return .credentials("ANTHROPIC_API_KEY", key)
            }
        case .grok:
            let envKeys = ["GROK_API_KEY", "X_AI_API_KEY", "XAI_API_KEY"]
            for envKey in envKeys {
                if let _ = self.envValue(key: envKey) {
                    return .env(envKey)
                }
            }
            let credKeys = ["GROK_API_KEY", "X_AI_API_KEY", "XAI_API_KEY"]
            for cred in credKeys {
                if let val = self.manager.credentialValue(for: cred) {
                    return .credentials(cred, val)
                }
            }
        case .gemini:
            if let key = self.envValue(key: "GEMINI_API_KEY") {
                return .env("GEMINI_API_KEY")
            }
            if let key = self.manager.credentialValue(for: "GEMINI_API_KEY") {
                return .credentials("GEMINI_API_KEY", key)
            }
        }
        return .missing
    }

    private func envValue(key: String) -> String? {
        ProcessInfo.processInfo.environment[key]
    }

    private func validate(provider: ProviderId, secret: String) async -> ValidationResult {
        let validator = ProviderValidator(timeoutSeconds: self.timeoutSeconds)
        return await validator.validate(provider: provider, secret: secret)
    }
}

private enum ProviderSource {
    case env(String)
    case credentials(String, String)
    case oauth(String, String)
    case missing
}
