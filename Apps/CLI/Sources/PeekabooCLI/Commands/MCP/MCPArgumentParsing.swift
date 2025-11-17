//
//  MCPArgumentParsing.swift
//  PeekabooCLI
//

import Foundation

enum MCPArgumentParsing {
    static func parseJSONObject(_ raw: String) throws -> [String: Any] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [:] }
        guard let data = trimmed.data(using: .utf8) else {
            throw MCPCommandError.invalidArguments("Arguments must be valid UTF-8 text")
        }

        let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])

        if let dict = json as? [String: Any] {
            return dict
        }

        if json is NSNull {
            return [:]
        }

        throw MCPCommandError.invalidArguments("MCP tool arguments must be a JSON object")
    }

    static func parseKeyValueList(_ items: [String], label: String) throws -> [String: String] {
        var result: [String: String] = [:]
        for item in items {
            let parts = item.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                result[String(parts[0])] = String(parts[1])
            } else {
                throw MCPCommandError.invalidArguments("Invalid \(label) format: \(item). Use key=value")
            }
        }
        return result
    }
}
