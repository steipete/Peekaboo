// Attribute.swift - Defines a typed wrapper for Accessibility Attribute keys.

import ApplicationServices // Re-add for AXUIElement type

// import ApplicationServices // For kAX... constants - We will now use AccessibilityConstants.swift primarily
import CoreGraphics // For CGRect, CGPoint, CGSize, CFRange
import Foundation

/// A type-safe wrapper for accessibility attribute keys.
///
/// Attribute provides compile-time type safety for accessibility attributes by
/// associating each attribute key with its expected value type. This prevents
/// runtime errors and provides better IDE support through type inference.
///
/// ## Topics
///
/// ### General Element Attributes
/// - ``role``
/// - ``subrole``
/// - ``title``
/// - ``description``
/// - ``identifier``
///
/// ### Value Attributes
/// - ``value``
/// - ``stringValue``
/// - ``attributedStringValue``
///
/// ### State Attributes
/// - ``enabled``
/// - ``focused``
/// - ``selected``
///
/// ### Creating Custom Attributes
/// - ``init(_:)``
/// - ``rawValue``
///
/// ## Usage
///
/// ```swift
/// // Type-safe attribute access
/// let titleAttr = Attribute<String>.title
/// let roleAttr = Attribute<String>.role
///
/// // Custom attribute
/// let customAttr = Attribute<String>("AXCustomAttribute")
/// ```
public struct Attribute<T> {
    // MARK: Lifecycle

    /// Creates a new attribute with the specified raw key.
    ///
    /// Use this initializer to create attributes for custom or less common
    /// accessibility properties not covered by the static properties.
    ///
    /// - Parameter rawValue: The accessibility attribute key string
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    // MARK: Public

    // MARK: - General Element Attributes

    public static var role: Attribute<String> { Attribute<String>(AXAttributeNames.kAXRoleAttribute) }
    public static var subrole: Attribute<String> { Attribute<String>(AXAttributeNames.kAXSubroleAttribute) }
    public static var roleDescription: Attribute<String> {
        Attribute<String>(AXAttributeNames.kAXRoleDescriptionAttribute)
    }

    public static var title: Attribute<String> { Attribute<String>(AXAttributeNames.kAXTitleAttribute) }
    public static var titleUIElement: Attribute<AXUIElement> {
        Attribute<AXUIElement>(AXAttributeNames.kAXTitleUIElementAttribute)
    }

    public static var description: Attribute<String> { Attribute<String>(AXAttributeNames.kAXDescriptionAttribute) }
    public static var help: Attribute<String> { Attribute<String>(AXAttributeNames.kAXHelpAttribute) }
    public static var identifier: Attribute<String> { Attribute<String>(AXAttributeNames.kAXIdentifierAttribute) }

    // MARK: - Value Attributes

    // kAXValueAttribute can be many types. For a generic getter, Any might be appropriate,
    // or specific versions if the context knows the type.
    // public static var value: Attribute<Any> { Attribute("AXValue") } // Generic Any can be problematic, prefer
    // specific types
    public static var valueDescription: Attribute<String> {
        Attribute<String>(AXAttributeNames.kAXValueDescriptionAttribute)
    }

    public static var valueIncrement: Attribute<NSNumber> {
        Attribute<NSNumber>(AXAttributeNames.kAXValueIncrementAttribute)
    }

    public static var valueWraps: Attribute<Bool> { Attribute<Bool>(AXAttributeNames.kAXValueWrapsAttribute) }
    // Example of a more specific value if known:
    // static var stringValue: Attribute<String> { Attribute(AXAttributeNames.kAXValueAttribute) }

    public static var placeholderValue: Attribute<String> {
        Attribute<String>(AXAttributeNames.kAXPlaceholderValueAttribute)
    }

    // MARK: - State Attributes

    public static var enabled: Attribute<Bool> { Attribute<Bool>(AXAttributeNames.kAXEnabledAttribute) }
    public static var focused: Attribute<Bool> { Attribute<Bool>(AXAttributeNames.kAXFocusedAttribute) }
    public static var busy: Attribute<Bool> { Attribute<Bool>(AXAttributeNames.kAXElementBusyAttribute) }
    public static var hidden: Attribute<Bool> { Attribute<Bool>(AXAttributeNames.kAXHiddenAttribute) }

    // MARK: - Hierarchy Attributes

    public static var parent: Attribute<AXUIElement> { Attribute<AXUIElement>(AXAttributeNames.kAXParentAttribute) }
    // For children, the direct attribute often returns [AXUIElement].
    // Element.children getter then wraps these.
    public static var children: Attribute<[AXUIElement]> {
        Attribute<[AXUIElement]>(AXAttributeNames.kAXChildrenAttribute)
    }

