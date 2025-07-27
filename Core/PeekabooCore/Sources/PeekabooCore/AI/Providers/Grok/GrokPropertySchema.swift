import Foundation

/// Type-safe property schema for Grok tool parameters
struct GrokPropertySchema: Codable {
    let type: String
    let description: String?
    let `enum`: [String]?
    let items: Box<GrokPropertySchema>?
    let properties: [String: GrokPropertySchema]?
    let minimum: Double?
    let maximum: Double?
    let pattern: String?
    let required: [String]?
    
    init(
        type: String,
        description: String? = nil,
        enum enumValues: [String]? = nil,
        items: GrokPropertySchema? = nil,
        properties: [String: GrokPropertySchema]? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        pattern: String? = nil,
        required: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.enum = enumValues
        self.items = items.map(Box.init)
        self.properties = properties
        self.minimum = minimum
        self.maximum = maximum
        self.pattern = pattern
        self.required = required
    }
    
    /// Create from a ParameterSchema
    init(from schema: ParameterSchema) {
        self.type = schema.type.rawValue
        self.description = schema.description
        self.enum = schema.enumValues
        self.items = schema.items.map { Box(GrokPropertySchema(from: $0.value)) }
        self.properties = schema.properties?.mapValues { GrokPropertySchema(from: $0) }
        self.minimum = schema.minimum
        self.maximum = schema.maximum
        self.pattern = schema.pattern
        self.required = nil
    }
}

/// Helper to convert ToolParameters to Grok-compatible structure
extension ToolParameters {
    func toGrokParameters() -> (type: String, properties: [String: GrokPropertySchema], required: [String]) {
        var grokProperties: [String: GrokPropertySchema] = [:]
        
        for (key, schema) in properties {
            grokProperties[key] = GrokPropertySchema(from: schema)
        }
        
        return (type: type, properties: grokProperties, required: required)
    }
}