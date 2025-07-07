import Foundation

// MARK: - Function Definition with Proper JSON Encoding

struct FunctionDefinition: Codable {
    let name: String
    let description: String
    let parameters: JSONParameters
    
    init(name: String, description: String, parameters: [String: Any]) {
        self.name = name
        self.description = description
        self.parameters = JSONParameters(parameters)
    }
}

/// Wrapper for arbitrary JSON parameters that can be encoded/decoded
struct JSONParameters: Codable {
    private let json: [String: Any]
    
    init(_ json: [String: Any]) {
        self.json = json
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        try container.encode(AgentAnyEncodable(jsonObject))
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let anyDecodable = try container.decode(AgentAnyDecodable.self)
        guard let json = anyDecodable.value as? [String: Any] else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected dictionary")
        }
        self.json = json
    }
}

// MARK: - Helper for encoding/decoding Any types

struct AgentAnyEncodable: Encodable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AgentAnyEncodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AgentAnyEncodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(value, .init(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

struct AgentAnyDecodable: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AgentAnyDecodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AgentAnyDecodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
        }
    }
}

// MARK: - Peekaboo Function Definitions

extension OpenAIAgent {
    static func makePeekabooTool(_ name: String, _ description: String) -> Tool {
        let parameters: [String: Any] = {
            switch name {
            case "see":
                return [
                    "type": "object",
                    "properties": [
                        "app": [
                            "type": "string",
                            "description": "Application name or 'frontmost' for active window"
                        ],
                        "window_title": [
                            "type": "string",
                            "description": "Specific window title to capture"
                        ],
                        "session_id": [
                            "type": "string",
                            "description": "Session ID for tracking UI state across commands"
                        ]
                    ],
                    "required": []
                ]
                
            case "click":
                return [
                    "type": "object",
                    "properties": [
                        "element": [
                            "type": "string",
                            "description": "Element ID (e.g., 'B1', 'T2') or description"
                        ],
                        "x": [
                            "type": "number",
                            "description": "X coordinate for direct click"
                        ],
                        "y": [
                            "type": "number",
                            "description": "Y coordinate for direct click"
                        ],
                        "double_click": [
                            "type": "boolean",
                            "description": "Perform double click instead of single click"
                        ],
                        "session_id": [
                            "type": "string",
                            "description": "Session ID to use element mappings from"
                        ]
                    ],
                    "required": []
                ]
                
            case "type":
                return [
                    "type": "object",
                    "properties": [
                        "text": [
                            "type": "string",
                            "description": "Text to type"
                        ],
                        "element": [
                            "type": "string",
                            "description": "Target element ID or description"
                        ],
                        "clear_first": [
                            "type": "boolean",
                            "description": "Clear existing text before typing"
                        ],
                        "session_id": [
                            "type": "string",
                            "description": "Session ID to use element mappings from"
                        ]
                    ],
                    "required": ["text"]
                ]
                
            case "scroll":
                return [
                    "type": "object",
                    "properties": [
                        "direction": [
                            "type": "string",
                            "enum": ["up", "down", "left", "right"],
                            "description": "Scroll direction"
                        ],
                        "amount": [
                            "type": "integer",
                            "description": "Number of scroll units (default: 5)"
                        ],
                        "element": [
                            "type": "string",
                            "description": "Element to scroll within"
                        ]
                    ],
                    "required": []
                ]
                
            case "hotkey":
                return [
                    "type": "object",
                    "properties": [
                        "keys": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "Keys to press (e.g., ['cmd', 'c'] for copy)"
                        ]
                    ],
                    "required": ["keys"]
                ]
                
            case "image":
                return [
                    "type": "object",
                    "properties": [
                        "app": [
                            "type": "string",
                            "description": "Application name to capture"
                        ],
                        "mode": [
                            "type": "string",
                            "enum": ["window", "screen", "frontmost", "area"],
                            "description": "Capture mode"
                        ],
                        "path": [
                            "type": "string",
                            "description": "Path to save the screenshot"
                        ],
                        "format": [
                            "type": "string",
                            "enum": ["file", "data"],
                            "description": "Output format (file path or base64 data)"
                        ]
                    ],
                    "required": []
                ]
                
            case "window":
                return [
                    "type": "object",
                    "properties": [
                        "action": [
                            "type": "string",
                            "enum": ["close", "minimize", "maximize", "focus", "move", "resize"],
                            "description": "Window action to perform"
                        ],
                        "app": [
                            "type": "string",
                            "description": "Application name"
                        ],
                        "title": [
                            "type": "string",
                            "description": "Window title"
                        ],
                        "x": [
                            "type": "number",
                            "description": "X position for move action"
                        ],
                        "y": [
                            "type": "number",
                            "description": "Y position for move action"
                        ],
                        "width": [
                            "type": "number",
                            "description": "Width for resize action"
                        ],
                        "height": [
                            "type": "number",
                            "description": "Height for resize action"
                        ]
                    ],
                    "required": ["action"]
                ]
                
            case "app":
                return [
                    "type": "object",
                    "properties": [
                        "action": [
                            "type": "string",
                            "enum": ["launch", "quit", "focus", "hide", "unhide"],
                            "description": "Application action"
                        ],
                        "name": [
                            "type": "string",
                            "description": "Application name"
                        ]
                    ],
                    "required": ["action", "name"]
                ]
                
            case "wait":
                return [
                    "type": "object",
                    "properties": [
                        "duration": [
                            "type": "number",
                            "description": "Duration to wait in seconds"
                        ]
                    ],
                    "required": ["duration"]
                ]
                
            default:
                return [
                    "type": "object",
                    "properties": [:],
                    "required": []
                ]
            }
        }()
        
        return Tool(
            type: "function",
            function: FunctionDefinition(
                name: "peekaboo_\(name)",
                description: description,
                parameters: parameters
            )
        )
    }
}