import Foundation
import Testing
@testable import Tachikoma

@Suite("Streaming Types Tests")
struct StreamingTypesTests {
    @Test("StreamEvent creation and types")
    func streamEventCreationAndTypes() {
        let events: [StreamEvent] = [
            .textDelta(StreamTextDelta(delta: "Hello")),
            .responseCompleted(StreamResponseCompleted(id: "resp-1", finishReason: .stop)),
            .toolCallDelta(StreamToolCallDelta(id: "tool_123", index: 0, function: FunctionCallDelta(name: "get_", arguments: "{}"))),
            .toolCallCompleted(StreamToolCallCompleted(id: "tool_123", function: FunctionCall(name: "get_weather", arguments: "{\"location\": \"SF\"}"))),
            .reasoningSummaryDelta(StreamReasoningSummaryDelta(delta: "I need to think...")),
            .reasoningSummaryCompleted(StreamReasoningSummaryCompleted(summary: "I need to think about this carefully.")),
            .responseCompleted(StreamResponseCompleted(id: "resp-2", finishReason: .stop)),
            .error(StreamError(error: ErrorDetail(message: "Network error"))),
        ]
        
        #expect(events.count == 8)
        
        // Test specific event properties
        if case let .textDelta(delta) = events[0] {
            #expect(delta.delta == "Hello")
        } else {
            Issue.record("Expected textDelta event")
        }
        
        if case let .toolCallDelta(toolCallDelta) = events[2] {
            #expect(toolCallDelta.id == "tool_123")
            #expect(toolCallDelta.function.name == "get_")
            #expect(toolCallDelta.function.arguments == "{}")
        } else {
            Issue.record("Expected toolCallDelta event")
        }
        
        if case .responseCompleted = events[6] {
            // Expected
        } else {
            Issue.record("Expected responseCompleted event")
        }
    }

    @Test("StreamEvent Codable")
    func streamEventCodable() throws {
        let originalEvents: [StreamEvent] = [
            .textDelta(StreamTextDelta(delta: "Hello")),
            .toolCallCompleted(StreamToolCallCompleted(id: "tool_123", function: FunctionCall(name: "get_weather", arguments: "{\"location\": \"SF\"}"))),
            .responseCompleted(StreamResponseCompleted(id: "resp-1", finishReason: .stop)),
            .error(StreamError(error: ErrorDetail(message: "Network error"))),
        ]
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for originalEvent in originalEvents {
            let data = try encoder.encode(originalEvent)
            let decodedEvent = try decoder.decode(StreamEvent.self, from: data)
            
            // Compare events (simplified comparison)
            switch (originalEvent, decodedEvent) {
            case let (.textDelta(orig), .textDelta(decoded)):
                #expect(orig.delta == decoded.delta)
            case let (.toolCallCompleted(orig), .toolCallCompleted(decoded)):
                #expect(orig.id == decoded.id)
                #expect(orig.function.name == decoded.function.name)
                #expect(orig.function.arguments == decoded.function.arguments)
            case (.responseCompleted, .responseCompleted):
                // Expected
                break
            case let (.error(orig), .error(decoded)):
                #expect(orig.error.message == decoded.error.message)
            default:
                Issue.record("Event types don't match")
            }
        }
    }

    @Test("StreamingResponseIterator behavior")
    func streamingResponseIteratorBehavior() async throws {
        // Create a mock stream of events
        let events: [StreamEvent] = [
            .textDelta(StreamTextDelta(delta: "Hello")),
            .textDelta(StreamTextDelta(delta: " world")),
            .responseCompleted(StreamResponseCompleted(id: "test-1", usage: nil, finishReason: .stop))
        ]
        
        // Create an AsyncStream to simulate streaming
        let stream = AsyncThrowingStream<StreamEvent, any Error> { continuation in
            Task {
                for event in events {
                    continuation.yield(event)
                    try await Task.sleep(nanoseconds: 1_000_000) // 1ms delay
                }
                continuation.finish()
            }
        }
        
        // Collect events from the stream
        var collectedEvents: [StreamEvent] = []
        
        do {
            for try await event in stream {
                collectedEvents.append(event)
            }
        } catch {
            Issue.record("Stream iteration failed: \(error)")
        }
        
        #expect(collectedEvents.count == 3)
        
        // Verify event sequence
        if case let .textDelta(delta1) = collectedEvents[0] {
            #expect(delta1.delta == "Hello")
        } else {
            Issue.record("Expected first textDelta")
        }
        
        if case let .textDelta(delta2) = collectedEvents[1] {
            #expect(delta2.delta == " world")
        } else {
            Issue.record("Expected second textDelta")
        }
        
        if case .responseCompleted = collectedEvents[2] {
            // Expected
        } else {
            Issue.record("Expected responseCompleted event at end")
        }
    }

