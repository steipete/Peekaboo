// ModelEnums.swift - Contains enum definitions for the AXorcist models

import Foundation

// Enum for output formatting options
public enum OutputFormat: String, Codable {
    case smart // Default, tries to be concise and informative
    case verbose // More detailed output, includes more attributes/info
    case text_content // Primarily extracts textual content
    case json_string // Returns the attributes as a JSON string (new)
}

// Define CommandType enum
public enum CommandType: String, Codable {
    case query
    case performAction = "performAction"
    case getAttributes = "getAttributes"
    case batch
    case describeElement = "describeElement"
    case getFocusedElement = "getFocusedElement"
    case collectAll = "collectAll"
    case extractText = "extractText"
    case ping
    // Add future commands here, ensuring case matches JSON or provide explicit raw value
}
