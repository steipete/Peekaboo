import Foundation

enum MCPCommandError: Error {
    case invalidArguments
}

enum MCPArgumentParsing {
    static func parseJSONObject(_ raw: String) throws -> [String: Any] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "null" {
            return [:]
        }

        guard let data = trimmed.data(using: .utf8) else {
            throw MCPCommandError.invalidArguments
        }

        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = obj as? [String: Any] else {
            throw MCPCommandError.invalidArguments
        }

        return dict
    }

    static func parseKeyValueList(_ pairs: [String], label _: String) throws -> [String: String] {
        var result: [String: String] = [:]
        result.reserveCapacity(pairs.count)

        for pair in pairs {
            guard let idx = pair.firstIndex(of: "=") else {
                throw MCPCommandError.invalidArguments
            }
            let key = String(pair[..<idx])
            let value = String(pair[pair.index(after: idx)...])
            guard !key.isEmpty else {
                throw MCPCommandError.invalidArguments
            }
            result[key] = value
        }

        return result
    }
}
