// CommandTypes.swift - Command type definitions

import Foundation

/// Supported command types for AXorcist accessibility operations.
///
/// Each command performs a specific accessibility task:
/// - Query operations: Find and filter elements
/// - Attribute operations: Get/set element properties
/// - Action operations: Perform UI interactions
/// - Observation: Subscribe to accessibility notifications
/// - Utility: System checks and batch operations
public enum CommandType: String, Codable, Sendable {
    case ping
    case query
    case getAttributes
    case describeElement
    case getElementAtPoint
    case getFocusedElement
    case performAction
    case batch
    case observe
    case collectAll
    case stopObservation
    case isProcessTrusted
    case isAXFeatureEnabled
    case setFocusedValue // Added from error
    case extractText // Added from error
    case setNotificationHandler // For AXObserver
    case removeNotificationHandler // For AXObserver
    case getElementDescription // Utility command for full description
}

/// Output format options for AXorcist command results.
///
/// Different formats optimize for various use cases:
/// - json: Machine-readable structured data
/// - verbose: Detailed human-readable output
/// - smart: Context-aware formatting (default)
/// - jsonString: JSON as string for embedded usage
/// - textContent: Text-only extraction
public enum OutputFormat: String, Codable, Sendable {
    case json
    case verbose
    case smart // Default, tries to be concise and informative
    case jsonString // JSON output as a string, often for AXpector.
    case textContent // Specifically for text content output, might ignore non-textual parts.
}