    @Test("StreamEvent error handling")
    func streamEventErrorHandling() async throws {
        let stream = AsyncThrowingStream<StreamEvent, any Error> { continuation in
            continuation.yield(.textDelta(StreamTextDelta(delta: "Hello")))
            continuation.finish(throwing: TachikomaError.networkError(underlying: NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Connection lost"])))
        }
        
        var collectedEvents: [StreamEvent] = []
        var caughtError: (any Error)?
        
        do {
            for try await event in stream {
                collectedEvents.append(event)
            }
        } catch {
            caughtError = error
        }
        
        #expect(collectedEvents.count == 1)
        #expect(caughtError is TachikomaError)
        
        if let tachikomaError = caughtError as? TachikomaError,
           case let .networkError(underlying) = tachikomaError {
            #expect(underlying.localizedDescription == "Connection lost")
        } else {
            Issue.record("Expected TachikomaError.networkError")
        }
    }
}

// MARK: - Tool Definition Tests

@Suite("Tool Definition Tests")
struct ToolDefinitionTests {
    @Test("Simple tool definition")
    func simpleToolDefinition() {
        let tool = ToolDefinition(
            function: FunctionDefinition(
                name: "get_time",
                description: "Get the current time",
                parameters: ToolParameters(
                    properties: [:],
                    required: []
                )
            )
        )
        
        #expect(tool.function.name == "get_time")
        #expect(tool.function.description == "Get the current time")
        #expect(tool.function.parameters.properties.isEmpty)
        #expect(tool.function.parameters.required.isEmpty)
    }

    @Test("Tool definition with parameters")
    func toolDefinitionWithParameters() {
        let tool = ToolDefinition(
            function: FunctionDefinition(
                name: "get_weather",
                description: "Get weather information",
                parameters: ToolParameters(
                    type: "object",
                    properties: [
                        "location": ParameterSchema(
                            type: .string,
                            description: "The location to get weather for"
                        ),
                        "units": ParameterSchema(
                            type: .string,
                            description: "Temperature units",
                            enumValues: ["celsius", "fahrenheit"]
                        ),
                        "include_forecast": ParameterSchema(
                            type: .boolean,
                            description: "Include forecast data"
                        )
                    ],
                    required: ["location"]
                )
            )
        )
        
        #expect(tool.function.name == "get_weather")
        #expect(tool.function.parameters.properties.count == 3)
        #expect(tool.function.parameters.required == ["location"])
        
        // Check parameter schemas
        let locationParam = tool.function.parameters.properties["location"]
        #expect(locationParam?.type == .string)
        #expect(locationParam?.description == "The location to get weather for")
        
        let unitsParam = tool.function.parameters.properties["units"]
        #expect(unitsParam?.enumValues == ["celsius", "fahrenheit"])
    }

    @Test("ParameterSchema types")
    func parameterSchemaTypes() {
        let schemas: [ParameterSchema] = [
            ParameterSchema(type: .string, description: "A string value"),
            ParameterSchema(type: .integer, description: "An integer value", minimum: 0, maximum: 100),
            ParameterSchema(type: .number, description: "A number value"),
            ParameterSchema(type: .boolean, description: "A boolean value"),
            ParameterSchema(type: .array, description: "An array value"),
            ParameterSchema(type: .object, description: "An object value"),
        ]
        
        #expect(schemas.count == 6)
        
        // Test specific properties
        let intSchema = schemas[1]
        #expect(intSchema.type == .integer)
        #expect(intSchema.minimum == 0)
        #expect(intSchema.maximum == 100)
    }

    @Test("Tool parameters codable")
    func toolParametersCodable() throws {
        let original = ToolParameters(
            type: "object",
            properties: [
                "name": ParameterSchema(type: .string, description: "Name field"),
                "age": ParameterSchema(type: .integer, description: "Age field", minimum: 0),
            ],
            required: ["name"]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolParameters.self, from: data)
        
        #expect(decoded.type == original.type)
        #expect(decoded.properties.count == original.properties.count)
        #expect(decoded.required == original.required)
        
        let nameParam = decoded.properties["name"]
        #expect(nameParam?.type == .string)
        #expect(nameParam?.description == "Name field")
    }

    @Test("Generic Tool creation")
    func genericToolCreation() async throws {
        // Context type for the tool
        struct WeatherContext {
            let apiKey: String
        }
        
        // Create a generic tool
        let weatherTool = Tool<WeatherContext>(
            name: "get_weather",
            description: "Get weather for a location",
            parameters: ToolParameters(
                properties: [
                    "location": ParameterSchema(type: .string, description: "Location name")
                ],
                required: ["location"]
            )
        ) { input, context in
            // Simulate tool execution
            var location = "Unknown"
            if case let .dictionary(dict) = input {
                location = dict["location"] as? String ?? "Unknown"
            }
            return .string("Weather in \(location): 72°F and sunny (API key: \(context.apiKey.prefix(3))...)")
        }
        
        // Convert to tool definition
        let toolDef = weatherTool.toToolDefinition()
        
        #expect(toolDef.function.name == "get_weather")
        #expect(toolDef.function.description == "Get weather for a location")
        
        // Test tool execution
        let context = WeatherContext(apiKey: "test-api-key-123")
        let input = ToolInput.dictionary(["location": "San Francisco"])
        
        let output = try await weatherTool.execute(input, context)
        
        if case let .string(result) = output {
            #expect(result.contains("San Francisco"))
            #expect(result.contains("test..."))
        } else {
            Issue.record("Expected string output")
        }
    }

    @Test("ToolCallItem creation")
    func toolCallItemCreation() {
        let toolCall = ToolCallItem(
            id: "call_abc123",
            type: .function,
            function: FunctionCall(
                name: "calculate",
                arguments: "{\"expression\": \"2 + 2\"}"
            )
        )
        
        #expect(toolCall.id == "call_abc123")
        #expect(toolCall.type == .function)
        #expect(toolCall.function.name == "calculate")
        #expect(toolCall.function.arguments == "{\"expression\": \"2 + 2\"}")
    }

    @Test("ToolInput and ToolOutput")
    func toolInputAndOutput() {
        let input = ToolInput.dictionary([
            "location": "Paris",
            "units": "celsius"
        ])
        
        if case let .dictionary(args) = input {
            #expect(args["location"] as? String == "Paris")
            #expect(args["units"] as? String == "celsius")
        } else {
            Issue.record("Expected dictionary input")
        }
        
        let output = ToolOutput.string("Weather in Paris: 18°C and cloudy")
        
        if case let .string(content) = output {
            #expect(content == "Weather in Paris: 18°C and cloudy")
        } else {
            Issue.record("Expected string output")
        }
    }

    @Test("FunctionCall argument parsing")
    func functionCallArgumentParsing() throws {
        let functionCall = FunctionCall(
            name: "get_weather",
            arguments: "{\"location\": \"Tokyo\", \"units\": \"celsius\"}"
        )
        
        #expect(functionCall.name == "get_weather")
        #expect(functionCall.arguments == "{\"location\": \"Tokyo\", \"units\": \"celsius\"}")
        
        // Test parsing arguments as JSON
        let data = functionCall.arguments.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(parsed?["location"] as? String == "Tokyo")
        #expect(parsed?["units"] as? String == "celsius")
    }

    @Test("ParameterSchema with complex properties")
    func parameterSchemaWithComplexProperties() {
        let schema = ParameterSchema(
            type: .object,
            description: "A complex object",
            properties: [
                "nested_string": ParameterSchema(type: .string, description: "Nested string"),
                "nested_array": ParameterSchema(type: .array, description: "Nested array"),
            ]
        )
        
        #expect(schema.type == .object)
        #expect(schema.properties?.count == 2)
        
        let nestedString = schema.properties?["nested_string"] as? ParameterSchema
        #expect(nestedString?.type == .string)
        #expect(nestedString?.description == "Nested string")
    }

    @Test("Tool definition JSON serialization")
    func toolDefinitionJSONSerialization() throws {
        let tool = ToolDefinition(
            function: FunctionDefinition(
                name: "calculate",
                description: "Perform a calculation",
                parameters: ToolParameters(
                    type: "object",
                    properties: [
                        "expression": ParameterSchema(
                            type: .string,
                            description: "Mathematical expression to evaluate"
                        )
                    ],
                    required: ["expression"]
                )
            )
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let jsonData = try encoder.encode(tool)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        #expect(jsonString.contains("calculate"))
        #expect(jsonString.contains("Perform a calculation"))
        #expect(jsonString.contains("expression"))
        #expect(jsonString.contains("Mathematical expression"))
        
        // Test round-trip encoding/decoding
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ToolDefinition.self, from: jsonData)
        
        #expect(decoded.function.name == tool.function.name)
        #expect(decoded.function.description == tool.function.description)
        #expect(decoded.function.parameters.required == tool.function.parameters.required)
    }
}