// AccessibilityConstants.swift - Centralized accessibility constants

import Foundation

// MARK: - Accessibility Action Names

public enum AXActionNames {
    // Standard Actions (from AXActionConstants.h and common usage)
    public static let kAXPressAction = "AXPress"
    public static let kAXIncrementAction = "AXIncrement"
    public static let kAXDecrementAction = "AXDecrement"
    public static let kAXConfirmAction = "AXConfirm"
    public static let kAXCancelAction = "AXCancel"
    public static let kAXShowMenuAction = "AXShowMenu"
    public static let kAXPickAction = "AXPick" // Often listed as obsolete but can appear
    public static let kAXRaiseAction = "AXRaise" // Brings an element to the front

    // Less common or sometimes context-specific
    // public static let kAXShowAlternateUIAction = "AXShowAlternateUI" // Shows an alternative UI for the element
    // public static let kAXShowDefaultUIAction = "AXShowDefaultUI"     // Shows the default UI for the element
    // public static let kAXDeleteAction = "AXDelete" // Action to delete content or an element

    // Internal/Custom action name for setting a value via performAction handler
    public static let kAXSetValueAction = "AXSetValue"
}

// MARK: - Modern Action Enum

/// Modern enum-based API for accessibility actions with cleaner syntax
public enum AXAction {
    case press
    case increment
    case decrement
    case confirm
    case cancel
    case showMenu
    case pick
    case raise
    case setValue

    // MARK: Public

    /// The raw string value for the action
    public var rawValue: String {
        switch self {
        case .press: AXActionNames.kAXPressAction
        case .increment: AXActionNames.kAXIncrementAction
        case .decrement: AXActionNames.kAXDecrementAction
        case .confirm: AXActionNames.kAXConfirmAction
        case .cancel: AXActionNames.kAXCancelAction
        case .showMenu: AXActionNames.kAXShowMenuAction
        case .pick: AXActionNames.kAXPickAction
        case .raise: AXActionNames.kAXRaiseAction
        case .setValue: AXActionNames.kAXSetValueAction
        }
    }
}

// MARK: - Accessibility Attribute Names

public enum AXAttributeNames {
    // Core Element Attributes
    public static let kAXPIDAttribute = "AXPid" // Process ID attribute
    public static let kAXRoleAttribute = "AXRole"
    public static let kAXSubroleAttribute = "AXSubrole"
    public static let kAXRoleDescriptionAttribute = "AXRoleDescription"
    public static let kAXTitleAttribute = "AXTitle"
    public static let kAXValueAttribute = "AXValue" // Can be String, Number, Bool, etc.
    public static let kAXValueDescriptionAttribute = "AXValueDescription"
    public static let kAXDescriptionAttribute = "AXDescription" // Often a more detailed description than title
    public static let kAXHelpAttribute = "AXHelp" // Tooltip or help text
    public static let kAXIdentifierAttribute = "AXIdentifier" // Developer-assigned unique ID
    // DOM-specific attributes are declared in the Web-specific section below to avoid duplication
    public static let kAXDOMClassListAttribute = "AXDOMClassList" // [String] or String
    public static let kAXDOMIdentifierAttribute = "AXDOMIdentifier" // String (DOM id)

    // State Attributes
    public static let kAXEnabledAttribute = "AXEnabled" // Bool
    public static let kAXFocusedAttribute = "AXFocused" // Bool
    public static let kAXElementBusyAttribute = "AXElementBusy" // Bool
    public static let kAXAlternateUIVisibleAttribute = "AXAlternateUIVisible" // Bool
    public static let kAXOrientationAttribute =
        "AXOrientation" // String e.g. "AXVerticalOrientationValue", "AXHorizontalOrientationValue"

