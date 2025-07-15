// AXCommands.swift - AXCommand enum and individual command structs

import CoreGraphics
import Foundation

// MARK: - AXCommand and Command Structs

/// Enumeration of all supported AXorcist accessibility commands.
///
/// AXCommand defines the complete set of operations that can be performed
/// through the AXorcist accessibility automation framework. Each case
/// represents a specific type of operation with its associated parameters.
///
/// ## Topics
///
/// ### Element Discovery
/// - ``query(_:)``
/// - ``getElementAtPoint(_:)``
/// - ``getFocusedElement(_:)``
/// - ``collectAll(_:)``
///
/// ### Element Interaction
/// - ``performAction(_:)``
/// - ``setFocusedValue(_:)``
///
/// ### Element Information
/// - ``getAttributes(_:)``
/// - ``describeElement(_:)``
/// - ``extractText(_:)``
///
/// ### Advanced Operations
/// - ``batch(_:)``
/// - ``observe(_:)``
///
/// ### Command Properties
/// - ``type``
///
/// ## Usage
///
/// ```swift
/// // Create a query command
/// let queryCmd = QueryCommand(appName: "Safari", searchCriteria: [.role(.button)])
/// let command = AXCommand.query(queryCmd)
///
/// // Execute through AXorcist
/// let envelope = AXCommandEnvelope(commandID: "search", command: command)
/// let response = axorcist.runCommand(envelope)
/// ```
public enum AXCommand: Sendable {
    /// Searches for UI elements matching specified criteria.
    case query(QueryCommand)

    /// Performs an accessibility action on a target element.
    case performAction(PerformActionCommand)

    /// Retrieves specific accessibility attributes from an element.
    case getAttributes(GetAttributesCommand)

    /// Provides detailed information about an element's structure and properties.
    case describeElement(DescribeElementCommand)

    /// Extracts text content from an element and its descendants.
    case extractText(ExtractTextCommand)

    /// Executes multiple commands in a single batch operation.
    case batch(AXBatchCommand)

    /// Sets the value of the currently focused element.
    case setFocusedValue(SetFocusedValueCommand)

    /// Finds the UI element at specific screen coordinates.
    case getElementAtPoint(GetElementAtPointCommand)

    /// Retrieves the currently focused accessibility element.
    case getFocusedElement(GetFocusedElementCommand)

    /// Observes accessibility notifications from specified elements.
    case observe(ObserveCommand)

    /// Collects all elements from an application with optional filtering.
    case collectAll(CollectAllCommand)

    // MARK: Public

    /// String identifier for the command type.
    ///
    /// Returns a string representation of the command type, useful for
    /// logging, debugging, and protocol communication.
    public var type: String {
        switch self {
        case .query: "query"
        case .performAction: "performAction"
        case .getAttributes: "getAttributes"
        case .describeElement: "describeElement"
        case .extractText: "extractText"
        case .batch: "batch"
        case .setFocusedValue: "setFocusedValue"
        case .getElementAtPoint: "getElementAtPoint"
        case .getFocusedElement: "getFocusedElement"
        case .observe: "observe"
        case .collectAll: "collectAll"
        }
    }
}

/// Command envelope that wraps AXCommand instances for execution.
///
/// AXCommandEnvelope provides a container for AXCommand instances along with
/// a unique identifier for tracking and correlation purposes. This is the
/// primary interface used by AXorcist for command execution.
///
/// ## Topics
///
/// ### Properties
/// - ``commandID``
/// - ``command``
///
/// ### Creating Envelopes
/// - ``init(commandID:command:)``
///
/// ## Usage
///
/// ```swift
/// let queryCommand = QueryCommand(appName: "TextEdit", searchCriteria: [.role(.window)])
/// let envelope = AXCommandEnvelope(
///     commandID: "find-window",
///     command: .query(queryCommand)
/// )
/// let response = axorcist.runCommand(envelope)
/// ```
public struct AXCommandEnvelope: Sendable {
    // MARK: Lifecycle

    /// Creates a new command envelope.
    ///
    /// - Parameters:
    ///   - commandID: Unique identifier for tracking this command
    ///   - command: The accessibility command to execute
    public init(commandID: String, command: AXCommand) {
        self.commandID = commandID
        self.command = command
    }

    // MARK: Public

    /// Unique identifier for this command execution.
    ///
    /// Used for tracking, logging, and correlating commands with their responses.
    /// Should be unique across command executions for proper traceability.
    public let commandID: String

    /// The accessibility command to execute.
    ///
    /// Contains the specific operation and its parameters that will be
    /// performed by the AXorcist framework.
    public let command: AXCommand
}

// Individual command structs
public struct QueryCommand: Sendable {
    // MARK: Lifecycle

