//
//  CFConstants.swift
//  AXorcist
//
//  Sendable wrapper for Core Foundation constants used in accessibility operations
//

@preconcurrency import ApplicationServices
@preconcurrency import CoreGraphics
@preconcurrency import Foundation

/// A comprehensive thread-safe wrapper for Core Foundation constants used throughout AXorcist.
///
/// This struct provides Sendable access to CF constants that are otherwise not
/// concurrency-safe. All constants are captured at initialization time and can
/// be safely used across actor boundaries.
///
/// The wrapper includes constants from:
/// - Accessibility framework (AX constants)
/// - Core Graphics (CG constants)
/// - Core Foundation (CF constants)
public struct CFConstants: @unchecked Sendable {

    // MARK: - AX Trust and Permission Constants

    /// The prompt option for AXIsProcessTrustedWithOptions
    public static let axTrustedCheckOptionPrompt: String = {
        kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    }()

    // MARK: - Core Graphics Window Constants

    /// Window layer constants for CGWindowListCopyWindowInfo
    public static let cgWindowListOptionOnScreenOnly = CGWindowListOption.optionOnScreenOnly
    public static let cgWindowListExcludeDesktopElements = CGWindowListOption.excludeDesktopElements

    /// Null window ID constant for window queries
    public static let cgNullWindowID = kCGNullWindowID

    /// Window info dictionary keys as strings
    public static let cgWindowOwnerPID: String = {
        kCGWindowOwnerPID as String
    }()

    public static let cgWindowName: String = {
        kCGWindowName as String
    }()

    public static let cgWindowNumber: String = {
        kCGWindowNumber as String
    }()

    public static let cgWindowBounds: String = {
        kCGWindowBounds as String
    }()

    // MARK: - Core Foundation Boolean Constants

    /// CF Boolean constants for safer usage in concurrent contexts
    public static let cfBooleanTrue = kCFBooleanTrue
    public static let cfBooleanFalse = kCFBooleanFalse
    public static let cfNull = kCFNull

    // MARK: - AX Value Type Constants

    /// AX Value type constants for geometric and other structured values
    public static let axValueCGPointType = kAXValueCGPointType
    public static let axValueCGSizeType = kAXValueCGSizeType
    public static let axValueCGRectType = kAXValueCGRectType
    public static let axValueCFRangeType = kAXValueCFRangeType
    public static let axValueAXErrorType = kAXValueAXErrorType
    public static let axValueIllegalType = kAXValueIllegalType

    // MARK: - AX Notification Constants

    /// Accessibility notification constants as strings
    public static let axFocusedUIElementChangedNotification: String = {
        kAXFocusedUIElementChangedNotification as String
    }()

    public static let axWindowCreatedNotification: String = {
        kAXWindowCreatedNotification as String
    }()

    public static let axWindowMovedNotification: String = {
        kAXWindowMovedNotification as String
    }()

    public static let axWindowResizedNotification: String = {
        kAXWindowResizedNotification as String
    }()

    // MARK: - AX Attribute Constants

    /// Core accessibility attribute constants as strings
    public static let axPositionAttribute: String = {
        kAXPositionAttribute as String
    }()

    public static let axValueAttribute: String = {
        kAXValueAttribute as String
    }()

    public static let axRoleAttribute: String = {
        kAXRoleAttribute as String
    }()

    public static let axRoleDescriptionAttribute: String = {
        kAXRoleDescriptionAttribute as String
    }()

    public static let axWindowsAttribute: String = {
        kAXWindowsAttribute as String
    }()

    public static let axFocusedUIElementAttribute: String = {
        kAXFocusedUIElementAttribute as String
    }()

    // MARK: - AX Role Constants

    /// Accessibility role constants as strings
    public static let axTextAreaRole: String = {
        kAXTextAreaRole as String
    }()

    public static let axWindowRole: String = {
        kAXWindowRole as String
    }()

    public static let axApplicationRole: String = {
        kAXApplicationRole as String
    }()

    // MARK: - Helper Methods

    /// Returns a CF boolean value as a Swift Bool safely
    public static func boolValue(from cfBoolean: CFBoolean) -> Bool {
        CFBooleanGetValue(cfBoolean)
    }

    /// Creates a CF boolean from a Swift Bool safely
    public static func cfBoolean(from bool: Bool) -> CFBoolean {
        bool ? cfBooleanTrue! : cfBooleanFalse!
    }
}
