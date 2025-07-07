// AXAttributeNameConstants.swift - Accessibility attribute name constants

import Foundation

public enum AXAttributeNames {
    // Standard Accessibility Attributes - Values should match CFSTR defined in AXAttributeConstants.h
    public static let kAXRoleAttribute = "AXRole" // Reverted to String literal
    public static let kAXSubroleAttribute = "AXSubrole"
    public static let kAXRoleDescriptionAttribute = "AXRoleDescription"
    public static let kAXTitleAttribute = "AXTitle"
    public static let kAXValueAttribute = "AXValue"
    public static let kAXValueDescriptionAttribute = "AXValueDescription" // New
    public static let kAXDescriptionAttribute = "AXDescription"
    public static let kAXHelpAttribute = "AXHelp"
    public static let kAXIdentifierAttribute = "AXIdentifier"
    public static let kAXPlaceholderValueAttribute = "AXPlaceholderValue"
    public static let kAXLabelUIElementAttribute = "AXLabelUIElement"
    public static let kAXTitleUIElementAttribute = "AXTitleUIElement"
    public static let kAXLabelValueAttribute = "AXLabelValue"
    public static let kAXElementBusyAttribute = "AXElementBusy" // New
    public static let kAXAlternateUIVisibleAttribute = "AXAlternateUIVisible" // New

    public static let kAXChildrenAttribute = "AXChildren"
    public static let kAXParentAttribute = "AXParent"
    public static let kAXWindowsAttribute = "AXWindows"
    public static let kAXMainWindowAttribute = "AXMainWindow"
    public static let kAXFocusedWindowAttribute = "AXFocusedWindow"
    public static let kAXFocusedUIElementAttribute = "AXFocusedUIElement"

    public static let kAXEnabledAttribute = "AXEnabled"
    public static let kAXFocusedAttribute = "AXFocused"
    public static let kAXMainAttribute = "AXMain" // Window-specific
    public static let kAXMinimizedAttribute = "AXMinimized" // New, Window-specific
    public static let kAXCloseButtonAttribute = "AXCloseButton" // New, Window-specific
    public static let kAXZoomButtonAttribute = "AXZoomButton" // New, Window-specific
    public static let kAXMinimizeButtonAttribute = "AXMinimizeButton" // New, Window-specific
    public static let kAXFullScreenButtonAttribute = "AXFullScreenButton" // New, Window-specific
    public static let kAXDefaultButtonAttribute = "AXDefaultButton" // New, Window-specific
    public static let kAXCancelButtonAttribute = "AXCancelButton" // New, Window-specific
    public static let kAXGrowAreaAttribute = "AXGrowArea" // New, Window-specific
    public static let kAXModalAttribute = "AXModal" // New, Window-specific

    public static let kAXMenuBarAttribute = "AXMenuBar" // New, App-specific
    public static let kAXFrontmostAttribute = "AXFrontmost" // New, App-specific
    public static let kAXHiddenAttribute = "AXHidden" // New, App-specific

    public static let kAXPositionAttribute = "AXPosition"
    public static let kAXSizeAttribute = "AXSize"

    // Value attributes
    public static let kAXMinValueAttribute = "AXMinValue" // New
    public static let kAXMaxValueAttribute = "AXMaxValue" // New
    public static let kAXValueIncrementAttribute = "AXValueIncrement" // New
    public static let kAXAllowedValuesAttribute = "AXAllowedValues" // New

    // Text-specific attributes
    public static let kAXSelectedTextAttribute = "AXSelectedText" // New
    public static let kAXSelectedTextRangeAttribute = "AXSelectedTextRange" // New
    public static let kAXNumberOfCharactersAttribute = "AXNumberOfCharacters" // New
    public static let kAXVisibleCharacterRangeAttribute = "AXVisibleCharacterRange" // New
    public static let kAXInsertionPointLineNumberAttribute = "AXInsertionPointLineNumber" // New

    // Actions - Values should match CFSTR defined in AXActionConstants.h
    public static let kAXActionsAttribute = "AXActions" // This is actually kAXActionNamesAttribute typically
    public static let kAXActionNamesAttribute = "AXActionNames" // Correct name for listing actions
    public static let kAXActionDescriptionAttribute =
        "AXActionDescription" // To get desc of an action (not in AXActionConstants.h but AXUIElement.h)

    // Attributes for web content and tables/lists
    public static let kAXVisibleChildrenAttribute = "AXVisibleChildren"
    public static let kAXSelectedChildrenAttribute = "AXSelectedChildren"
    public static let kAXTabsAttribute = "AXTabs" // Often a kAXRadioGroup or kAXTabGroup role
    public static let kAXRowsAttribute = "AXRows"
    public static let kAXColumnsAttribute = "AXColumns"
    public static let kAXSelectedRowsAttribute = "AXSelectedRows" // New
    public static let kAXSelectedColumnsAttribute = "AXSelectedColumns" // New
    public static let kAXIndexAttribute = "AXIndex" // New (for rows/columns)
    public static let kAXDisclosingAttribute = "AXDisclosing" // New (for outlines)

    // Custom or less standard attributes (verify usage and standard names)
    public static let kAXPathHintAttribute = "AXPathHint" // Our custom attribute for pathing

    // DOM specific attributes (these seem custom or web-specific, not standard Apple AX)
    // Verify if these are actual attribute names exposed by web views or custom implementations.
    public static let kAXDOMIdentifierAttribute = "AXDOMIdentifier" // Example, might not be standard AX
    public static let kAXDOMClassListAttribute = "AXDOMClassList" // Example, might not be standard AX
    public static let kAXARIADOMResourceAttribute = "AXARIADOMResource" // Example
    public static let kAXARIADOMFunctionAttribute = "AXARIADOM-función" // Corrected identifier, kept original string value.
    public static let kAXARIADOMChildrenAttribute = "AXARIADOMChildren" // New
    public static let kAXDOMChildrenAttribute = "AXDOMChildren" // New

    // New constants for missing attributes
    public static let kAXToolbarButtonAttribute = "AXToolbarButton"
    public static let kAXProxyAttribute = "AXProxy"
    public static let kAXSelectedCellsAttribute = "AXSelectedCells"
    public static let kAXHeaderAttribute = "AXHeader"
    public static let kAXHorizontalScrollBarAttribute = "AXHorizontalScrollBar"
    public static let kAXVerticalScrollBarAttribute = "AXVerticalScrollBar"

    // Attributes used in child heuristic collection (often non-standard or specific)
    public static let kAXWebAreaChildrenAttribute = "AXWebAreaChildren"
    public static let kAXHTMLContentAttribute = "AXHTMLContent"
    public static let kAXApplicationNavigationAttribute = "AXApplicationNavigation"
    public static let kAXApplicationElementsAttribute = "AXApplicationElements"
    public static let kAXContentsAttribute = "AXContents"
    public static let kAXBodyAreaAttribute = "AXBodyArea"
    public static let kAXDocumentContentAttribute = "AXDocumentContent"
    public static let kAXWebPageContentAttribute = "AXWebPageContent"
    public static let kAXSplitGroupContentsAttribute = "AXSplitGroupContents"
    public static let kAXLayoutAreaChildrenAttribute = "AXLayoutAreaChildren"
    public static let kAXGroupChildrenAttribute = "AXGroupChildren"
}
