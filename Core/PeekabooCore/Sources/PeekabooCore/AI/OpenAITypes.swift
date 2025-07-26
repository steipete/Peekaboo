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
    public let function: Function

    public init(type: String = "function", function: Function) {
        self.type = type
        self.function = function
    }
    
    // Nested types to match OpenAI API structure
    public struct Function: Codable, Sendable {
        public let name: String
        public let description: String
        public let parameters: Parameters
        
        public init(name: String, description: String, parameters: Parameters) {
            self.name = name
            self.description = description
            self.parameters = parameters
        }
    }
    
    public struct Parameters: Codable, Sendable {
        public let type: String
        // Using a JSON-serializable dictionary instead of [String: Any]
        public let propertiesJSON: String
        public let required: [String]
        
        public var properties: [String: Any] {
            guard let data = propertiesJSON.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return [:]
            }
            return dict
        }
        
        public init(type: String = "object", properties: [String: Any] = [:], required: [String] = []) {
            self.type = type
            // Convert properties to JSON string for Sendable conformance
            if let data = try? JSONSerialization.data(withJSONObject: properties),
               let json = String(data: data, encoding: .utf8) {
                self.propertiesJSON = json
            } else {
                self.propertiesJSON = "{}"
            }
            self.required = required
        }
        
        // Custom encoding/decoding for the properties dictionary
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(required, forKey: .required)
            
            // Encode properties as a JSON object
            if let data = propertiesJSON.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: data) {
                try container.encode(AnyEncodable(jsonObject), forKey: .properties)
            }
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.type = try container.decode(String.self, forKey: .type)
            self.required = try container.decode([String].self, forKey: .required)
            
            // Decode properties as Any
            if let anyProperties = try? container.decode(AnyDecodable.self, forKey: .properties),
               let dict = anyProperties.value as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: dict),
               let json = String(data: data, encoding: .utf8) {
                self.propertiesJSON = json
            } else {
                self.propertiesJSON = "{}"
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case type, properties, required
        }
    }
}

// MARK: - Helper types for encoding/decoding Any

struct AnyEncodable: Encodable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        if let data = try? JSONSerialization.data(withJSONObject: value),
           let json = try? JSONSerialization.jsonObject(with: data) {
            try (json as? Encodable)?.encode(to: encoder)
        }
    }
}

struct AnyDecodable: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyDecodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyDecodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
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