    public static var selectedChildren: Attribute<[AXUIElement]> {
        Attribute<[AXUIElement]>(AXAttributeNames.kAXSelectedChildrenAttribute)
    }

    public static var visibleChildren: Attribute<[AXUIElement]> {
        Attribute<[AXUIElement]>(AXAttributeNames.kAXVisibleChildrenAttribute)
    }

    public static var windows: Attribute<[AXUIElement]> {
        Attribute<[AXUIElement]>(AXAttributeNames.kAXWindowsAttribute)
    }

    public static var window: Attribute<AXUIElement> { Attribute<AXUIElement>(AXAttributeNames.kAXWindowAttribute)
    } // Often the main/key window of an app element
    public static var mainWindow: Attribute<AXUIElement> {
        Attribute<AXUIElement>(AXAttributeNames.kAXMainWindowAttribute)
    }

    public static var focusedWindow: Attribute<AXUIElement> {
        Attribute<AXUIElement>(AXAttributeNames.kAXFocusedWindowAttribute)
    }

    public static var focusedUIElement: Attribute<AXUIElement> {
        Attribute<AXUIElement>(AXAttributeNames.kAXFocusedUIElementAttribute)
    }

    // MARK: - Application Specific Attributes

    // public static var enhancedUserInterface: Attribute<Bool> {
    //     Attribute<Bool>(AXAttributeNames.kAXEnhancedUserInterfaceAttribute)
    // } // Constant not found, commenting out
    public static var frontmost: Attribute<Bool> { Attribute<Bool>(AXAttributeNames.kAXFrontmostAttribute) }
    public static var mainMenu: Attribute<AXUIElement> { Attribute<AXUIElement>(AXAttributeNames.kAXMenuBarAttribute) }
    // public static var hiddenApplication: Attribute<Bool> { Attribute(AXAttributeNames.kAXHiddenAttribute) } // Same
    // as element hidden, but for app. Covered by .hidden
    public static var focusedApplication: Attribute<AXUIElement> {
        Attribute<AXUIElement>(AXAttributeNames.kAXFocusedApplicationAttribute)
    }

    // MARK: - Window Specific Attributes

    public static var minimized: Attribute<Bool> { Attribute<Bool>(AXAttributeNames.kAXMinimizedAttribute) }
    public static var modal: Attribute<Bool> { Attribute<Bool>(AXAttributeNames.kAXModalAttribute) }
    public static var defaultButton: Attribute<AXUIElement> {
        Attribute<AXUIElement>(AXAttributeNames.kAXDefaultButtonAttribute)
    }

    public static var cancelButton: Attribute<AXUIElement> {
        Attribute<AXUIElement>(AXAttributeNames.kAXCancelButtonAttribute)
    }

    public static var closeButton: Attribute<AXUIElement> {
        Attribute<AXUIElement>(AXAttributeNames.kAXCloseButtonAttribute)
    }

    public static var zoomButton: Attribute<AXUIElement> {
        Attribute<AXUIElement>(AXAttributeNames.kAXZoomButtonAttribute)
    }

    public static var minimizeButton: Attribute<AXUIElement> {
        Attribute<AXUIElement>(AXAttributeNames.kAXMinimizeButtonAttribute)
    }

    public static var toolbarButton: Attribute<AXUIElement> {
        Attribute<AXUIElement>(AXAttributeNames.kAXToolbarButtonAttribute)
    }

    public static var fullScreenButton: Attribute<AXUIElement> {
        Attribute<AXUIElement>(AXAttributeNames.kAXFullScreenButtonAttribute)
    }

    public static var proxy: Attribute<AXUIElement> { Attribute<AXUIElement>(AXAttributeNames.kAXProxyAttribute) }
    public static var growArea: Attribute<AXUIElement> { Attribute<AXUIElement>(AXAttributeNames.kAXGrowAreaAttribute) }
    public static var main: Attribute<Bool> { Attribute<Bool>(AXAttributeNames.kAXMainAttribute) }
    public static var fullScreen: Attribute<Bool> { Attribute<Bool>(AXAttributeNames.kAXFullScreenAttribute) }

    // MARK: - Table/List/Outline Attributes

    public static var rows: Attribute<[AXUIElement]> { Attribute<[AXUIElement]>(AXAttributeNames.kAXRowsAttribute) }
    public static var columns: Attribute<[AXUIElement]> {
        Attribute<[AXUIElement]>(AXAttributeNames.kAXColumnsAttribute)
    }

    public static var selectedRows: Attribute<[AXUIElement]> {
        Attribute<[AXUIElement]>(AXAttributeNames.kAXSelectedRowsAttribute)
    }

    public static var selectedColumns: Attribute<[AXUIElement]> {
        Attribute<[AXUIElement]>(AXAttributeNames.kAXSelectedColumnsAttribute)
    }

