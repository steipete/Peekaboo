//
//  MenuSystemToolFormatter+Dialog.swift
//  PeekabooCore
//

import Foundation

extension MenuSystemToolFormatter {
    // MARK: - Dialog Tools

    func formatDialogInputResult(_ result: [String: Any]) -> String {
        var parts: [String] = []

        parts.append("→ Entered")

        if let text = ToolResultExtractor.string("text", from: result) {
            let displayText = text.count > 50
                ? String(text.prefix(47)) + "..."
                : text
            parts.append("\"\(displayText)\"")
        }

        if let dialogTitle = ToolResultExtractor.string("dialogTitle", from: result) {
            parts.append("in \"\(dialogTitle)\"")
        } else if let dialogType = ToolResultExtractor.string("dialogType", from: result) {
            parts.append("in \(dialogType) dialog")
        }

        if let field = ToolResultExtractor.string("field", from: result) {
            parts.append("(\(field))")
        }

        var details: [String] = []

        if let submitted = ToolResultExtractor.bool("submitted", from: result), submitted {
            details.append("submitted")
        }

        if let confirmed = ToolResultExtractor.bool("confirmed", from: result), confirmed {
            details.append("confirmed")
        }

        if let validation = ToolResultExtractor.string("validation", from: result) {
            details.append("validation: \(validation)")
        }

        if !details.isEmpty {
            parts.append("[\(details.joined(separator: ", "))]")
        }

        return parts.joined(separator: " ")
    }

    func formatDialogClickResult(_ result: [String: Any]) -> String {
        var parts: [String] = []

        parts.append("→ Clicked")

        if let button = ToolResultExtractor.string("button", from: result) {
            parts.append("\"\(button)\"")
        }

        if let dialogTitle = ToolResultExtractor.string("dialogTitle", from: result) {
            parts.append("in \"\(dialogTitle)\"")
        }

        var details: [String] = []

        if let action = ToolResultExtractor.string("action", from: result) {
            details.append(action)
        }

        if let saved = ToolResultExtractor.bool("saved", from: result), saved {
            details.append("saved changes")
        }

        if let cancelled = ToolResultExtractor.bool("cancelled", from: result), cancelled {
            details.append("cancelled")
        }

        if let closed = ToolResultExtractor.bool("dialogClosed", from: result), closed {
            details.append("dialog closed")
        }

        if !details.isEmpty {
            parts.append("• \(details.joined(separator: ", "))")
        }

        return parts.joined(separator: " ")
    }
}
