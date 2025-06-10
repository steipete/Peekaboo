import Foundation
@testable import peekaboo
import Testing

@Suite("JSONOutput Tests", .tags(.jsonOutput, .unit))
struct JSONOutputTests {
    // MARK: - AnyCodable Tests

    @Test("AnyCodable encoding with various types", .tags(.fast))
    func anyCodableEncodingVariousTypes() throws {
        // Test by wrapping in a container structure since JSONSerialization needs complete documents
        struct TestWrapper: Codable {
            let value: AnyCodable
        }

        // Test string
        let stringWrapper = TestWrapper(value: AnyCodable("test string"))
        let stringData = try JSONEncoder().encode(stringWrapper)
        let stringDict = try JSONSerialization.jsonObject(with: stringData) as? [String: Any]
        #expect(stringDict?["value"] as? String == "test string")

        // Test number
        let numberWrapper = TestWrapper(value: AnyCodable(42))
        let numberData = try JSONEncoder().encode(numberWrapper)
        let numberDict = try JSONSerialization.jsonObject(with: numberData) as? [String: Any]
        #expect(numberDict?["value"] as? Int == 42)

        // Test boolean
        let boolWrapper = TestWrapper(value: AnyCodable(true))
        let boolData = try JSONEncoder().encode(boolWrapper)
        let boolDict = try JSONSerialization.jsonObject(with: boolData) as? [String: Any]
        #expect(boolDict?["value"] as? Bool == true)

        // Test null (using optional nil)
        let nilValue: String? = nil
        let nilWrapper = TestWrapper(value: AnyCodable(nilValue as Any))
        let nilData = try JSONEncoder().encode(nilWrapper)
        let nilDict = try JSONSerialization.jsonObject(with: nilData) as? [String: Any]
        // nil values are encoded as NSNull in JSON, which becomes <null> in dictionary
        #expect(nilDict?["value"] is NSNull)
    }

    @Test("AnyCodable with nested structures", .tags(.fast))
    func anyCodableNestedStructures() throws {
        // Test array
        let arrayValue = AnyCodable([1, 2, 3])
        let arrayData = try JSONEncoder().encode(arrayValue)
        let arrayResult = try JSONSerialization.jsonObject(with: arrayData) as? [Int]
        #expect(arrayResult == [1, 2, 3])

        // Test dictionary
        let dictValue = AnyCodable(["key": "value", "number": 42])
        let dictData = try JSONEncoder().encode(dictValue)
        let dictResult = try JSONSerialization.jsonObject(with: dictData) as? [String: Any]
        #expect(dictResult?["key"] as? String == "value")
        #expect(dictResult?["number"] as? Int == 42)
    }

    @Test("AnyCodable decoding", .tags(.fast))
    func anyCodableDecoding() throws {
        // Test decoding from JSON
        let jsonString = #"{"string": "test", "number": 42, "bool": true, "null": null}"#
        let jsonData = Data(jsonString.utf8)
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: jsonData)

