import Foundation

// MARK: - OpenAI API Types

struct Assistant: Codable, Sendable {
    let id: String
    let object: String
    let createdAt: Int
}

struct Thread: Codable, Sendable {
    let id: String
    let object: String
    let createdAt: Int
}

struct Run: Codable, Sendable {
    let id: String
    let object: String
    let status: Status
    let requiredAction: RequiredAction?

    enum Status: String, Codable, Sendable {
        case queued
        case inProgress = "in_progress"
        case requiresAction = "requires_action"
        case cancelling
        case cancelled
        case failed
        case completed
        case expired
    }
}

struct RequiredAction: Codable, Sendable {
    let type: String
    let submitToolOutputs: SubmitToolOutputs
}

struct SubmitToolOutputs: Codable, Sendable {
    let toolCalls: [OpenAIToolCall]
}

struct OpenAIToolCall: Codable, Sendable {
    let id: String
    let type: String
    let function: FunctionCall
}

struct FunctionCall: Codable, Sendable {
    let name: String
    let arguments: String
}

struct Message: Codable, Sendable {
    let id: String
    let object: String
    let role: String
    let content: [MessageContent]
    let createdAt: Int
}

struct MessageContent: Codable, Sendable {
    let type: String
    let text: TextContent?
}

struct TextContent: Codable, Sendable {
    let value: String
}

struct MessageList: Codable, Sendable {
    let data: [Message]
}

// MARK: - Tool Definition

struct Tool: Codable, Sendable {
    let type: String
    let function: ToolFunction

    init(function: ToolFunction) {
        self.type = "function"
        self.function = function
    }
}

struct ToolFunction: Codable, Sendable {
    let name: String
    let description: String
    let parameters: FunctionParameters

    init(name: String, description: String, parameters: FunctionParameters) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

struct FunctionParameters: Codable, Sendable {
    let type: String
    let properties: [String: Property]
    let required: [String]

    var dictionary: [String: Any] {
        var dict: [String: Any] = ["type": type]

        var props: [String: Any] = [:]
        for (key, prop) in self.properties {
            props[key] = prop.dictionary
        }
        dict["properties"] = props
        dict["required"] = self.required

        return dict
    }

    init(properties: [String: Property], required: [String]) {
        self.type = "object"
        self.properties = properties
        self.required = required
    }
}

struct Property: Codable, Sendable {
    let type: String
    let description: String
    let `enum`: [String]?

    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "type": type,
            "description": description,
        ]
        if let enumValues = self.enum {
            dict["enum"] = enumValues
        }
        return dict
    }

    init(type: String, description: String, enum: [String]? = nil) {
        self.type = type
        self.description = description
        self.enum = `enum`
    }
}

// MARK: - Error Types

struct OpenAIError: Codable, Sendable {
    let error: ErrorDetail

    struct ErrorDetail: Codable, Sendable {
        let message: String
        let type: String?
        let code: String?
    }
}

// MARK: - Request Types

struct AssistantRequest: Codable, Sendable {
    let model: String
    let name: String?
    let description: String?
    let instructions: String
    let tools: [Tool]

    init(model: String, name: String? = nil, description: String? = nil, instructions: String, tools: [Tool]) {
        self.model = model
        self.name = name
        self.description = description
        self.instructions = instructions
        self.tools = tools
    }
}

// MARK: - Agent Error

enum AgentError: LocalizedError, Sendable {
    case missingAPIKey
    case apiError(String)
    case commandFailed(String)
    case invalidResponse(String)
    case rateLimited(retryAfter: TimeInterval?)
    case timeout
    case invalidArguments(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OPENAI_API_KEY environment variable not set"
        case let .apiError(message):
            return "API Error: \(message)"
        case let .commandFailed(message):
            return "Command failed: \(message)"
        case let .invalidResponse(message):
            return "Invalid response: \(message)"
        case let .rateLimited(retryAfter):
            if let retryAfter {
                return "Rate limited. Retry after \(retryAfter) seconds"
            }
            return "Rate limited"
        case .timeout:
            return "Request timed out"
        case let .invalidArguments(message):
            return "Invalid arguments: \(message)"
        }
    }
}

// MARK: - Agent Result

struct OpenAIAgentResult: Codable, Sendable {
    let steps: [Step]
    let summary: String?
    let success: Bool

    struct Step: Codable, Sendable {
        let description: String
        let command: String?
        let output: String?
        let screenshot: String? // Base64 encoded

        init(description: String, command: String? = nil, output: String? = nil, screenshot: String? = nil) {
            self.description = description
            self.command = command
            self.output = output
            self.screenshot = screenshot
        }
    }

    init(steps: [Step], summary: String? = nil, success: Bool) {
        self.steps = steps
        self.summary = summary
        self.success = success
    }
}

// MARK: - Tool Executor Protocol

protocol ToolExecutor: Sendable {
    func executeTool(name: String, arguments: String) async -> String
    func availableTools() -> [Tool]
    func systemPrompt() -> String
}
