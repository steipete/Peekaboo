import AppKit
import Commander
import CryptoKit
import Foundation
import PeekabooCore
import PeekabooFoundation

@available(macOS 14.0, *)
@MainActor
extension ConfigCommand {
    struct AddCommand: ConfigRuntimeCommand {
        static let commandDescription = CommandDescription(
            commandName: "add",
            abstract: "Add and validate a provider credential (API key)"
        )

        @Argument(help: "Provider id (openai|anthropic|grok|xai|gemini)")
        var provider: String

        @Argument(help: "Secret value (API key)")
        var secret: String

        @Option(name: .long, help: "Validation timeout in seconds (default 30)")
        var timeoutSeconds: Double = 30

        @RuntimeStorage var runtime: CommandRuntime?

        mutating func run(using runtime: CommandRuntime) async throws {
            self.prepare(using: runtime)
            let normalized = ProviderId.normalize(self.provider)
            guard let providerId = normalized else {
                self.output.error(
                    code: "INVALID_PROVIDER",
                    message: "Supported providers: openai, anthropic, grok, xai, gemini"
                )
                throw ExitCode.failure
            }

            let timeout = self.timeoutSeconds > 0 ? self.timeoutSeconds : 30
            let validator = ProviderValidator(timeoutSeconds: timeout)
            let result = await validator.validate(provider: providerId, secret: self.secret)

            do {
                try self.configManager.setCredential(key: providerId.credentialKey, value: self.secret)
            } catch {
                self.output.error(code: "FILE_IO_ERROR", message: "Failed to store credential: \(error)")
                throw ExitCode.failure
            }

            switch result {
            case .success:
                self.output.success(message: "[ok] Stored and validated \(providerId.displayName) credential")
            case let .failure(reason):
                self.output.error(
                    code: "VALIDATION_FAILED",
                    message: "[warn] Stored credential but validation failed: \(reason)"
                )
            case let .timeout(seconds):
                self.output.error(
                    code: "VALIDATION_TIMEOUT",
                    message: "[warn] Stored credential but validation timed out after \(Int(seconds))s"
                )
            }
        }
    }

    struct LoginCommand: ConfigRuntimeCommand {
        static let commandDescription = CommandDescription(
            commandName: "login",
            abstract: "OAuth login for supported providers (openai, anthropic)"
        )

        @Argument(help: "Provider id (openai|anthropic)")
        var provider: String

        @Option(name: .long, help: "Timeout in seconds for token exchange (default 30)")
        var timeoutSeconds: Double = 30

        @Flag(name: .customLong("no-browser"), help: "Do not auto-open the browser")
        var noBrowser: Bool = false

        @RuntimeStorage var runtime: CommandRuntime?

        mutating func run(using runtime: CommandRuntime) async throws {
            self.prepare(using: runtime)
            let timeout = self.timeoutSeconds > 0 ? self.timeoutSeconds : 30
            let normalized = ProviderId.normalize(self.provider)

            guard let providerId = normalized, providerId.supportsOAuth else {
                self.output.error(
                    code: "INVALID_PROVIDER",
                    message: "OAuth supported providers: openai, anthropic"
                )
                throw ExitCode.failure
            }

            switch providerId {
            case .openai:
                try await self.runOpenAIOAuth(timeout: timeout)
            case .anthropic:
                try await self.runAnthropicOAuth(timeout: timeout)
            default:
                break
            }
        }

        private func runOpenAIOAuth(timeout: Double) async throws {
            let clientId = "app_EMoamEEZ73f0CkXaXp7hrann"
            let authorize = "https://auth.openai.com/oauth/authorize"
            let token = "https://auth.openai.com/oauth/token"
            let redirect = "http://localhost:1455/auth/callback"
            try await self.oauthFlow(
                providerKey: "OPENAI",
                authorizeURL: authorize,
                tokenURL: token,
                clientId: clientId,
                scope: "openid profile email offline_access",
                redirectURI: redirect,
                extraAuthorizeParams: [:],
                extraTokenParams: [:],
                timeout: timeout,
                betaHeader: nil
            )
        }

        private func runAnthropicOAuth(timeout: Double) async throws {
            let clientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
            let authorize = "https://claude.ai/oauth/authorize"
            let token = "https://console.anthropic.com/v1/oauth/token"
            let redirect = "https://console.anthropic.com/oauth/code/callback"
            try await self.oauthFlow(
                providerKey: "ANTHROPIC",
                authorizeURL: authorize,
                tokenURL: token,
                clientId: clientId,
                scope: "org:create_api_key user:profile user:inference",
                redirectURI: redirect,
                extraAuthorizeParams: ["code": "true"],
                extraTokenParams: [:],
                timeout: timeout,
                betaHeader: "oauth-2025-04-20,claude-code-20250219,interleaved-thinking-2025-05-14,fine-grained-tool-streaming-2025-05-14"
            )
        }

