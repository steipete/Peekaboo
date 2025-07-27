import Foundation

// MARK: - Session Metadata

/// Type-safe metadata for agent sessions
public struct SessionMetadata: Codable, Sendable {
    private let storage: [String: MetadataValue]
    
    public init() {
        self.storage = [:]
    }
    
    private init(storage: [String: MetadataValue]) {
        self.storage = storage
    }
    
    /// Metadata value types
    public enum MetadataValue: Codable, Sendable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case date(Date)
        case data(Data)
        case array([MetadataValue])
        case dictionary([String: MetadataValue])
        
        // MARK: - Codable
        
        private enum CodingKeys: String, CodingKey {
            case type
            case value
        }
        
        private enum ValueType: String, Codable {
            case string, int, double, bool, date, data, array, dictionary
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(ValueType.self, forKey: .type)
            
            switch type {
            case .string:
                let value = try container.decode(String.self, forKey: .value)
                self = .string(value)
            case .int:
                let value = try container.decode(Int.self, forKey: .value)
                self = .int(value)
            case .double:
                let value = try container.decode(Double.self, forKey: .value)
                self = .double(value)
            case .bool:
                let value = try container.decode(Bool.self, forKey: .value)
                self = .bool(value)
            case .date:
                let value = try container.decode(Date.self, forKey: .value)
                self = .date(value)
            case .data:
                let value = try container.decode(Data.self, forKey: .value)
                self = .data(value)
            case .array:
                let value = try container.decode([MetadataValue].self, forKey: .value)
                self = .array(value)
            case .dictionary:
                let value = try container.decode([String: MetadataValue].self, forKey: .value)
                self = .dictionary(value)
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .string(let value):
                try container.encode(ValueType.string, forKey: .type)
                try container.encode(value, forKey: .value)
            case .int(let value):
                try container.encode(ValueType.int, forKey: .type)
                try container.encode(value, forKey: .value)
            case .double(let value):
                try container.encode(ValueType.double, forKey: .type)
                try container.encode(value, forKey: .value)
            case .bool(let value):
                try container.encode(ValueType.bool, forKey: .type)
                try container.encode(value, forKey: .value)
            case .date(let value):
                try container.encode(ValueType.date, forKey: .type)
                try container.encode(value, forKey: .value)
            case .data(let value):
                try container.encode(ValueType.data, forKey: .type)
                try container.encode(value, forKey: .value)
            case .array(let value):
                try container.encode(ValueType.array, forKey: .type)
                try container.encode(value, forKey: .value)
            case .dictionary(let value):
                try container.encode(ValueType.dictionary, forKey: .type)
                try container.encode(value, forKey: .value)
            }
        }
    }
    
    // MARK: - Builder Methods
    
    /// Add a string value
    public func with(_ key: String, value: String) -> SessionMetadata {
        var newStorage = storage
        newStorage[key] = .string(value)
        return SessionMetadata(storage: newStorage)
    }
    
    /// Add an integer value
    public func with(_ key: String, value: Int) -> SessionMetadata {
        var newStorage = storage
        newStorage[key] = .int(value)
        return SessionMetadata(storage: newStorage)
    }
    
    /// Add a double value
    public func with(_ key: String, value: Double) -> SessionMetadata {
        var newStorage = storage
        newStorage[key] = .double(value)
        return SessionMetadata(storage: newStorage)
    }
    
    /// Add a boolean value
    public func with(_ key: String, value: Bool) -> SessionMetadata {
        var newStorage = storage
        newStorage[key] = .bool(value)
        return SessionMetadata(storage: newStorage)
    }
    
    /// Add a date value
    public func with(_ key: String, value: Date) -> SessionMetadata {
        var newStorage = storage
        newStorage[key] = .date(value)
        return SessionMetadata(storage: newStorage)
    }
    
    /// Add a data value
    public func with(_ key: String, value: Data) -> SessionMetadata {
        var newStorage = storage
        newStorage[key] = .data(value)
        return SessionMetadata(storage: newStorage)
    }
    
    /// Add an array value
    public func with(_ key: String, value: [MetadataValue]) -> SessionMetadata {
        var newStorage = storage
        newStorage[key] = .array(value)
        return SessionMetadata(storage: newStorage)
    }
    
    /// Add a dictionary value
    public func with(_ key: String, value: [String: MetadataValue]) -> SessionMetadata {
        var newStorage = storage
        newStorage[key] = .dictionary(value)
        return SessionMetadata(storage: newStorage)
    }
    
    // MARK: - Accessors
    
    /// Get all keys
    public var keys: [String] {
        Array(storage.keys)
    }
    
    /// Check if empty
    public var isEmpty: Bool {
        storage.isEmpty
    }
    
    /// Get count
    public var count: Int {
        storage.count
    }
    
    /// Access raw value
    public subscript(key: String) -> MetadataValue? {
        storage[key]
    }
    
    /// Get string value
    public func string(_ key: String) -> String? {
        guard let value = storage[key] else { return nil }
        if case .string(let str) = value {
            return str
        }
        return nil
    }
    
    /// Get int value
    public func int(_ key: String) -> Int? {
        guard let value = storage[key] else { return nil }
        if case .int(let num) = value {
            return num
        }
        return nil
    }
    
    /// Get double value
    public func double(_ key: String) -> Double? {
        guard let value = storage[key] else { return nil }
        if case .double(let num) = value {
            return num
        }
        return nil
    }
    
    /// Get bool value
    public func bool(_ key: String) -> Bool? {
        guard let value = storage[key] else { return nil }
        if case .bool(let flag) = value {
            return flag
        }
        return nil
    }
    
    /// Get date value
    public func date(_ key: String) -> Date? {
        guard let value = storage[key] else { return nil }
        if case .date(let date) = value {
            return date
        }
        return nil
    }
    
    /// Get data value
    public func data(_ key: String) -> Data? {
        guard let value = storage[key] else { return nil }
        if case .data(let data) = value {
            return data
        }
        return nil
    }
    
    /// Get array value
    public func array(_ key: String) -> [MetadataValue]? {
        guard let value = storage[key] else { return nil }
        if case .array(let arr) = value {
            return arr
        }
        return nil
    }
    
    /// Get dictionary value
    public func dictionary(_ key: String) -> [String: MetadataValue]? {
        guard let value = storage[key] else { return nil }
        if case .dictionary(let dict) = value {
            return dict
        }
        return nil
    }
    
    // MARK: - Conversion from [String: Any]
    
    /// Initialize from untyped dictionary (for migration)
    public init(from dictionary: [String: Any]) {
        var newStorage: [String: MetadataValue] = [:]
        
        for (key, value) in dictionary {
            if let metadataValue = MetadataValue(from: value) {
                newStorage[key] = metadataValue
            }
        }
        
        self.storage = newStorage
    }
    
    /// Convert to untyped dictionary (for legacy compatibility if needed)
    public func toDictionary() -> [String: Any] {
        var result: [String: Any] = [:]
        
        for (key, value) in storage {
            result[key] = value.toAny()
        }
        
        return result
    }
}

