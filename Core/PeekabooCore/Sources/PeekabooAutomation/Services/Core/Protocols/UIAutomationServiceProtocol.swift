import CoreGraphics
import Foundation
import PeekabooFoundation

/// Protocol defining UI automation operations
@MainActor
public protocol UIAutomationServiceProtocol: Sendable {
    /// Detect UI elements in a screenshot
    /// - Parameters:
    ///   - imageData: The screenshot image data
    ///   - sessionId: Optional session ID to use for caching
    ///   - windowContext: Optional window context for coordinate mapping
    /// - Returns: Detection result with identified elements
    func detectElements(in imageData: Data, sessionId: String?, windowContext: WindowContext?) async throws
        -> ElementDetectionResult

    /// Click at a specific point or element
    /// - Parameters:
    ///   - target: Click target (element ID, coordinates, or query)
    ///   - clickType: Type of click (single, double, right)
    ///   - sessionId: Session ID for element resolution
    func click(target: ClickTarget, clickType: ClickType, sessionId: String?) async throws

    /// Type text at current focus or specific element
    /// - Parameters:
    ///   - text: Text to type (supports special keys)
    ///   - target: Optional target element
    ///   - clearExisting: Whether to clear existing text first
    ///   - typingDelay: Delay between keystrokes in milliseconds
    ///   - sessionId: Session ID for element resolution
    func type(text: String, target: String?, clearExisting: Bool, typingDelay: Int, sessionId: String?) async throws

    /// Type using advanced typing actions (text, special keys, key sequences)
    /// - Parameters:
    ///   - actions: Array of typing actions to perform
    ///   - typingDelay: Delay between keystrokes in milliseconds
    ///   - sessionId: Session ID for element resolution
    func typeActions(_ actions: [TypeAction], typingDelay: Int, sessionId: String?) async throws -> TypeResult

    /// Scroll in a specific direction with the supplied configuration.
    /// - Parameter request: Scroll configuration including direction, amount, options, and session context.
    func scroll(_ request: ScrollRequest) async throws

    /// Press a hotkey combination
    /// - Parameters:
    ///   - keys: Comma-separated key combination (e.g., "cmd,c")
    ///   - holdDuration: How long to hold the keys in milliseconds
    func hotkey(keys: String, holdDuration: Int) async throws

    /// Perform a swipe/drag gesture
    /// - Parameters:
    ///   - from: Starting point
    ///   - to: Ending point
    ///   - duration: Duration of the swipe in milliseconds
    ///   - steps: Number of intermediate steps
    func swipe(from: CGPoint, to: CGPoint, duration: Int, steps: Int) async throws

    /// Check if accessibility permission is granted
    /// - Returns: True if permission is granted
    func hasAccessibilityPermission() async -> Bool

    /// Wait for an element to appear and become actionable
    /// - Parameters:
    ///   - target: The element target to wait for
    ///   - timeout: Maximum time to wait in seconds
    ///   - sessionId: Session ID for element resolution
    /// - Returns: Result indicating if element was found with timing info
    func waitForElement(target: ClickTarget, timeout: TimeInterval, sessionId: String?) async throws
        -> WaitForElementResult

    /// Perform a drag operation between two points
    /// - Parameters:
    ///   - from: Starting point for the drag
    ///   - to: Ending point for the drag
    ///   - duration: Duration of the drag in milliseconds
    ///   - steps: Number of intermediate steps
    ///   - modifiers: Modifier keys to hold during drag (comma-separated: cmd,shift,option,ctrl)
    func drag(from: CGPoint, to: CGPoint, duration: Int, steps: Int, modifiers: String?) async throws

    /// Move the mouse cursor to a specific location
    /// - Parameters:
    ///   - to: Target location for the mouse cursor
    ///   - duration: Duration of the movement in milliseconds (0 for instant)
    ///   - steps: Number of intermediate steps for smooth movement
    func moveMouse(to: CGPoint, duration: Int, steps: Int) async throws

    /// Get information about the currently focused UI element
    /// - Returns: Information about the focused element, or nil if no element has focus
    func getFocusedElement() -> UIFocusInfo?

    /// Find an element matching the given criteria
    /// - Parameters:
    ///   - criteria: Search criteria for finding the element
    ///   - appName: Optional application name to search within
    /// - Returns: The first element matching the criteria
    /// - Throws: PeekabooError.elementNotFound if no matching element is found
    func findElement(matching criteria: UIElementSearchCriteria, in appName: String?) async throws -> DetectedElement
}

/// Result of element detection
public struct ElementDetectionResult: Sendable {
    /// Unique session identifier
    public let sessionId: String

    /// Path to the annotated screenshot
    public let screenshotPath: String

    /// Detected UI elements organized by type
    public let elements: DetectedElements

    /// Detection metadata
    public let metadata: DetectionMetadata

    public init(
        sessionId: String,
        screenshotPath: String,
        elements: DetectedElements,
        metadata: DetectionMetadata)
    {
        self.sessionId = sessionId
        self.screenshotPath = screenshotPath
        self.elements = elements
        self.metadata = metadata
    }
}