        private func oauthFlow(
            providerKey: String,
            authorizeURL: String,
            tokenURL: String,
            clientId: String,
            scope: String,
            redirectURI: String,
            extraAuthorizeParams: [String: String],
            extraTokenParams: [String: String],
            timeout: Double,
            betaHeader: String?
        ) async throws {
            let pkce = PKCE()
            var components = URLComponents(string: authorizeURL)!
            var query: [URLQueryItem] = [
                .init(name: "response_type", value: "code"),
                .init(name: "client_id", value: clientId),
                .init(name: "redirect_uri", value: redirectURI),
                .init(name: "scope", value: scope),
                .init(name: "code_challenge", value: pkce.challenge),
                .init(name: "code_challenge_method", value: "S256"),
                .init(name: "state", value: pkce.verifier),
            ]
            query.append(contentsOf: extraAuthorizeParams.map { URLQueryItem(name: $0.key, value: $0.value) })
            components.queryItems = query
            guard let url = components.url else {
                self.output.error(code: "OAUTH_ERROR", message: "Failed to build authorize URL")
                throw ExitCode.failure
            }

            if !self.noBrowser {
                NSWorkspace.shared.open(url)
            }

            self.output.info([
                "Open this URL in a browser if it did not open automatically:",
                "  \(url.absoluteString)",
                "",
                "After authorizing, paste the resulting code (full callback URL or code parameter) here:"
            ])

            guard let codeInput = readLine(), !codeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.output.error(code: "OAUTH_ERROR", message: "No code entered")
                throw ExitCode.failure
            }

            let code = Self.parseCode(from: codeInput)
            guard !code.isEmpty else {
                self.output.error(code: "OAUTH_ERROR", message: "Failed to extract authorization code")
                throw ExitCode.failure
            }

            var tokenRequest = URLRequest(url: URL(string: tokenURL)!)
            tokenRequest.httpMethod = "POST"
            tokenRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

            var body: [String: Any] = [
                "grant_type": "authorization_code",
                "client_id": clientId,
                "code": code,
                "redirect_uri": redirectURI,
                "code_verifier": pkce.verifier,
            ]
            extraTokenParams.forEach { body[$0.key] = $0.value }

            let tokenResult = await HTTP.postJSON(
                request: tokenRequest,
                body: body,
                timeoutSeconds: timeout
            )

            guard case let .success(json) = tokenResult,
                  let access = json["access_token"] as? String,
                  let refresh = json["refresh_token"] as? String,
                  let expiresIn = json["expires_in"] as? Double
            else {
                let message: String
                switch tokenResult {
                case let .failure(reason): message = reason
                case let .timeout(seconds): message = "timed out after \(Int(seconds))s"
                default: message = "unexpected token response"
                }
                self.output.error(code: "OAUTH_ERROR", message: "Token exchange failed: \(message)")
                throw ExitCode.failure
            }

            let expires = Date().addingTimeInterval(expiresIn)
            let prefix = providerKey.uppercased()
            do {
                try self.configManager.setCredential(key: "\(prefix)_ACCESS_TOKEN", value: access)
                try self.configManager.setCredential(key: "\(prefix)_REFRESH_TOKEN", value: refresh)
                try self.configManager.setCredential(
                    key: "\(prefix)_ACCESS_EXPIRES",
                    value: String(Int(expires.timeIntervalSince1970))
                )
                if let betaHeader {
                    try self.configManager.setCredential(key: "\(prefix)_BETA_HEADER", value: betaHeader)
                }
            } catch {
                self.output.error(code: "FILE_IO_ERROR", message: "Failed to store tokens: \(error)")
                throw ExitCode.failure
            }

            self.output.success(message: "[ok] OAuth tokens stored for \(providerKey.lowercased())")
        }

        private static func parseCode(from input: String) -> String {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed), let code = url.queryItems?["code"] {
                return code
            }
            if let hashRange = trimmed.range(of: "#") {
                return String(trimmed[..<hashRange.lowerBound])
            }
            return trimmed
        }
    }
}

// MARK: - Helpers

struct PKCE {
    let verifier: String
    let challenge: String