// MARK: - MetadataValue Extensions

extension SessionMetadata.MetadataValue {
    /// Initialize from Any value (for migration)
    init?(from value: Any) {
        switch value {
        case let str as String:
            self = .string(str)
        case let num as Int:
            self = .int(num)
        case let num as Double:
            self = .double(num)
        case let flag as Bool:
            self = .bool(flag)
        case let date as Date:
            self = .date(date)
        case let data as Data:
            self = .data(data)
        case let arr as [Any]:
            let values = arr.compactMap { SessionMetadata.MetadataValue(from: $0) }
            if values.count == arr.count {
                self = .array(values)
            } else {
                return nil
            }
        case let dict as [String: Any]:
            var values: [String: SessionMetadata.MetadataValue] = [:]
            for (key, val) in dict {
                if let metadataValue = SessionMetadata.MetadataValue(from: val) {
                    values[key] = metadataValue
                } else {
                    return nil
                }
            }
            self = .dictionary(values)
        default:
            return nil
        }
    }
    
    /// Convert to Any (for legacy compatibility)
    func toAny() -> Any {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .bool(let value):
            return value
        case .date(let value):
            return value
        case .data(let value):
            return value
        case .array(let values):
            return values.map { $0.toAny() }
        case .dictionary(let dict):
            return dict.mapValues { $0.toAny() }
        }
    }
}

// MARK: - Common Metadata Keys

extension SessionMetadata {
    /// Common metadata keys used in sessions
    public enum Key {
        public static let modelName = "modelName"
        public static let temperature = "temperature"
        public static let maxTokens = "maxTokens"
        public static let toolCallCount = "toolCallCount"
        public static let totalTokens = "totalTokens"
        public static let isResumed = "isResumed"
        public static let parentSessionId = "parentSessionId"
        public static let tags = "tags"
        public static let title = "title"
        public static let description = "description"
    }
}