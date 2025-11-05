//
//  AgentDisplayTokens.swift
//  PeekabooCore
//

import Foundation

/// Shared glyphs and tokens used to render agent output consistently across the CLI and Mac app.
public enum AgentDisplayTokens {
    /// Canonical status markers
    public enum Status {
        public static let running = "[run]"
        public static let success = "[ok]"
        public static let failure = "[err]"
        public static let warning = "[warn]"
        public static let info = "[info]"
        public static let done = "[done]"
        public static let time = "[time]"
        public static let planning = "[plan]"
        public static let dialog = "[dialog]"
    }

    /// Canonical glyphs for tool categories
    private static let iconByKey: [String: String] = [
        "see": "[see]",
        "screenshot": "[see]",
        "window_capture": "[see]",
        "click": "[tap]",
        "dialog_click": "[tap]",
        "type": "[type]",
        "dialog_input": "[type]",
        "press": "[type]",
        "list_apps": "[apps]",
        "launch_app": "[apps]",
        "list_windows": "[win]",
        "focus_window": "[focus]",
        "resize_window": "[win]",
        "list_screens": "[scrn]",
        "list_spaces": "[space]",
        "switch_space": "[space]",
        "move_window_to_space": "[space]",
        "hotkey": "[key]",
        "wait": Status.time,
        "scroll": "[scrl]",
        "find_element": "[find]",
        "list_elements": "[find]",
        "focused": "[focus]",
        "shell": "[sh]",
        "menu_click": "[menu]",
        "list_menus": "[menu]",
        "list_dock": "[dock]",
        "dock_click": "[dock]",
        "dock_launch": "[dock]",
        "copy_to_clipboard": "[clip]",
        "paste_from_clipboard": "[clip]",
        "move": "[move]",
        "drag": "[move]",
        "swipe": "[move]",
        "task_completed": Status.done,
        "done": Status.done,
        "need_more_information": Status.info,
        "need_info": Status.info,
        "dialog": Status.dialog,
    ]

    /// Normalize a tool name for dictionary lookup
    private static func normalizedToolKey(_ toolName: String) -> String {
        let key = toolName
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return key
    }

    /// Resolve the glyph token for a tool name, falling back to a generic token.
    public static func icon(for toolName: String) -> String {
        let key = self.normalizedToolKey(toolName)
        if let token = iconByKey[key] {
            return token
        }

        // Attempt to match prefix-based aliases (e.g. "see_tool")
        if let token = iconByKey.first(where: { key.hasPrefix($0.key) })?.value {
            return token
        }

        return "[tool]"
    }
}