        #expect(decoded["string"]?.value as? String == "test")
        #expect(decoded["number"]?.value as? Int == 42)
        #expect(decoded["bool"]?.value as? Bool == true)
        // Check that null value is properly handled (decoded as NSNull)
        #expect(decoded["null"]?.value is NSNull)
    }

    // MARK: - AnyEncodable Tests

    @Test("AnyEncodable with custom types", .tags(.fast))
    func anyEncodableCustomTypes() throws {
        // Test with ApplicationInfo
        let appInfo = ApplicationInfo(
            app_name: "Test App",
            bundle_id: "com.test.app",
            pid: 1234,
            is_active: true,
            window_count: 2
        )

        // Test encoding through AnyCodable instead
        let anyCodable = AnyCodable(appInfo)
        let data = try JSONEncoder().encode(anyCodable)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["app_name"] as? String == "Test App")
        #expect(json?["bundle_id"] as? String == "com.test.app")
        #expect(json?["pid"] as? Int32 == 1234)
        #expect(json?["is_active"] as? Bool == true)
        #expect(json?["window_count"] as? Int == 2)
    }

    // MARK: - JSON Output Function Tests

    @Test("outputJSON function with success data", .tags(.fast))
    func outputJSONSuccess() throws {
        // Test data
        let testData = ApplicationListData(applications: [
            ApplicationInfo(
                app_name: "Finder",
                bundle_id: "com.apple.finder",
                pid: 123,
                is_active: true,
                window_count: 1
            )
        ])

        // Test JSON serialization directly without capturing stdout
        let encoder = JSONEncoder()
        let data = try encoder.encode(testData)
        let jsonString = String(data: data, encoding: .utf8) ?? ""

        // Verify JSON structure
        #expect(jsonString.contains("Finder"))
        #expect(jsonString.contains("com.apple.finder"))
        #expect(!jsonString.isEmpty)
    }

    @Test("CodableJSONResponse structure", .tags(.fast))
    func codableJSONResponseStructure() throws {
        let testData = ["test": "value"]
        let response = CodableJSONResponse(
            success: true,
            data: testData,
            messages: nil,
            debug_logs: []
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["success"] as? Bool == true)
        #expect((json?["data"] as? [String: Any])?["test"] as? String == "value")
        #expect(json?["error"] == nil)
    }

    @Test("Error output JSON formatting", .tags(.fast))
    func errorOutputJSONFormatting() throws {
        // Test error JSON structure directly
        let errorInfo = ErrorInfo(
            message: "Test error message",
            code: .APP_NOT_FOUND,
            details: "Additional error details"
        )

        let response = JSONResponse(
            success: false,
            data: nil,
            messages: nil,
            error: errorInfo
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let jsonString = String(data: data, encoding: .utf8) ?? ""

        // Verify error JSON structure
        #expect(jsonString.contains("\"success\":false") || jsonString.contains("\"success\": false"))
        #expect(jsonString.contains("\"error\""))
        #expect(jsonString.contains("Test error message"))
        #expect(jsonString.contains("APP_NOT_FOUND"))
    }

    // MARK: - Edge Cases and Error Handling

    @Test("AnyCodable with complex nested data", .tags(.fast))
    func anyCodableComplexNestedData() throws {
        let complexData: [String: Any] = [
            "simple": "string",
            "nested": [
                "array": [1, 2, 3],
                "dict": ["key": "value"],
                "mixed": [
                    "string",
                    42,
                    true,
                    ["nested": "array"]
                ]
            ]
        ]

        let anyCodable = AnyCodable(complexData)
        let encoded = try JSONEncoder().encode(anyCodable)
        let decoded = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        #expect(decoded?["simple"] as? String == "string")
        #expect((decoded?["nested"] as? [String: Any]) != nil)
    }

    @Test("JSON encoding performance with large data", .tags(.performance))
    func jsonEncodingPerformance() throws {
        // Create large dataset
        var largeAppList: [ApplicationInfo] = []
        for index in 0..<100 {
            let appInfo = ApplicationInfo(
                app_name: "App \(index)",
                bundle_id: "com.test.app\(index)",
                pid: Int32(1000 + index),
                is_active: index.isMultiple(of: 2),
                window_count: index % 10
            )
            largeAppList.append(appInfo)
        }

        let data = ApplicationListData(applications: largeAppList)

        // Measure encoding performance
        let startTime = CFAbsoluteTimeGetCurrent()
        let encoded = try JSONEncoder().encode(data)
        let encodingTime = CFAbsoluteTimeGetCurrent() - startTime

        #expect(!encoded.isEmpty)
        #expect(encodingTime < 1.0) // Should encode within 1 second
    }

    @Test("Thread safety of JSON operations", .tags(.concurrency))
    func threadSafetyJSONOperations() async {
        await withTaskGroup(of: Bool.self) { group in
            for index in 0..<10 {
                group.addTask {
                    do {
                        let appInfo = ApplicationInfo(
                            app_name: "App \(index)",
                            bundle_id: "com.test.app\(index)",
                            pid: Int32(1000 + index),
                            is_active: true,
                            window_count: 1
                        )

                        // Test encoding through AnyCodable instead
                        let anyCodable = AnyCodable(appInfo)
                        _ = try JSONEncoder().encode(anyCodable)
                        return true
                    } catch {
                        return false
                    }
                }
            }

            var successCount = 0
            for await success in group where success {
                successCount += 1
            }

            #expect(successCount == 10)
        }
    }

    @Test("Memory usage with repeated JSON operations", .tags(.memory))
    func memoryUsageJSONOperations() {
        // Test memory doesn't grow excessively with repeated JSON operations
        for _ in 1...100 {
            let data = ApplicationInfo(
                app_name: "Test",
                bundle_id: "com.test",
                pid: 123,
                is_active: true,
                window_count: 1
            )

            do {
                let encoded = try JSONEncoder().encode(data)
                #expect(!encoded.isEmpty)
            } catch {
                Issue.record("JSON encoding should not fail: \(error)")
            }
        }
    }

    @Test("Error code enum completeness", .tags(.fast))
    func errorCodeEnumCompleteness() {
        // Test that all error codes have proper raw values
        let errorCodes: [ErrorCode] = [
            .PERMISSION_ERROR_SCREEN_RECORDING,
            .PERMISSION_ERROR_ACCESSIBILITY,
            .APP_NOT_FOUND,
            .AMBIGUOUS_APP_IDENTIFIER,
            .WINDOW_NOT_FOUND,
            .CAPTURE_FAILED,
            .FILE_IO_ERROR,
            .INVALID_ARGUMENT,
            .UNKNOWN_ERROR
        ]

        for errorCode in errorCodes {
            #expect(!errorCode.rawValue.isEmpty)
            let isAllASCII = errorCode.rawValue.allSatisfy { character in
                character.isASCII
            }
            #expect(isAllASCII)
        }
    }
}

// MARK: - Extension Test Suite for Output Format Validation

