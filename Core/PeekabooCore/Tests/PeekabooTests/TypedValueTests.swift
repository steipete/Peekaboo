//
//  TypedValueTests.swift
//  PeekabooCore
//

import Foundation
import Testing
@testable import PeekabooCore
@testable import PeekabooAutomation
@testable import PeekabooAgentRuntime
@testable import PeekabooVisualizer

@Suite("TypedValue Tests")
struct TypedValueTests {
    // MARK: - Basic Type Tests

    @Test("Null value creation and accessors")
    func testNullValue() {
        let value = TypedValue.null
        #expect(value.isNull == true)
        #expect(value.valueType == .null)
        #expect(value.boolValue == nil)
        #expect(value.intValue == nil)
        #expect(value.doubleValue == nil)
        #expect(value.stringValue == nil)
        #expect(value.arrayValue == nil)
        #expect(value.objectValue == nil)
    }

    @Test("Bool value creation and accessors")
    func testBoolValue() {
        let value = TypedValue.bool(true)
        #expect(value.boolValue == true)
        #expect(value.valueType == .boolean)
        #expect(value.isNull == false)
        #expect(value.intValue == nil)
        #expect(value.stringValue == nil)
    }

    @Test("Int value creation and accessors")
    func testIntValue() {
        let value = TypedValue.int(42)
        #expect(value.intValue == 42)
        #expect(value.doubleValue == 42.0)
        #expect(value.valueType == .integer)
        #expect(value.boolValue == nil)
        #expect(value.stringValue == nil)
    }

    @Test("Double value creation and accessors")
    func testDoubleValue() {
        let value = TypedValue.double(3.14)
        #expect(value.doubleValue == 3.14)
        #expect(value.valueType == .number)
        #expect(value.intValue == nil)
        #expect(value.boolValue == nil)
        #expect(value.stringValue == nil)
    }

    @Test("String value creation and accessors")
    func testStringValue() {
        let value = TypedValue.string("hello")
        #expect(value.stringValue == "hello")
        #expect(value.valueType == .string)
        #expect(value.intValue == nil)
        #expect(value.boolValue == nil)
    }

    @Test("Array value creation and accessors")
    func testArrayValue() {
        let value = TypedValue.array([.int(1), .string("two"), .bool(true)])
        #expect(value.arrayValue?.count == 3)
        #expect(value.arrayValue?[0].intValue == 1)
        #expect(value.arrayValue?[1].stringValue == "two")
        #expect(value.arrayValue?[2].boolValue == true)
        #expect(value.valueType == .array)
    }

    @Test("Object value creation and accessors")
    func testObjectValue() {
        let value = TypedValue.object([
            "name": .string("John"),
            "age": .int(30),
            "active": .bool(true),
        ])
        #expect(value.objectValue?["name"]?.stringValue == "John")
        #expect(value.objectValue?["age"]?.intValue == 30)
        #expect(value.objectValue?["active"]?.boolValue == true)
        #expect(value.valueType == .object)
    }

    // MARK: - JSON Conversion Tests

    @Test("Convert to JSON - primitive types")
    func toJSONPrimitives() {
        #expect(TypedValue.null.toJSON() is NSNull)
        #expect(TypedValue.bool(true).toJSON() as? Bool == true)
        #expect(TypedValue.int(42).toJSON() as? Int == 42)
        #expect(TypedValue.double(3.14).toJSON() as? Double == 3.14)
        #expect(TypedValue.string("test").toJSON() as? String == "test")
    }

    @Test("Convert to JSON - complex types")
    func toJSONComplex() {
        let arrayValue = TypedValue.array([.int(1), .string("two")])
        let jsonArray = arrayValue.toJSON() as? [Any]
        #expect(jsonArray?.count == 2)
        #expect(jsonArray?[0] as? Int == 1)
        #expect(jsonArray?[1] as? String == "two")

        let objectValue = TypedValue.object(["key": .string("value")])
        let jsonObject = objectValue.toJSON() as? [String: Any]
        #expect(jsonObject?["key"] as? String == "value")
    }

