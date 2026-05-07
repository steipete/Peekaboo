import CoreGraphics
import Darwin
import Foundation
import PeekabooFoundation

public struct DragOperationRequest: Sendable, Equatable {
    public let from: CGPoint
    public let to: CGPoint
    public let duration: Int
    public let steps: Int
    public let modifiers: String?
    public let profile: MouseMovementProfile

    public init(
        from: CGPoint,
        to: CGPoint,
        duration: Int,
        steps: Int,
        modifiers: String?,
        profile: MouseMovementProfile)
    {
        self.from = from
        self.to = to
        self.duration = duration
        self.steps = steps
        self.modifiers = modifiers
        self.profile = profile
    }
}

/// Protocol defining UI automation operations
@MainActor
public protocol UIAutomationServiceProtocol: Sendable {
    /// Detect UI elements in a screenshot
    /// - Parameters:
    ///   - imageData: The screenshot image data
    ///   - snapshotId: Optional snapshot ID to use for caching
    ///   - windowContext: Optional window context for coordinate mapping
    /// - Returns: Detection result with identified elements
    func detectElements(in imageData: Data, snapshotId: String?, windowContext: WindowContext?) async throws
        -> ElementDetectionResult

    /// Click at a specific point or element
    /// - Parameters:
    ///   - target: Click target (element ID, coordinates, or query)
    ///   - clickType: Type of click (single, double, right)
    ///   - snapshotId: Snapshot ID for element resolution
    func click(target: ClickTarget, clickType: ClickType, snapshotId: String?) async throws

    /// Type text at current focus or specific element
    /// - Parameters:
    ///   - text: Text to type (supports special keys)
    ///   - target: Optional target element
    ///   - clearExisting: Whether to clear existing text first
    ///   - typingDelay: Delay between keystrokes in milliseconds
    ///   - snapshotId: Snapshot ID for element resolution
    func type(text: String, target: String?, clearExisting: Bool, typingDelay: Int, snapshotId: String?) async throws

    /// Type using advanced typing actions (text, special keys, key sequences)
    /// - Parameters:
    ///   - actions: Array of typing actions to perform
    ///   - cadence: Typing cadence (fixed delay or human WPM)
    ///   - snapshotId: Snapshot ID for element resolution
    func typeActions(_ actions: [TypeAction], cadence: TypingCadence, snapshotId: String?) async throws -> TypeResult

    /// Scroll in a specific direction with the supplied configuration.
    /// - Parameter request: Scroll configuration including direction, amount, options, and snapshot context.
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
    ///   - snapshotId: Snapshot ID for element resolution
    /// - Returns: Result indicating if element was found with timing info
    func waitForElement(target: ClickTarget, timeout: TimeInterval, snapshotId: String?) async throws
        -> WaitForElementResult

    /// Perform a drag operation between two points
    /// - Parameter request: Drag configuration including coordinates, timing, modifiers, and profile.
    func drag(_ request: DragOperationRequest) async throws

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

/// Optional capability for automation services that can override the transport timeout used for element detection.
@MainActor
public protocol DetectElementsRequestTimeoutAdjusting: UIAutomationServiceProtocol {
    func detectElements(
        in imageData: Data,
        snapshotId: String?,
        windowContext: WindowContext?,
        requestTimeoutSec: TimeInterval) async throws -> ElementDetectionResult
}

/// Optional capability for automation services that can send hotkeys to a process without focusing it.
@MainActor
public protocol TargetedHotkeyServiceProtocol: UIAutomationServiceProtocol {
    var supportsTargetedHotkeys: Bool { get }
    var targetedHotkeyUnavailableReason: String? { get }
    var targetedHotkeyRequiresEventSynthesizingPermission: Bool { get }

    func hotkey(keys: String, holdDuration: Int, targetProcessIdentifier: pid_t) async throws
}

extension TargetedHotkeyServiceProtocol {
    public var supportsTargetedHotkeys: Bool {
        true
    }

    public var targetedHotkeyUnavailableReason: String? {
        nil
    }

    public var targetedHotkeyRequiresEventSynthesizingPermission: Bool {
        false
    }
}
