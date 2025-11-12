import AppKit // For NSRunningApplication
import ApplicationServices
import Foundation

// Note: Assumes Element, Attribute, AXValueWrapper, etc. are defined and accessible.
// Assumes GlobalAXLogger is available.

/// Extension providing element query and discovery handlers for AXorcist.
///
/// This extension handles:
/// - Element discovery using various locator strategies
/// - Tree traversal with configurable depth limits
/// - Property extraction and formatting
/// - Complex element matching and filtering
/// - Application targeting and focus management
@MainActor
public extension AXorcist {
    private func logQuery(_ level: AXLogLevel, _ parts: String...) {
        let message = parts.joined(separator: ", ")
        GlobalAXLogger.shared.log(AXLogEntry(level: level, message: message))
    }

    // MARK: - Query Handler

    func handleQuery(command: QueryCommand, maxDepth externalMaxDepth: Int?) -> AXResponse {
        logQuery(
            .info,
            "HandleQuery: App '\(command.appIdentifier ?? "focused")'",
            "Locator: \(command.locator)"
        )

        let appIdentifier = command.appIdentifier ?? "focused"
        let resolvedMaxDepth = externalMaxDepth ?? 10

        // DEBUG LOG FOR MAX DEPTH
        logQuery(
            .debug,
            "HandleQuery: externalMaxDepth = \(String(describing: externalMaxDepth))",
            "resolved maxDepth = \(resolvedMaxDepth)"
        )

        let (foundElement, findError) = findTargetElement(
            for: appIdentifier,
            locator: command.locator,
            maxDepthForSearch: resolvedMaxDepth
        )

        guard let element = foundElement else {
            let errorMessage = findError ??
                "HandleQuery: Element not found for app '\(appIdentifier)' with locator \(command.locator)."
            logQuery(.error, errorMessage)
            return .errorResponse(message: errorMessage, code: .elementNotFound)
        }
        logQuery(
            .debug,
            "HandleQuery: Found element: \(element.briefDescription(option: ValueFormatOption.smart))"
        )

        // Fetch attributes specified in command.attributesToReturn, or default if nil/empty
        let attributesToFetch = command.attributesToReturn ?? AXMiscConstants.defaultAttributesToFetch
        let elementData = buildQueryResponse(
            element: element,
            attributesToFetch: attributesToFetch,
            includeChildrenBrief: command.includeChildrenBrief ?? false
        )

        return .successResponse(payload: AnyCodable(elementData))
    }

    // MARK: - Get Attributes Handler

    func handleGetAttributes(command: GetAttributesCommand) -> AXResponse {
        logQuery(
            .info,
            "HandleGetAttrs: App '\(command.appIdentifier ?? "focused")'",
            "Locator: \(command.locator)",
            "Attributes: \(command.attributes.joined(separator: ", "))"
        )

        let (foundElement, findError) = findTargetElement(
            for: command.appIdentifier ?? "focused",
            locator: command.locator,
            maxDepthForSearch: command.maxDepthForSearch
        )

        guard let element = foundElement else {
            let fallbackError = [
                "HandleGetAttrs: Element not found for app '\(command.appIdentifier ?? "focused")'",
                "Locator: \(command.locator)"
            ].joined(separator: ", ")
            let errorMessage = findError ?? fallbackError
            logQuery(.error, errorMessage)
            return .errorResponse(message: errorMessage, code: .elementNotFound)
        }
        logQuery(
            .debug,
            "HandleGetAttrs: Found element: \(element.briefDescription(option: ValueFormatOption.smart))"
        )

        var attributesDict: [String: AXValueWrapper] = [:]
        for attrName in command.attributes {
            if let value: Any = element.attribute(Attribute<Any>(attrName)) {
                attributesDict[attrName] = AXValueWrapper(value: value)
            } else {
                attributesDict[attrName] = AXValueWrapper(value: nil) // Explicitly store nil for missing attributes
            }
        }

        let briefDesc = element.briefDescription(option: ValueFormatOption.smart)
        logQuery(
            .debug,
            "HandleGetAttrs: Attributes for '\(briefDesc)'",
            "\(attributesDict.mapValues { String(describing: $0.anyValue) })"
        )

        // Log fetched attributes for debugging purposes
        logQuery(
            .debug,
            "GetAttributes: Fetched attributes for \(briefDesc)",
            "\(attributesDict.mapValues { String(describing: $0.anyValue) })"
        )

        // Construct a simple payload containing just the attributes dictionary.
        // For a more structured response like AXElementData, we'd use buildQueryResponse or similar.
        struct AttributesPayload: Codable {
            let attributes: [String: AXValueWrapper]
            let elementDescription: String
        }
        let payload = AttributesPayload(attributes: attributesDict, elementDescription: briefDesc)

        return .successResponse(payload: AnyCodable(payload))
    }

