import Foundation

// MARK: - JSON Formatting Helpers

/// Format JSON for pretty printing with optional indentation
func formatJSON(_ jsonString: String, indent: String = "   ") -> String? {
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
