import Foundation

// MARK: - OpenAI API Types

public struct Assistant: Codable, Sendable {
    public let id: String
    public let object: String
    public let createdAt: Int
}

public struct Thread: Codable, Sendable {
    public let id: String
    public let object: String
    public let createdAt: Int
}

public struct Run: Codable, Sendable {
    public let id: String
    public let object: String
    public let status: Status
    public let requiredAction: RequiredAction?

    public enum Status: String, Codable, Sendable {
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

public struct RequiredAction: Codable, Sendable {
    public let type: String
    public let submitToolOutputs: SubmitToolOutputs
}

public struct SubmitToolOutputs: Codable, Sendable {
    public let toolCalls: [ToolCall]
}

public struct ToolCall: Codable, Sendable {
    public let id: String
    public let type: String
    public let function: FunctionCall
}

public struct FunctionCall: Codable, Sendable {
    public let name: String
    public let arguments: String
}

public struct Message: Codable, Sendable {
    public let id: String
    public let object: String
    public let role: String
    public let content: [MessageContent]
    public let createdAt: Int
}

public struct MessageContent: Codable, Sendable {
    public let type: String
    public let text: TextContent?
}

public struct TextContent: Codable, Sendable {
    public let value: String
}

public struct MessageList: Codable, Sendable {
    public let data: [Message]
}

// MARK: - Tool Definition

public struct Tool: Codable, Sendable {
    public let type: String
    public let function: ToolFunction

    public init(function: ToolFunction) {
        self.type = "function"
        self.function = function
    }
}

public struct ToolFunction: Codable, Sendable {
    public let name: String
    public let description: String
    public let parameters: FunctionParameters

    public init(name: String, description: String, parameters: FunctionParameters) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

public struct FunctionParameters: Codable, Sendable {
    public let type: String
    public let properties: [String: Property]
    public let required: [String]

    public var dictionary: [String: Any] {
        var dict: [String: Any] = ["type": type]

        var props: [String: Any] = [:]
        for (key, prop) in self.properties {
            props[key] = prop.dictionary
        }
        dict["properties"] = props
        dict["required"] = self.required

        return dict
    }

    public init(properties: [String: Property], required: [String]) {
        self.type = "object"
        self.properties = properties
        self.required = required
    }
}

public struct Property: Codable, Sendable {
    public let type: String
    public let description: String
    public let `enum`: [String]?

    public var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "type": type,
            "description": description,
        ]
        if let enumValues = self.enum {
            dict["enum"] = enumValues
        }
        return dict
    }

    public init(type: String, description: String, enum: [String]? = nil) {
        self.type = type
        self.description = description
        self.enum = `enum`
    }
}

// MARK: - Error Types

public struct OpenAIError: Codable, Sendable {
    public let error: ErrorDetail

    public struct ErrorDetail: Codable, Sendable {
        public let message: String
        public let type: String?
        public let code: String?
    }
}

// MARK: - Request Types

public struct AssistantRequest: Codable, Sendable {
    public let model: String
    public let name: String?
    public let description: String?
    public let instructions: String
    public let tools: [Tool]

    public init(model: String, name: String? = nil, description: String? = nil, instructions: String, tools: [Tool]) {
        self.model = model
        self.name = name
        self.description = description
        self.instructions = instructions
        self.tools = tools
    }
}
