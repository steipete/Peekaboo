import CoreGraphics
import Foundation
import PeekabooFoundation

/// Target for capture operations
public enum CaptureTarget: Sendable {
    case screen(index: Int?)
    case window(app: String, index: Int?)
    case frontmost
    case area(CGRect)
}

/// Automation action
public enum AutomationAction: Sendable {
    case click(target: ClickTarget, type: ClickType)
    case type(text: String, target: String?, clear: Bool)
    case scroll(direction: ScrollDirection, amount: Int, target: String?)
    case hotkey(keys: String)
    case wait(milliseconds: Int)
}

/// Result of automation
public struct AutomationResult: Sendable {
    public let sessionId: String
    public let actions: [ExecutedAction]
    public let initialScreenshot: String?

    public init(sessionId: String, actions: [ExecutedAction], initialScreenshot: String?) {
        self.sessionId = sessionId
        self.actions = actions
        self.initialScreenshot = initialScreenshot
    }
}

/// An executed action with result
public struct ExecutedAction: Sendable {
    public let action: AutomationAction
    public let success: Bool
    public let duration: TimeInterval
    public let error: String?

    public init(action: AutomationAction, success: Bool, duration: TimeInterval, error: String?) {
        self.action = action
        self.success = success
        self.duration = duration
        self.error = error
    }
}
