//
//  MenuSystemToolFormatter.swift
//  Peekaboo
//

import Foundation
import PeekabooCore

/// Formatter for menu, dialog, and system tools with comprehensive result formatting
class MenuSystemToolFormatter: BaseToolFormatter {
    
    override func formatResultSummary(result: [String: Any]) -> String {
        switch toolType {
        // Menu tools
        case .menuClick:
            return formatMenuClickResult(result)
        case .listMenus:
            return formatListMenuItemsResult(result)
            
        // Dialog tools
        case .dialogInput:
            return formatDialogInputResult(result)
        case .dialogClick:
            return formatDialogClickResult(result)
        
            
        // System tools
        case .shell:
            return formatShellResult(result)
        case .wait:
            return formatWaitResult(result)
        
            
        // Dock tools
        case .dockClick:
            return formatDockClickResult(result)
        
            
        default:
            return super.formatResultSummary(result: result)
        }
    }
    
    // MARK: - Menu Tools
    
    private func formatMenuClickResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Clicked menu")
        
        // Menu path
        if let menuPath: [String] = ToolResultExtractor.array("menuPath", from: result) {
            let path = menuPath.joined(separator: " → ")
            parts.append("\"\(path)\"")
        } else if let item = ToolResultExtractor.string("menuItem", from: result) {
            parts.append("\"\(item)\"")
        }
        
        // App context
        if let app = ToolResultExtractor.string("app", from: result) {
            parts.append("in \(app)")
        }
        
        // Action result
        var details: [String] = []
        
        if let action = ToolResultExtractor.string("actionTriggered", from: result) {
            details.append("triggered: \(action)")
        }
        
        if let windowOpened = ToolResultExtractor.string("windowOpened", from: result) {
            details.append("opened: \(windowOpened)")
        }
        
        if let shortcut = ToolResultExtractor.string("shortcut", from: result) {
            let formatted = FormattingUtilities.formatKeyboardShortcut(shortcut)
            details.append("shortcut: \(formatted)")
        }
        
        if let enabled = ToolResultExtractor.bool("wasEnabled", from: result), !enabled {
            details.append("was disabled")
        }
        
        if !details.isEmpty {
            parts.append("[\(details.joined(separator: ", "))]")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatMenuSearchResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Found")
        
        // Match count
        if let matches: [[String: Any]] = ToolResultExtractor.array("matches", from: result) {
            let count = matches.count
            parts.append("\(count) menu item\(count == 1 ? "" : "s")")
        } else if let count = ToolResultExtractor.int("matchCount", from: result) {
            parts.append("\(count) menu item\(count == 1 ? "" : "s")")
        }
        
        // Search query
        if let query = ToolResultExtractor.string("query", from: result) {
            parts.append("matching \"\(query)\"")
        }
        
        // Top matches
        if let matches: [[String: Any]] = ToolResultExtractor.array("matches", from: result) {
            let topMatches = matches.prefix(3).compactMap { match in
                match["title"] as? String ?? match["item"] as? String
            }
            
            if !topMatches.isEmpty {
                let matchList = topMatches.map { "\"\($0)\"" }.joined(separator: ", ")
                parts.append("• \(matchList)")
            }
            
            // Apps with matches
            let apps = Set(matches.compactMap { $0["app"] as? String })
            if apps.count > 1 {
                parts.append("across \(apps.count) apps")
            }
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatListMenuItemsResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        // Item count
        if let items: [[String: Any]] = ToolResultExtractor.array("items", from: result) {
            let count = items.count
            parts.append("→ \(count) menu item\(count == 1 ? "" : "s")")
        } else if let count = ToolResultExtractor.int("count", from: result) {
            parts.append("→ \(count) menu item\(count == 1 ? "" : "s")")
        }
        
        // Menu context
        if let menu = ToolResultExtractor.string("menu", from: result) {
            parts.append("in \(menu) menu")
        }
        
        if let app = ToolResultExtractor.string("app", from: result) {
            parts.append("for \(app)")
        }
        
        // Categories
        if let items: [[String: Any]] = ToolResultExtractor.array("items", from: result) {
            var enabledCount = 0
            var disabledCount = 0
            var hasShortcuts = 0
            var hasSubmenus = 0
            
            for item in items {
                if let enabled = item["enabled"] as? Bool {
                    if enabled { enabledCount += 1 } else { disabledCount += 1 }
                }
                if let shortcut = item["shortcut"] as? String, !shortcut.isEmpty {
                    hasShortcuts += 1
                }
                if let hasSubmenu = item["hasSubmenu"] as? Bool, hasSubmenu {
                    hasSubmenus += 1
                }
            }
            
            var details: [String] = []
            if enabledCount > 0 {
                details.append("\(enabledCount) enabled")
            }
            if disabledCount > 0 {
                details.append("\(disabledCount) disabled")
            }
            if hasShortcuts > 0 {
                details.append("\(hasShortcuts) with shortcuts")
            }
            if hasSubmenus > 0 {
                details.append("\(hasSubmenus) with submenus")
            }
            
            if !details.isEmpty {
                parts.append("[\(details.joined(separator: ", "))]")
            }
        }
        
        return parts.joined(separator: " ")
    }
    
    // MARK: - Dialog Tools
    
    private func formatDialogInputResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Entered")
        
        // Input text
        if let text = ToolResultExtractor.string("text", from: result) {
            let displayText = text.count > 50
                ? String(text.prefix(47)) + "..."
                : text
            parts.append("\"\(displayText)\"")
        }
        
        // Dialog info
        if let dialogTitle = ToolResultExtractor.string("dialogTitle", from: result) {
            parts.append("in \"\(dialogTitle)\"")
        } else if let dialogType = ToolResultExtractor.string("dialogType", from: result) {
            parts.append("in \(dialogType) dialog")
        }
        
        // Field info
        if let field = ToolResultExtractor.string("field", from: result) {
            parts.append("(\(field))")
        }
        
        // Action taken
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
    
    private func formatDialogClickResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Clicked")
        
        // Button clicked
        if let button = ToolResultExtractor.string("button", from: result) {
            parts.append("\"\(button)\"")
        }
        
        // Dialog context
        if let dialogTitle = ToolResultExtractor.string("dialogTitle", from: result) {
            parts.append("in \"\(dialogTitle)\"")
        }
        
        // Result
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
    
    private func formatDialogDismissResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Dismissed dialog")
        
        // Dialog info
        if let dialogTitle = ToolResultExtractor.string("dialogTitle", from: result) {
            parts.append("\"\(dialogTitle)\"")
        }
        
        // Method
        if let method = ToolResultExtractor.string("method", from: result) {
            parts.append("via \(method)")
        }
        
        // Data loss warning
        if let dataLost = ToolResultExtractor.bool("dataLost", from: result), dataLost {
            parts.append("⚠️ Unsaved changes discarded")
        }
        
        return parts.joined(separator: " ")
    }
    