    public static var selectedCells: Attribute<[AXUIElement]> {
        Attribute<[AXUIElement]>(AXAttributeNames.kAXSelectedCellsAttribute)
    }

    public static var visibleRows: Attribute<[AXUIElement]> {
        Attribute<[AXUIElement]>(AXAttributeNames.kAXVisibleRowsAttribute)
    }

    public static var visibleColumns: Attribute<[AXUIElement]> {
        Attribute<[AXUIElement]>(AXAttributeNames.kAXVisibleColumnsAttribute)
    }

    public static var header: Attribute<AXUIElement> { Attribute<AXUIElement>(AXAttributeNames.kAXHeaderAttribute) }
    public static var orientation: Attribute<String> { Attribute<String>(AXAttributeNames.kAXOrientationAttribute) }

    // MARK: - Text Attributes

    public static var selectedText: Attribute<String> { Attribute<String>(AXAttributeNames.kAXSelectedTextAttribute) }
    public static var selectedTextRange: Attribute<CFRange> {
        Attribute<CFRange>(AXAttributeNames.kAXSelectedTextRangeAttribute)
    }

    public static var numberOfCharacters: Attribute<Int> {
        Attribute<Int>(AXAttributeNames.kAXNumberOfCharactersAttribute)
    }

    public static var visibleCharacterRange: Attribute<CFRange> {
        Attribute<CFRange>(AXAttributeNames.kAXVisibleCharacterRangeAttribute)
    }

    // Parameterized attributes are handled differently, often via functions.
    // static var attributedStringForRange: Attribute<NSAttributedString> {
    // Attribute(kAXAttributedStringForRangeParameterizedAttribute) }
    // static var stringForRange: Attribute<String> { Attribute(kAXStringForRangeParameterizedAttribute) }

    // MARK: - Parameterized Text Attributes (Raw strings from AXAttributeConstants.h / common usage)

    public static var stringForRangeParameterized: Attribute<String> {
        Attribute<String>("AXStringForRangeParameterized")
    }

    public static var rangeForLineParameterized: Attribute<CFRange> { Attribute<CFRange>("AXRangeForLineParameterized")
    }

    public static var boundsForRangeParameterized: Attribute<CGRect> {
        Attribute<CGRect>("AXBoundsForRangeParameterized")
    }

    public static var lineForIndexParameterized: Attribute<Int> { Attribute<Int>("AXLineForIndexParameterized") }
    public static var attributedStringForRangeParameterized: Attribute<NSAttributedString> {
        Attribute<NSAttributedString>("AXAttributedStringForRangeParameterized")
    }

    // MARK: - Parameterized Table/Cell Attributes

    public static var cellForColumnAndRowParameterized: Attribute<AXUIElement> {
        Attribute<AXUIElement>(AXAttributeNames.kAXCellForColumnAndRowParameterizedAttribute)
    }

    // MARK: - Scroll Area Attributes

    public static var horizontalScrollBar: Attribute<AXUIElement> {
        Attribute<AXUIElement>(AXAttributeNames.kAXHorizontalScrollBarAttribute)
    }

    public static var verticalScrollBar: Attribute<AXUIElement> {
        Attribute<AXUIElement>(AXAttributeNames.kAXVerticalScrollBarAttribute)
    }

    // MARK: - Action Related

    // Action names are typically an array of strings.
    public static var actionNames: Attribute<[String]> { Attribute<[String]>(AXAttributeNames.kAXActionNamesAttribute) }
    // Action description is parameterized by the action name, so a simple Attribute<String> isn't quite right.
    // It would be kAXActionDescriptionAttribute, and you pass a parameter.
    // For now, we will represent it as taking a string, and the usage site will need to handle parameterization.
    public static var actionDescription: Attribute<String> {
        Attribute<String>(AXAttributeNames.kAXActionDescriptionAttribute)
    }

    // MARK: - AXValue holding attributes (expect these to return AXValueRef)

    // These will typically be unwrapped by a helper function (like ValueParser or similar) into their Swift types.
    public static var position: Attribute<CGPoint> { Attribute<CGPoint>(AXAttributeNames.kAXPositionAttribute) }
    public static var size: Attribute<CGSize> { Attribute<CGSize>(AXAttributeNames.kAXSizeAttribute) }

    // Note: CGRect for kAXBoundsAttribute is also common if available.
    // For now, relying on position and size.

    // Add more attributes as needed from ApplicationServices/HIServices Accessibility Attributes...

    /// The raw accessibility attribute key string.
    ///
    /// This contains the actual Core Foundation constant string used
    /// by the accessibility APIs (e.g., "AXRole", "AXTitle").
    public let rawValue: String
}
