//
//  WindowToolFormatter.swift
//  PeekabooCore
//

import Foundation

/// Formatter for window management tools with comprehensive result formatting
public class WindowToolFormatter: BaseToolFormatter {
    override public func formatCompactSummary(arguments: [String: Any]) -> String {
        switch toolType {
        case .focusWindow:
            if let app = arguments["appName"] as? String {
                return app
            }
            return "active window"

        case .resizeWindow:
            var parts: [String] = []
            if let app = arguments["appName"] as? String {
                parts.append(app)
            }
            if let width = arguments["width"], let height = arguments["height"] {
                parts.append("to \(width)x\(height)")
            }
            return parts.isEmpty ? "active window" : parts.joined(separator: " ")

        case .listWindows:
            if let app = arguments["appName"] as? String {
                return "for \(app)"
            }
            return ""

        case .minimizeWindow, .maximizeWindow:
            if let app = arguments["appName"] as? String {
                return app
            }
            return "active window"

        case .listScreens:
            return ""

        default:
            return super.formatCompactSummary(arguments: arguments)
        }
    }

    override public func formatResultSummary(result: [String: Any]) -> String {
        switch toolType {
        case .focusWindow:
            return self.formatFocusWindowResult(result)
        case .resizeWindow:
            return self.formatResizeWindowResult(result)
        case .listWindows:
            return self.formatListWindowsResult(result)
        case .minimizeWindow:
            return self.formatMinimizeWindowResult(result)
        case .maximizeWindow:
            return self.formatMaximizeWindowResult(result)
        case .listScreens:
            return self.formatListScreensResult(result)
        case .listSpaces:
            return self.formatListSpacesResult(result)
        case .switchSpace:
            return self.formatSwitchSpaceResult(result)
        case .moveWindowToSpace:
            return self.formatMoveWindowToSpaceResult(result)
        default:
            return super.formatResultSummary(result: result)
        }
    }

    override public func formatStarting(arguments: [String: Any]) -> String {
        switch toolType {
        case .focusWindow:
            let app = arguments["appName"] as? String ?? "window"
            return "Focusing \(app)..."

        case .resizeWindow:
            let summary = self.formatCompactSummary(arguments: arguments)
            if !summary.isEmpty {
                return "Resizing \(summary)..."
            }
            return "Resizing window..."

        case .listWindows:
            if let app = arguments["appName"] as? String {
                return "Listing windows for \(app)..."
            }
            return "Listing windows..."

        case .minimizeWindow:
            if let app = arguments["appName"] as? String {
                return "Minimizing \(app)..."
            }
            return "Minimizing window..."

        case .maximizeWindow:
            if let app = arguments["appName"] as? String {
                return "Maximizing \(app)..."
            }
            return "Maximizing window..."

        case .listScreens:
            return "Listing screens..."

        case .listSpaces:
            return "Listing Spaces..."

        case .switchSpace:
            if let space = arguments["to"] {
                return "Switching to Space \(space)..."
            }
            return "Switching Space..."

        case .moveWindowToSpace:
            if let app = arguments["appName"] as? String {
                let target = arguments["to"] ?? arguments["to_current"] ?? arguments["follow"]
                return "Moving \(app) window to space \(target ?? "target")..."
            }
            return "Moving window to another space..."

        default:
            return super.formatStarting(arguments: arguments)
        }
    }

}

private extension WindowToolFormatter {
    // MARK: - Window Management

    private func formatFocusWindowResult(_ result: [String: Any]) -> String {
        var parts: [String] = ["→ Focused"]

        if let title = self.truncatedTitle(from: result, limit: 40) {
            parts.append("\"\(title)\"")
        }

        if let app = self.windowAppName(from: result) {
            parts.append("(\(app))")
        }

        if let detailSummary = self.focusDetailSummary(result) {
            parts.append(detailSummary)
        }

        parts.append(contentsOf: self.focusStateChanges(result))

        return parts.joined(separator: " ")
    }