    // Hierarchy Attributes
    public static let kAXParentAttribute = "AXParent" // AXUIElement
    public static let kAXChildrenAttribute = "AXChildren" // [AXUIElement]
    public static let kAXSelectedChildrenAttribute = "AXSelectedChildren" // [AXUIElement]
    public static let kAXVisibleChildrenAttribute = "AXVisibleChildren" // [AXUIElement]
    public static let kAXWindowAttribute = "AXWindow" // AXUIElement (containing window)
    public static let kAXTopLevelUIElementAttribute = "AXTopLevelUIElement" // AXUIElement (top-level window/element)

    // Application Attributes
    public static let kAXMainWindowAttribute = "AXMainWindow" // AXUIElement
    public static let kAXFocusedWindowAttribute = "AXFocusedWindow" // AXUIElement
    public static let kAXFocusedUIElementAttribute = "AXFocusedUIElement" // AXUIElement (within an app)
    public static let kAXWindowsAttribute = "AXWindows" // [AXUIElement] (app's windows)
    public static let kAXMenuBarAttribute = "AXMenuBar" // AXUIElement
    public static let kAXFrontmostAttribute = "AXFrontmost" // Bool (is app frontmost?)
    public static let kAXHiddenAttribute = "AXHidden" // Bool (is app hidden?)
    // public static let kAXEnhancedUserInterfaceAttribute = "AXEnhancedUserInterface" // Bool (private)

    // System-wide Attributes (available on SystemWide element)
    public static let kAXFocusedApplicationAttribute =
        "AXFocusedApplication" // AXUIElement (the currently focused application)

    // Window Attributes
    public static let kAXMainAttribute = "AXMain" // Bool (is window main?)
    public static let kAXMinimizedAttribute = "AXMinimized" // Bool
    public static let kAXFullScreenAttribute = "AXFullScreen" // Bool (is window fullscreen?)
    public static let kAXCloseButtonAttribute = "AXCloseButton" // AXUIElement
    public static let kAXZoomButtonAttribute = "AXZoomButton" // AXUIElement
    public static let kAXMinimizeButtonAttribute = "AXMinimizeButton" // AXUIElement
    public static let kAXFullScreenButtonAttribute = "AXFullScreenButton" // AXUIElement
    public static let kAXDefaultButtonAttribute = "AXDefaultButton" // AXUIElement
    public static let kAXCancelButtonAttribute = "AXCancelButton" // AXUIElement
    public static let kAXGrowAreaAttribute = "AXGrowArea" // AXUIElement
    public static let kAXModalAttribute = "AXModal" // Bool
    public static let kAXProxyAttribute = "AXProxy" // AXUIElement (e.g., window's document proxy icon)
    public static let kAXToolbarButtonAttribute = "AXToolbarButton" // AXUIElement (button to show/hide toolbar)

    // Geometry Attributes (values are AXValue containing CGPoint, CGSize)
    public static let kAXPositionAttribute = "AXPosition" // AXValue (CGPoint)
    public static let kAXSizeAttribute = "AXSize" // AXValue (CGSize)
    // public static let kAXFrameAttribute = "AXFrame" // AXValue (CGRect) - Less common, usually derived

    // Value-specific Attributes
    public static let kAXMinValueAttribute = "AXMinValue"
    public static let kAXMaxValueAttribute = "AXMaxValue"
    public static let kAXValueIncrementAttribute = "AXValueIncrement"
    public static let kAXAllowedValuesAttribute = "AXAllowedValues" // [Any]
    public static let kAXPlaceholderValueAttribute = "AXPlaceholderValue" // String (for text fields)
    public static let kAXPlaceholderTextAttribute = "AXPlaceholderText" // Non-standard, but sometimes seen
    public static let kAXLabelValueAttribute = "AXLabelValue" // For AXLabel elements, often has the text of the label.

