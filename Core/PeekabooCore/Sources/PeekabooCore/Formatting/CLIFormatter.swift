import Foundation

/// Formatter for presenting UnifiedToolOutput in CLI contexts
public enum CLIFormatter {
    /// Format any UnifiedToolOutput for CLI display
    public static func format(_ output: UnifiedToolOutput<some Any>) -> String {
        var result = output.summary.brief

        // Add counts if any
        if !output.summary.counts.isEmpty {
            let countsStr = output.summary.counts
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: ", ")
            result += " (\(countsStr))"
        }

        // Add highlights
        for highlight in output.summary.highlights {
            result += "\n"
            switch highlight.kind {
            case .primary:
                result += "→ \(highlight.label): \(highlight.value)"
            case .warning:
                result += "⚠️  \(highlight.label): \(highlight.value)"
            case .info:
                result += "ℹ️  \(highlight.label): \(highlight.value)"
            }
        }

        // Add type-specific formatting
        result += self.formatSpecificData(output.data)

        // Add warnings if any
        if !output.metadata.warnings.isEmpty {
            result += "\n\nWarnings:"
            for warning in output.metadata.warnings {
                result += "\n⚠️  \(warning)"
            }
        }

        // Add hints if any
        if !output.metadata.hints.isEmpty {
            result += "\n\nHints:"
            for hint in output.metadata.hints {
                result += "\n💡 \(hint)"
            }
        }

        return result
    }

    /// Format specific data types
    private static func formatSpecificData(_ data: some Any) -> String {
        var result = ""

        switch data {
        case let appData as ServiceApplicationListData:
            result += self.formatApplicationList(appData)

        case let windowData as ServiceWindowListData:
            result += self.formatWindowList(windowData)

        case let uiData as UIAnalysisData:
            result += self.formatUIAnalysis(uiData)

        case let interactionData as InteractionResultData:
            result += self.formatInteractionResult(interactionData)

        default:
            // No specific formatting for unknown types
            break
        }

        return result
    }

    private static func formatApplicationList(_ data: ServiceApplicationListData) -> String {
        guard !data.applications.isEmpty else { return "" }

        var result = "\n\nApplications:"
        for (index, app) in data.applications.enumerated() {
            result += "\n\(index + 1). \(app.name)"
            if let bundleId = app.bundleIdentifier {
                result += " (\(bundleId))"
            }
            result += " - PID: \(app.processIdentifier)"
            if app.isActive {
                result += " [ACTIVE]"
            }
            if app.isHidden {
                result += " [HIDDEN]"
            }
            result += " - Windows: \(app.windowCount)"
        }
        return result
    }

    private static func formatWindowList(_ data: ServiceWindowListData) -> String {
        guard !data.windows.isEmpty else { return "" }

        var result = "\n\nWindows:"
        for (index, window) in data.windows.enumerated() {
            result += "\n\(index + 1). \(window.title.isEmpty ? "[Untitled]" : window.title)"
            result += " - ID: \(window.windowID)"

            // Format bounds
            let bounds = window.bounds
            result += "\n   Position: (\(Int(bounds.origin.x)), \(Int(bounds.origin.y)))"
            result += " Size: \(Int(bounds.size.width))×\(Int(bounds.size.height))"

            if window.isMinimized {
                result += " [MINIMIZED]"
            }
            if window.isOffScreen {
                result += " [OFF-SCREEN]"
            }
        }
        return result
    }

    private static func formatUIAnalysis(_ data: UIAnalysisData) -> String {
        var result = ""

        if let screenshot = data.screenshot {
            result += "\n\nScreenshot: \(screenshot.path)"
        }

        result += "\nSession: \(data.sessionId)"
        result += "\nElements: \(data.elements.count)"

        // Group elements by role
        let elementsByRole = Dictionary(grouping: data.elements) { $0.role }
        let sortedRoles = elementsByRole.keys.sorted()

        result += "\n\nUI Elements by Type:"
        for role in sortedRoles {
            let elements = elementsByRole[role] ?? []
            let actionable = elements.count(where: { $0.isActionable })
            result += "\n• \(role): \(elements.count)"
            if actionable > 0 {
                result += " (\(actionable) actionable)"
            }
        }

        return result
    }

    private static func formatInteractionResult(_ data: InteractionResultData) -> String {
        var result = ""

        if let target = data.target {
            result += "\n\nAction: \(data.action) on \(target)"
        } else {
            result += "\n\nAction: \(data.action)"
        }

        result += "\nResult: \(data.success ? "Success" : "Failed")"

        if !data.details.isEmpty {
            result += "\nDetails:"
            for (key, value) in data.details.sorted(by: { $0.key < $1.key }) {
                result += "\n  \(key): \(value)"
            }
        }

        return result
    }
}
