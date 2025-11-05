//
//  ElementToolFormatter.swift
//  Peekaboo
//

import Foundation

/// Formatter for element-related tools
struct ElementToolFormatter: MacToolFormatterProtocol {
    let handledTools: Set<String> = ["find_element", "list_elements", "focused"]

    func formatSummary(toolName: String, arguments: [String: Any]) -> String? {
        switch toolName {
        case "find_element":
            self.formatFindElementSummary(arguments)
        case "list_elements":
            self.formatListElementsSummary(arguments)
        case "focused":
            "Get focused element"
        default:
            nil
        }
    }

    func formatResult(toolName: String, result: [String: Any]) -> String? {
        switch toolName {
        case "find_element":
            self.formatFindElementResult(result)
        case "list_elements":
            self.formatListElementsResult(result)
        case "focused":
            self.formatFocusedResult(result)
        default:
            nil
        }
    }

    // MARK: - Find Element

    private func formatFindElementSummary(_ args: [String: Any]) -> String {
        var parts = ["Find"]

        if let type = args["type"] as? String {
            parts.append(type)
        }

        if let name = args["name"] as? String {
            parts.append("'\(name)'")
        } else if let label = args["label"] as? String {
            parts.append("'\(label)'")
        } else if let title = args["title"] as? String {
            parts.append("'\(title)'")
        }

        return parts.joined(separator: " ")
    }

    private func formatFindElementResult(_ result: [String: Any]) -> String? {
        if let found = result["found"] as? Bool {
            if found {
                if let element = result["element"] as? [String: Any] {
                    var parts = ["Found"]

                    if let type = element["type"] as? String {
                        parts.append(type)
                    }

                    if let label = element["label"] as? String {
                        parts.append("'\(label)'")
                    } else if let title = element["title"] as? String {
                        parts.append("'\(title)'")
                    }

                    return parts.joined(separator: " ")
                }
                return "Found element"
            } else {
                return "Element not found"
            }
        }
        return nil
    }

    // MARK: - List Elements

    private func formatListElementsSummary(_ args: [String: Any]) -> String {
        var parts = ["List"]

        if let type = args["type"] as? String {
            parts.append("\(type) elements")
        } else {
            parts.append("elements")
        }

        if let app = args["app"] as? String {
            parts.append("in \(app)")
        }

        return parts.joined(separator: " ")
    }

    private func formatListElementsResult(_ result: [String: Any]) -> String? {
        if let count = result["count"] as? Int {
            if let type = result["type"] as? String {
                return "Found \(count) \(type) element\(count == 1 ? "" : "s")"
            }
            return "Found \(count) element\(count == 1 ? "" : "s")"
        } else if let elements = result["elements"] as? [[String: Any]] {
            if let type = result["type"] as? String {
                return "Found \(elements.count) \(type) element\(elements.count == 1 ? "" : "s")"
            }
            return "Found \(elements.count) element\(elements.count == 1 ? "" : "s")"
        }
        return "Listed elements"
    }

    // MARK: - Focused

    private func formatFocusedResult(_ result: [String: Any]) -> String? {
        if let element = result["element"] as? [String: Any] {
            var parts: [String] = []

            if let type = element["type"] as? String {
                parts.append(type)
            }

            if let label = element["label"] as? String {
                parts.append("'\(label)'")
            } else if let title = element["title"] as? String {
                parts.append("'\(title)'")
            } else if let value = element["value"] as? String {
                let displayValue = value.count > 30
                    ? String(value.prefix(30)) + "..."
                    : value
                parts.append("'\(displayValue)'")
            }

            if !parts.isEmpty {
                return "Focused: " + parts.joined(separator: " ")
            }
        }

        return "No element focused"
    }
}