    // Text-specific Attributes
    public static let kAXSelectedTextAttribute = "AXSelectedText" // String
    public static let kAXSelectedTextRangeAttribute = "AXSelectedTextRange" // AXValue (CFRange)
    public static let kAXNumberOfCharactersAttribute = "AXNumberOfCharacters" // Int
    public static let kAXVisibleCharacterRangeAttribute = "AXVisibleCharacterRange" // AXValue (CFRange)
    public static let kAXInsertionPointLineNumberAttribute = "AXInsertionPointLineNumber" // Int
    // public static let kAXTextInputMarkedRangeAttribute = "AXTextInputMarkedRange" // AXValue (CFRange) (private)

    // Action-related Attributes
    public static let kAXActionNamesAttribute = "AXActionNames" // [String]
    public static let kAXActionDescriptionAttribute = "AXActionDescription" // String (parameterized by action name)

    // Table, List, Outline Attributes
    public static let kAXRowsAttribute = "AXRows" // [AXUIElement]
    public static let kAXColumnsAttribute = "AXColumns" // [AXUIElement]
    public static let kAXSelectedRowsAttribute = "AXSelectedRows" // [AXUIElement]
    public static let kAXSelectedColumnsAttribute = "AXSelectedColumns" // [AXUIElement]
    public static let kAXVisibleRowsAttribute = "AXVisibleRows" // [AXUIElement]
    public static let kAXVisibleColumnsAttribute = "AXVisibleColumns" // [AXUIElement]
    public static let kAXHeaderAttribute = "AXHeader" // AXUIElement (e.g., for a column)
    public static let kAXIndexAttribute = "AXIndex" // Int (e.g., row/column index)
    public static let kAXDisclosingAttribute = "AXDisclosing" // Bool (for outline rows)
    public static let kAXDisclosedRowsAttribute = "AXDisclosedRows" // [AXUIElement]
    public static let kAXDisclosureLevelAttribute = "AXDisclosureLevel" // Int

    // ScrollView/Area Attributes
    public static let kAXHorizontalScrollBarAttribute = "AXHorizontalScrollBar" // AXUIElement
    public static let kAXVerticalScrollBarAttribute = "AXVerticalScrollBar" // AXUIElement
    public static let kAXScrollAreaContentsAttribute =
        "AXContents" // Often an alias or specific child group for scroll areas

    // Web-specific (often found in WebArea roles)
    public static let kAXURLAttribute = "AXURL" // URL or String
    public static let kAXDocumentAttribute = "AXDocument" // String (URL or path of document)
    // public static let kAXARIADOMResourceAttribute = "AXARIADOMResource"
    // public static let kAXARIADOMFunctionAttribute = "AXARIADOM-función" // Keep original as it might be specific
    // public static let kAXARIADOMChildrenAttribute = "AXARIADOMChildren"
    // public static let kAXDOMChildrenAttribute = "AXDOMChildren"

    // Cell-specific Attributes
    public static let kAXCellForColumnAndRowParameterizedAttribute =
        "AXCellForColumnAndRowParameterized" // AXUIElement (params: col, row)
    public static let kAXRowIndexRangeAttribute = "AXRowIndexRange" // AXValue (CFRange)
    public static let kAXColumnIndexRangeAttribute = "AXColumnIndexRange" // AXValue (CFRange)
    public static let kAXSelectedCellsAttribute = "AXSelectedCells" // [AXUIElement]

    // Tabs
    public static let kAXTabsAttribute = "AXTabs" // [AXUIElement]

    // Linking Attributes
    public static let kAXTitleUIElementAttribute = "AXTitleUIElement" // AXUIElement
    public static let kAXServesAsTitleForUIElementsAttribute = "AXServesAsTitleForUIElements" // [AXUIElement]
    public static let kAXLinkedUIElementsAttribute = "AXLinkedUIElements" // [AXUIElement]

