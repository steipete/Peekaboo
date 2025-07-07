// AXActionNameConstants.swift - Accessibility action name constants

import Foundation

public enum AXActionNames {
    public static let kAXIncrementAction = "AXIncrement" // New
    public static let kAXDecrementAction = "AXDecrement" // New
    public static let kAXConfirmAction = "AXConfirm" // New
    public static let kAXCancelAction = "AXCancel" // New
    public static let kAXShowMenuAction = "AXShowMenu"
    public static let kAXPickAction = "AXPick" // New (Obsolete in headers, but sometimes seen)
    public static let kAXPressAction = "AXPress" // New
    public static let kAXRaiseAction = "AXRaise" // New

    // Specific action name for setting a value, used internally by performActionOnElement
    public static let kAXSetValueAction = "AXSetValue"
}
