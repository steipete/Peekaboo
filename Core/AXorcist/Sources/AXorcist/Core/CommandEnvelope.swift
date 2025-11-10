// CommandEnvelope.swift - Main command envelope structure

import CoreGraphics // For CGPoint
import Foundation

/// The main command envelope structure for AXorcist operations.
///
/// CommandEnvelope wraps all the information needed to execute an accessibility
/// command, including the command type, target application, parameters, and options.
/// It serves as the primary interface for all AXorcist operations.
///
/// ## Topics
///
/// ### Core Properties
/// - ``commandId``
/// - ``command``
/// - ``application``
///
/// ### Command Parameters
/// - ``attributes``
/// - ``locator``
/// - ``maxElements``
/// - ``maxDepth``
///
/// ### Action Parameters
/// - ``actionName``
/// - ``actionValue``
/// - ``point``
/// - ``pid``
///
/// ### Batch Operations
/// - ``subCommands``
///
/// ### Observation
/// - ``notifications``
/// - ``includeElementDetails``
/// - ``watchChildren``
///
/// ## Usage
///
/// ```swift
/// let command = CommandEnvelope(
///     commandId: "find-button",
///     command: .query,
///     application: "MyApp",
///     locator: Locator(role: "button", title: "OK")
/// )
/// let response = axorcist.runCommand(command)
/// ```
public struct CommandEnvelope: Codable {
    // MARK: Lifecycle

    public init(commandId: String,
                command: CommandType,
                application: String? = nil,
                attributes: [String]? = nil,
                payload: [String: String]? = nil,
                debugLogging: Bool = false,
                locator: Locator? = nil,
                pathHint: [String]? = nil,
                maxElements: Int? = nil,
                maxDepth: Int? = nil,
                outputFormat: OutputFormat? = nil,
                actionName: String? = nil,
                actionValue: AnyCodable? = nil,
                subCommands: [CommandEnvelope]? = nil,
                point: CGPoint? = nil,
                pid: Int? = nil,
                notifications: [String]? = nil,
                includeElementDetails: [String]? = nil,
                watchChildren: Bool? = nil,
                filterCriteria: [String: String]? = nil,
                includeChildrenBrief: Bool? = nil,
                includeChildrenInText: Bool? = nil,
                includeIgnoredElements: Bool? = nil)
    {
        self.commandId = commandId
        self.command = command
        self.application = application
        self.attributes = attributes
        self.payload = payload
        self.debugLogging = debugLogging
        self.locator = locator
        self.pathHint = pathHint
        self.maxElements = maxElements
        self.maxDepth = maxDepth
        self.outputFormat = outputFormat
        self.actionName = actionName
        self.actionValue = actionValue
        self.subCommands = subCommands
        self.point = point
        self.pid = pid
        self.notifications = notifications
        self.includeElementDetails = includeElementDetails
        self.watchChildren = watchChildren
        self.filterCriteria = filterCriteria
        self.includeChildrenBrief = includeChildrenBrief
        self.includeChildrenInText = includeChildrenInText
        self.includeIgnoredElements = includeIgnoredElements
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        commandId = try container.decode(String.self, forKey: .commandId)
        command = try container.decode(CommandType.self, forKey: .command)
        application = try container.decodeIfPresent(String.self, forKey: .application)
        attributes = try container.decodeIfPresent([String].self, forKey: .attributes)
        payload = try container.decodeIfPresent([String: String].self, forKey: .payload)
        debugLogging = try container.decodeIfPresent(Bool.self, forKey: .debugLogging) ?? false
        locator = try container.decodeIfPresent(Locator.self, forKey: .locator)
        pathHint = try container.decodeIfPresent([String].self, forKey: .pathHint)
        maxElements = try container.decodeIfPresent(Int.self, forKey: .maxElements)
        maxDepth = try container.decodeIfPresent(Int.self, forKey: .maxDepth)
        outputFormat = try container.decodeIfPresent(OutputFormat.self, forKey: .outputFormat)
        actionName = try container.decodeIfPresent(String.self, forKey: .actionName)
        actionValue = try container.decodeIfPresent(AnyCodable.self, forKey: .actionValue)
        subCommands = try container.decodeIfPresent([CommandEnvelope].self, forKey: .subCommands)
        point = try container.decodeIfPresent(CGPoint.self, forKey: .point)
        pid = try container.decodeIfPresent(Int.self, forKey: .pid)
        notifications = try container.decodeIfPresent([String].self, forKey: .notifications)
        includeElementDetails = try container.decodeIfPresent([String].self, forKey: .includeElementDetails)
        watchChildren = try container.decodeIfPresent(Bool.self, forKey: .watchChildren)
        filterCriteria = try container.decodeIfPresent([String: String].self, forKey: .filterCriteria)
        includeChildrenBrief = try container.decodeIfPresent(Bool.self, forKey: .includeChildrenBrief)
        includeChildrenInText = try container.decodeIfPresent(Bool.self, forKey: .includeChildrenInText)
        includeIgnoredElements = try container.decodeIfPresent(Bool.self, forKey: .includeIgnoredElements)
    }

