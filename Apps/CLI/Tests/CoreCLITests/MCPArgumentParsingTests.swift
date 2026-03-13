//
//  MCPArgumentParsingTests.swift
//  PeekabooCLITests
//

import Foundation
import Testing
@testable import PeekabooCLI

@Suite(.tags(.safe))
struct MCPArgumentParsingTests {
    @Test func `parse JSON object object`() throws {
        let result = try MCPArgumentParsing.parseJSONObject(#"{"foo": "bar", "count": 2}"#)
        #expect(result["foo"] as? String == "bar")
        #expect(result["count"] as? Int == 2)
    }

    @Test func `parse JSON object null returns empty`() throws {
        let result = try MCPArgumentParsing.parseJSONObject("null")
        #expect(result.isEmpty)
    }

    @Test func `parse JSON object invalid type throws`() {
        let error = #expect(throws: MCPCommandError.self) {
            try MCPArgumentParsing.parseJSONObject(#"["not","object"]"#)
        }
        if case .invalidArguments = error {
            return
        }
        Issue.record("Expected invalidArguments, got \(error)")
    }

    @Test func `parse key value list parses`() throws {
        let result = try MCPArgumentParsing.parseKeyValueList(["A=1", "B=two"], label: "env")
        #expect(result["A"] == "1")
        #expect(result["B"] == "two")
    }

    @Test func `parse key value list rejects invalid`() {
        let error = #expect(throws: MCPCommandError.self) {
            _ = try MCPArgumentParsing.parseKeyValueList(["BADPAIR"], label: "env")
        }
        if case .invalidArguments = error {
            return
        }
        Issue.record("Expected invalidArguments, got \(error)")
    }
}
