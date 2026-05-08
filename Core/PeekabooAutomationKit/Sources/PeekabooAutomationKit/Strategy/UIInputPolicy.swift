import CoreGraphics
import Foundation

/// Per-app overrides for action/synthesis strategy selection.
public struct AppUIInputPolicy: Codable, Equatable, Sendable {
    public var defaultStrategy: UIInputStrategy?
    public var click: UIInputStrategy?
    public var scroll: UIInputStrategy?
    public var type: UIInputStrategy?
    public var hotkey: UIInputStrategy?
    public var setValue: UIInputStrategy?
    public var performAction: UIInputStrategy?

    public init(
        defaultStrategy: UIInputStrategy? = nil,
        click: UIInputStrategy? = nil,
        scroll: UIInputStrategy? = nil,
        type: UIInputStrategy? = nil,
        hotkey: UIInputStrategy? = nil,
        setValue: UIInputStrategy? = nil,
        performAction: UIInputStrategy? = nil)
    {
        self.defaultStrategy = defaultStrategy
        self.click = click
        self.scroll = scroll
        self.type = type
        self.hotkey = hotkey
        self.setValue = setValue
        self.performAction = performAction
    }

    public func strategy(for verb: UIInputVerb) -> UIInputStrategy? {
        switch verb {
        case .click:
            self.click ?? self.defaultStrategy
        case .scroll:
            self.scroll ?? self.defaultStrategy
        case .type:
            self.type ?? self.defaultStrategy
        case .hotkey:
            self.hotkey ?? self.defaultStrategy
        case .setValue:
            self.setValue ?? self.defaultStrategy
        case .performAction:
            self.performAction ?? self.defaultStrategy
        }
    }
}

/// Resolved input policy for action/synthesis dispatch.
public struct UIInputPolicy: Codable, Equatable, Sendable {
    public static let currentBehavior = UIInputPolicy(
        defaultStrategy: .synthFirst,
        click: .actionFirst,
        scroll: .actionFirst,
        setValue: .actionOnly,
        performAction: .actionOnly)

    public var defaultStrategy: UIInputStrategy
    public var click: UIInputStrategy?
    public var scroll: UIInputStrategy?
    public var type: UIInputStrategy?
    public var hotkey: UIInputStrategy?
    public var setValue: UIInputStrategy?
    public var performAction: UIInputStrategy?
    public var perApp: [String: AppUIInputPolicy]

    public init(
        defaultStrategy: UIInputStrategy = .synthFirst,
        click: UIInputStrategy? = nil,
        scroll: UIInputStrategy? = nil,
        type: UIInputStrategy? = nil,
        hotkey: UIInputStrategy? = nil,
        setValue: UIInputStrategy? = nil,
        performAction: UIInputStrategy? = nil,
        perApp: [String: AppUIInputPolicy] = [:])
    {
        self.defaultStrategy = defaultStrategy
        self.click = click
        self.scroll = scroll
        self.type = type
        self.hotkey = hotkey
        self.setValue = setValue
        self.performAction = performAction
        self.perApp = perApp
    }

    public func strategy(for verb: UIInputVerb, bundleIdentifier: String? = nil) -> UIInputStrategy {
        if let bundleIdentifier,
           let appPolicy = self.perApp[bundleIdentifier],
           let appStrategy = appPolicy.strategy(for: verb)
        {
            return appStrategy
        }

        switch verb {
        case .click:
            return self.click ?? self.defaultStrategy
        case .scroll:
            return self.scroll ?? self.defaultStrategy
        case .type:
            return self.type ?? self.defaultStrategy
        case .hotkey:
            return self.hotkey ?? self.defaultStrategy
        case .setValue:
            return self.setValue ?? self.defaultStrategy
        case .performAction:
            return self.performAction ?? self.defaultStrategy
        }
    }
}

/// Metadata emitted by verb services after choosing an input path.
public struct UIInputExecutionResult: Codable, Equatable, Sendable {
    public var verb: UIInputVerb
    public var strategy: UIInputStrategy
    public var path: UIInputExecutionPath
    public var fallbackReason: UIInputFallbackReason?
    public var bundleIdentifier: String?
    public var elementRole: String?
    public var actionName: String?
    public var anchorPoint: CGPoint?
    public var duration: TimeInterval

    public init(
        verb: UIInputVerb,
        strategy: UIInputStrategy,
        path: UIInputExecutionPath,
        fallbackReason: UIInputFallbackReason? = nil,
        bundleIdentifier: String? = nil,
        elementRole: String? = nil,
        actionName: String? = nil,
        anchorPoint: CGPoint? = nil,
        duration: TimeInterval = 0)
    {
        self.verb = verb
        self.strategy = strategy
        self.path = path
        self.fallbackReason = fallbackReason
        self.bundleIdentifier = bundleIdentifier
        self.elementRole = elementRole
        self.actionName = actionName
        self.anchorPoint = anchorPoint
        self.duration = duration
    }
}
