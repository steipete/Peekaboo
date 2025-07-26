// NotificationTypes.swift - AX notification type definitions

import Foundation

// MARK: - AXNotificationName enum

// Define AXNotificationName as a String-based enum for notification names
public enum AXNotificationName: String, Codable, Sendable {
    case focusedUIElementChanged = "AXFocusedUIElementChanged"
    case valueChanged = "AXValueChanged"
    case uiElementDestroyed = "AXUIElementDestroyed"
    case mainWindowChanged = "AXMainWindowChanged"
    case focusedWindowChanged = "AXFocusedWindowChanged"
    case applicationActivated = "AXApplicationActivated"
    case applicationDeactivated = "AXApplicationDeactivated"
    case applicationHidden = "AXApplicationHidden"
    case applicationShown = "AXApplicationShown"
    case windowCreated = "AXWindowCreated"
    case windowResized = "AXWindowResized"
    case windowMoved = "AXWindowMoved"
    case announcementRequested = "AXAnnouncementRequested"
    case focusedApplicationChanged = "AXFocusedApplicationChanged"
    case focusedTabChanged = "AXFocusedTabChanged"
    case windowMinimized = "AXWindowMiniaturized"
    case windowDeminiaturized = "AXWindowDeminiaturized"
    case sheetCreated = "AXSheetCreated"
    case drawerCreated = "AXDrawerCreated"
    case titleChanged = "AXTitleChanged"
    case resized = "AXResized"
    case moved = "AXMoved"
    case created = "AXCreated"
    case layoutChanged = "AXLayoutChanged"
    case selectedTextChanged = "AXSelectedTextChanged"
    case rowCountChanged = "AXRowCountChanged"
    case selectedChildrenChanged = "AXSelectedChildrenChanged"
    case selectedRowsChanged = "AXSelectedRowsChanged"
    case selectedColumnsChanged = "AXSelectedColumnsChanged"
    case rowExpanded = "AXRowExpanded"
    case rowCollapsed = "AXRowCollapsed"
    case selectedCellsChanged = "AXSelectedCellsChanged"
    case helpTagCreated = "AXHelpTagCreated"
    case loadComplete = "AXLoadComplete"
}
