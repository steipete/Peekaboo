// AttributeFormatter.swift - Contains functions for formatting element attributes for display

import ApplicationServices
import Foundation

// Helper function to format the parent attribute
@MainActor
func formatParentAttribute(
    _ parent: Element?,
    outputFormat: OutputFormat,
    valueFormatOption: ValueFormatOption
) -> AnyCodable {
    guard let parentElement = parent else { return AnyCodable(nil as String?) }
    if outputFormat == .textContent {
        return AnyCodable("Element: \(parentElement.role() ?? "?Role")")
    } else {
        return AnyCodable(parentElement.briefDescription(option: valueFormatOption))
    }
}

// Helper function to format the children attribute
@MainActor
func formatChildrenAttribute(
    _ children: [Element]?,
    outputFormat: OutputFormat,
    valueFormatOption: ValueFormatOption
) -> AnyCodable {
    guard let actualChildren = children, !actualChildren.isEmpty else {
        return AnyCodable(nil as String?)
    }

    if outputFormat == .textContent {
        var childrenSummaries: [String] = []
        for childElement in actualChildren {
            childrenSummaries.append(childElement.briefDescription(option: valueFormatOption))
        }
        return AnyCodable("[\(childrenSummaries.joined(separator: ", "))]")
    } else {
        let childrenDescriptions = actualChildren.map { $0.briefDescription(option: valueFormatOption) }
        return AnyCodable(childrenDescriptions)
    }
}

// Helper function to format the focused UI element attribute
@MainActor
func formatFocusedUIElementAttribute(
    _ focusedElement: Element?,
    outputFormat: OutputFormat,
    valueFormatOption: ValueFormatOption
) -> AnyCodable {
    guard let actualFocusedElement = focusedElement else { return AnyCodable(nil as String?) }
    if outputFormat == .textContent {
        return AnyCodable("Element: \(actualFocusedElement.role() ?? "?Role")")
    } else {
        return AnyCodable(actualFocusedElement.briefDescription(option: valueFormatOption))
    }
}
