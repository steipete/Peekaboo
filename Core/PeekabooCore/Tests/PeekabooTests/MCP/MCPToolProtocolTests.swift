import Testing
import Foundation
@testable import PeekabooCore
import MCP

@Suite("MCP Tool Protocol Tests")
struct MCPToolProtocolTests {
    
    // MARK: - ToolArguments Tests
    
    @Test("ToolArguments initialization from dictionary")
    func testToolArgumentsFromDictionary() {
        let rawArgs: [String: Any] = [
            "path": "/tmp/test.png",
            "format": "png",
            "quality": 0.9,
            "overwrite": true,
            "tags": ["screenshot", "test"]
        ]
        
        let args = ToolArguments(raw: rawArgs)
        
        #expect(args.getString("path") == "/tmp/test.png")
        #expect(args.getString("format") == "png")
        #expect(args.getNumber("quality") == 0.9)
        #expect(args.getBool("overwrite") == true)
        #expect(args.getStringArray("tags") == ["screenshot", "test"])
    }
    
    @Test("ToolArguments initialization from Value")
    func testToolArgumentsFromValue() {
        let value = Value.object([
            "name": .string("test"),
            "count": .int(42),
            "ratio": .double(3.14),
            "enabled": .bool(true),
            "items": .array([.string("a"), .string("b"), .string("c")])
        ])
        
        let args = ToolArguments(value: value)
        
        #expect(args.getString("name") == "test")
        #expect(args.getInt("count") == 42)
        #expect(args.getNumber("ratio") == 3.14)
        #expect(args.getBool("enabled") == true)
        #expect(args.getStringArray("items") == ["a", "b", "c"])
    }
    
    @Test("ToolArguments type conversion")
    func testToolArgumentsTypeConversion() {
        let args = ToolArguments(raw: [
            "stringAsInt": "123",
            "intAsString": 456,
            "doubleAsString": 7.89,
            "boolAsString": "true",
            "stringAsBool": "yes",
            "intAsBool": 1,
            "zeroAsBool": 0
        ])
        
        // String to number conversions
        #expect(args.getInt("stringAsInt") == 123)
        #expect(args.getNumber("stringAsInt") == 123.0)
        
        // Number to string conversions
        #expect(args.getString("intAsString") == "456")
        #expect(args.getString("doubleAsString") == "7.89")
        
        // Bool conversions
        #expect(args.getBool("boolAsString") == true)
        #expect(args.getBool("stringAsBool") == true)
        #expect(args.getBool("intAsBool") == true)
        #expect(args.getBool("zeroAsBool") == false)
    }
    
    @Test("ToolArguments empty and missing values")
    func testToolArgumentsEmptyAndMissing() {
        let emptyArgs = ToolArguments(raw: [:])
        #expect(emptyArgs.isEmpty == true)
        #expect(emptyArgs.getString("missing") == nil)
        #expect(emptyArgs.getInt("missing") == nil)
        #expect(emptyArgs.getBool("missing") == nil)
        
        let args = ToolArguments(raw: ["key": "value"])
        #expect(args.isEmpty == false)
        #expect(args.getValue(for: "missing") == nil)
    }
    
    @Test("ToolArguments decode to Codable type")
    func testToolArgumentsDecode() throws {
        struct TestInput: Codable, Equatable {
            let name: String
            let count: Int
            let enabled: Bool
            let tags: [String]?
        }
        
        let args = ToolArguments(raw: [
            "name": "Test",
            "count": 5,
            "enabled": true,
            "tags": ["a", "b"]
        ])
        
        let decoded = try args.decode(TestInput.self)
        #expect(decoded.name == "Test")
        #expect(decoded.count == 5)
        #expect(decoded.enabled == true)
        #expect(decoded.tags == ["a", "b"])
    }
    
    // MARK: - ToolResponse Tests
    
    @Test("ToolResponse text creation")
    func testToolResponseText() {
        let response = ToolResponse.text("Operation completed successfully")
        
        #expect(response.content.count == 1)
        #expect(response.isError == false)
        #expect(response.meta == nil)
        
        if case .text(let text) = response.content.first {
            #expect(text == "Operation completed successfully")
        } else {
            Issue.record("Expected text content")
        }
    }
    
