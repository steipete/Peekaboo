//
//  UIAutomationToolFormatter.swift
//  PeekabooCore
//

import Foundation

/// Formatter for UI automation tools with comprehensive result formatting
public class UIAutomationToolFormatter: BaseToolFormatter {
    override public func formatResultSummary(result: [String: Any]) -> String {
        switch toolType {
        case .click:
            self.formatClickResult(result)
        case .type:
            self.formatTypeResult(result)
        case .hotkey:
            self.formatHotkeyResult(result)
        case .press:
            self.formatPressResult(result)
        case .scroll:
            self.formatScrollResult(result)
        case .drag:
            self.formatDragResult(result)
        case .swipe:
            self.formatSwipeResult(result)
        case .move:
            self.formatMoveResult(result)
        default:
            super.formatResultSummary(result: result)
        }
    }
}
