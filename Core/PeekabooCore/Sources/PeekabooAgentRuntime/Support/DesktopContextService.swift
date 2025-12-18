//
//  DesktopContextService.swift
//  PeekabooCore
//
//  Enhancement #1: Active Window Context Auto-Injection
//  Gathers desktop state (focused app, window, cursor, clipboard) for agent context.
//

import AppKit
import CoreGraphics
import Foundation
import os.log
import PeekabooAutomation
import UniformTypeIdentifiers

/// Service that gathers current desktop state for injection into agent prompts.
/// This provides the LLM with immediate awareness of the user's current context
/// without requiring explicit screenshot analysis.
@available(macOS 14.0, *)
@MainActor
public final class DesktopContextService {
    private let services: any PeekabooServiceProviding
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "DesktopContext")

    public init(services: any PeekabooServiceProviding) {
        self.services = services
    }

    // MARK: - Context Gathering

    /// Gather current desktop context as a formatted string for injection into agent prompts.
    public func gatherContext(includeClipboardPreview: Bool) async -> DesktopContext {
        async let focusedWindow = self.gatherFocusedWindowInfo()
        async let cursorPosition = self.gatherCursorPosition()
        async let recentApps = self.gatherRecentApps()

        let clipboardContent: String? = if includeClipboardPreview {
            await self.gatherClipboardContent()
        } else {
            nil
        }

        return await DesktopContext(
            focusedWindow: focusedWindow,
            cursorPosition: cursorPosition,
            clipboardPreview: clipboardContent,
            recentApps: recentApps,
            timestamp: Date())
    }

    /// Format the desktop context as a string suitable for injection into prompts.
    public func formatContextForPrompt(_ context: DesktopContext) -> String {
        var lines = ["[Desktop State]"]

        // Focused window
        if let window = context.focusedWindow {
            let title = window.title.isEmpty ? "(untitled)" : "\"\(window.title)\""
            lines.append("- Focused: \(window.appName) \u{2014} \(title)")

            if let bounds = window.bounds {
                let size = "\(Int(bounds.width))\u{00D7}\(Int(bounds.height))"
                let position = "(\(Int(bounds.origin.x)), \(Int(bounds.origin.y)))"
                lines.append("- Window: \(size) at \(position)")
            }
        } else {
            lines.append("- Focused: Desktop (Finder)")
        }

        // Cursor position
        if let cursor = context.cursorPosition {
            lines.append("- Cursor: (\(Int(cursor.x)), \(Int(cursor.y)))")
        }

        // Clipboard
        if let clipboard = context.clipboardPreview, !clipboard.isEmpty {
            let preview = clipboard.count > 100
                ? String(clipboard.prefix(100)) + "\u{2026}"
                : clipboard
            // Escape newlines for single-line display
            let escaped = preview
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "")
            lines.append("- Clipboard: \"\(escaped)\"")
        }

        // Recent apps
        if !context.recentApps.isEmpty {
            let appList = context.recentApps.prefix(3).joined(separator: ", ")
            lines.append("- Recent apps: [\(appList)]")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private Helpers

    private func gatherFocusedWindowInfo() async -> FocusedWindowInfo? {
        // Get frontmost application via NSWorkspace
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appName = frontApp.localizedName ?? frontApp.bundleIdentifier ?? "Unknown"

        // Get focused window info via CGWindowListCopyWindowInfo
        // This avoids requiring accessibility permissions for basic window enumeration
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return FocusedWindowInfo(
                appName: appName,
                title: "",
                bounds: nil,
                processId: Int(frontApp.processIdentifier))
        }

        // Find windows belonging to the frontmost app
        let pid = frontApp.processIdentifier
        let appWindows = windowInfoList.filter { info in
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32 else { return false }
            return ownerPID == pid
        }

        // Get the topmost window (first in z-order)
        guard let topWindow = appWindows.first else {
            return FocusedWindowInfo(
                appName: appName,
                title: "",
                bounds: nil,
                processId: Int(pid))
        }

        // Extract window properties
        let title = topWindow[kCGWindowName as String] as? String ?? ""
        var bounds: CGRect?
        if let boundsDict = topWindow[kCGWindowBounds as String] as? [String: Any],
           let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
        {
            bounds = rect
        }

        return FocusedWindowInfo(
            appName: appName,
            title: title,
            bounds: bounds,
            processId: Int(pid))
    }

    private func gatherCursorPosition() async -> CGPoint? {
        // Get current mouse location
        let mouseLocation = NSEvent.mouseLocation

        // Convert from screen coordinates (origin at bottom-left) to display coordinates (origin at top-left)
        guard let mainScreen = NSScreen.main else {
            return mouseLocation
        }

        let flippedY = mainScreen.frame.height - mouseLocation.y
        return CGPoint(x: mouseLocation.x, y: flippedY)
    }

    private func gatherClipboardContent() async -> String? {
        do {
            // Use the ClipboardServiceProtocol.get(prefer:) method
            // Request plain text content for context injection
            let result = try services.clipboard.get(prefer: .plainText)
            return result?.textPreview
        } catch {
            self.logger.debug("Failed to read clipboard: \(error.localizedDescription)")
            return nil
        }
    }

    private func gatherRecentApps() async -> [String] {
        // Get running applications, sorted by recent activation
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.localizedName)

        return Array(runningApps.prefix(5))
    }
}

// MARK: - Supporting Types

/// Represents the current desktop state at a point in time.
public struct DesktopContext: Sendable {
    public let focusedWindow: FocusedWindowInfo?
    public let cursorPosition: CGPoint?
    public let clipboardPreview: String?
    public let recentApps: [String]
    public let timestamp: Date

    public init(
        focusedWindow: FocusedWindowInfo?,
        cursorPosition: CGPoint?,
        clipboardPreview: String?,
        recentApps: [String],
        timestamp: Date)
    {
        self.focusedWindow = focusedWindow
        self.cursorPosition = cursorPosition
        self.clipboardPreview = clipboardPreview
        self.recentApps = recentApps
        self.timestamp = timestamp
    }
}

/// Information about the currently focused window.
public struct FocusedWindowInfo: Sendable {
    public let appName: String
    public let title: String
    public let bounds: CGRect?
    public let processId: Int

    public init(appName: String, title: String, bounds: CGRect?, processId: Int) {
        self.appName = appName
        self.title = title
        self.bounds = bounds
        self.processId = processId
    }
}