    init() {
        let randomData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let verifier = randomData.urlSafeBase64()
        let hash = SHA256.hash(data: verifier.data(using: .utf8)!)
        let challenge = Data(hash).urlSafeBase64()
        self.verifier = verifier
        self.challenge = challenge
    }
}

enum ProviderId: String {
    case openai
    case anthropic
    case grok
    case gemini

    static func normalize(_ value: String) -> ProviderId? {
        let lower = value.lowercased()
        if lower == "xai" { return .grok }
        return ProviderId(rawValue: lower)
    }

    var displayName: String {
        switch self {
        case .openai: "OpenAI"
        case .anthropic: "Anthropic"
        case .grok: "Grok (xAI)"
        case .gemini: "Gemini"
        }
    }

    var credentialKey: String {
        switch self {
        case .openai: "OPENAI_API_KEY"
        case .anthropic: "ANTHROPIC_API_KEY"
        case .grok: "GROK_API_KEY"
        case .gemini: "GEMINI_API_KEY"
        }
    }

    var supportsOAuth: Bool {
        self == .openai || self == .anthropic
    }
}

enum ValidationResult {
    case success
    case failure(String)
    case timeout(Double)
}

struct ProviderValidator {
    let timeoutSeconds: Double

    init(timeoutSeconds: Double) {
        self.timeoutSeconds = timeoutSeconds
    }

    func validate(provider: ProviderId, secret: String) async -> ValidationResult {
        switch provider {
        case .openai:
            return await self.validateBearer(
                url: "https://api.openai.com/v1/models",
                secret: secret,
                header: "Authorization",
                valuePrefix: "Bearer "
            )
        case .anthropic:
            var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            request.httpMethod = "POST"
            request.setValue(secret, forHTTPHeaderField: "x-api-key")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.httpBody = try? JSONSerialization.data(withJSONObject: [
                "model": "claude-3-haiku-20241022",
                "max_tokens": 1,
                "messages": [
                    ["role": "user", "content": "ping"]
                ],
            ])
            let result = await HTTP.perform(request: request, timeoutSeconds: self.timeoutSeconds)
            return result
        case .grok:
            return await self.validateBearer(
                url: "https://api.x.ai/v1/models",
                secret: secret,
                header: "Authorization",
                valuePrefix: "Bearer "
            )
        case .gemini:
            let url = "https://generativelanguage.googleapis.com/v1beta/models?key=\(secret)"
            var request = URLRequest(url: URL(string: url)!)
            request.httpMethod = "GET"
            let result = await HTTP.perform(request: request, timeoutSeconds: self.timeoutSeconds)
            return result
        }
    }

    private func validateBearer(
        url: String,
        secret: String,
        header: String,
        valuePrefix: String
    ) async -> ValidationResult {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        request.setValue(valuePrefix + secret, forHTTPHeaderField: header)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return await HTTP.perform(request: request, timeoutSeconds: self.timeoutSeconds)
    }
}

enum HTTP {
    static func perform(request: URLRequest, timeoutSeconds: Double) async -> ValidationResult {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeoutSeconds
        config.timeoutIntervalForResource = timeoutSeconds
        let session = URLSession(configuration: config)
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure("invalid response")
            }
            if (200...299).contains(http.statusCode) { return .success }
            return .failure("status \(http.statusCode)")
        } catch {
            if (error as? URLError)?.code == .timedOut {
                return .timeout(timeoutSeconds)
            }
            return .failure(error.localizedDescription)
        }
    }

    static func postJSON(request: URLRequest, body: [String: Any], timeoutSeconds: Double) async -> ValidationResultJSON {
        var req = request
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return await self.performJSON(request: req, timeoutSeconds: timeoutSeconds)
    }

    static func performJSON(request: URLRequest, timeoutSeconds: Double) async -> ValidationResultJSON {
        var req = request
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeoutSeconds
        config.timeoutIntervalForResource = timeoutSeconds
        let session = URLSession(configuration: config)
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                return .failure("invalid response")
            }
            if (200...299).contains(http.statusCode) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    return .success(json)
                }
                return .failure("invalid json")
            }
            return .failure("status \(http.statusCode)")
        } catch {
            if (error as? URLError)?.code == .timedOut {
                return .timeout(timeoutSeconds)
            }
            return .failure(error.localizedDescription)
        }
    }
}

enum ValidationResultJSON {
    case success([String: Any])
    case failure(String)
    case timeout(Double)
}

private extension URL {
    var queryItems: [String: String] {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .reduce(into: [String: String]()) { $0[$1.name] = $1.value } ?? [:]
    }
}

private extension Data {
    func urlSafeBase64() -> String {
        self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
