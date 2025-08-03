//
//  VisualizerXPCProtocol.swift
//  PeekabooCore
//
//  Created by Peekaboo on 2025-01-30.
//

import CoreGraphics
import Foundation

/// Protocol defining the XPC interface for visual feedback communication
/// between the CLI/MCP and the Peekaboo.app
@objc public protocol VisualizerXPCProtocol: NSObjectProtocol {
    // MARK: - Screenshot Feedback

    /// Shows a camera flash effect for screenshot capture
    /// - Parameters:
    ///   - rect: The area that was captured
    ///   - reply: Callback with success status
    func showScreenshotFlash(in rect: CGRect, reply: @Sendable @escaping (Bool) -> Void)

    // MARK: - Click Feedback

    /// Shows click feedback animation
    /// - Parameters:
    ///   - point: The location of the click
    ///   - type: Type of click ("single", "double", "right")
    ///   - reply: Callback with success status
    func showClickFeedback(at point: CGPoint, type: String, reply: @Sendable @escaping (Bool) -> Void)

    // MARK: - Typing Feedback

    /// Shows typing feedback with keyboard visualization
    /// - Parameters:
    ///   - keys: Array of keys being typed
    ///   - duration: Duration to show the keyboard
    ///   - reply: Callback with success status
    func showTypingFeedback(keys: [String], duration: TimeInterval, reply: @Sendable @escaping (Bool) -> Void)

    // MARK: - Scroll Feedback

    /// Shows scroll direction indicators
    /// - Parameters:
    ///   - point: Location where scroll occurs
    ///   - direction: Scroll direction ("up", "down", "left", "right")
    ///   - amount: Number of scroll units
    ///   - reply: Callback with success status
    func showScrollFeedback(
        at point: CGPoint,
        direction: String,
        amount: Int,
        reply: @Sendable @escaping (Bool) -> Void)

    // MARK: - Mouse Movement

    /// Shows mouse movement trail
    /// - Parameters:
    ///   - fromPoint: Starting point
    ///   - toPoint: Ending point
    ///   - duration: Animation duration
    ///   - reply: Callback with success status
    func showMouseMovement(
        from fromPoint: CGPoint,
        to toPoint: CGPoint,
        duration: TimeInterval,
        reply: @Sendable @escaping (Bool) -> Void)

    // MARK: - Swipe/Drag

    /// Shows swipe or drag gesture visualization
    /// - Parameters:
    ///   - fromPoint: Starting point
    ///   - toPoint: Ending point
    ///   - duration: Gesture duration
    ///   - reply: Callback with success status
    func showSwipeGesture(
        from fromPoint: CGPoint,
        to toPoint: CGPoint,
        duration: TimeInterval,
        reply: @Sendable @escaping (Bool) -> Void)

    // MARK: - Hotkey Display

    /// Shows hotkey combination display
    /// - Parameters:
    ///   - keys: Array of keys in the combination
    ///   - duration: Display duration
    ///   - reply: Callback with success status
    func showHotkeyDisplay(keys: [String], duration: TimeInterval, reply: @Sendable @escaping (Bool) -> Void)

    // MARK: - App Lifecycle

    /// Shows app launch animation
    /// - Parameters:
    ///   - appName: Name of the app being launched
    ///   - iconPath: Optional path to app icon
    ///   - reply: Callback with success status
    func showAppLaunch(appName: String, iconPath: String?, reply: @Sendable @escaping (Bool) -> Void)

    /// Shows app quit animation
    /// - Parameters:
    ///   - appName: Name of the app being quit
    ///   - iconPath: Optional path to app icon
    ///   - reply: Callback with success status
    func showAppQuit(appName: String, iconPath: String?, reply: @Sendable @escaping (Bool) -> Void)

    // MARK: - Window Operations

    /// Shows window operation feedback
    /// - Parameters:
    ///   - operation: Type of operation ("move", "resize", "minimize", "close")
    ///   - windowRect: Current or target window rectangle
    ///   - duration: Animation duration
    ///   - reply: Callback with success status
    func showWindowOperation(
        operation: String,
        windowRect: CGRect,
        duration: TimeInterval,
        reply: @Sendable @escaping (Bool) -> Void)

    // MARK: - Menu Navigation

    /// Shows menu navigation path
    /// - Parameters:
    ///   - menuPath: Array of menu items in the path
    ///   - reply: Callback with success status
    func showMenuNavigation(menuPath: [String], reply: @Sendable @escaping (Bool) -> Void)