    // Parameterized Attributes (Set for easy checking)
    // These require parameters when being accessed via AXUIElementCopyParameterizedAttributeValue
    public static let parameterizedAttributes: Set<String> = [
        "AXStringForRangeParameterized", // Param: AXValue (CFRange) -> String
        "AXRangeForLineParameterized", // Param: Int (line number) -> AXValue (CFRange)
        "AXRangeForPositionParameterized", // Param: AXValue (CGPoint) -> AXValue (CFRange)
        "AXRangeForIndexParameterized", // Param: Int (char index) -> AXValue (CFRange)
        "AXBoundsForRangeParameterized", // Param: AXValue (CFRange) -> AXValue (CGRect)
        "AXRTFForRangeParameterized", // Param: AXValue (CFRange) -> Data
        "AXAttributedStringForRangeParameterized", // Param: AXValue (CFRange) -> AttributedString
        "AXStyleRangeForIndexParameterized", // Param: Int (char index) -> AXValue (CFRange)
        "AXLineForIndexParameterized", // Param: Int (char index) -> Int (line number)
        kAXCellForColumnAndRowParameterizedAttribute, // Already defined above
        kAXActionDescriptionAttribute, // Param: String (action name) -> String
        // AXLayoutPointForScreenPointParameterized, AXLayoutSizeForScreenSizeParameterized, etc. for layout areas
    ]

    // Attributes used in child heuristic collection (often non-standard or role-specific containers)
    public static let kAXWebAreaChildrenAttribute = "AXWebAreaChildren" // Often kAXChildren on AXWebArea
    public static let kAXHTMLContentAttribute = "AXHTMLContent" // Sometimes on web areas
    public static let kAXApplicationNavigationAttribute = "AXApplicationNavigation" // Could be custom
    public static let kAXApplicationElementsAttribute = "AXApplicationElements" // Could be custom
    public static let kAXContentsAttribute = "AXContents" // Generic container, e.g. for groups, scroll areas
    public static let kAXBodyAreaAttribute = "AXBodyArea" // Could be custom for web views
    public static let kAXDocumentContentAttribute = "AXDocumentContent" // Usually on window or document role
    public static let kAXWebPageContentAttribute = "AXWebPageContent" // Custom for web views
    public static let kAXSplitGroupContentsAttribute = "AXSplitGroupContents" // Children of a split group
    public static let kAXLayoutAreaChildrenAttribute = "AXLayoutAreaChildren" // Children of AXLayoutArea
    public static let kAXGroupChildrenAttribute = "AXGroupChildren" // Often just kAXChildren on AXGroup

    // Action related
    public static let kAXActionsAttribute = "AXActions" // Standard attribute for available actions.

    // Hierarchy and Path related
    public static let kAXPathHintAttribute = "AXPathHint" // Custom attribute for path hints, if used

    // Web content related
    // public static let kAXDOMIdentifierAttribute = "AXDOMIdentifier" // Used in web views for DOM element IDs.

    // macOS 13 additions (example)
    // public static let kAXCustomActionsAttribute = "AXCustomActions" // This is a guess, verify actual name
    public static let kAXValueWrapsAttribute = "AXValueWraps" // Added based on error

    // Attributes related to windows and applications (These were duplicated, ensure only one set exists)
    // kAXMainWindowAttribute, kAXFocusedWindowAttribute etc. are defined above.
    // Text Marker Attributes (ensure these are not duplicated from above or are correctly placed if unique)
    // public static let kAXSelectedTextMarkerRangeAttribute = "AXSelectedTextMarkerRange" // Already exists or part of
    // text attributes
    // public static let kAXVisibleTextMarkerRangeAttribute = "AXVisibleTextMarkerRange" // Already exists
    // public static let kAXTextMarkerRangeForUIElementAttribute = "AXTextMarkerRangeForUIElement" // Already exists
    // public static let kAXUIElementForTextMarkerAttribute = "AXUIElementForTextMarker" // Already exists
    // public static let kAXAttributedValueForTextMarkerRangeAttribute = "AXAttributedValueForTextMarkerRangeAttribute"
    // // Already exists
    // public static let kAXIndexForTextMarkerAttribute = "AXIndexForTextMarkerAttribute" // Already exists
    // public static let kAXTextMarkerForIndexAttribute = "AXTextMarkerForIndexAttribute" // Already exists
    // public static let kAXBoundsForTextMarkerRangeAttribute = "AXBoundsForTextMarkerRangeAttribute" // Already exists
    // public static let kAXLineTextMarkerRangeForTextMarkerAttribute = "AXLineTextMarkerRangeForTextMarkerAttribute" //
    // Already exists
}

