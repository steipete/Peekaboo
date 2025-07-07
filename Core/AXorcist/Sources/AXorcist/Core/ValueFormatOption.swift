// ValueFormatOption.swift - Enum for specifying value formatting

import Foundation

// Enum for specifying how values, especially for descriptions, should be formatted.
public enum ValueFormatOption: String, Codable, Sendable {
    case smart // Tries to provide the most useful, possibly summarized, representation.
    case raw // Provides the raw or complete value, potentially verbose.
    case textContent // Specifically for text content extraction, might ignore non-textual parts.
    case stringified // For detailed string representation, often for logging or debugging.
}