/// Container for detected UI elements by type
public struct DetectedElements: Sendable {
    public let buttons: [DetectedElement]
    public let textFields: [DetectedElement]
    public let links: [DetectedElement]
    public let images: [DetectedElement]
    public let groups: [DetectedElement]
    public let sliders: [DetectedElement]
    public let checkboxes: [DetectedElement]
    public let menus: [DetectedElement]
    public let other: [DetectedElement]

    /// All elements as a flat array
    public var all: [DetectedElement] {
        self.buttons + self.textFields + self.links + self.images + self.groups + self.sliders + self.checkboxes + self
            .menus + self.other
    }

    /// Find element by ID
    public func findById(_ id: String) -> DetectedElement? {
        // Find element by ID
        self.all.first { $0.id == id }
    }

    public init(
        buttons: [DetectedElement] = [],
        textFields: [DetectedElement] = [],
        links: [DetectedElement] = [],
        images: [DetectedElement] = [],
        groups: [DetectedElement] = [],
        sliders: [DetectedElement] = [],
        checkboxes: [DetectedElement] = [],
        menus: [DetectedElement] = [],
        other: [DetectedElement] = [])
    {
        self.buttons = buttons
        self.textFields = textFields
        self.links = links
        self.images = images
        self.groups = groups
        self.sliders = sliders
        self.checkboxes = checkboxes
        self.menus = menus
        self.other = other
    }
}

/// A detected UI element
public struct DetectedElement: Sendable, Codable {
    /// Unique identifier (e.g., "B1", "T2")
    public let id: String

    /// Element type
    public let type: ElementType

    /// Display label or text
    public let label: String?

    /// Current value (for text fields, sliders, etc.)
    public let value: String?

    /// Bounding rectangle
    public let bounds: CGRect

    /// Whether the element is enabled
    public let isEnabled: Bool

    /// Whether the element is selected/checked
    public let isSelected: Bool?

    /// Additional attributes
    public let attributes: [String: String]

    public init(
        id: String,
        type: ElementType,
        label: String? = nil,
        value: String? = nil,
        bounds: CGRect,
        isEnabled: Bool = true,
        isSelected: Bool? = nil,
        attributes: [String: String] = [:])
    {
        self.id = id
        self.type = type
        self.label = label
        self.value = value
        self.bounds = bounds
        self.isEnabled = isEnabled
        self.isSelected = isSelected
        self.attributes = attributes
    }
}

// ElementType is now in PeekabooFoundation

/// Window context information for element detection
public nonisolated struct WindowContext: Sendable {
    /// Application name
    public let applicationName: String?

    /// Window title
    public let windowTitle: String?

    /// Window bounds in screen coordinates
    public let windowBounds: CGRect?

    /// Whether element detection should attempt to focus embedded web content when inputs are missing
    public let shouldFocusWebContent: Bool?

    public init(
        applicationName: String? = nil,
        windowTitle: String? = nil,
        windowBounds: CGRect? = nil,
        shouldFocusWebContent: Bool? = nil)
    {
        self.applicationName = applicationName
        self.windowTitle = windowTitle
        self.windowBounds = windowBounds
        self.shouldFocusWebContent = shouldFocusWebContent
    }
}

/// Metadata about element detection
public struct DetectionMetadata: Sendable {
    /// Time taken for detection
    public let detectionTime: TimeInterval

    /// Number of elements detected
    public let elementCount: Int

    /// Detection method used
    public let method: String

    /// Any warnings during detection
    public let warnings: [String]

    /// Window context information (if available)
    public let windowContext: WindowContext?

    /// Whether a dialog was captured instead of a regular window
    public let isDialog: Bool

    public init(
        detectionTime: TimeInterval,
        elementCount: Int,
        method: String,
        warnings: [String] = [],
        windowContext: WindowContext? = nil,
        isDialog: Bool = false)
    {
        self.detectionTime = detectionTime
        self.elementCount = elementCount
        self.method = method
        self.warnings = warnings
        self.windowContext = windowContext
        self.isDialog = isDialog
    }
}

/// Target for click operations
public enum ClickTarget: Sendable {
    /// Click on element by ID (e.g., "B1")
    case elementId(String)

    /// Click at specific coordinates
    case coordinates(CGPoint)

    /// Click on element matching query
    case query(String)
}

// ClickType is now in PeekabooFoundation

// ScrollDirection is now in PeekabooFoundation

// SwipeDirection is now in PeekabooFoundation

// ModifierKey is now in PeekabooFoundation

/// Result of waiting for an element
public struct WaitForElementResult: Sendable {
    public let found: Bool
    public let element: DetectedElement?
    public let waitTime: TimeInterval

    public init(found: Bool, element: DetectedElement?, waitTime: TimeInterval) {
        self.found = found
        self.element = element
        self.waitTime = waitTime
    }
}

// TypeAction is now in PeekabooFoundation

// SpecialKey is now in PeekabooFoundation

/// Result of typing operations
public struct TypeResult: Sendable {
    public let totalCharacters: Int
    public let keyPresses: Int

    public init(totalCharacters: Int, keyPresses: Int) {
        self.totalCharacters = totalCharacters
        self.keyPresses = keyPresses
    }
}

/// Criteria for searching UI elements
public enum UIElementSearchCriteria: Sendable {
    case label(String)
    case identifier(String)
    case type(String)
}