    @Test("Create from JSON - primitive types")
    func fromJSONPrimitives() throws {
        let nullValue = try TypedValue.fromJSON(NSNull())
        #expect(nullValue.isNull == true)

        let boolValue = try TypedValue.fromJSON(true)
        #expect(boolValue.boolValue == true)

        let intValue = try TypedValue.fromJSON(42)
        #expect(intValue.intValue == 42)

        let doubleValue = try TypedValue.fromJSON(3.14)
        #expect(doubleValue.doubleValue == 3.14)

        let stringValue = try TypedValue.fromJSON("test")
        #expect(stringValue.stringValue == "test")
    }

    @Test("Create from JSON - complex types")
    func fromJSONComplex() throws {
        let arrayJSON: [Any] = [1, "two", true]
        let arrayValue = try TypedValue.fromJSON(arrayJSON)
        #expect(arrayValue.arrayValue?.count == 3)

        let dictJSON: [String: Any] = ["name": "John", "age": 30]
        let objectValue = try TypedValue.fromJSON(dictJSON)
        #expect(objectValue.objectValue?["name"]?.stringValue == "John")
        #expect(objectValue.objectValue?["age"]?.intValue == 30)
    }

    @Test("Integer coercion from double")
    func integerCoercion() throws {
        let wholeDouble = try TypedValue.fromJSON(42.0)
        #expect(wholeDouble.intValue == 42)
        #expect(wholeDouble.valueType == .integer)

        let fractionalDouble = try TypedValue.fromJSON(42.5)
        #expect(fractionalDouble.doubleValue == 42.5)
        #expect(fractionalDouble.intValue == nil)
        #expect(fractionalDouble.valueType == .number)
    }

    // MARK: - Codable Tests

    @Test("Encode and decode primitive types")
    func codablePrimitives() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let values: [TypedValue] = [
            .null,
            .bool(true),
            .int(42),
            .double(3.14),
            .string("test"),
        ]

