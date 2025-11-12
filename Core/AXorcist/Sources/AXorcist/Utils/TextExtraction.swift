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
    if let placeholder = element.placeholderValue(), !placeholder.isEmpty { return placeholder }
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
    let directText = joinedText(from: collectDirectText(from: element))
    let childText = childText(
        for: element,
        includeChildren: includeChildren,
        maxDepth: maxDepth,
        currentDepth: currentDepth
    )

    let resolved = mergeText(directText: directText, childText: childText)
    logExtractionResult(
        resolvedText: resolved,
        element: element,
        includeChildren: includeChildren,
        depth: currentDepth
    )
    return resolved
}

@MainActor
private func collectDirectText(from element: Element) -> [String] {
    var pieces: [String] = []
    if let title: String = element.attribute(Attribute<String>.title), !title.isEmpty { pieces.append(title) }
    if let value: String = element.attribute(Attribute<String>(AXAttributeNames.kAXValueAttribute)), !value.isEmpty {
        pieces.append(value)
    }
    if let description: String = element.attribute(Attribute<String>.description), !description.isEmpty {
        pieces.append(description)
    }
    if let placeholder: String = element.attribute(Attribute<String>.placeholderValue), !placeholder.isEmpty {
        pieces.append(placeholder)
    }
    return pieces
}

@MainActor
private func childText(
    for element: Element,
    includeChildren: Bool,
    maxDepth: Int,
    currentDepth: Int
) -> String? {
    guard includeChildren, currentDepth < maxDepth, let children = element.children() else { return nil }
    let childTexts = children.compactMap { child in
        getElementTextualContent(
            element: child,
            includeChildren: true,
            maxDepth: maxDepth,
            currentDepth: currentDepth + 1
        )
    }
    return joinedText(from: childTexts)
}

@MainActor
private func joinedText(from pieces: [String]) -> String? {
    let joined = pieces.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    return joined.isEmpty ? nil : joined
}

@MainActor
private func mergeText(directText: String?, childText: String?) -> String? {
    switch (directText, childText) {
    case let (direct?, child?):
        if direct.isEmpty { return child }
        if child.isEmpty { return direct }
        return "\(direct) \(child)"
    case let (direct?, nil):
        return direct
    case let (nil, child?):
        return child
    default:
        return nil
    }
}

@MainActor
private func logExtractionResult(
    resolvedText: String?,
    element: Element,
    includeChildren: Bool,
    depth: Int
) {
    let descriptor = element.briefDescription(option: ValueFormatOption.smart)
    if let resolvedText {
        let message = """
        TextExtraction/Content: Extracted '\(resolvedText)' for element
        \(descriptor) (children included: \(includeChildren), depth: \(depth))
        """
        GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message: message))
    } else {
        let message = """
        TextExtraction/Content: No direct text found for \(descriptor)
        (children included: \(includeChildren), depth: \(depth))
        """
        GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message: message))
    }
}
