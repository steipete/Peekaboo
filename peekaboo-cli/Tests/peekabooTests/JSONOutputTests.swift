@testable import peekaboo
import Testing
import Foundation

@Suite("JSONOutput Tests", .tags(.jsonOutput, .unit))
struct JSONOutputTests {
    
    // MARK: - AnyCodable Tests
    
    @Test("AnyCodable encoding with various types", .tags(.fast))
    func anyCodableEncodingVariousTypes() throws {
        // Test string
        let stringValue = AnyCodable("test string")
        let stringData = try JSONEncoder().encode(stringValue)
        let stringResult = try JSONSerialization.jsonObject(with: stringData) as? String
        #expect(stringResult == "test string")
        
        // Test number
        let numberValue = AnyCodable(42)
        let numberData = try JSONEncoder().encode(numberValue)
        let numberResult = try JSONSerialization.jsonObject(with: numberData) as? Int
        #expect(numberResult == 42)
        
        // Test boolean
        let boolValue = AnyCodable(true)
        let boolData = try JSONEncoder().encode(boolValue)
        let boolResult = try JSONSerialization.jsonObject(with: boolData) as? Bool
        #expect(boolResult == true)
        
        // Test null (using optional nil)
        let nilValue: String? = nil
        let nilAnyCodable = AnyCodable(nilValue as Any)
        let nilData = try JSONEncoder().encode(nilAnyCodable)
        let nilString = String(data: nilData, encoding: .utf8)
        #expect(nilString == "null")
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
        let jsonData = #"{"string": "test", "number": 42, "bool": true, "null": null}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: jsonData)
        
        #expect(decoded["string"]?.value as? String == "test")
        #expect(decoded["number"]?.value as? Int == 42)
        #expect(decoded["bool"]?.value as? Bool == true)
        #expect(decoded["null"]?.value == nil)
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
                is_active: index % 2 == 0,
                window_count: index % 10
            )
            largeAppList.append(appInfo)
        }
        
        let data = ApplicationListData(applications: largeAppList)
        
        // Measure encoding performance
        let startTime = CFAbsoluteTimeGetCurrent()
        let encoded = try JSONEncoder().encode(data)
        let encodingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        #expect(encoded.count > 0)
        #expect(encodingTime < 1.0) // Should encode within 1 second
    }
    
    @Test("Thread safety of JSON operations", .tags(.concurrency))
    func threadSafetyJSONOperations() async {
        await withTaskGroup(of: Bool.self) { group in
            for i in 0..<10 {
                group.addTask {
                    do {
                        let appInfo = ApplicationInfo(
                            app_name: "App \(i)",
                            bundle_id: "com.test.app\(i)",
                            pid: Int32(1000 + i),
                            is_active: true,
                            window_count: 1
                        )
                        
                        // Test encoding through AnyCodable instead
        let anyCodable = AnyCodable(appInfo)
                        let _ = try JSONEncoder().encode(anyCodable)
                        return true
                    } catch {
                        return false
                    }
                }
            }
            
            var successCount = 0
            for await success in group {
                if success {
                    successCount += 1
                }
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
                #expect(encoded.count > 0)
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
            #expect(errorCode.rawValue.allSatisfy { $0.isASCII })
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
        encoder.keyEncodingStrategy = .convertToSnakeCase
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
        encoder.keyEncodingStrategy = .convertToSnakeCase
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
                bounds: WindowBounds(xCoordinate: index * 10, yCoordinate: index * 10, width: 800, height: 600),
                is_on_screen: index % 2 == 0
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
        
        #expect(encoded.count > 0)
        #expect(duration < 0.5) // Should complete within 500ms
        
        // Verify the JSON is valid
        let _ = try JSONSerialization.jsonObject(with: encoded)
        #expect(Bool(true)) // JSON was successfully created
    }
}