    private func formatResizeWindowResult(_ result: [String: Any]) -> String {
        var parts: [String] = ["→ Resized"]

        if let description = self.resizeWindowDescription(result) {
            parts.append(contentsOf: description)
        }

        if let sizeSummary = self.resizeSizeSummary(result) {
            parts.append(sizeSummary)
        }

        if let positionSummary = self.resizePositionSummary(result) {
            parts.append(positionSummary)
        }

        if self.isConstrained(result) {
            parts.append("\(AgentDisplayTokens.Status.warning) Constrained to screen bounds")
        }

        return parts.joined(separator: " ")
    }

    private func formatListWindowsResult(_ result: [String: Any]) -> String {
        var parts: [String] = []

        if let windows: [[String: Any]] = ToolResultExtractor.array("windows", from: result) {
            appendWindowCountDescription(for: windows, into: &parts)
            appendWindowAppBreakdown(from: windows, into: &parts)
            appendWindowStateSummary(for: windows, into: &parts)
            appendWindowTitlePreview(for: windows, into: &parts)
        } else {
            appendLegacyWindowCount(from: result, into: &parts)
        }

        appendWindowFilterInfo(from: result, into: &parts)
        return parts.isEmpty ? "→ listed" : parts.joined(separator: " ")
    }

    private func formatMinimizeWindowResult(_ result: [String: Any]) -> String {
        var parts: [String] = []

        parts.append("→ Minimized")

        // Window info
        if let app = ToolResultExtractor.string("app", from: result) {
            parts.append(app)
        }

        if let title = ToolResultExtractor.string("windowTitle", from: result) {
            let truncated = title.count > 40
                ? String(title.prefix(40)) + "..."
                : title
            parts.append("\"\(truncated)\"")
        }

        // Animation info
        if let animated = ToolResultExtractor.bool("animated", from: result), animated {
            parts.append("with animation")
        }

        // Dock position
        if let dockPosition = ToolResultExtractor.string("dockPosition", from: result) {
            parts.append("to \(dockPosition) of Dock")
        }

        return parts.joined(separator: " ")
    }

