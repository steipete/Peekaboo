import Foundation

public class OllamaProvider: AIProvider {
    public let name: String = "ollama"
    public let model: String
    
    internal var baseURL: URL
    
    public init(model: String, baseURL: URL? = nil) {
        self.model = model
        self.baseURL = baseURL ?? URL(string: "http://localhost:11434")!
    }
    
    public var isAvailable: Bool {
        get async {
            // Check if Ollama server is reachable
            do {
                let url = baseURL.appendingPathComponent("api/tags")
                let (_, response) = try await URLSession.shared.data(from: url)
                if let httpResponse = response as? HTTPURLResponse {
                    return httpResponse.statusCode == 200
                }
            } catch {
                // Server not reachable
            }
            return false
        }
    }
    
    public func checkAvailability() async -> AIProviderStatus {
        let available = await isAvailable
        
        if !available {
            return AIProviderStatus(
                available: false,
                error: "Ollama server not reachable at \(baseURL)",
                details: AIProviderDetails(
                    modelAvailable: false,
                    serverReachable: false,
                    apiKeyPresent: true
                )
            )
        }
        
        // Try to get model list
        var modelList: [String]? = nil
        do {
            let url = baseURL.appendingPathComponent("api/tags")
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                modelList = models.compactMap { $0["name"] as? String }
            }
        } catch {
            // Ignore errors getting model list
        }
        
        return AIProviderStatus(
            available: true,
            details: AIProviderDetails(
                modelAvailable: modelList?.contains(model) ?? false,
                serverReachable: true,
                apiKeyPresent: true,
                modelList: modelList
            )
        )
    }
    
    public func analyze(imageBase64: String, question: String) async throws -> String {
        // This is a placeholder implementation
        // In a real implementation, this would make an API call to Ollama
        throw AIProviderError.notConfigured("Ollama provider not fully implemented")
    }
}