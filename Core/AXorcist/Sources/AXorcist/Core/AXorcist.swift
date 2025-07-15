import AppKit // For NSRunningApplication
import ApplicationServices
import Foundation

/// The main class for AXorcist accessibility automation operations.
///
/// AXorcist provides a comprehensive interface for interacting with macOS accessibility APIs.
/// It supports querying UI elements, performing actions, extracting text, and batch operations.
///
/// ## Usage
///
/// ```swift
/// let axorcist = AXorcist.shared
/// let command = AXCommandEnvelope(commandID: "test", command: .query(queryCommand))
/// let response = axorcist.runCommand(command)
/// ```
///
/// ## Topics
///
/// ### Getting Started
/// - ``runCommand(_:)``
/// - ``shared``
///
/// ### Command Types
/// - ``AXCommandEnvelope``
/// - ``AXResponse``
@MainActor
public class AXorcist {
    // MARK: Lifecycle

    /// Creates a new AXorcist instance.
    @MainActor public init() {}

    // MARK: Public

    /// The shared singleton instance of AXorcist.
    ///
    /// Use this shared instance for most accessibility operations to ensure
    /// consistent state and avoid unnecessary resource allocation.
    public static let shared = AXorcist()

    /// Executes an accessibility command and returns the response.
    ///
    /// This is the central method for all AXorcist operations. It processes
    /// various types of accessibility commands including queries, actions,
    /// attribute retrieval, and batch operations.
    ///
    /// - Parameter commandEnvelope: The command envelope containing the command to execute
    /// - Returns: An ``AXResponse`` containing the result of the operation
    ///
    /// ## Example
    ///
    /// ```swift
    /// let queryCommand = AXQueryCommand(
    ///     appName: "Finder",
    ///     searchCriteria: [.role(.window)]
    /// )
    /// let envelope = AXCommandEnvelope(
    ///     commandID: "find-window",
    ///     command: .query(queryCommand)
    /// )
    /// let response = AXorcist.shared.runCommand(envelope)
    /// ```
    public func runCommand(_ commandEnvelope: AXCommandEnvelope) -> AXResponse {
        logger.log(AXLogEntry(
            level: .info,
            message: "RunCommand: ID '\(commandEnvelope.commandID)', Type: \(commandEnvelope.command.type)"
        ))

        let response: AXResponse = switch commandEnvelope.command {
        case let .query(queryCommand):
            handleQuery(command: queryCommand, maxDepth: queryCommand.maxDepthForSearch)
        case let .performAction(actionCommand):
            handlePerformAction(command: actionCommand)
        case let .getAttributes(getAttributesCommand):
            handleGetAttributes(command: getAttributesCommand)
        case let .describeElement(describeCommand):
            handleDescribeElement(command: describeCommand)
        case let .extractText(extractTextCommand):
            handleExtractText(command: extractTextCommand)
        case let .batch(batchCommandEnvelope):
            // The batch command itself is an envelope, pass it directly to handleBatchCommands.
            handleBatchCommands(command: batchCommandEnvelope)
        case let .setFocusedValue(setFocusedValueCommand):
            handleSetFocusedValue(command: setFocusedValueCommand)
        case let .getElementAtPoint(getElementAtPointCommand):
            handleGetElementAtPoint(command: getElementAtPointCommand)
        case let .getFocusedElement(getFocusedElementCommand):
            handleGetFocusedElement(command: getFocusedElementCommand)
        case let .observe(observeCommand):
            handleObserve(command: observeCommand)
        case let .collectAll(collectAllCommand):
            handleCollectAll(command: collectAllCommand)
            // Add other command types here
            // default:
            //     let errormsg = "AXorcist/RunCommand: Unknown command type: \(commandEnvelope.command.type)"
            //     logger.log(AXLogEntry(level: .error, message: errormsg))
            //     response = .errorResponse(message: errormsg, code: .unknownCommand)
        }

        logger.log(AXLogEntry(
            level: .info,
            message: "RunCommand ID '\(commandEnvelope.commandID)' completed. Status: \(response.status)"
        ))
        return response
    }

    // MARK: - Logger Methods

    public func getLogs() -> [String] {
        GlobalAXLogger.shared.getLogsAsStrings()
    }

    public func clearLogs() {
        GlobalAXLogger.shared.clearEntries()
        logger.log(AXLogEntry(level: .info, message: "Log history cleared."))
    }

    // MARK: Internal

    // MARK: - CollectAll Handler (New)

    func handleCollectAll(command: CollectAllCommand) -> AXResponse {
        logger.log(AXLogEntry(
            level: .info,
            message: "HandleCollectAll: Starting collection for app '\(command.appIdentifier ?? "focused")' " +
                "with maxDepth: \(command.maxDepth)"
        ))

        // Find the target application element
        let rootElement: Element
        if let appId = command.appIdentifier, appId != "focused" {
            // Find specific application
            if let appPid = pid(forAppIdentifier: appId),
               let app = Element.application(for: appPid)
            {
                rootElement = app
            } else {
                let errorMessage = "HandleCollectAll: Could not find application '\(appId)'."
                logger.log(AXLogEntry(level: .error, message: errorMessage))
                return .errorResponse(message: errorMessage, code: .applicationNotFound)
            }
        } else {
            // Use focused application
            if let app = Element.focusedApplication() {
                rootElement = app
            } else {
                let errorMessage = "HandleCollectAll: No focused application found."
                logger.log(AXLogEntry(level: .error, message: errorMessage))
                return .errorResponse(message: errorMessage, code: .applicationNotFound)
            }
        }

        // Collect all elements recursively
        var collectedElements: [AXElementData] = []
        let attributesToFetch = command.attributesToReturn ?? AXMiscConstants.defaultAttributesToFetch

        collectElementsRecursively(
            element: rootElement,
            currentDepth: 0,
            maxDepth: command.maxDepth,
            filterCriteria: command.filterCriteria,
            attributesToFetch: attributesToFetch,
            collectedElements: &collectedElements
        )

        logger.log(AXLogEntry(
            level: .info,
            message: "HandleCollectAll: Collected \(collectedElements.count) elements"
        ))

        return .successResponse(payload: AnyCodable([
            "elements": collectedElements,
            "count": collectedElements.count,
        ]))
    }

    // MARK: Private

    private let logger = GlobalAXLogger.shared // Use the shared logger

    private func collectElementsRecursively(
        element: Element,
        currentDepth: Int,
        maxDepth: Int,
        filterCriteria: [String: String]?,
        attributesToFetch: [String],
        collectedElements: inout [AXElementData]
    ) {
        // Check depth limit
        guard currentDepth <= maxDepth else { return }

        // Apply filter criteria if provided
        if let criteria = filterCriteria {
            guard elementMatchesCriteria(element, criteria: criteria) else { return }
        }

        // Build element data
        let elementData = buildQueryResponse(
            element: element,
            attributesToFetch: attributesToFetch,
            includeChildrenBrief: false
        )
        collectedElements.append(elementData)

        // Recursively collect children
        if let children = element.children() {
            for child in children {
                collectElementsRecursively(
                    element: child,
                    currentDepth: currentDepth + 1,
                    maxDepth: maxDepth,
                    filterCriteria: filterCriteria,
                    attributesToFetch: attributesToFetch,
                    collectedElements: &collectedElements
                )
            }
        }
    }
}