    // MARK: - Dialog Interactions

    /// Shows dialog interaction feedback
    /// - Parameters:
    ///   - elementType: Type of element ("button", "textfield", "checkbox")
    ///   - elementRect: Rectangle of the element
    ///   - action: Action performed ("click", "focus", "type")
    ///   - reply: Callback with success status
    func showDialogInteraction(
        elementType: String,
        elementRect: CGRect,
        action: String,
        reply: @Sendable @escaping (Bool) -> Void)

    // MARK: - Space Switching

    /// Shows space switching animation
    /// - Parameters:
    ///   - fromSpace: Source space index
    ///   - toSpace: Destination space index
    ///   - direction: Animation direction ("left", "right")
    ///   - reply: Callback with success status
    func showSpaceSwitch(
        from fromSpace: Int,
        to toSpace: Int,
        direction: String,
        reply: @Sendable @escaping (Bool) -> Void)

    // MARK: - Element Detection

    /// Shows detected UI elements with overlays
    /// - Parameters:
    ///   - elements: Dictionary of element IDs to their rectangles
    ///   - duration: Display duration
    ///   - reply: Callback with success status
    func showElementDetection(
        elements: [String: CGRect],
        duration: TimeInterval,
        reply: @Sendable @escaping (Bool) -> Void)

    /// Shows annotated screenshot with UI element overlays
    /// - Parameters:
    ///   - imageData: The screenshot image data
    ///   - elementData: Serialized array of detected elements
    ///   - windowBounds: The window bounds for coordinate mapping
    ///   - duration: Display duration
    ///   - reply: Callback with success status
    func showAnnotatedScreenshot(
        imageData: Data,
        elementData: Data,
        windowBounds: CGRect,
        duration: TimeInterval,
        reply: @Sendable @escaping (Bool) -> Void)

    // MARK: - Configuration

    /// Checks if visual feedback is enabled
    /// - Parameter reply: Callback with enabled status
    func isVisualFeedbackEnabled(reply: @Sendable @escaping (Bool) -> Void)

    /// Updates visual feedback settings
    /// - Parameters:
    ///   - settings: Dictionary of setting keys and values
    ///   - reply: Callback with success status
    func updateSettings(_ settings: [String: Any], reply: @Sendable @escaping (Bool) -> Void)
}

/// Service name for the XPC connection
public let VisualizerXPCServiceName = "boo.peekaboo.visualizer"

/// Notification names for visualizer events
extension Notification.Name {
    public static let visualizerConnected = Notification.Name("boo.peekaboo.visualizer.connected")
    public static let visualizerDisconnected = Notification.Name("boo.peekaboo.visualizer.disconnected")
    public static let visualizerSettingsChanged = Notification.Name("boo.peekaboo.visualizer.settingsChanged")
}

/// Error types for visualizer operations
public enum VisualizerError: Error, LocalizedError {
    case notConnected
    case appNotRunning
    case animationFailed(String)
    case invalidParameter(String)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            "Visualizer XPC service is not connected"
        case .appNotRunning:
            "Peekaboo.app is not running"
        case let .animationFailed(reason):
            "Animation failed: \(reason)"
        case let .invalidParameter(param):
            "Invalid parameter: \(param)"
        }
    }
}

/// Settings keys for visual feedback configuration
public enum VisualizerSettings {
    public static let enabledKey = "visualFeedbackEnabled"
    public static let animationSpeedKey = "animationSpeed"
    public static let effectIntensityKey = "effectIntensity"
    public static let soundEffectsKey = "soundEffectsEnabled"
    public static let reduceMotionKey = "respectReduceMotion"

    // Per-action toggles
    public static let screenshotFlashKey = "screenshotFlashEnabled"
    public static let clickAnimationKey = "clickAnimationEnabled"
    public static let typingFeedbackKey = "typingFeedbackEnabled"
    public static let scrollIndicatorKey = "scrollIndicatorEnabled"
    public static let mouseTrailKey = "mouseTrailEnabled"
    public static let hotkeyDisplayKey = "hotkeyDisplayEnabled"
    public static let appAnimationsKey = "appAnimationsEnabled"
    public static let windowAnimationsKey = "windowAnimationsEnabled"
    public static let menuHighlightKey = "menuHighlightEnabled"
    public static let dialogFeedbackKey = "dialogFeedbackEnabled"
    public static let spaceAnimationKey = "spaceAnimationEnabled"
    public static let elementOverlaysKey = "elementOverlaysEnabled"
}
