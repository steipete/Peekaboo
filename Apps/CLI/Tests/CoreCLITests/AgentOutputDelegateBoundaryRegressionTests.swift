import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite(.tags(.safe), .serialized)
@MainActor
struct AgentOutputDelegateBoundaryRegressionTests {
    @Test(arguments: ["true", "null", "42", #""message""#, "[1,2]"])
    func `Valid JSON values reach verbose tool completion output`(_ result: String) async throws {
        let delegate = AgentOutputDelegate(outputMode: .verbose, jsonOutput: false, task: "test")

        let output = try await captureStandardOutputText {
            delegate.agentDidEmitEvent(.toolCallCompleted(name: "unknown_tool", result: result))
        }

        let formatted = try #require(formatJSON(result))
        #expect(output.contains("Result:"))
        #expect(output.contains(formatted))
        #expect(!output.contains("Invalid JSON result"))
    }

    @Test
    func `Malformed JSON completion remains invalid`() async throws {
        let delegate = AgentOutputDelegate(outputMode: .verbose, jsonOutput: false, task: "test")

        let output = try await captureStandardOutputText {
            delegate.agentDidEmitEvent(.toolCallCompleted(name: "unknown_tool", result: "invalid"))
        }

        #expect(output.contains("Invalid JSON result"))
        #expect(output.contains("Raw result: invalid"))
    }

    @Test(arguments: ["true", "null", "42", #""message""#])
    func `Formatter preserves scalar JSON values`(_ value: String) {
        #expect(formatJSON(value, indent: "") == value)
    }

    @Test
    func `Formatter preserves arrays and sorts object keys`() throws {
        let array = try #require(formatJSON("[1,2]", indent: ""))
        let arrayValue = try JSONSerialization.jsonObject(with: Data(array.utf8)) as? [Int]
        #expect(arrayValue == [1, 2])

        let object = try #require(formatJSON(#"{"b":2,"a":1}"#, indent: ""))
        let objectValue = try JSONSerialization.jsonObject(with: Data(object.utf8)) as? [String: Int]
        #expect(objectValue == ["a": 1, "b": 2])
        let firstKey = try #require(object.range(of: #""a""#))
        let secondKey = try #require(object.range(of: #""b""#))
        #expect(firstKey.lowerBound < secondKey.lowerBound)
        #expect(formatJSON("invalid") == nil)
    }

    @Test(arguments: [
        #"{"success":false,"error":"Agent execution was cancelled","cancelled":true}"#,
        #"{"error":"Legacy communication failure"}"#,
    ])
    func `Failed communication completion is never rendered as success`(_ result: String) async throws {
        let delegate = AgentOutputDelegate(outputMode: .verbose, jsonOutput: false, task: "test")

        let output = try await captureStandardOutputText {
            delegate.agentDidEmitEvent(.toolCallCompleted(name: "need_info", result: result))
        }

        #expect(output.contains("Error:"))
        #expect(!output.contains("Need Info completed"))
    }

    @Test
    func `Null error communication completion remains successful`() async throws {
        let delegate = AgentOutputDelegate(outputMode: .verbose, jsonOutput: false, task: "test")

        let output = try await captureStandardOutputText {
            delegate.agentDidEmitEvent(.toolCallCompleted(name: "need_info", result: #"{"error":null}"#))
        }

        #expect(output.contains("Need Info completed"))
        #expect(!output.contains("Error:"))
    }
}