    @Test("ToolResponse error creation")
    func testToolResponseError() {
        let response = ToolResponse.error("Something went wrong")
        
        #expect(response.content.count == 1)
        #expect(response.isError == true)
        
        if case .text(let text) = response.content.first {
            #expect(text == "Something went wrong")
        } else {
            Issue.record("Expected text content")
        }
    }
    
    @Test("ToolResponse image creation")
    func testToolResponseImage() {
        let imageData = Data("fake image data".utf8)
        let response = ToolResponse.image(data: imageData, mimeType: "image/jpeg")
        
        #expect(response.content.count == 1)
        #expect(response.isError == false)
        
        if case .image(let data, let mimeType, _) = response.content.first {
            #expect(data == imageData.base64EncodedString())
            #expect(mimeType == "image/jpeg")
        } else {
            Issue.record("Expected image content")
        }
    }
    
    @Test("ToolResponse with metadata")
    func testToolResponseWithMetadata() {
        let meta = Value.object([
            "duration": .double(1.5),
            "files": .array([.string("/tmp/file1.txt"), .string("/tmp/file2.txt")])
        ])
        
        let response = ToolResponse.text("Processed files", meta: meta)
        
        #expect(response.meta != nil)
        if let responseMeta = response.meta,
           case let .object(dict) = responseMeta {
            #expect(dict["duration"] as? Value == .double(1.5))
        }
    }
    
    @Test("ToolResponse multi-content")
    func testToolResponseMultiContent() {
        let contents: [MCP.Tool.Content] = [
            .text("Processing started"),
            .text("Step 1 complete"),
            .image(data: "imagedata".data(using: .utf8)!.base64EncodedString(), mimeType: "image/png", metadata: nil),
            .text("Processing complete")
        ]
        
        let response = ToolResponse.multiContent(contents)
        
        #expect(response.content.count == 4)
        #expect(response.isError == false)
        
        // Verify content types
        var textCount = 0
        var imageCount = 0
        
        for content in response.content {
            switch content {
            case .text: textCount += 1
            case .image: imageCount += 1
            case .audio: break // Not used in this test
            case .resource: break // Not used in this test
            }
        }
        
        #expect(textCount == 3)
        #expect(imageCount == 1)
    }
}

// MARK: - Mock Tool for Testing

struct MockTool: MCPTool {
    let name: String
    let description: String
    let inputSchema: Value
    var shouldFail: Bool = false
    var executionDelay: Double = 0
    
    func execute(arguments: ToolArguments) async throws -> ToolResponse {
        if executionDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(executionDelay * 1_000_000_000))
        }
        
        if shouldFail {
            return .error("Mock tool execution failed")
        }
        
        let message = arguments.getString("message") ?? "Default response"
        return .text(message, meta: .object(["toolName": .string(name)]))
    }
}

@Suite("Mock Tool Tests")
struct MockToolTests {
    
    @Test("Mock tool successful execution")
    func testMockToolSuccess() async throws {
        let tool = MockTool(
            name: "test",
            description: "Test tool",
            inputSchema: SchemaBuilder.object(
                properties: ["message": SchemaBuilder.string()],
                required: []
            )
        )
        
        let args = ToolArguments(raw: ["message": "Hello"])
        let response = try await tool.execute(arguments: args)
        
        #expect(response.isError == false)
        if case .text(let text) = response.content.first {
            #expect(text == "Hello")
        }
    }
    
    @Test("Mock tool failure")
    func testMockToolFailure() async throws {
        let tool = MockTool(
            name: "test",
            description: "Test tool",
            inputSchema: .object([:]),
            shouldFail: true
        )
        
        let response = try await tool.execute(arguments: ToolArguments(raw: [:]))
        
        #expect(response.isError == true)
        if case .text(let text) = response.content.first {
            #expect(text == "Mock tool execution failed")
        }
    }
    
    @Test("Mock tool with delay")
    func testMockToolWithDelay() async throws {
        let tool = MockTool(
            name: "slow",
            description: "Slow tool",
            inputSchema: .object([:]),
            executionDelay: 0.1 // 100ms
        )
        
        let start = Date()
        let response = try await tool.execute(arguments: ToolArguments(raw: [:]))
        let duration = Date().timeIntervalSince(start)
        
        #expect(duration >= 0.1)
        #expect(response.isError == false)
    }
}