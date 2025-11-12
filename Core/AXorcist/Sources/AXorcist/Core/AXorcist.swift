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

        let response = execute(commandEnvelope: commandEnvelope)

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
        let collectionContext = ElementCollectionContext(
            maxDepth: command.maxDepth,
            filterCriteria: command.filterCriteria,
            attributesToFetch: attributesToFetch
        )

        collectElementsRecursively(
            element: rootElement,
            currentDepth: 0,
            context: collectionContext,
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

    private func execute(commandEnvelope: AXCommandEnvelope) -> AXResponse {
        if let response = executeQueryRelatedCommands(commandEnvelope) {
            return response
        }
        if let response = executeInteractionCommands(commandEnvelope) {
            return response
        }
        return executeObserverCommands(commandEnvelope)
    }

    private func executeQueryRelatedCommands(_ envelope: AXCommandEnvelope) -> AXResponse? {
        switch envelope.command {
        case let .query(queryCommand):
            return handleQuery(command: queryCommand, maxDepth: queryCommand.maxDepthForSearch)
        case let .getAttributes(getAttributesCommand):
            return handleGetAttributes(command: getAttributesCommand)
        case let .describeElement(describeCommand):
            return handleDescribeElement(command: describeCommand)
        case let .collectAll(collectAllCommand):
            return handleCollectAll(command: collectAllCommand)
        default:
            return nil
        }
    }

    private func executeInteractionCommands(_ envelope: AXCommandEnvelope) -> AXResponse? {
        switch envelope.command {
        case let .performAction(actionCommand):
            return handlePerformAction(command: actionCommand)
        case let .extractText(extractTextCommand):
            return handleExtractText(command: extractTextCommand)
        case let .setFocusedValue(setFocusedValueCommand):
            return handleSetFocusedValue(command: setFocusedValueCommand)
        default:
            return nil
        }
    }

    private func executeObserverCommands(_ envelope: AXCommandEnvelope) -> AXResponse {
        switch envelope.command {
        case let .batch(batchCommandEnvelope):
            return handleBatchCommands(command: batchCommandEnvelope)
        case let .getElementAtPoint(getElementAtPointCommand):
            return handleGetElementAtPoint(command: getElementAtPointCommand)
        case let .getFocusedElement(getFocusedElementCommand):
            return handleGetFocusedElement(command: getFocusedElementCommand)
        case let .observe(observeCommand):
            return handleObserve(command: observeCommand)
        default:
            fatalError("Unsupported command type: \(envelope.command)")
        }
    }

    private func collectElementsRecursively(
        element: Element,
        currentDepth: Int,
        context: ElementCollectionContext,
        collectedElements: inout [AXElementData]
    ) {
        // Check depth limit
        guard currentDepth <= context.maxDepth else { return }

        // Apply filter criteria if provided
        if let criteria = context.filterCriteria {
            guard elementMatchesCriteria(element, criteria: criteria) else { return }
        }

        // Build element data
        let elementData = buildQueryResponse(
            element: element,
            attributesToFetch: context.attributesToFetch,
            includeChildrenBrief: false
        )
        collectedElements.append(elementData)

        // Recursively collect children
        if let children = element.children() {
            for child in children {
                collectElementsRecursively(
                    element: child,
                    currentDepth: currentDepth + 1,
                    context: context,
                    collectedElements: &collectedElements
                )
            }
        }
    }

    private struct ElementCollectionContext {
        let maxDepth: Int
        let filterCriteria: [String: String]?
        let attributesToFetch: [String]
    }
}