    public init(
        appIdentifier: String?,
        locator: Locator,
        attributesToReturn: [String]? = nil,
        maxDepthForSearch: Int = 10,
        includeChildrenBrief: Bool? = nil
    ) {
        self.appIdentifier = appIdentifier
        self.locator = locator
        self.attributesToReturn = attributesToReturn
        self.maxDepthForSearch = maxDepthForSearch
        self.includeChildrenBrief = includeChildrenBrief
    }

    // MARK: Public

    public let appIdentifier: String?
    public let locator: Locator
    public let attributesToReturn: [String]?
    public let maxDepthForSearch: Int
    public let includeChildrenBrief: Bool?
}

public struct PerformActionCommand: Sendable {
    // MARK: Lifecycle

    public init(
        appIdentifier: String?,
        locator: Locator,
        action: String,
        value: AnyCodable? = nil,
        maxDepthForSearch: Int = 10
    ) {
        self.appIdentifier = appIdentifier
        self.locator = locator
        self.action = action
        self.value = value
        self.maxDepthForSearch = maxDepthForSearch
    }

    // MARK: Public

    public let appIdentifier: String?
    public let locator: Locator
    public let action: String
    public let value: AnyCodable?
    public let maxDepthForSearch: Int
}

public struct GetAttributesCommand: Sendable {
    // MARK: Lifecycle

    public init(appIdentifier: String?, locator: Locator, attributes: [String], maxDepthForSearch: Int = 10) {
        self.appIdentifier = appIdentifier
        self.locator = locator
        self.attributes = attributes
        self.maxDepthForSearch = maxDepthForSearch
    }

    // MARK: Public

    public let appIdentifier: String?
    public let locator: Locator
    public let attributes: [String]
    public let maxDepthForSearch: Int
}

public struct DescribeElementCommand: Sendable {
    // MARK: Lifecycle

    public init(
        appIdentifier: String?,
        locator: Locator,
        formatOption: ValueFormatOption = .smart,
        maxDepthForSearch: Int = 10,
        depth: Int = 3,
        includeIgnored: Bool = false,
        maxSearchDepth: Int = 10
    ) {
        self.appIdentifier = appIdentifier
        self.locator = locator
        self.formatOption = formatOption
        self.maxDepthForSearch = maxDepthForSearch
        self.depth = depth
        self.includeIgnored = includeIgnored
        self.maxSearchDepth = maxSearchDepth
    }

    // MARK: Public

    public let appIdentifier: String?
    public let locator: Locator
    public let formatOption: ValueFormatOption
    public let maxDepthForSearch: Int
    public let depth: Int
    public let includeIgnored: Bool
    public let maxSearchDepth: Int
}

public struct ExtractTextCommand: Sendable {
    // MARK: Lifecycle

    public init(
        appIdentifier: String?,
        locator: Locator,
        maxDepthForSearch: Int = 10,
        includeChildren: Bool? = nil,
        maxDepth: Int? = nil
    ) {
        self.appIdentifier = appIdentifier
        self.locator = locator
        self.maxDepthForSearch = maxDepthForSearch
        self.includeChildren = includeChildren
        self.maxDepth = maxDepth
    }

    // MARK: Public

    public let appIdentifier: String?
    public let locator: Locator
    public let maxDepthForSearch: Int
    public let includeChildren: Bool?
    public let maxDepth: Int?
}

public struct SetFocusedValueCommand: Sendable {
    // MARK: Lifecycle

    public init(appIdentifier: String?, locator: Locator, value: String, maxDepthForSearch: Int = 10) {
        self.appIdentifier = appIdentifier
        self.locator = locator
        self.value = value
        self.maxDepthForSearch = maxDepthForSearch
    }

    // MARK: Public

    public let appIdentifier: String?
    public let locator: Locator
    public let value: String
    public let maxDepthForSearch: Int
}

public struct GetElementAtPointCommand: Sendable {
    // MARK: Lifecycle

    public init(
        point: CGPoint,
        appIdentifier: String? = nil,
        pid: Int? = nil,
        attributesToReturn: [String]? = nil,
        includeChildrenBrief: Bool? = nil
    ) {
        self.point = point
        self.appIdentifier = appIdentifier
        self.pid = pid
        self.xCoordinate = Float(point.x)
        self.yCoordinate = Float(point.y)
        self.attributesToReturn = attributesToReturn
        self.includeChildrenBrief = includeChildrenBrief
    }

    public init(
        appIdentifier: String?,
        x: Float,
        y: Float,
        attributesToReturn: [String]? = nil,
        includeChildrenBrief: Bool? = nil
    ) {
        self.point = CGPoint(x: CGFloat(x), y: CGFloat(y))
        self.xCoordinate = x
        self.yCoordinate = y
        self.appIdentifier = appIdentifier
        self.pid = nil
        self.attributesToReturn = attributesToReturn
        self.includeChildrenBrief = includeChildrenBrief
    }