        for value in values {
            let data = try encoder.encode(value)
            let decoded = try decoder.decode(TypedValue.self, from: data)
            #expect(decoded == value)
        }
    }

    @Test("Encode and decode complex types")
    func codableComplex() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let arrayValue = TypedValue.array([.int(1), .string("two"), .bool(true)])
        let arrayData = try encoder.encode(arrayValue)
        let decodedArray = try decoder.decode(TypedValue.self, from: arrayData)
        #expect(decodedArray == arrayValue)

        let objectValue = TypedValue.object([
            "name": .string("John"),
            "age": .int(30),
            "nested": .object(["key": .string("value")]),
        ])
        let objectData = try encoder.encode(objectValue)
        let decodedObject = try decoder.decode(TypedValue.self, from: objectData)
        #expect(decodedObject == objectValue)
    }

    // MARK: - ExpressibleBy Tests

    @Test("ExpressibleBy literal conformances")
    func expressibleByLiterals() {
        let nilValue: TypedValue = nil
        #expect(nilValue.isNull == true)

        let boolValue: TypedValue = true
        #expect(boolValue.boolValue == true)

        let intValue: TypedValue = 42
        #expect(intValue.intValue == 42)

        let doubleValue: TypedValue = 3.14
        #expect(doubleValue.doubleValue == 3.14)

        let stringValue: TypedValue = "hello"
        #expect(stringValue.stringValue == "hello")

        let arrayValue: TypedValue = [1, 2, 3]
        #expect(arrayValue.arrayValue?.count == 3)

        let dictValue: TypedValue = ["key": "value", "number": 42]
        #expect(dictValue.objectValue?.count == 2)
    }

    // MARK: - Convenience Methods Tests

    @Test("Type matching")
    func typeMatching() {
        #expect(TypedValue.bool(true).matches(Bool.self) == true)
        #expect(TypedValue.int(42).matches(Int.self) == true)
        #expect(TypedValue.double(3.14).matches(Double.self) == true)
        #expect(TypedValue.string("test").matches(String.self) == true)
        #expect(TypedValue.null.matches(NSNull.self) == true)

        #expect(TypedValue.bool(true).matches(Int.self) == false)
        #expect(TypedValue.int(42).matches(String.self) == false)
    }

    @Test("Type casting")
    func typeCasting() {
        #expect(TypedValue.bool(true).cast(to: Bool.self) == true)
        #expect(TypedValue.int(42).cast(to: Int.self) == 42)
        #expect(TypedValue.double(3.14).cast(to: Double.self) == 3.14)
        #expect(TypedValue.string("test").cast(to: String.self) == "test")

        #expect(TypedValue.bool(true).cast(to: Int.self) == nil)
        #expect(TypedValue.int(42).cast(to: String.self) == nil)
    }

    @Test("Dictionary conversion")
    func dictionaryConversion() throws {
        let dict: [String: Any] = [
            "name": "John",
            "age": 30,
            "active": true,
        ]

        let typedValue = try TypedValue.fromDictionary(dict)
        #expect(typedValue.valueType == .object)

        let convertedDict = try typedValue.toDictionary()
        #expect(convertedDict["name"] as? String == "John")
        #expect(convertedDict["age"] as? Int == 30)
        #expect(convertedDict["active"] as? Bool == true)
    }

    // MARK: - Edge Cases

    @Test("Nested structures")
    func nestedStructures() throws {
        let nestedJSON: [String: Any] = [
            "user": [
                "name": "John",
                "scores": [100, 95, 87],
                "settings": [
                    "theme": "dark",
                    "notifications": true,
                ],
            ],
        ]

        let typedValue = try TypedValue.fromJSON(nestedJSON)
        let userValue = typedValue.objectValue?["user"]
        let scoresValue = userValue?.objectValue?["scores"]
        let settingsValue = userValue?.objectValue?["settings"]

        #expect(userValue?.objectValue?["name"]?.stringValue == "John")
        #expect(scoresValue?.arrayValue?.count == 3)
        #expect(settingsValue?.objectValue?["theme"]?.stringValue == "dark")
        #expect(settingsValue?.objectValue?["notifications"]?.boolValue == true)
    }

    @Test("Round-trip conversion maintains types")
    func roundTripConversion() throws {
        let original: [String: Any] = [
            "int": 42,
            "double": 3.14,
            "wholeDouble": 100.0,
            "string": "test",
            "bool": true,
            "null": NSNull(),
            "array": [1, 2, 3],
            "object": ["nested": "value"],
        ]

        let typedValue = try TypedValue.fromJSON(original)
        let converted = typedValue.toJSON() as? [String: Any]

        #expect(converted?["int"] as? Int == 42)
        #expect(converted?["double"] as? Double == 3.14)
        #expect(converted?["wholeDouble"] as? Int == 100)
        #expect(converted?["string"] as? String == "test")
        #expect(converted?["bool"] as? Bool == true)
        #expect(converted?["null"] is NSNull)
        #expect((converted?["array"] as? [Any])?.count == 3)
        #expect((converted?["object"] as? [String: Any])?["nested"] as? String == "value")
    }

    @Test("Error handling for unsupported types")
    func unsupportedTypes() throws {
        struct CustomType {}
        let custom = CustomType()

        #expect(throws: TypedValueError.self) {
            _ = try TypedValue.fromJSON(custom)
        }
    }

    // MARK: - Hashable Tests

    @Test("Hashable conformance")
    func hashable() {
        var set = Set<TypedValue>()
        set.insert(.null)
        set.insert(.bool(true))
        set.insert(.int(42))
        set.insert(.string("test"))

        #expect(set.count == 4)
        #expect(set.contains(.null))
        #expect(set.contains(.bool(true)))
        #expect(set.contains(.int(42)))
        #expect(set.contains(.string("test")))

        set.insert(.int(42))
        #expect(set.count == 4)
    }

    // MARK: - Equatable Tests

    @Test("Equality comparison")
    func equality() {
        #expect(TypedValue.null == TypedValue.null)
        #expect(TypedValue.bool(true) == TypedValue.bool(true))
        #expect(TypedValue.bool(true) != TypedValue.bool(false))
        #expect(TypedValue.int(42) == TypedValue.int(42))
        #expect(TypedValue.int(42) != TypedValue.int(43))
        #expect(TypedValue.string("test") == TypedValue.string("test"))
        #expect(TypedValue.string("test") != TypedValue.string("other"))

        let array1 = TypedValue.array([.int(1), .string("two")])
        let array2 = TypedValue.array([.int(1), .string("two")])
        let array3 = TypedValue.array([.int(1), .string("three")])
        #expect(array1 == array2)
        #expect(array1 != array3)

        let object1 = TypedValue.object(["key": .string("value")])
        let object2 = TypedValue.object(["key": .string("value")])
        let object3 = TypedValue.object(["key": .string("other")])
        #expect(object1 == object2)
        #expect(object1 != object3)
    }
}