    // MARK: - System Tools
    
    private func formatShellResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        // Command status
        if let exitCode = ToolResultExtractor.int("exitCode", from: result) {
            if exitCode == 0 {
                parts.append("→ Command succeeded")
            } else {
                parts.append("→ Command failed (exit code: \(exitCode))")
            }
        } else if let success = ToolResultExtractor.bool("success", from: result) {
            parts.append(success ? "→ Command succeeded" : "→ Command failed")
        } else {
            parts.append("→ Executed")
        }
        
        // Command executed
        if let command = ToolResultExtractor.string("command", from: result) {
            let truncated = command.count > 60
                ? String(command.prefix(57)) + "..."
                : command
            parts.append("`\(truncated)`")
        }
        
        // Output summary
        var details: [String] = []
        
        if let outputLines = ToolResultExtractor.int("outputLines", from: result) {
            details.append("\(outputLines) lines output")
        } else if let output = ToolResultExtractor.string("output", from: result) {
            let lines = output.components(separatedBy: .newlines).count
            if lines > 1 {
                details.append("\(lines) lines output")
            }
        }
        
        if let errorLines = ToolResultExtractor.int("errorLines", from: result), errorLines > 0 {
            details.append("\(errorLines) error lines")
        }
        
        if let duration = ToolResultExtractor.double("duration", from: result) {
            details.append(FormattingUtilities.formatDetailedDuration(duration))
        }
        
        if let filesCreated = ToolResultExtractor.int("filesCreated", from: result), filesCreated > 0 {
            details.append("\(filesCreated) files created")
        }
        
        if let filesModified = ToolResultExtractor.int("filesModified", from: result), filesModified > 0 {
            details.append("\(filesModified) files modified")
        }
        
        if !details.isEmpty {
            parts.append("[\(details.joined(separator: ", "))]")
        }
        