    // MARK: Public

    public let point: CGPoint
    public let appIdentifier: String?
    public let pid: Int?
    public let xCoordinate: Float
    public let yCoordinate: Float
    public let attributesToReturn: [String]?
    public let includeChildrenBrief: Bool?
}

public struct GetFocusedElementCommand: Sendable {
    // MARK: Lifecycle

    public init(appIdentifier: String?, attributesToReturn: [String]? = nil, includeChildrenBrief: Bool? = nil) {
        self.appIdentifier = appIdentifier
        self.attributesToReturn = attributesToReturn
        self.includeChildrenBrief = includeChildrenBrief
    }

    // MARK: Public

    public let appIdentifier: String?
    public let attributesToReturn: [String]?
    public let includeChildrenBrief: Bool?
}

public struct ObserveCommand: Sendable {
    // MARK: Lifecycle

    public init(
        appIdentifier: String?,
        locator: Locator? = nil,
        notifications: [String],
        includeDetails: Bool = true,
        watchChildren: Bool = false,
        notificationName: AXNotification,
        includeElementDetails: [String]? = nil,
        maxDepthForSearch: Int = 10
    ) {
        self.appIdentifier = appIdentifier
        self.locator = locator
        self.notifications = notifications
        self.includeDetails = includeDetails
        self.watchChildren = watchChildren
        self.notificationName = notificationName
        self.includeElementDetails = includeElementDetails
        self.maxDepthForSearch = maxDepthForSearch
    }

    // MARK: Public

    public let appIdentifier: String?
    public let locator: Locator?
    public let notifications: [String]
    public let includeDetails: Bool
    public let watchChildren: Bool
    public let notificationName: AXNotification
    public let includeElementDetails: [String]?
    public let maxDepthForSearch: Int
}

// Command struct for collectAll
public struct CollectAllCommand: Sendable {
    // MARK: Lifecycle

    public init(
        appIdentifier: String? = nil, // Provide default nil
        attributesToReturn: [String]? = nil,
        maxDepth: Int = 10,
        filterCriteria: [String: String]? = nil,
        valueFormatOption: ValueFormatOption? = .smart
    ) {
        self.appIdentifier = appIdentifier
        self.attributesToReturn = attributesToReturn
        self.maxDepth = maxDepth
        self.filterCriteria = filterCriteria
        self.valueFormatOption = valueFormatOption
    }

    // MARK: Public

    public let appIdentifier: String?
    public let attributesToReturn: [String]?
    public let maxDepth: Int
    public let filterCriteria: [String: String]? // JSON string for criteria, or can be decoded
    public let valueFormatOption: ValueFormatOption?
}

// Batch command structures
/// Command for executing multiple accessibility operations in a single batch.
///
/// AXBatchCommand allows you to group multiple accessibility commands together
/// and execute them sequentially. This is useful for complex automation workflows
/// that require multiple steps to complete.
///
/// ## Topics
///
/// ### Batch Properties
/// - ``commands``
///
/// ### Creating Batches
/// - ``init(commands:)``
///
/// ### Sub-Command Types
/// - ``SubCommandEnvelope``
///
/// ## Usage
///
/// ```swift
/// let batch = AXBatchCommand(commands: [
///     .init(commandID: "find-window", command: .query(queryCmd)),
///     .init(commandID: "click-button", command: .performAction(actionCmd))
/// ])
/// let envelope = AXCommandEnvelope(commandID: "batch-workflow", command: .batch(batch))
/// ```
public struct AXBatchCommand: Sendable {
    // MARK: Lifecycle

    /// Creates a new batch command.
    ///
    /// - Parameter commands: Array of sub-commands to execute in sequence
    public init(commands: [SubCommandEnvelope]) {
        self.commands = commands
    }

    // MARK: Public

    /// Container for individual commands within a batch operation.
    ///
    /// SubCommandEnvelope wraps each individual command with its own identifier,
    /// allowing for granular tracking of batch operation progress.
    public struct SubCommandEnvelope: Sendable {
        // MARK: Lifecycle

        /// Creates a new sub-command envelope.
        ///
        /// - Parameters:
        ///   - commandID: Unique identifier for this sub-command
        ///   - command: The accessibility command to execute
        public init(commandID: String, command: AXCommand) {
            self.commandID = commandID
            self.command = command
        }

        // MARK: Public

        /// Unique identifier for this sub-command within the batch.
        public let commandID: String

        /// The accessibility command to execute.
        public let command: AXCommand
    }

    /// Array of commands to execute in sequence.
    ///
    /// Commands are executed in the order they appear in this array.
    /// If any command fails, the batch operation may continue or stop
    /// depending on the configuration.
    public let commands: [SubCommandEnvelope]
}
