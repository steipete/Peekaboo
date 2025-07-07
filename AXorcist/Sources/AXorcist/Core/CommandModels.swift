// CommandModels.swift - Contains command-related model structs

import Foundation

// Main command envelope - REPLACED with definition from axorc.swift for consistency
public struct CommandEnvelope: Codable {
    public let command_id: String
    public let command: CommandType // Uses CommandType from this file
    public let application: String?
    public let attributes: [String]?
    public let payload: [String: String]? // For ping compatibility
    public let debug_logging: Bool?
    public let locator: Locator? // Locator from this file
    public let path_hint: [String]?
    public let max_elements: Int?
    public let output_format: OutputFormat? // OutputFormat from this file
    public let action_name: String? // For performAction
    public let action_value: AnyCodable? // For performAction (AnyCodable from this file)
    public let sub_commands: [CommandEnvelope]? // For batch command

    // Added a public initializer for convenience, matching fields.
    public init(command_id: String,
                command: CommandType,
                application: String? = nil,
                attributes: [String]? = nil,
                payload: [String: String]? = nil,
                debug_logging: Bool? = nil,
                locator: Locator? = nil,
                path_hint: [String]? = nil,
                max_elements: Int? = nil,
                output_format: OutputFormat? = nil,
                action_name: String? = nil,
                action_value: AnyCodable? = nil,
                sub_commands: [CommandEnvelope]? = nil) {
        self.command_id = command_id
        self.command = command
        self.application = application
        self.attributes = attributes
        self.payload = payload
        self.debug_logging = debug_logging
        self.locator = locator
        self.path_hint = path_hint
        self.max_elements = max_elements
        self.output_format = output_format
        self.action_name = action_name
        self.action_value = action_value
        self.sub_commands = sub_commands
    }
}

// Locator for finding elements
public struct Locator: Codable {
    public var match_all: Bool?
    public var criteria: [String: String]
    public var root_element_path_hint: [String]?
    public var requireAction: String?
    public var computed_name_contains: String?

    enum CodingKeys: String, CodingKey {
        case match_all
        case criteria
        case root_element_path_hint
        case requireAction = "require_action"
        case computed_name_contains
    }

    public init(match_all: Bool? = nil, criteria: [String: String] = [:], root_element_path_hint: [String]? = nil,
                requireAction: String? = nil, computed_name_contains: String? = nil) {
        self.match_all = match_all
        self.criteria = criteria
        self.root_element_path_hint = root_element_path_hint
        self.requireAction = requireAction
        self.computed_name_contains = computed_name_contains
    }
}
