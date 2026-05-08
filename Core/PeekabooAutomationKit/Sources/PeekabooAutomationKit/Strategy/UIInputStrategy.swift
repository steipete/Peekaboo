import Foundation

/// Policy for choosing between accessibility action invocation and synthetic input.
public enum UIInputStrategy: String, Codable, CaseIterable, Equatable, Sendable {
    /// Try accessibility action invocation first, then fall back to synthetic input when unsupported.
    case actionFirst

    /// Use synthetic input first. This preserves the historical behavior.
    case synthFirst

    /// Use accessibility action invocation only.
    case actionOnly

    /// Use synthetic input only.
    case synthOnly
}

/// UI input verbs that can choose an action/synthesis delivery strategy.
public enum UIInputVerb: String, Codable, CaseIterable, Equatable, Sendable {
    case click
    case scroll
    case type
    case hotkey
    case setValue
    case performAction
}

/// The concrete input path used for one interaction.
public enum UIInputExecutionPath: String, Codable, Equatable, Sendable {
    case action
    case synth
}

/// Why a strategy fell back from action invocation to synthetic input.
public enum UIInputFallbackReason: String, Codable, Equatable, Sendable {
    case actionUnsupported
    case attributeUnsupported
    case valueNotSettable
    case secureValueNotAllowed
    case missingElement
    case staleElement
    case menuShortcutUnavailable
    case actionFailed
}
