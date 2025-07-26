import Foundation

// Generic JSON response for agent commands
public struct AgentJSONResponse: Codable {
    public let success: Bool
    public let result: OpenAIAgent.AgentResult?
    public let error: String?
    
    public init(success: Bool, result: OpenAIAgent.AgentResult? = nil, error: String? = nil) {
        self.success = success
        self.result = result
        self.error = error
    }
}

// Helper function to create error responses
public func createAgentErrorResponse(_ error: AgentError) -> AgentJSONResponse {
    return AgentJSONResponse(success: false, result: nil, error: error.errorDescription)
}