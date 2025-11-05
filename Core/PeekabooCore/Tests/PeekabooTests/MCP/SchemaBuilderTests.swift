import Foundation
import MCP
import TachikomaMCP
import Testing
@testable import PeekabooCore

@Suite("SchemaBuilder Tests")
struct SchemaBuilderTests {
    // MARK: - Object Schema Tests

    @Test("Create simple object schema")
    func simpleObjectSchema() {
        let schema = SchemaBuilder.object(
            properties: [
                "name": SchemaBuilder.string(description: "User name"),
            ],
            required: ["name"],
            description: "A simple user object")

        // Verify the schema structure
        guard case let .object(dict) = schema else {
            Issue.record("Expected object schema")
            return
        }

        #expect(dict["type"] == .string("object"))
        #expect(dict["description"] == .string("A simple user object"))

        // Check required array
        if let required = dict["required"],
           case let .array(requiredArray) = required
        {
            #expect(requiredArray.count == 1)
            #expect(requiredArray.first == .string("name"))
        } else {
            Issue.record("Expected required array")
        }

        // Check properties
        if let properties = dict["properties"],
           case let .object(props) = properties
        {
            #expect(props.count == 1)
            #expect(props["name"] != nil)
        } else {
            Issue.record("Expected properties object")
        }
    }

    @Test("Create complex object schema with multiple properties")
    func complexObjectSchema() {
        let schema = SchemaBuilder.object(
            properties: [
                "path": SchemaBuilder.string(description: "File path"),
                "format": SchemaBuilder.string(
                    description: "Output format",
                    enum: ["png", "jpg", "data"]),
                "quality": SchemaBuilder.number(description: "Image quality"),
                "overwrite": SchemaBuilder.boolean(description: "Overwrite existing files"),
            ],
            required: ["path", "format"])

        guard case let .object(dict) = schema,
              let properties = dict["properties"],
              case let .object(props) = properties
        else {
            Issue.record("Expected object schema with properties")
            return
        }

        #expect(props.count == 4)
        #expect(props["path"] != nil)
        #expect(props["format"] != nil)
        #expect(props["quality"] != nil)
        #expect(props["overwrite"] != nil)

        // Verify required fields
        if let required = dict["required"],
           case let .array(requiredArray) = required
        {
            #expect(requiredArray.count == 2)
            #expect(requiredArray.contains(.string("path")))
            #expect(requiredArray.contains(.string("format")))
        }
    }

    // MARK: - String Schema Tests

    @Test("Create string schema with description")
    func stringSchemaWithDescription() {
        let schema = SchemaBuilder.string(description: "A test string")

        guard case let .object(dict) = schema else {
            Issue.record("Expected object schema")
            return
        }

        #expect(dict["type"] == .string("string"))
        #expect(dict["description"] == .string("A test string"))
    }

    @Test("Create string schema with enum values")
    func stringSchemaWithEnum() {
        let schema = SchemaBuilder.string(
            description: "Color choice",
            enum: ["red", "green", "blue"])

        guard case let .object(dict) = schema else {
            Issue.record("Expected object schema")
            return
        }

        #expect(dict["type"] == .string("string"))

        if let enumValue = dict["enum"],
           case let .array(enumArray) = enumValue
        {
            #expect(enumArray.count == 3)
            #expect(enumArray.contains(.string("red")))
            #expect(enumArray.contains(.string("green")))
            #expect(enumArray.contains(.string("blue")))
        } else {
            Issue.record("Expected enum array")
        }
    }

    @Test("Create string schema with default value")
    func stringSchemaWithDefault() {
        let schema = SchemaBuilder.string(
            description: "Format type",
            enum: ["png", "jpg"],
            default: "png")

        guard case let .object(dict) = schema else {
            Issue.record("Expected object schema")
            return
        }

        #expect(dict["default"] == .string("png"))
    }

    // MARK: - Boolean Schema Tests

    @Test("Create boolean schema")
    func booleanSchema() {
        let schema = SchemaBuilder.boolean(description: "Enable feature")

        guard case let .object(dict) = schema else {
            Issue.record("Expected object schema")
            return
        }

        #expect(dict["type"] == .string("boolean"))
        #expect(dict["description"] == .string("Enable feature"))
    }

    @Test("Create boolean schema without description")
    func booleanSchemaNoDescription() {
        let schema = SchemaBuilder.boolean()

        guard case let .object(dict) = schema else {
            Issue.record("Expected object schema")
            return
        }

        #expect(dict["type"] == .string("boolean"))
        #expect(dict["description"] == nil)
    }

    // MARK: - Number Schema Tests

    @Test("Create number schema")
    func numberSchema() {
        let schema = SchemaBuilder.number(description: "Timeout in seconds")

        guard case let .object(dict) = schema else {
            Issue.record("Expected object schema")
            return
        }

        #expect(dict["type"] == .string("number"))
        #expect(dict["description"] == .string("Timeout in seconds"))
    }

    // MARK: - Complex Nested Schema Tests

    @Test("Create nested object schema")
    func nestedObjectSchema() {
        let schema = SchemaBuilder.object(
            properties: [
                "user": SchemaBuilder.object(
                    properties: [
                        "name": SchemaBuilder.string(description: "User name"),
                        "age": SchemaBuilder.number(description: "User age"),
                    ],
                    required: ["name"]),
                "settings": SchemaBuilder.object(
                    properties: [
                        "theme": SchemaBuilder.string(enum: ["light", "dark"], default: "light"),
                        "notifications": SchemaBuilder.boolean(description: "Enable notifications"),
                    ]),
            ],
            required: ["user"])

        guard case let .object(dict) = schema,
              let properties = dict["properties"],
              case let .object(props) = properties
        else {
            Issue.record("Expected nested object schema")
            return
        }

        #expect(props["user"] != nil)
        #expect(props["settings"] != nil)

        // Verify nested user object
        if let userSchema = props["user"],
           case let .object(userDict) = userSchema,
           let userProps = userDict["properties"],
           case let .object(userProperties) = userProps
        {
            #expect(userProperties["name"] != nil)
            #expect(userProperties["age"] != nil)
        } else {
            Issue.record("Expected nested user properties")
        }
    }

    // MARK: - Edge Cases

    @Test("Empty object schema")
    func emptyObjectSchema() {
        let schema = SchemaBuilder.object(properties: [:])

        guard case let .object(dict) = schema else {
            Issue.record("Expected object schema")
            return
        }

        #expect(dict["type"] == .string("object"))

        if let properties = dict["properties"],
           case let .object(props) = properties
        {
            #expect(props.isEmpty)
        }

        // No required array should be present for empty required list
        if let required = dict["required"],
           case let .array(requiredArray) = required
        {
            #expect(requiredArray.isEmpty)
        }
    }

    @Test("Schema with special characters in descriptions")
    func specialCharactersInDescriptions() {
        let schema = SchemaBuilder.string(
            description: "Path with \"quotes\" and \nnewlines\tand tabs")

        guard case let .object(dict) = schema else {
            Issue.record("Expected object schema")
            return
        }

        #expect(dict["description"] == .string("Path with \"quotes\" and \nnewlines\tand tabs"))
    }
}

// Value already conforms to Equatable in MCP SDK