// MARK: - Accessibility Role Names

public enum AXRoleNames {
    // Standard Application & System Roles
    public static let kAXApplicationRole = "AXApplication"
    public static let kAXSystemWideRole = "AXSystemWide" // For system-wide element

    // Window and Presentation Roles
    public static let kAXWindowRole = "AXWindow"
    public static let kAXSheetRole = "AXSheet"
    public static let kAXDrawerRole = "AXDrawer"
    public static let kAXDialogRole = "AXDialog" // Often a subrole of window

    // Grouping and Layout Roles
    public static let kAXGroupRole = "AXGroup" // Generic container
    public static let kAXScrollAreaRole = "AXScrollArea"
    public static let kAXSplitGroupRole = "AXSplitGroup"
    public static let kAXSplitterRole = "AXSplitter"
    public static let kAXToolbarRole = "AXToolbar"
    public static let kAXLayoutAreaRole = "AXLayoutArea"
    public static let kAXLayoutItemRole = "AXLayoutItem"

    // Control Roles
    public static let kAXButtonRole = "AXButton"
    public static let kAXRadioButtonRole = "AXRadioButton"
    public static let kAXCheckBoxRole = "AXCheckBox"
    public static let kAXPopUpButtonRole = "AXPopUpButton"
    public static let kAXMenuButtonRole = "AXMenuButton"
    public static let kAXSliderRole = "AXSlider"
    public static let kAXIncrementorRole = "AXIncrementor"
    public static let kAXScrollBarRole = "AXScrollBar"
    public static let kAXDisclosureTriangleRole = "AXDisclosureTriangle"
    public static let kAXComboBoxRole = "AXComboBox"
    public static let kAXTextFieldRole = "AXTextField" // Includes secure text fields by subrole
    public static let kAXColorWellRole = "AXColorWell"
    public static let kAXSearchFieldRole = "AXSearchField" // Often a subrole of text field
    public static let kAXSwitchRole = "AXSwitch" // e.g., macOS toggle switch

    // Text Roles
    public static let kAXStaticTextRole = "AXStaticText" // Non-editable text
    public static let kAXTextAreaRole = "AXTextArea" // Editable multi-line text

    // Menu and Menu Item Roles
    public static let kAXMenuBarRole = "AXMenuBar"
    public static let kAXMenuBarItemRole = "AXMenuBarItem"
    public static let kAXMenuRole = "AXMenu"
    public static let kAXMenuItemRole = "AXMenuItem"

    // List, Table, Outline Roles
    public static let kAXListRole = "AXList"
    public static let kAXTableRole = "AXTable"
    public static let kAXOutlineRole = "AXOutline"
    public static let kAXColumnRole = "AXColumn"
    public static let kAXRowRole = "AXRow" // Often a subrole within tables/outlines
    public static let kAXCellRole = "AXCell"

    // Indicator Roles
    public static let kAXValueIndicatorRole = "AXValueIndicator" // e.g., for a slider
    public static let kAXBusyIndicatorRole = "AXBusyIndicator" // Spinner
    public static let kAXProgressIndicatorRole = "AXProgressIndicator" // Progress bar
    public static let kAXRelevanceIndicatorRole = "AXRelevanceIndicator" // e.g., stars for rating
    public static let kAXLevelIndicatorRole = "AXLevelIndicator" // e.g., signal strength

