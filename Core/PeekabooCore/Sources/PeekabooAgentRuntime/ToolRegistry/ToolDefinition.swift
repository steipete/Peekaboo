import Foundation
import PeekabooAutomation
import Tachikoma

public struct PeekabooToolCommandDescription: Sendable {
    public let commandName: String
    public let abstract: String
    public let discussion: String

    public init(commandName: String, abstract: String, discussion: String) {
        self.commandName = commandName
        self.abstract = abstract
        self.discussion = discussion
    }
}

/// Represents a tool's complete definition used across CLI, agent, and documentation
@available(macOS 14.0, *)
public struct PeekabooToolDefinition: Sendable {
    public let name: String
    public let commandName: String? // CLI command name (if different from tool name)
    public let abstract: String // One-line description
    public let discussion: String // Detailed help with examples
    public let category: ToolCategory
    public let parameters: [ParameterDefinition]
    public let examples: [String]
    public let agentGuidance: String? // Special tips for AI agents

    public init(
        name: String,
        commandName: String? = nil,
        abstract: String,
        discussion: String,
        category: ToolCategory,
        parameters: [ParameterDefinition] = [],
        examples: [String] = [],
        agentGuidance: String? = nil)
    {
        self.name = name
        self.commandName = commandName
        self.abstract = abstract
        self.discussion = discussion
        self.category = category
        self.parameters = parameters
        self.examples = examples
        self.agentGuidance = agentGuidance
    }

    /// Generate CLI CommandDescription
    public var commandConfiguration: PeekabooToolCommandDescription {
        PeekabooToolCommandDescription(
            commandName: self.commandName ?? self.name,
            abstract: self.abstract,
            discussion: self.discussion)
    }

    /// Generate agent tool description
    public var agentDescription: String {
        if let guidance = agentGuidance {
            return "\(self.abstract)\n\n\(guidance)"
        }
        return self.abstract
    }
}

/// Represents a parameter definition
public struct ParameterDefinition: Sendable {
    public let name: String
    public let type: UnifiedParameterType
    public let description: String
    public let required: Bool
    public let defaultValue: String?
    public let options: [String]?
    public let cliOptions: CLIOptions? // CLI-specific options

    public init(
        name: String,
        type: UnifiedParameterType,
        description: String,
        required: Bool = false,
        defaultValue: String? = nil,
        options: [String]? = nil,
        cliOptions: CLIOptions? = nil)
    {
        self.name = name
        self.type = type
        self.description = description
        self.required = required
        self.defaultValue = defaultValue
        self.options = options
        self.cliOptions = cliOptions
    }
}

/// Parameter types matching both CLI and agent needs
public enum UnifiedParameterType: Sendable {
    case string
    case integer
    case number
    case boolean
    case enumeration
    case object
    case array
}

/// CLI-specific parameter options
public struct CLIOptions: Sendable {
    public let argumentType: ArgumentType
    public let shortName: Character?
    public let longName: String?

    public init(
        argumentType: ArgumentType,
        shortName: Character? = nil,
        longName: String? = nil)
    {
        self.argumentType = argumentType
        self.shortName = shortName
        self.longName = longName
    }

    public enum ArgumentType: Sendable {
        case argument // Positional argument
        case option // --name value
        case flag // --flag
    }
}

/// Tool categories for organization
public enum ToolCategory: String, CaseIterable, Sendable {
    case vision = "Vision"
    case automation = "UI Automation"
    case ui = "UI"
    case window = "Window Management"
    case app = "Applications"
    case application = "Application"
    case menu = "Menu/Dialog"
    case dialog = "Dialog"
    case dock = "Dock"
    case system = "System"
    case element = "Elements"
    case query = "Query"
    case completion = "Completion"

    public var icon: String {
        switch self {
        case .vision: "[see]️"
        case .automation, .ui: "👻"
        case .window: "[win]"
        case .app, .application: "[apps]"
        case .menu, .dialog: "[menu]"
        case .dock: "🚢"
        case .system: "⚙️"
        case .element, .query: "🔍"
        case .completion: "\(AgentDisplayTokens.Status.success)"
        }
    }
}