    // MARK: - Describe Element Handler

    func handleDescribeElement(command: DescribeElementCommand) -> AXResponse {
        logQuery(
            .info,
            "HandleDescribe: App '\(command.appIdentifier ?? "focused")'",
            "Locator: \(command.locator)",
            "Depth: \(command.depth)",
            "IncludeIgnored: \(command.includeIgnored)"
        )

        let (foundElement, findError) = findTargetElement(
            for: command.appIdentifier ?? "focused",
            locator: command.locator,
            maxDepthForSearch: command.maxSearchDepth
        )

        guard let element = foundElement else {
            let fallbackError = [
                "HandleDescribe: Element not found for app '\(command.appIdentifier ?? "focused")'",
                "Locator: \(command.locator)"
            ].joined(separator: ", ")
            let errorMessage = findError ?? fallbackError
            logQuery(.error, errorMessage)
            return .errorResponse(message: errorMessage, code: .elementNotFound)
        }
        logQuery(
            .debug,
            "HandleDescribe: Found element: \(element.briefDescription(option: ValueFormatOption.smart))",
            "Describing tree..."
        )

        let descriptionTree = describeElementTree(
            element: element,
            depth: command.depth,
            includeIgnored: command.includeIgnored,
            currentDepth: 0
        )

        return .successResponse(payload: AnyCodable(descriptionTree))
    }

    // MARK: - Helper Methods for Querying

    internal func buildQueryResponse(
        element: Element,
        attributesToFetch: [String],
        includeChildrenBrief: Bool
    ) -> AXElementData {
        let fetchedAttributes = fetchInstanceElementAttributes(element: element, attributeNames: attributesToFetch)

        // Get all possible attribute names for this element
        let allAXAttributes = element.attributeNames()
        let textualContent = extractTextFromElement(element, maxDepth: 3) // MaxDepth set to 3 for brief text
        let childrenBriefs = includeChildrenBrief ?
            (element.children()?.map { $0.briefDescription(option: ValueFormatOption.smart) } ?? []) : nil
        let fullDesc = element.briefDescription(option: .stringified) // Using .stringified for a detailed description
        let pathArray = element.generatePathString().components(separatedBy: " -> ") // Convert path string to array

        let briefDescription = element.briefDescription(option: ValueFormatOption.smart)
        let role = element.role()
        // let fullDescription = element.briefDescription(option: .stringified) // This is synchronous - Commented out
        // as unused

        return AXElementData(
            briefDescription: briefDescription,
            role: role,
            attributes: fetchedAttributes,
            allPossibleAttributes: allAXAttributes,
            textualContent: textualContent,
            childrenBriefDescriptions: childrenBriefs,
            fullAXDescription: fullDesc,
            path: pathArray
        )
    }

    private func describeElementTree(
        element: Element,
        depth: Int,
        includeIgnored: Bool,
        currentDepth: Int
    ) -> AXElementDescription {
        if !includeIgnored, element.isIgnored() {
            // Return a minimal description for an ignored element if not including them
            return AXElementDescription(
                briefDescription: element.briefDescription(option: ValueFormatOption.smart) + " (Ignored)",
                role: element.role(),
                attributes: [:], // No attributes for ignored elements unless explicitly asked
                children: nil
            )
        }

        let attributes = fetchInstanceElementAttributes(
            element: element,
            attributeNames: AXMiscConstants.defaultAttributesToFetch
        )
        var childrenDescriptions: [AXElementDescription]?

        if currentDepth < depth {
            if let children = element.children() {
                childrenDescriptions = []
                for child in children {
                    if !includeIgnored, child.isIgnored() {
                        continue // Skip ignored children if not including them
                    }
                    childrenDescriptions?.append(describeElementTree(
                        element: child,
                        depth: depth,
                        includeIgnored: includeIgnored,
                        currentDepth: currentDepth + 1
                    ))
                }
                if childrenDescriptions?.isEmpty ?? true { childrenDescriptions = nil }
            }
        }

        return AXElementDescription(
            briefDescription: element.briefDescription(option: ValueFormatOption.smart),
            role: element.role(),
            attributes: attributes,
            children: childrenDescriptions
        )
    }

    private func fetchInstanceElementAttributes(
        element: Element,
        attributeNames: [String]
    ) -> [String: AXValueWrapper] {
        var attributesDict: [String: AXValueWrapper] = [:]
        for name in attributeNames {
            if let value: Any = element.attribute(Attribute<Any>(name)) {
                attributesDict[name] = AXValueWrapper(value: value)
            } else {
                // For attributes explicitly requested but not found, we might represent them as nil
                // or simply omit them. Current AXValueWrapper handles nils.
                attributesDict[name] = AXValueWrapper(value: nil)
            }
        }
        return attributesDict
    }
}