    private func formatMaximizeWindowResult(_ result: [String: Any]) -> String {
        var parts: [String] = []

        parts.append("→ Maximized")

        // Window info
        if let app = ToolResultExtractor.string("app", from: result) {
            parts.append(app)
        }

        if let title = ToolResultExtractor.string("windowTitle", from: result) {
            let truncated = title.count > 40
                ? String(title.prefix(40)) + "..."
                : title
            parts.append("\"\(truncated)\"")
        }

        // Size info
        if let newBounds = ToolResultExtractor.dictionary("bounds", from: result) {
            if let width = newBounds["width"] as? Int,
               let height = newBounds["height"] as? Int
            {
                parts.append("to \(width)×\(height)")
            }
        }

        // Fullscreen state
        if let fullscreen = ToolResultExtractor.bool("fullscreen", from: result), fullscreen {
            parts.append("• Entered fullscreen")
        }

        // Screen info
        if let screen = ToolResultExtractor.string("screen", from: result) {
            parts.append("on \(screen)")
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Screen Management

    private func formatListScreensResult(_ result: [String: Any]) -> String {
        var parts: [String] = []

        // Screen count
        if let screens: [[String: Any]] = ToolResultExtractor.array("screens", from: result) {
            let count = screens.count
            parts.append("→ \(count) screen\(count == 1 ? "" : "s")")

            // Main screen
            if let mainScreen = screens.first(where: { ($0["isMain"] as? Bool) == true }) {
                if let name = mainScreen["name"] as? String {
                    parts.append("Main: \(name)")
                }

                if let width = mainScreen["width"] as? Int,
                   let height = mainScreen["height"] as? Int
                {
                    parts.append("(\(width)×\(height))")
                }
            }

            // External screens
            let externalCount = screens.count(where: { ($0["isBuiltin"] as? Bool) != true })
            if externalCount > 0 {
                parts.append("• \(externalCount) external")
            }

            // Total resolution
            if screens.count > 1 {
                let totalWidth = screens.compactMap { $0["width"] as? Int }.reduce(0, +)
                let totalHeight = screens.compactMap { $0["height"] as? Int }.max() ?? 0
                parts.append("• Total: \(totalWidth)×\(totalHeight)")
            }
        } else if let count = ToolResultExtractor.int("count", from: result) {
            parts.append("→ \(count) screen\(count == 1 ? "" : "s")")
        }

        return parts.isEmpty ? "→ listed" : parts.joined(separator: " ")
    }

    private func appendWindowCountDescription(
        for windows: [[String: Any]],
        into parts: inout [String]
    ) {
        let count = windows.count
        parts.append("→ \(count) window\(count == 1 ? "" : "s")")
    }

    private func appendWindowAppBreakdown(
        from windows: [[String: Any]],
        into parts: inout [String]
    ) {
        let appGroups = Dictionary(grouping: windows) { window in
            (window["app"] as? String) ?? "Unknown"
        }

        guard !appGroups.isEmpty else { return }

        if appGroups.count > 1 {
            let appSummary = appGroups
                .map { app, wins in "\(app): \(wins.count)" }
                .sorted()
                .prefix(3)
                .joined(separator: ", ")
            parts.append("[\(appSummary)]")
        } else if let app = appGroups.keys.first {
            parts.append("for \(app)")
        }
    }

    private func appendWindowStateSummary(
        for windows: [[String: Any]],
        into parts: inout [String]
    ) {
        let minimized = windows.count(where: { ($0["isMinimized"] as? Bool) == true })
        let hidden = windows.count(where: { ($0["isHidden"] as? Bool) == true })
        let fullscreen = windows.count(where: { ($0["isFullscreen"] as? Bool) == true })

        var states: [String] = []
        if minimized > 0 { states.append("\(minimized) minimized") }
        if hidden > 0 { states.append("\(hidden) hidden") }
        if fullscreen > 0 { states.append("\(fullscreen) fullscreen") }

        guard !states.isEmpty else { return }
        let summary = states.joined(separator: ", ")
        parts.append("(\(summary))")
    }

    private func appendWindowTitlePreview(
        for windows: [[String: Any]],
        into parts: inout [String]
    ) {
        guard windows.count <= 3 else { return }

        let titles = windows.compactMap { $0["title"] as? String }.prefix(3)
        guard !titles.isEmpty else { return }

        let titleList = titles.map { title -> String in
            let truncated = title.count > 25 ? String(title.prefix(25)) + "..." : title
            return "\"\(truncated)\""
        }.joined(separator: ", ")
        parts.append("• \(titleList)")
    }

    private func appendLegacyWindowCount(
        from result: [String: Any],
        into parts: inout [String]
    ) {
        if let count = ToolResultExtractor.int("count", from: result) {
            parts.append("→ \(count) window\(count == 1 ? "" : "s")")
            return
        }

        if let data = result["data"] as? [String: Any],
           let windows = data["windows"] as? [[String: Any]]
        {
            let count = windows.count
            parts.append("→ \(count) window\(count == 1 ? "" : "s")")
        }
    }

    private func appendWindowFilterInfo(
        from result: [String: Any],
        into parts: inout [String]
    ) {
        if let app = ToolResultExtractor.string("app", from: result) ??
            ToolResultExtractor.string("appName", from: result)
        {
            if !parts.joined(separator: " ").contains(app) {
                parts.append("for \(app)")
            }
        }

        if let screen = ToolResultExtractor.string("screen", from: result) {
            parts.append("on \(screen)")
        }
    }

    // MARK: - Space Management

    private func formatListSpacesResult(_ result: [String: Any]) -> String {
        var parts: [String] = []

        // Space count
        if let spaces: [[String: Any]] = ToolResultExtractor.array("spaces", from: result) {
            let count = spaces.count
            parts.append("→ \(count) space\(count == 1 ? "" : "s")")

            // Current space
            if let currentSpace = spaces.first(where: { ($0["isCurrent"] as? Bool) == true }) {
                if let index = currentSpace["index"] as? Int {
                    parts.append("Current: Space \(index)")
                }

                if let windowCount = currentSpace["windowCount"] as? Int {
                    parts.append("(\(windowCount) windows)")
                }
            }

            // Space types
            let fullscreenSpaces = spaces.count(where: { ($0["isFullscreen"] as? Bool) == true })
            let visibleSpaces = spaces.count(where: { ($0["isVisible"] as? Bool) == true })

            var details: [String] = []
            if fullscreenSpaces > 0 {
                details.append("\(fullscreenSpaces) fullscreen")
            }
            if visibleSpaces > 1 {
                details.append("\(visibleSpaces) visible")
            }

            if !details.isEmpty {
                parts.append("[\(details.joined(separator: ", "))]")
            }
        } else if let count = ToolResultExtractor.int("count", from: result) {
            parts.append("→ \(count) space\(count == 1 ? "" : "s")")
        }

        // Current space info
        if let current = ToolResultExtractor.int("currentSpace", from: result) {
            parts.append("• Currently on Space \(current)")
        }

        return parts.isEmpty ? "→ listed" : parts.joined(separator: " ")
    }

    private func formatSwitchSpaceResult(_ result: [String: Any]) -> String {
        var parts: [String] = []

        parts.append("→ Switched to")

        // Space info
        if let spaceIndex = ToolResultExtractor.int("spaceIndex", from: result) {
            parts.append("Space \(spaceIndex)")
        } else if let spaceName = ToolResultExtractor.string("spaceName", from: result) {
            parts.append(spaceName)
        }

        // Previous space
        if let previousSpace = ToolResultExtractor.int("previousSpace", from: result) {
            parts.append("(from Space \(previousSpace))")
        }

        // Animation
        if let animated = ToolResultExtractor.bool("animated", from: result), animated {
            parts.append("with animation")
        }

        // Windows on new space
        if let windowCount = ToolResultExtractor.int("windowCount", from: result) {
            parts.append("• \(windowCount) window\(windowCount == 1 ? "" : "s") here")
        }

        // Apps on new space
        if let apps: [String] = ToolResultExtractor.array("apps", from: result) {
            if !apps.isEmpty {
                let appList = apps.prefix(3).joined(separator: ", ")
                parts.append("• Apps: \(appList)")
            }
        }

        return parts.isEmpty ? "→ switched" : parts.joined(separator: " ")
    }

    private func formatMoveWindowToSpaceResult(_ result: [String: Any]) -> String {
        var parts: [String] = []

        parts.append("→ Moved")

        // Window info
        if let app = ToolResultExtractor.string("app", from: result) {
            parts.append(app)

            if let title = ToolResultExtractor.string("windowTitle", from: result) {
                let truncated = title.count > 30
                    ? String(title.prefix(30)) + "..."
                    : title
                parts.append("\"\(truncated)\"")
            }
        }

        // Space transition
        if let toSpace = ToolResultExtractor.int("toSpace", from: result) {
            parts.append("to Space \(toSpace)")

            if let fromSpace = ToolResultExtractor.int("fromSpace", from: result) {
                parts.append("(from Space \(fromSpace))")
            }
        }

        // Follow window
        if let followed = ToolResultExtractor.bool("followedWindow", from: result), followed {
            parts.append("• Switched to new space")
        }

        // Other windows
        if let remainingWindows = ToolResultExtractor.int("remainingWindows", from: result) {
            parts.append("• \(remainingWindows) windows remain on original space")
        }

        return parts.isEmpty ? "→ moved" : parts.joined(separator: " ")
    }

    // MARK: - Focus Helpers

    private func truncatedTitle(from result: [String: Any], limit: Int) -> String? {
        guard let title = ToolResultExtractor.string("windowTitle", from: result) else { return nil }
        if title.count > limit {
            return String(title.prefix(limit)) + "..."
        }
        return title
    }

    private func windowAppName(from result: [String: Any]) -> String? {
        ToolResultExtractor.string("app", from: result) ??
            ToolResultExtractor.string("appName", from: result)
    }

    private func focusDetailSummary(_ result: [String: Any]) -> String? {
        var details: [String] = []
        if let windowId = ToolResultExtractor.int("windowId", from: result) {
            details.append("ID: \(windowId)")
        }
        if let bounds = ToolResultExtractor.dictionary("bounds", from: result),
           let width = bounds["width"] as? Int,
           let height = bounds["height"] as? Int
        {
            details.append("\(width)×\(height)")
        }
        if let space = ToolResultExtractor.int("space", from: result) {
            details.append("space \(space)")
        }
        if let screen = ToolResultExtractor.string("screen", from: result) {
            details.append("on \(screen)")
        }
        guard !details.isEmpty else { return nil }
        return "[\(details.joined(separator: ", "))]"
    }

    private func focusStateChanges(_ result: [String: Any]) -> [String] {
        var states: [String] = []
        if ToolResultExtractor.bool("wasMinimized", from: result) == true {
            states.append("• Restored from minimized")
        }
        if ToolResultExtractor.bool("wasHidden", from: result) == true {
            states.append("• Unhidden")
        }
        return states
    }

    // MARK: - Resize Helpers

    private func resizeWindowDescription(_ result: [String: Any]) -> [String]? {
        guard let app = ToolResultExtractor.string("app", from: result) else { return nil }
        var description = [app]
        if let title = ToolResultExtractor.string("windowTitle", from: result) {
            description.append("\"\(self.truncated(title: title, limit: 30))\"")
        }
        return description
    }

    private func truncated(title: String, limit: Int) -> String {
        if title.count > limit {
            return String(title.prefix(limit)) + "..."
        }
        return title
    }

    private func resizeSizeSummary(_ result: [String: Any]) -> String? {
        if let newBounds = ToolResultExtractor.dictionary("newBounds", from: result),
           let oldBounds = ToolResultExtractor.dictionary("oldBounds", from: result),
           let newWidth = newBounds["width"] as? Int,
           let newHeight = newBounds["height"] as? Int,
           let oldWidth = oldBounds["width"] as? Int,
           let oldHeight = oldBounds["height"] as? Int
        {
            var summary = "from \(oldWidth)×\(oldHeight) to \(newWidth)×\(newHeight)"
            let widthChange = self.percentageChange(newValue: newWidth, oldValue: oldWidth)
            let heightChange = self.percentageChange(newValue: newHeight, oldValue: oldHeight)
            if abs(widthChange) > 5 || abs(heightChange) > 5 {
                summary += String(format: " [%+.0f%% width, %+.0f%% height]", widthChange, heightChange)
            }
            return summary
        }

        if let width = ToolResultExtractor.int("width", from: result),
           let height = ToolResultExtractor.int("height", from: result)
        {
            return "to \(width)×\(height)"
        }
        return nil
    }

    private func resizePositionSummary(_ result: [String: Any]) -> String? {
        guard let newX = ToolResultExtractor.int("x", from: result),
              let newY = ToolResultExtractor.int("y", from: result)
        else { return nil }
        return "at (\(newX), \(newY))"
    }

    private func percentageChange(newValue: Int, oldValue: Int) -> Double {
        guard oldValue != 0 else { return 0 }
        return ((Double(newValue) - Double(oldValue)) / Double(oldValue)) * 100
    }

    private func isConstrained(_ result: [String: Any]) -> Bool {
        ToolResultExtractor.bool("constrained", from: result) ?? false
    }

}
