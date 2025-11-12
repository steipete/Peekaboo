// TextExtraction.swift - Utilities for extracting text from accessibility elements

import ApplicationServices
import Foundation

@MainActor
public func extractTextFromElement(_ element: Element, maxDepth: Int = 5, currentDepth: Int = 0) -> String? {
    if currentDepth > maxDepth {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "extractTextFromElement: Max depth reached for element: " +
                "\(element.briefDescription(option: ValueFormatOption.smart))"
        ))
        return nil
    }

    // Attempt to get text from common attributes
    if let title = element.title(), !title.isEmpty { return title }
    if let value = element.value() as? String, !value.isEmpty { return value }
    if let description = element.descriptionText(), !description.isEmpty { return description }
    if let help = element.help(), !help.isEmpty { return help }

    // If no direct text, try children
    var childrenText: [String] = []
    if let children = element.children() { // children() is now synchronous
        for child in children {
            // Removed await
            if let childText = extractTextFromElement(child, maxDepth: maxDepth, currentDepth: currentDepth + 1) {
                childrenText.append(childText)
            }
        }
    }

    if !childrenText.isEmpty {
        return childrenText.joined(separator: " ")
    }

    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "extractTextFromElement: No text found for element: " +
            "\(element.briefDescription(option: ValueFormatOption.smart))"
    ))
    return nil
}

@MainActor
public func extractTextFromElementNonRecursive(_ element: Element) -> String? {
    // Try attributes that often hold primary text
    if let title = element.title(), !title.isEmpty { return title }
    if let value = element.value() as? String, !value.isEmpty { return value }
    if let description = element.descriptionText(), !description.isEmpty { return description }

    // Fallback to a broader set if primary ones fail
    // if let placeholder = element.placeholderValue(), !placeholder.isEmpty { return placeholder }
    if let help = element.help(), !help.isEmpty { return help }

    // Consider role description as a last resort if it's textual and meaningful
    // This might be too generic in many cases, so it's lower priority.
    // let roleDesc = element.roleDescription()
    // if let roleDesc = roleDesc, !roleDesc.isEmpty { return roleDesc }

    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "extractTextFromElementNonRecursive: No direct text found for element: " +
            "\(element.briefDescription(option: ValueFormatOption.smart))"
    ))
    return nil
}

// More focused text extraction, typically used by handlers.
@MainActor
func getElementTextualContent(
    element: Element,
    includeChildren: Bool = false,
    maxDepth: Int = 1,
    currentDepth: Int = 0
) -> String? {
    var textPieces: [String] = []

    // Prioritize attributes common for text content
    if let title: String = element.attribute(Attribute<String>.title) { textPieces.append(title) }
    if let value: String = element.attribute(Attribute<String>(AXAttributeNames.kAXValueAttribute)) {
        textPieces.append(value)
    }
    if let description: String = element.attribute(Attribute<String>.description) { textPieces.append(description) }
    // if let placeholder: String = element.attribute(Attribute<String>.placeholderValue) {
    //     textPieces.append(placeholder)
    // }
    // Less common but potentially useful
    // if let help: String = element.attribute(Attribute.help) { textPieces.append(help) }
    // if let selectedText: String = element.attribute(Attribute.selectedText) { textPieces.append(selectedText) }

    let joinedDirectText = textPieces.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

    if includeChildren, currentDepth < maxDepth {
        if let children = element.children() {
            var childTexts: [String] = []
            for child in children {
                // Recursive call is now synchronous
                if let childTextContent = getElementTextualContent(
                    element: child,
                    includeChildren: true,
                    maxDepth: maxDepth,
                    currentDepth: currentDepth + 1
                ) {
                    childTexts.append(childTextContent)
                }
            }
            let joinedChildText = childTexts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joinedChildText.isEmpty {
                // Smartly join parent and child text, avoiding duplicates if child text is part of parent text.
                if joinedDirectText.isEmpty {
                    return joinedChildText
                } else if joinedChildText.isEmpty {
                    return joinedDirectText
                } else {
                    // A more sophisticated joining might be needed if there's overlap.
                    // For now, simple space join.
                    return "\(joinedDirectText) \(joinedChildText)"
                }
            }
        }
    }

    if !joinedDirectText.isEmpty {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "TextExtraction/Content: Extracted '\(joinedDirectText)' for element " +
                "\(element.briefDescription(option: ValueFormatOption.smart)) " +
                "(children included: \(includeChildren), depth: \(currentDepth))"
        ))
        return joinedDirectText
    }

    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "TextExtraction/Content: No direct text found for " +
            "\(element.briefDescription(option: ValueFormatOption.smart)) " +
            "(children included: \(includeChildren), depth: \(currentDepth))"
    ))
    return nil
}
