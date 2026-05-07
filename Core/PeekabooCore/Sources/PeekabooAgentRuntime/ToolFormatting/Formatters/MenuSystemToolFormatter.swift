//
//  MenuSystemToolFormatter.swift
//  PeekabooCore
//

import Foundation
import PeekabooAutomation

/// Formatter for menu and dialog tools with comprehensive result formatting.
public class MenuSystemToolFormatter: BaseToolFormatter {
    override public func formatResultSummary(result: [String: Any]) -> String {
        switch toolType {
        case .menuClick:
            self.formatMenuClickResult(result)

        case .listMenus:
            self.formatListMenuItemsResult(result)

        case .dialogInput:
            self.formatDialogInputResult(result)

        case .dialogClick:
            self.formatDialogClickResult(result)

        default:
            super.formatResultSummary(result: result)
        }
    }
}
