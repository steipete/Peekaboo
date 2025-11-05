//
//  VisionToolFormatter.swift
//  Peekaboo
//

import Foundation

/// Formatter for vision-related tools (see, screenshot, window_capture)
struct VisionToolFormatter: MacToolFormatterProtocol {
    let handledTools: Set<String> = ["see", "screenshot", "window_capture"]

    func formatSummary(toolName: String, arguments: [String: Any]) -> String? {
        switch toolName {
        case "see":
            self.formatSeeSummary(arguments)
        case "screenshot":
            self.formatScreenshotSummary(arguments)
        case "window_capture":
            self.formatWindowCaptureSummary(arguments)
        default:
            nil
        }
    }

    func formatResult(toolName: String, result: [String: Any]) -> String? {
        switch toolName {
        case "see":
            self.formatSeeResult(result)
        case "screenshot":
            self.formatScreenshotResult(result)
        case "window_capture":
            self.formatWindowCaptureResult(result)
        default:
            nil
        }
    }

    // MARK: - See Tool

    private func formatSeeSummary(_ args: [String: Any]) -> String {
        var parts: [String] = []
        if let mode = args["mode"] as? String {
            parts.append(mode == "window" ? "active window" : mode)
        } else if let app = args["app"] as? String {
            parts.append(app)
        } else {
            parts.append("screen")
        }
        if args["analyze"] != nil {
            parts.append("and analyze")
        }
        return "Capture \(parts.joined(separator: " "))"
    }

    private func formatSeeResult(_ result: [String: Any]) -> String? {
        var parts: [String] = []

        if let description = result["description"] as? String {
            // Truncate long descriptions
            let truncated = description.count > 100
                ? String(description.prefix(100)) + "..."
                : description
            parts.append("Captured: \(truncated)")
        }

        if let elements = result["elements"] as? [[String: Any]] {
            parts.append("(\(elements.count) elements)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    // MARK: - Screenshot Tool

    private func formatScreenshotSummary(_ args: [String: Any]) -> String {
        var parts = ["Screenshot"]

        let target: String = if let mode = args["mode"] as? String {
            mode == "window" ? "active window" : mode
        } else if let app = args["app"] as? String {
            app
        } else {
            "full screen"
        }
        parts.append(target)

        // Add format if specified
        if let format = args["format"] as? String {
            parts.append("as \(format.uppercased())")
        }

        // Add path info if available
        if let path = args["path"] as? String {
            let filename = (path as NSString).lastPathComponent
            parts.append("→ \(filename)")
        }

        return parts.joined(separator: " ")
    }

    private func formatScreenshotResult(_ result: [String: Any]) -> String? {
        if let path = result["path"] as? String {
            let filename = (path as NSString).lastPathComponent
            return "Saved to \(filename)"
        }

        if let size = result["size"] as? [String: Any],
           let width = size["width"] as? Int,
           let height = size["height"] as? Int
        {
            return "Captured \(width)×\(height)"
        }

        return nil
    }

    // MARK: - Window Capture Tool

    private func formatWindowCaptureSummary(_ args: [String: Any]) -> String {
        var parts = ["Capture"]

        if let appName = args["appName"] as? String {
            parts.append(appName)
        } else {
            parts.append("active window")
        }

        // Add window title if available
        if let windowTitle = args["windowTitle"] as? String {
            parts.append("- '\(windowTitle)'")
        } else if let windowIndex = args["windowIndex"] as? Int {
            parts.append("(window #\(windowIndex))")
        }

        return parts.joined(separator: " ")
    }

    private func formatWindowCaptureResult(_ result: [String: Any]) -> String? {
        var parts: [String] = []

        if let app = result["app"] as? String {
            parts.append("Captured \(app)")
        }

        if let windowTitle = result["windowTitle"] as? String {
            parts.append("- '\(windowTitle)'")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
