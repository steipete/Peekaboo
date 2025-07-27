import Foundation

// MARK: - Model Parameters

/// Type-safe representation of additional model parameters
public struct ModelParameters: Codable, Sendable {
    private let storage: [String: Value]
    
    /// Supported parameter value types
    public enum Value: Codable, Sendable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case dictionary([String: Value])
        case array([Value])
        
        // MARK: - Codable
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            
            if let intValue = try? container.decode(Int.self) {
                self = .int(intValue)
            } else if let doubleValue = try? container.decode(Double.self) {
                self = .double(doubleValue)
            } else if let boolValue = try? container.decode(Bool.self) {
                self = .bool(boolValue)
            } else if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
            } else if let dictValue = try? container.decode([String: Value].self) {
                self = .dictionary(dictValue)
            } else if let arrayValue = try? container.decode([Value].self) {
                self = .array(arrayValue)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unable to decode ModelParameters.Value"
                )
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            
            switch self {
            case .string(let value):
                try container.encode(value)
            case .int(let value):
                try container.encode(value)
            case .double(let value):
                try container.encode(value)
            case .bool(let value):
                try container.encode(value)
            case .dictionary(let value):
                try container.encode(value)
            case .array(let value):
                try container.encode(value)
            }
        }
        
        /// Convert to raw value for JSON serialization
        public var rawValue: Any {
            switch self {
            case .string(let value):
                return value
            case .int(let value):
                return value
            case .double(let value):
                return value
            case .bool(let value):
                return value
            case .dictionary(let dict):
                return dict.mapValues { $0.rawValue }
            case .array(let array):
                return array.map { $0.rawValue }
            }
        }
    }
    
    // MARK: - Initialization
    
    public init(_ storage: [String: Value] = [:]) {
        self.storage = storage
    }
    
    /// Initialize from a dictionary of raw values
    public init(from rawValues: [String: Any]) {
        var convertedStorage: [String: Value] = [:]
        for (key, value) in rawValues {
            if let converted = Self.convertToValue(value) {
                convertedStorage[key] = converted
            }
        }
        self.storage = convertedStorage
    }
    
    /// Convert any value to our Value enum
    private static func convertToValue(_ value: Any) -> Value? {
        switch value {
        case let string as String:
            return .string(string)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case let bool as Bool:
            return .bool(bool)
        case let dict as [String: Any]:
            var converted: [String: Value] = [:]
            for (k, v) in dict {
                if let convertedValue = convertToValue(v) {
                    converted[k] = convertedValue
                }
            }
            return .dictionary(converted)
        case let array as [Any]:
            let converted = array.compactMap { convertToValue($0) }
            return .array(converted)
        default:
            return nil
        }
    }
    
    // MARK: - Access Methods
    
    public subscript(key: String) -> Value? {
        get { storage[key] }
    }
    
    public func string(_ key: String) -> String? {
        guard case .string(let value) = storage[key] else { return nil }
        return value
    }
    
    public func int(_ key: String) -> Int? {
        guard case .int(let value) = storage[key] else { return nil }
        return value
    }
    
    public func double(_ key: String) -> Double? {
        guard case .double(let value) = storage[key] else { return nil }
        return value
    }
    
    public func bool(_ key: String) -> Bool? {
        guard case .bool(let value) = storage[key] else { return nil }
        return value
    }
    
    /// Get the raw dictionary for JSON serialization
    public var rawDictionary: [String: Any] {
        storage.mapValues { $0.rawValue }
    }
    
    /// Check if empty
    public var isEmpty: Bool {
        storage.isEmpty
    }
    
    // MARK: - Builder Methods
    
    public func with(_ key: String, value: String) -> ModelParameters {
        var newStorage = storage
        newStorage[key] = .string(value)
        return ModelParameters(newStorage)
    }
    
    public func with(_ key: String, value: Int) -> ModelParameters {
        var newStorage = storage
        newStorage[key] = .int(value)
        return ModelParameters(newStorage)
    }
    
    public func with(_ key: String, value: Double) -> ModelParameters {
        var newStorage = storage
        newStorage[key] = .double(value)
        return ModelParameters(newStorage)
    }
    
    public func with(_ key: String, value: Bool) -> ModelParameters {
        var newStorage = storage
        newStorage[key] = .bool(value)
        return ModelParameters(newStorage)
    }
    
    public func with(_ key: String, value: [String: Any]) -> ModelParameters {
        guard let converted = Self.convertToValue(value) else { return self }
        var newStorage = storage
        newStorage[key] = converted
        return ModelParameters(newStorage)
    }
    
    // MARK: - Codable
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.storage = try container.decode([String: Value].self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storage)
    }
}

// MARK: - Convenience Builders

extension ModelParameters {
    /// Create parameters for OpenAI o3/o4 models
    public static func o3Parameters(
        reasoningEffort: String = "medium",
        maxCompletionTokens: Int = 32768
    ) -> ModelParameters {
        ModelParameters()
            .with("reasoning_effort", value: reasoningEffort)
            .with("max_completion_tokens", value: maxCompletionTokens)
            .with("reasoning", value: ["summary": "detailed"])
    }
    
    /// Create parameters with API type
    public static func withAPIType(_ apiType: String) -> ModelParameters {
        ModelParameters().with("apiType", value: apiType)
    }
}