        // Key output if available
        if let keyOutput = ToolResultExtractor.string("keyOutput", from: result) {
            let truncated = keyOutput.count > 100
                ? String(keyOutput.prefix(97)) + "..."
                : keyOutput
            parts.append("• \(truncated)")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatWaitResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Waited")
        
        // Duration
        if let seconds = ToolResultExtractor.double("seconds", from: result) {
            parts.append(FormattingUtilities.formatDetailedDuration(seconds))
        } else if let duration = ToolResultExtractor.double("duration", from: result) {
            parts.append(FormattingUtilities.formatDetailedDuration(duration))
        }
        
        // Wait condition
        if let condition = ToolResultExtractor.string("condition", from: result) {
            parts.append("for \(condition)")
        } else if let waitingFor = ToolResultExtractor.string("waitingFor", from: result) {
            parts.append("for \(waitingFor)")
        }
        
        // Result
        if let found = ToolResultExtractor.bool("found", from: result) {
            parts.append(found ? "✓ Found" : "✗ Not found")
        } else if let completed = ToolResultExtractor.bool("completed", from: result) {
            parts.append(completed ? "✓ Completed" : "✗ Timed out")
        }
        
        // Additional context
        if let attempts = ToolResultExtractor.int("attempts", from: result), attempts > 1 {
            parts.append("(\(attempts) attempts)")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatCopyResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Copied")
        
        // What was copied
        if let text = ToolResultExtractor.string("text", from: result) {
            let displayText = text.count > 50
                ? String(text.prefix(47)) + "..."
                : text
            parts.append("\"\(displayText)\"")
            
            // Text details
            if text.count > 50 {
                parts.append("(\(text.count) chars)")
            }
        } else if let type = ToolResultExtractor.string("type", from: result) {
            parts.append(type)
        }
        
        // Size info
        if let bytes = ToolResultExtractor.int("bytes", from: result) {
            parts.append("[" + FormattingUtilities.formatFileSize(bytes) + "]")
        }
        
        // Source
        if let source = ToolResultExtractor.string("source", from: result) {
            parts.append("from \(source)")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatPasteResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Pasted")
        
        // What was pasted
        if let text = ToolResultExtractor.string("text", from: result) {
            let displayText = text.count > 50
                ? String(text.prefix(47)) + "..."
                : text
            parts.append("\"\(displayText)\"")
            
            if text.count > 50 {
                parts.append("(\(text.count) chars)")
            }
        } else if let type = ToolResultExtractor.string("type", from: result) {
            parts.append(type)
        }
        
        // Destination
        if let destination = ToolResultExtractor.string("destination", from: result) {
            parts.append("into \(destination)")
        } else if let app = ToolResultExtractor.string("app", from: result) {
            parts.append("in \(app)")
        }
        
        // Format preserved
        if let formatPreserved = ToolResultExtractor.bool("formatPreserved", from: result) {
            parts.append(formatPreserved ? "✓ Format preserved" : "⚠️ Plain text")
        }
        
        return parts.joined(separator: " ")
    }
    
    // MARK: - Dock Tools
    
    private func formatDockClickResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Clicked")
        
        // App in dock
        if let app = ToolResultExtractor.string("app", from: result) {
            parts.append("\(app) in Dock")
        }
        
        // Action result
        if let launched = ToolResultExtractor.bool("launched", from: result), launched {
            parts.append("• App launched")
        } else if let focused = ToolResultExtractor.bool("focused", from: result), focused {
            parts.append("• App focused")
        }
        
        // Window state
        if let windowsShown = ToolResultExtractor.int("windowsShown", from: result) {
            parts.append("• \(windowsShown) window\(windowsShown == 1 ? "" : "s") shown")
        }
        
        // Click type
        if let clickType = ToolResultExtractor.string("clickType", from: result), clickType != "left" {
            parts.append("(\(clickType) click)")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatDockAddRemoveResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        // Action type
        if let action = ToolResultExtractor.string("action", from: result) {
            if action == "add" {
                parts.append("→ Added")
            } else if action == "remove" {
                parts.append("→ Removed")
            }
        }
        
        // App
        if let app = ToolResultExtractor.string("app", from: result) {
            parts.append("\(app)")
            parts.append(parts.first?.contains("Added") == true ? "to Dock" : "from Dock")
        }
        
        // Position
        if let position = ToolResultExtractor.int("position", from: result) {
            parts.append("at position \(position)")
        }
        
        // Dock count
        if let dockCount = ToolResultExtractor.int("dockItemCount", from: result) {
            parts.append("• Dock now has \(dockCount) items")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatDockPositionResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Moved Dock")
        
        // New position
        if let position = ToolResultExtractor.string("position", from: result) {
            parts.append("to \(position)")
        }
        
        // Previous position
        if let previousPosition = ToolResultExtractor.string("previousPosition", from: result) {
            parts.append("(was \(previousPosition))")
        }
        
        // Auto-hide
        if let autoHide = ToolResultExtractor.bool("autoHide", from: result) {
            parts.append(autoHide ? "• Auto-hide enabled" : "• Auto-hide disabled")
        }
        
        // Size
        if let size = ToolResultExtractor.string("size", from: result) {
            parts.append("• Size: \(size)")
        }
        
        return parts.joined(separator: " ")
    }
}