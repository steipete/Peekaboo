import Foundation

// MARK: - JSON Formatting Helpers

/// Format JSON for pretty printing with optional indentation
public func formatJSON(_ jsonString: String, indent: String = "   ") -> String? {
    guard let data = jsonString.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data),
          let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
          let prettyString = String(data: prettyData, encoding: .utf8) else {
        return nil
    }

    // Add indentation to each line
    return prettyString
        .split(separator: "\n")
        .map { indent + $0 }
        .joined(separator: "\n")
}

/// Parse JSON string arguments into a dictionary
public func parseArguments(_ arguments: String) -> [String: Any] {
    guard let data = arguments.data(using: .utf8),
          let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return [:]
    }
    return args
}

/// Parse JSON result string into a dictionary
public func parseResult(_ rawResult: String) -> [String: Any]? {
    guard let data = rawResult.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }
    return json
}