    // Image and Web Content Roles
    public static let kAXImageRole = "AXImage"
    public static let kAXWebAreaRole = "AXWebArea" // Container for web content
    public static let kAXLinkRole = "AXLink"

    // Other Roles
    public static let kAXHelpTagRole = "AXHelpTag" // Tooltip content
    public static let kAXMatteRole = "AXMatte" // Backdrop for sheets/dialogs
    public static let kAXRulerRole = "AXRuler"
    public static let kAXRulerMarkerRole = "AXRulerMarker"
    public static let kAXGridRole = "AXGrid" // Generic grid structure
    public static let kAXGrowAreaRole = "AXGrowArea" // Resize handle of a window
    public static let kAXHandleRole = "AXHandle" // Generic grabbable handle
    public static let kAXPopoverRole = "AXPopover"

    public static let kAXUnknownRole = "AXUnknown" // Fallback role
}

// MARK: - Accessibility Notification Names (Moved from AXNotificationConstants.swift)

public enum AXNotification: String, Sendable {
    // System-Wide Notifications
    case mainWindowChanged = "AXMainWindowChanged" // kAXMainWindowChangedNotification
    case focusedWindowChanged = "AXFocusedWindowChanged" // kAXFocusedWindowChangedNotification
    case focusedUIElementChanged = "AXFocusedUIElementChanged" // kAXFocusedUIElementChangedNotification
    case applicationActivated = "AXApplicationActivated" // kAXApplicationActivatedNotification
    case applicationDeactivated = "AXApplicationDeactivated" // kAXApplicationDeactivatedNotification
    case applicationHidden = "AXApplicationHidden" // kAXApplicationHiddenNotification
    case applicationShown = "AXApplicationShown" // kAXApplicationShownNotification
    case windowCreated = "AXWindowCreated" // kAXWindowCreatedNotification
    case windowResized = "AXWindowResized" // kAXWindowResizedNotification
    case windowMoved = "AXWindowMoved" // kAXWindowMovedNotification
    case announcementRequested = "AXAnnouncementRequested" // kAXAnnouncementRequestedNotification
    case focusedApplicationChanged = "AXFocusedApplicationChanged" // kAXFocusedApplicationChangedNotification

    // UIElement Notifications (more specific)
    case focusedTabChanged = "AXFocusedTabChanged"
    case windowMinimized = "AXWindowMiniaturized" // Standard: NSAccessibilityWindowMiniaturizedNotification
    case windowDeminiaturized = "AXWindowDeminiaturized" // Standard: NSAccessibilityWindowDeminiaturizedNotification
    case sheetCreated = "AXSheetCreated"
    case drawerCreated = "AXDrawerCreated"
    case uiElementDestroyed = "AXUIElementDestroyed" // Standard: NSAccessibilityUIElementDestroyedNotification
    case valueChanged = "AXValueChanged"
    case titleChanged =
        "AXTitleChanged" // Not a standard top-level notification, often via kAXValueChanged on title attribute
    case resized = "AXResized" // Standard: NSAccessibilityResizedNotification
    case moved = "AXMoved" // Standard: NSAccessibilityMovedNotification
    case created = "AXCreated" // Standard: NSAccessibilityCreatedNotification (for UI elements)
    case layoutChanged = "AXLayoutChanged" // Might be app-specific or kAXUIElementsKey in userInfo
    case selectedTextChanged = "AXSelectedTextChanged" // Standard: NSAccessibilitySelectedTextChangedNotification
    case rowCountChanged = "AXRowCountChanged" // Standard: NSAccessibilityRowCountChangedNotification
    case selectedChildrenChanged =
        "AXSelectedChildrenChanged" // Standard: NSAccessibilitySelectedChildrenChangedNotification
    case selectedRowsChanged = "AXSelectedRowsChanged" // Standard: NSAccessibilitySelectedRowsChangedNotification
    case selectedColumnsChanged =
        "AXSelectedColumnsChanged" // Standard: NSAccessibilitySelectedColumnsChangedNotification
    case rowExpanded = "AXRowExpanded" // Standard: NSAccessibilityRowExpandedNotification (for outlines)
    case rowCollapsed = "AXRowCollapsed" // Standard: NSAccessibilityRowCollapsedNotification (for outlines)
    case selectedCellsChanged = "AXSelectedCellsChanged" // Standard: NSAccessibilitySelectedCellsChangedNotification
    case helpTagCreated = "AXHelpTagCreated" // Standard: NSAccessibilityHelpTagCreatedNotification
    case loadComplete = "AXLoadComplete" // Often for web views after content is loaded

