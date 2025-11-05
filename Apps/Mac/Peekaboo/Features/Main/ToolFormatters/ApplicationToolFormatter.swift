//
//  ApplicationToolFormatter.swift
//  Peekaboo
//

import Foundation
import PeekabooCore

/// Formatter for application-related tools
struct ApplicationToolFormatter: MacToolFormatterProtocol {
    let handledTools: Set<String> = ["launch_app", "list_apps", "focus_window", "list_windows", "resize_window"]

    func formatSummary(toolName: String, arguments: [String: Any]) -> String? {
        switch toolName {
        case "launch_app":
            self.formatLaunchAppSummary(arguments)
        case "list_apps":
            "List running applications"
        case "focus_window":
            self.formatFocusWindowSummary(arguments)
        case "list_windows":
            self.formatListWindowsSummary(arguments)
        case "resize_window":
            self.formatResizeWindowSummary(arguments)
        default:
            nil
        }
    }

    func formatResult(toolName: String, result: [String: Any]) -> String? {
        switch toolName {
        case "launch_app":
            self.formatLaunchAppResult(result)
        case "list_apps":
            self.formatListAppsResult(result)
        case "focus_window":
            self.formatFocusWindowResult(result)
        case "list_windows":
            self.formatListWindowsResult(result)
        case "resize_window":
            self.formatResizeWindowResult(result)
        default:
            nil
        }
    }

    // MARK: - Launch App

    private func formatLaunchAppSummary(_ args: [String: Any]) -> String {
        if let app = args["app"] as? String {
            return "Launch \(app)"
        } else if let appName = args["appName"] as? String {
            return "Launch \(appName)"
        }
        return "Launch application"
    }

    private func formatLaunchAppResult(_ result: [String: Any]) -> String? {
        if let app = result["app"] as? String {
            return "Launched \(app)"
        } else if let appName = result["appName"] as? String {
            return "Launched \(appName)"
        }
        return "Application launched"
    }

    // MARK: - List Apps

    private func formatListAppsResult(_ result: [String: Any]) -> String? {
        // Try different ways to get app count
        var appCount: Int?

        if let count = result["count"] as? Int {
            appCount = count
        } else if let apps = result["apps"] as? [[String: Any]] {
            appCount = apps.count
        } else if let apps = result["applications"] as? [[String: Any]] {
            appCount = apps.count
        }

        if let count = appCount {
            return "→ \(count) apps running"
        }

        return "Listed applications"
    }

    // MARK: - Focus Window

    private func formatFocusWindowSummary(_ args: [String: Any]) -> String {
        var parts = ["Focus"]

        if let app = args["app"] as? String {
            parts.append(app)
        } else if let appName = args["appName"] as? String {
            parts.append(appName)
        }

        if let title = args["windowTitle"] as? String {
            // Use shared truncation utility
            let truncated = FormattingUtilities.truncate(title, maxLength: 40)
            parts.append("- '\(truncated)'")
        } else if let index = args["windowIndex"] as? Int {
            parts.append("window #\(index)")
        }

        return parts.joined(separator: " ")
    }

    private func formatFocusWindowResult(_ result: [String: Any]) -> String? {
        var parts = ["Focused"]

        if let app = result["app"] as? String {
            parts.append(app)
        } else if let appName = result["appName"] as? String {
            parts.append(appName)
        }

        if let title = result["windowTitle"] as? String {
            parts.append("- '\(title)'")
        }

        return parts.joined(separator: " ")
    }

    // MARK: - List Windows

    private func formatListWindowsSummary(_ args: [String: Any]) -> String {
        if let app = args["app"] as? String {
            return "List windows for \(app)"
        } else if let appName = args["appName"] as? String {
            return "List windows for \(appName)"
        }
        return "List windows"
    }

    private func formatListWindowsResult(_ result: [String: Any]) -> String? {
        // Check for count in various formats
        var windowCount: Int?

        // Direct count field
        if let count = result["count"] as? Int {
            windowCount = count
        }
        // Count from windows array
        else if let windows = result["windows"] as? [[String: Any]] {
            windowCount = windows.count
        }

        if let count = windowCount {
            if let app = result["app"] as? String {
                return "Found \(count) window\(count == 1 ? "" : "s") for \(app)"
            } else if let appName = result["appName"] as? String {
                return "Found \(count) window\(count == 1 ? "" : "s") for \(appName)"
            }
            return "Found \(count) window\(count == 1 ? "" : "s")"
        }

        return "Listed windows"
    }

    // MARK: - Resize Window

    private func formatResizeWindowSummary(_ args: [String: Any]) -> String {
        var parts = ["Resize"]

        if let app = args["app"] as? String {
            parts.append(app)
        } else if let appName = args["appName"] as? String {
            parts.append(appName)
        }

        if let width = args["width"], let height = args["height"] {
            parts.append("to \(width)×\(height)")
        } else if let action = args["action"] as? String {
            parts.append(action)
        }

        return parts.joined(separator: " ")
    }

    private func formatResizeWindowResult(_ result: [String: Any]) -> String? {
        if let newSize = result["newSize"] as? [String: Any],
           let width = newSize["width"], let height = newSize["height"]
        {
            return "Resized to \(width)×\(height)"
        }

        if let action = result["action"] as? String {
            return "Window \(action)"
        }

        return nil
    }
}
