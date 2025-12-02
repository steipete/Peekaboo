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
    ///   - cadence: Typing cadence (fixed delay or human WPM)
    ///   - sessionId: Session ID for element resolution
    func typeActions(_ actions: [TypeAction], cadence: TypingCadence, sessionId: String?) async throws -> TypeResult

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
    ///   - profile: Movement profile for the swipe path
    func swipe(from: CGPoint, to: CGPoint, duration: Int, steps: Int, profile: MouseMovementProfile) async throws

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

    // swiftlint:disable function_parameter_count
    /// Perform a drag operation between two points
    /// - Parameters:
    ///   - from: Starting point for the drag
    ///   - to: Ending point for the drag
    ///   - duration: Duration of the drag in milliseconds
    ///   - steps: Number of intermediate steps
    ///   - modifiers: Modifier keys to hold during drag (comma-separated: cmd,shift,option,ctrl)
    ///   - profile: Movement profile for the drag path
    func drag(
        from: CGPoint,
        to: CGPoint,
        duration: Int,
        steps: Int,
        modifiers: String?,
        profile: MouseMovementProfile) async throws
    // swiftlint:enable function_parameter_count

    /// Move the mouse cursor to a specific location
    /// - Parameters:
    ///   - to: Target location for the mouse cursor
    ///   - duration: Duration of the movement in milliseconds (0 for instant)
    ///   - steps: Number of intermediate steps for smooth movement
    ///   - profile: Movement profile that controls path generation
    func moveMouse(to: CGPoint, duration: Int, steps: Int, profile: MouseMovementProfile) async throws

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

/// Profiles controlling how mouse paths are generated.
public enum MouseMovementProfile: Sendable, Equatable, Codable {
    /// Linear interpolation between the current and target coordinate.
    case linear
    /// Human-style motion with eased velocity, micro-jitter, and subtle overshoot.
    case human(HumanMouseProfileConfiguration = .default)

    private enum CodingKeys: String, CodingKey { case kind, profile }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "linear":
            self = .linear
        case "human":
            let profile = try container.decodeIfPresent(HumanMouseProfileConfiguration.self, forKey: .profile) ??
                .default
            self = .human(profile)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unknown MouseMovementProfile kind: \(kind)")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .linear:
            try container.encode("linear", forKey: .kind)
        case let .human(profile):
            try container.encode("human", forKey: .kind)
            try container.encode(profile, forKey: .profile)
        }
    }
}

/// Tunable values for the human-style mouse movement profile.
public struct HumanMouseProfileConfiguration: Sendable, Equatable, Codable {
    public var jitterAmplitude: CGFloat
    public var overshootProbability: Double
    public var overshootFractionRange: ClosedRange<Double>
    public var settleRadius: CGFloat
    public var randomSeed: UInt64?

    public init(
        jitterAmplitude: CGFloat = 0.35,
        overshootProbability: Double = 0.2,
        overshootFractionRange: ClosedRange<Double> = 0.02...0.06,
        settleRadius: CGFloat = 6,
        randomSeed: UInt64? = nil)
    {
        self.jitterAmplitude = jitterAmplitude
        self.overshootProbability = overshootProbability
        self.overshootFractionRange = overshootFractionRange
        self.settleRadius = settleRadius
        self.randomSeed = randomSeed
    }

    public static let `default` = HumanMouseProfileConfiguration()
}

/// Result of element detection
public struct ElementDetectionResult: Sendable, Codable {
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
public struct DetectedElements: Sendable, Codable {
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
public nonisolated struct WindowContext: Sendable, Codable {
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
public struct DetectionMetadata: Sendable, Codable {
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
public enum ClickTarget: Sendable, Codable {
    /// Click on element by ID (e.g., "B1")
    case elementId(String)

    /// Click at specific coordinates
    case coordinates(CGPoint)

    /// Click on element matching query
    case query(String)

    private enum CodingKeys: String, CodingKey { case kind, value, x, y }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "elementId":
            self = try .elementId(container.decode(String.self, forKey: .value))
        case "coordinates":
            let x = try container.decode(CGFloat.self, forKey: .x)
            let y = try container.decode(CGFloat.self, forKey: .y)
            self = .coordinates(CGPoint(x: x, y: y))
        case "query":
            self = try .query(container.decode(String.self, forKey: .value))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unknown ClickTarget kind: \(kind)")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .elementId(id):
            try container.encode("elementId", forKey: .kind)
            try container.encode(id, forKey: .value)
        case let .coordinates(point):
            try container.encode("coordinates", forKey: .kind)
            try container.encode(point.x, forKey: .x)
            try container.encode(point.y, forKey: .y)
        case let .query(query):
            try container.encode("query", forKey: .kind)
            try container.encode(query, forKey: .value)
        }
    }
}

// ClickType is now in PeekabooFoundation

// ScrollDirection is now in PeekabooFoundation

// SwipeDirection is now in PeekabooFoundation

// ModifierKey is now in PeekabooFoundation

public struct ScrollRequest: Sendable, Codable {
    public var direction: PeekabooFoundation.ScrollDirection
    public var amount: Int
    public var target: String?
    public var smooth: Bool
    public var delay: Int
    public var sessionId: String?

    public init(
        direction: PeekabooFoundation.ScrollDirection,
        amount: Int,
        target: String? = nil,
        smooth: Bool = false,
        delay: Int = 10,
        sessionId: String? = nil)
    {
        self.direction = direction
        self.amount = amount
        self.target = target
        self.smooth = smooth
        self.delay = delay
        self.sessionId = sessionId
    }
}

/// Result of waiting for an element
public struct WaitForElementResult: Sendable, Codable {
    public let found: Bool
    public let element: DetectedElement?
    public let waitTime: TimeInterval
    public let warnings: [String]

    public init(found: Bool, element: DetectedElement?, waitTime: TimeInterval, warnings: [String] = []) {
        self.found = found
        self.element = element
        self.waitTime = waitTime
        self.warnings = warnings
    }

    public init(found: Bool, element: DetectedElement?, waitTime: TimeInterval) {
        self.init(found: found, element: element, waitTime: waitTime, warnings: [])
    }
}

public struct UIFocusInfo: Sendable, Codable {
    public let role: String
    public let title: String?
    public let value: String?
    public let frame: CGRect
    public let applicationName: String
    public let bundleIdentifier: String
    public let processId: Int

    public init(
        role: String,
        title: String?,
        value: String?,
        frame: CGRect,
        applicationName: String,
        bundleIdentifier: String,
        processId: Int)
    {
        self.role = role
        self.title = title
        self.value = value
        self.frame = frame
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.processId = processId
    }
}

// TypeAction is now in PeekabooFoundation

// SpecialKey is now in PeekabooFoundation

/// Result of typing operations
public struct TypeResult: Sendable, Codable {
    public let totalCharacters: Int
    public let keyPresses: Int

    public init(totalCharacters: Int, keyPresses: Int) {
        self.totalCharacters = totalCharacters
        self.keyPresses = keyPresses
    }
}

/// Criteria for searching UI elements
public enum UIElementSearchCriteria: Sendable, Codable {
    case label(String)
    case identifier(String)
    case type(String)

    private enum CodingKeys: String, CodingKey { case kind, value }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        let value = try container.decode(String.self, forKey: .value)
        switch kind {
        case "label": self = .label(value)
        case "identifier": self = .identifier(value)
        case "type": self = .type(value)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unknown UIElementSearchCriteria kind: \(kind)")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .label(value):
            try container.encode("label", forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .identifier(value):
            try container.encode("identifier", forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .type(value):
            try container.encode("type", forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }
}