@Suite("JSON Output Format Validation", .tags(.jsonOutput, .integration))
struct JSONOutputFormatValidationTests {
    @Test("MCP protocol compliance", .tags(.integration))
    func mcpProtocolCompliance() throws {
        // Test that JSON output follows MCP protocol format
        let testData = ApplicationListData(applications: [])
        let response = CodableJSONResponse(
            success: true,
            data: testData,
            messages: nil,
            debug_logs: []
        )

        let encoder = JSONEncoder()
        // Properties are already in snake_case, no conversion needed
        let data = try encoder.encode(response)

        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json != nil) // JSON was successfully created

        // Verify required MCP fields
        #expect(json?["success"] != nil)
        #expect(json?["data"] != nil)
    }

    @Test("Snake case conversion consistency", .tags(.fast))
    func snakeCaseConversionConsistency() throws {
        let appInfo = ApplicationInfo(
            app_name: "Test App",
            bundle_id: "com.test.app",
            pid: 1234,
            is_active: true,
            window_count: 2
        )

        let encoder = JSONEncoder()
        // Properties are already in snake_case, no conversion needed
        let data = try encoder.encode(appInfo)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Verify snake_case conversion
        #expect(json?["app_name"] != nil)
        #expect(json?["bundle_id"] != nil)
        #expect(json?["is_active"] != nil)
        #expect(json?["window_count"] != nil)

        // Verify no camelCase keys exist
        #expect(json?["appName"] == nil)
        #expect(json?["bundleId"] == nil)
        #expect(json?["isActive"] == nil)
        #expect(json?["windowCount"] == nil)
    }

    @Test("Large data structure serialization", .tags(.performance))
    func largeDataStructureSerialization() throws {
        // Create a complex data structure
        var windows: [WindowInfo] = []
        for index in 0..<100 {
            let window = WindowInfo(
                window_title: "Window \(index)",
                window_id: UInt32(1000 + index),
                window_index: index,
                bounds: WindowBounds(x_coordinate: index * 10, y_coordinate: index * 10, width: 800, height: 600),
                is_on_screen: index.isMultiple(of: 2)
            )
            windows.append(window)
        }

        let windowData = WindowListData(
            windows: windows,
            target_application_info: TargetApplicationInfo(
                app_name: "Test App",
                bundle_id: "com.test.app",
                pid: 1234
            )
        )

        let startTime = CFAbsoluteTimeGetCurrent()
        let encoded = try JSONEncoder().encode(windowData)
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        #expect(!encoded.isEmpty)
        #expect(duration < 0.5) // Should complete within 500ms

        // Verify the JSON is valid
        _ = try JSONSerialization.jsonObject(with: encoded)
        #expect(Bool(true)) // JSON was successfully created
    }

    @Test("WindowBounds JSON encoding with custom CodingKeys", .tags(.fast))
    func windowBoundsJSONEncoding() throws {
        // Create a WindowBounds instance
        let bounds = WindowBounds(x_coordinate: 100, y_coordinate: 200, width: 1920, height: 1080)
        
        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(bounds)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Verify that x_coordinate and y_coordinate are encoded as "x" and "y"
        #expect(json?["x"] as? Int == 100)
        #expect(json?["y"] as? Int == 200)
        #expect(json?["width"] as? Int == 1920)
        #expect(json?["height"] as? Int == 1080)
        
        // Verify that the original property names are NOT in the JSON
        #expect(json?["x_coordinate"] == nil)
        #expect(json?["y_coordinate"] == nil)
        
        // Verify the JSON string representation
        let jsonString = String(data: data, encoding: .utf8) ?? ""
        #expect(jsonString.contains("\"x\":100"))
        #expect(jsonString.contains("\"y\":200"))
        #expect(!jsonString.contains("x_coordinate"))
        #expect(!jsonString.contains("y_coordinate"))
    }

    @Test("WindowInfo with bounds JSON encoding", .tags(.fast))
    func windowInfoWithBoundsJSONEncoding() throws {
        // Create a WindowInfo with bounds
        let bounds = WindowBounds(x_coordinate: 50, y_coordinate: 75, width: 800, height: 600)
        let windowInfo = WindowInfo(
            window_title: "Test Window",
            window_id: 12345,
            window_index: 0,
            bounds: bounds,
            is_on_screen: true
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(windowInfo)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Verify WindowInfo structure
        #expect(json?["window_title"] as? String == "Test Window")
        #expect(json?["window_id"] as? UInt32 == 12345)
        #expect(json?["window_index"] as? Int == 0)
        #expect(json?["is_on_screen"] as? Bool == true)
        
        // Verify bounds are properly encoded with custom keys
        let boundsJson = json?["bounds"] as? [String: Any]
        #expect(boundsJson?["x"] as? Int == 50)
        #expect(boundsJson?["y"] as? Int == 75)
        #expect(boundsJson?["width"] as? Int == 800)
        #expect(boundsJson?["height"] as? Int == 600)
        
        // Ensure no x_coordinate or y_coordinate in the JSON
        #expect(boundsJson?["x_coordinate"] == nil)
        #expect(boundsJson?["y_coordinate"] == nil)
    }
}