    // Menu related (examples, verify standard names if they exist as top-level notifications)
    // case menuOpened = "AXMenuOpened"
    // case menuClosed = "AXMenuClosed"
    // case menuItemSelected = "AXMenuItemSelected"

    // From AppKit/NSAccessibility.h - many more exist.
    // These string values must match the actual CFString constants used by the system.
    // For example, NSAccessibilityMainWindowChangedNotification is "AXMainWindowChanged".

    // Add other system-defined notifications as needed
}

// MARK: - Miscellaneous Accessibility Constants

public enum AXMiscConstants {
    public static let axBinaryVersion = "0.8.0" // AXorcist version for this constants file

    // Default attributes to fetch when none are specified
    public static let defaultAttributesToFetch: [String] = [
        AXAttributeNames.kAXRoleAttribute,
        AXAttributeNames.kAXSubroleAttribute,
        AXAttributeNames.kAXTitleAttribute,
        AXAttributeNames.kAXValueAttribute,
        AXAttributeNames.kAXIdentifierAttribute,
        AXAttributeNames.kAXDOMClassListAttribute,
        AXAttributeNames.kAXDOMIdentifierAttribute,
        AXAttributeNames.kAXDescriptionAttribute,
        AXAttributeNames.kAXEnabledAttribute,
        AXAttributeNames.kAXFocusedAttribute,
        AXAttributeNames.kAXPositionAttribute,
        AXAttributeNames.kAXSizeAttribute,
        AXAttributeNames.kAXChildrenAttribute, // To get an idea of hierarchy
    ]

    // Default values for collection and search
    public static let defaultMaxDepthCollectAll = 5
    public static let defaultMaxDepthSearch = 10
    public static let defaultMaxDepthPathResolution = 10
    public static let defaultMaxDepthDescribe = 3
    public static let defaultMaxDepthSearchForHintStep = 3 // Default depth for JSON path hint navigation per step
    public static let defaultMaxElementsToCollect = 1000 // New constant for element collection limit
    public static let defaultTimeoutPerElementCollectAll: TimeInterval = 2.0 // seconds

    // String Constants (for default/fallback values)
    public static let kAXNotAvailableString = "n/a" // Placeholder for unavailable attribute values

    // Keys for userInfo dictionaries or internal use
    public static let focusedApplicationKey = "focusedApplication" // Key to signify the focused application
    // focusedWindowKey was here, but seems unused, can be re-added if needed
    public static let focusedUIElementKey =
        "focusedUIElement" // Key for focused UI element in userInfo (used in AXObserverCenter)

    // Keys for Custom/Computed Attributes or App Identifiers (used in AttributeHelpers, etc.)
    public static let computedNameAttributeKey = "ComputedName" // Key for element's computed name
    public static let computedPathAttributeKey = "ComputedPath" // Key for element's computed path string
    public static let isClickableAttributeKey = "IsClickable" // Key for computed clickability
    public static let isIgnoredAttributeKey = "IsIgnored" // Key for computed ignored status

    // Path generation constants
    public static let maxPathSegments = 20 // Limit for path segment generation to avoid infinite loops
    // pathHintAttributeKey was for Element.swift's pathHint property, which is different from
    // AXAttributeNames.kAXPathHintAttribute
}