    // MARK: Public

    /// Unique identifier for this command execution.
    ///
    /// This ID is used for tracking and correlating commands with their responses,
    /// especially useful in batch operations or asynchronous processing.
    public let commandId: String

    /// The type of command to execute.
    ///
    /// Determines what operation will be performed (query, action, observation, etc.).
    public let command: CommandType

    /// Target application name or bundle identifier.
    ///
    /// Specifies which application the command should operate on. Can be an
    /// application name like "Safari" or a bundle identifier like "com.apple.Safari".
    public let application: String?

    /// Specific attributes to retrieve or filter by.
    ///
    /// When provided, limits the operation to only the specified accessibility attributes.
    public let attributes: [String]?

    /// Key-value payload for compatibility with ping operations.
    public let payload: [String: String]?

    /// Whether to enable debug logging for this command.
    public let debugLogging: Bool

    /// Element locator specifying how to find the target element.
    ///
    /// Provides search criteria for identifying specific UI elements within the application.
    public let locator: Locator?

    /// Legacy path hint for element location (deprecated).
    ///
    /// > Important: Use ``locator`` instead of this property for new code.
    public let pathHint: [String]?

    /// Maximum number of elements to return in search results.
    public let maxElements: Int?

    /// Maximum depth for hierarchical searches.
    ///
    /// Controls how deep into the UI element tree the search should traverse.
    public let maxDepth: Int?

    /// Output format for the command response.
    public let outputFormat: OutputFormat?

    /// Name of the action to perform for action commands.
    ///
    /// Examples: "AXPress", "AXShowMenu", "AXScrollToVisible"
    public let actionName: String?

    /// Value parameter for action commands.
    ///
    /// Some actions require additional parameters (e.g., scroll amount, text to enter).
    public let actionValue: AnyCodable?

    /// Sub-commands for batch operations.
    ///
    /// When present, this command represents a batch operation containing
    /// multiple individual commands to execute in sequence.
    public let subCommands: [CommandEnvelope]?

    /// Screen coordinates for point-based operations.
    ///
    /// Used with commands that need to interact with elements at specific screen locations.
    public let point: CGPoint?

    /// Process ID for targeting specific application instances.
    ///
    /// When multiple instances of an application are running, this specifies
    /// which instance to target.
    public let pid: Int?

    // MARK: - Observation Parameters

    /// Notification types to observe for observation commands.
    ///
    /// List of accessibility notification names to monitor (e.g., "AXValueChanged").
    public let notifications: [String]?

    /// Element details to include in observation notifications.
    ///
    /// Specifies which element attributes should be included when notifications are triggered.
    public let includeElementDetails: [String]?

    /// Whether to monitor child elements for notifications.
    ///
    /// When true, notifications from child elements will also be captured.
    public let watchChildren: Bool?

    // New field for collectAll filtering
    public let filterCriteria: [String: String]?

    // Additional fields for various commands
    public let includeChildrenBrief: Bool?
    public let includeChildrenInText: Bool?
    public let includeIgnoredElements: Bool?

    // MARK: Internal

    enum CodingKeys: String, CodingKey {
        case commandId
        case command
        case application
        case attributes
        case payload
        case debugLogging
        case locator
        case pathHint
        case maxElements
        case maxDepth
        case outputFormat
        case actionName
        case actionValue
        case subCommands
        case point
        case pid
        // CodingKeys for observe parameters
        case notifications
        case includeElementDetails
        case watchChildren
        // CodingKey for new field
        case filterCriteria
        // Additional CodingKeys
        case includeChildrenBrief
        case includeChildrenInText
        case includeIgnoredElements
    }
}
